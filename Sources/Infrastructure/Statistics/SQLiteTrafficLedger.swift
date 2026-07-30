import Foundation

actor SQLiteTrafficLedger: TrafficLedgerStoring {
  private let databaseURL: URL
  private var persistence: TrafficLedgerPersistence?
  private var runtimeState = TrafficLedgerRuntimeState()
  private var isPrepared = false
  private var lastPrunedLocalDay: String?

  init(databaseURL: URL) {
    self.databaseURL = databaseURL
  }

  func prepare(calendar: Calendar, now: Date) async throws -> TrafficStatisticsSnapshot {
    let persistence = try requirePersistence()
    try prepareIfNeeded(calendar: calendar, now: now, persistence: persistence)
    return try snapshot(calendar: calendar, now: now)
  }

  func beginMonitoring(
    version: String,
    at date: Date,
    calendar: Calendar
  ) async throws -> TrafficStatisticsSnapshot {
    let persistence = try preparedPersistence(calendar: calendar, now: date)
    try persistence.transaction {
      if runtimeState.currentSessionID == nil {
        try openCoreSession(version: version, at: date, persistence: persistence)
      } else if runtimeState.currentMihomoVersion != version {
        try replaceCoreSession(
          version: version,
          at: date,
          reason: "version_change",
          persistence: persistence
        )
      }
    }
    return try snapshot(calendar: calendar, now: date)
  }

  func record(
    _ observation: TrafficLedgerObservation,
    calendar: Calendar
  ) async throws -> TrafficStatisticsSnapshot {
    let persistence = try preparedPersistence(calendar: calendar, now: observation.observedAt)
    try persistence.transaction {
      let opensFreshSession = runtimeState.currentSessionID == nil
      if runtimeState.currentSessionID == nil {
        try openCoreSession(
          version: runtimeState.currentMihomoVersion ?? "unknown",
          at: observation.observedAt,
          persistence: persistence
        )
      }

      if !opensFreshSession {
        switch observation.transition {
        case .baselineEstablished:
          try recordReconnectGapIfNeeded(
            currentKernelTotal: observation.kernelTotal,
            observedAt: observation.observedAt,
            calendar: calendar,
            persistence: persistence
          )
        case .delta(let report):
          try add(
            report.categories,
            observedAt: observation.observedAt,
            calendar: calendar,
            persistence: persistence
          )
        case .countersReset:
          try replaceCoreSession(
            version: runtimeState.currentMihomoVersion ?? "unknown",
            at: observation.observedAt,
            reason: "counter_reset",
            persistence: persistence
          )
        }
      }

      runtimeState.lastObservedAt = observation.observedAt
      runtimeState.lastKernelTotal = observation.kernelTotal
      try persistence.saveRuntimeState(runtimeState)
      try pruneIfNeeded(
        calendar: calendar,
        now: observation.observedAt,
        persistence: persistence
      )
    }
    return try snapshot(calendar: calendar, now: observation.observedAt)
  }

  func startInterval(
    name: String,
    note: String?,
    at date: Date,
    calendar: Calendar
  ) async throws -> TrafficStatisticsSnapshot {
    let persistence = try preparedPersistence(calendar: calendar, now: date)
    let normalizedName = try TrafficIntervalInput.normalizedName(name)
    try persistence.transaction {
      try persistence.intervals.insert(
        id: UUID(),
        name: normalizedName,
        note: TrafficIntervalInput.normalizedNote(note),
        startedAt: date,
        baseline: try persistence.totals().proxy
      )
    }
    return try snapshot(calendar: calendar, now: date)
  }

  func stopInterval(
    id: UUID,
    at date: Date,
    calendar: Calendar
  ) async throws -> TrafficStatisticsSnapshot {
    let persistence = try preparedPersistence(calendar: calendar, now: date)
    try persistence.transaction {
      try persistence.intervals.complete(
        id: id,
        endedAt: date,
        baseline: try persistence.totals().proxy
      )
    }
    return try snapshot(calendar: calendar, now: date)
  }

  func renameInterval(
    id: UUID,
    name: String,
    calendar: Calendar,
    now: Date
  ) async throws -> TrafficStatisticsSnapshot {
    let persistence = try preparedPersistence(calendar: calendar, now: now)
    try persistence.transaction {
      try persistence.intervals.rename(
        id: id,
        name: try TrafficIntervalInput.normalizedName(name)
      )
    }
    return try snapshot(calendar: calendar, now: now)
  }

  func deleteInterval(
    id: UUID,
    calendar: Calendar,
    now: Date
  ) async throws -> TrafficStatisticsSnapshot {
    let persistence = try preparedPersistence(calendar: calendar, now: now)
    try persistence.transaction {
      try persistence.intervals.delete(id: id)
    }
    return try snapshot(calendar: calendar, now: now)
  }

  func interruptActiveIntervals(
    reason: TrafficIntervalEndReason,
    calendar: Calendar,
    now: Date
  ) async throws -> TrafficStatisticsSnapshot {
    let persistence = try preparedPersistence(calendar: calendar, now: now)
    try persistence.transaction {
      let interruptedAt = runtimeState.lastObservedAt ?? now
      try persistence.intervals.interruptActive(
        endedAt: interruptedAt,
        baseline: try persistence.totals().proxy,
        reason: reason
      )
      if let sessionID = runtimeState.currentSessionID {
        try persistence.closeCoreSession(
          id: sessionID,
          endedAt: interruptedAt,
          reason: reason.rawValue
        )
      }
      runtimeState.currentSessionID = nil
      runtimeState.currentMihomoVersion = nil
      runtimeState.lastKernelTotal = nil
      try persistence.saveRuntimeState(runtimeState)
    }
    return try snapshot(calendar: calendar, now: now)
  }

  func clear(calendar: Calendar, now: Date) async throws -> TrafficStatisticsSnapshot {
    let persistence = try requirePersistence()
    try persistence.reset()
    runtimeState = TrafficLedgerRuntimeState()
    isPrepared = true
    lastPrunedLocalDay = nil
    return try snapshot(calendar: calendar, now: now)
  }

  private func requirePersistence() throws -> TrafficLedgerPersistence {
    if let persistence {
      return persistence
    }
    let persistence = try TrafficLedgerPersistence(databaseURL: databaseURL)
    self.persistence = persistence
    return persistence
  }

  private func preparedPersistence(
    calendar: Calendar,
    now: Date
  ) throws -> TrafficLedgerPersistence {
    let persistence = try requirePersistence()
    try prepareIfNeeded(calendar: calendar, now: now, persistence: persistence)
    return persistence
  }

  private func prepareIfNeeded(
    calendar: Calendar,
    now: Date,
    persistence: TrafficLedgerPersistence
  ) throws {
    guard !isPrepared else {
      return
    }
    runtimeState = try persistence.loadRuntimeState()
    try persistence.transaction {
      let lifetime = try persistence.totals()
      let interruptedAt = runtimeState.lastObservedAt ?? now
      try persistence.intervals.interruptActive(
        endedAt: interruptedAt,
        baseline: lifetime.proxy,
        reason: .recovery
      )
      if let sessionID = runtimeState.currentSessionID {
        try persistence.closeCoreSession(
          id: sessionID,
          endedAt: interruptedAt,
          reason: TrafficIntervalEndReason.recovery.rawValue
        )
      }
      runtimeState.currentSessionID = nil
      runtimeState.currentMihomoVersion = nil
      runtimeState.lastKernelTotal = nil
      try persistence.saveRuntimeState(runtimeState)
      try pruneIfNeeded(calendar: calendar, now: now, persistence: persistence)
    }
    isPrepared = true
  }

  private func openCoreSession(
    version: String,
    at date: Date,
    persistence: TrafficLedgerPersistence
  ) throws {
    let sessionID = UUID()
    try persistence.createCoreSession(id: sessionID, version: version, startedAt: date)
    runtimeState.currentSessionID = sessionID
    runtimeState.currentMihomoVersion = version
    runtimeState.lastKernelTotal = nil
    try persistence.saveRuntimeState(runtimeState)
  }

  private func replaceCoreSession(
    version: String,
    at date: Date,
    reason: String,
    persistence: TrafficLedgerPersistence
  ) throws {
    if let sessionID = runtimeState.currentSessionID {
      try persistence.closeCoreSession(id: sessionID, endedAt: date, reason: reason)
    }
    try openCoreSession(version: version, at: date, persistence: persistence)
  }

  private func recordReconnectGapIfNeeded(
    currentKernelTotal: TrafficBytes,
    observedAt: Date,
    calendar: Calendar,
    persistence: TrafficLedgerPersistence
  ) throws {
    guard let previousKernelTotal = runtimeState.lastKernelTotal else {
      return
    }
    guard
      let gap = TrafficBytes.nonnegativeDelta(
        current: currentKernelTotal,
        previous: previousKernelTotal
      )
    else {
      try replaceCoreSession(
        version: runtimeState.currentMihomoVersion ?? "unknown",
        at: observedAt,
        reason: "counter_reset",
        persistence: persistence
      )
      return
    }
    try add(
      CategorizedTrafficBytes.zero.adding(gap, to: .unknown),
      observedAt: observedAt,
      calendar: calendar,
      persistence: persistence
    )
  }

  private func add(
    _ categories: CategorizedTrafficBytes,
    observedAt: Date,
    calendar: Calendar,
    persistence: TrafficLedgerPersistence
  ) throws {
    guard let sessionID = runtimeState.currentSessionID else {
      throw TrafficStatisticsError.database("缺少内核统计会话")
    }
    try persistence.add(
      categories,
      observedAt: observedAt,
      calendar: calendar,
      coreSessionID: sessionID
    )
  }

  private func pruneIfNeeded(
    calendar: Calendar,
    now: Date,
    persistence: TrafficLedgerPersistence
  ) throws {
    let localDay = TrafficLedgerPersistence.localDay(for: now, calendar: calendar)
    guard localDay != lastPrunedLocalDay else {
      return
    }
    guard let cutoff = calendar.date(byAdding: .day, value: -365, to: now) else {
      throw TrafficStatisticsError.database("无法计算分钟桶保留时间")
    }
    try persistence.pruneBuckets(before: cutoff)
    lastPrunedLocalDay = localDay
  }

  private func snapshot(calendar: Calendar, now: Date) throws -> TrafficStatisticsSnapshot {
    let persistence = try requirePersistence()
    let lifetime = try persistence.totals()
    let localDay = TrafficLedgerPersistence.localDay(for: now, calendar: calendar)
    let recentLocalDays = try recentLocalDays(calendar: calendar, now: now)
    let storedDays = try persistence.dailyTotals(
      category: .proxy,
      since: recentLocalDays.first ?? localDay
    )
    let storedByDay = Dictionary(uniqueKeysWithValues: storedDays.map { ($0.localDay, $0) })
    return TrafficStatisticsSnapshot(
      today: try persistence.totals(localDay: localDay),
      lifetime: lifetime,
      intervals: try persistence.intervals.load(currentProxyTotal: lifetime.proxy),
      recentProxyDays: recentLocalDays.map {
        storedByDay[$0] ?? TrafficDailyTotal(localDay: $0, bytes: .zero)
      },
      lastObservedAt: runtimeState.lastObservedAt
    )
  }

  private func recentLocalDays(calendar: Calendar, now: Date) throws -> [String] {
    try (0..<30).reversed().map { offset in
      guard let date = calendar.date(byAdding: .day, value: -offset, to: now) else {
        throw TrafficStatisticsError.database("无法计算最近每日统计日期")
      }
      return TrafficLedgerPersistence.localDay(for: date, calendar: calendar)
    }
  }
}
