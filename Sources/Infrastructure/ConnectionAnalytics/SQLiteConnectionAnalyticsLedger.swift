import Foundation

actor SQLiteConnectionAnalyticsLedger: ConnectionAnalyticsLedgerStoring {
  private let databaseURL: URL
  private var persistence: ConnectionAnalyticsLedgerPersistence?
  private var lastPrunedLocalDay: String?

  init(databaseURL: URL) {
    self.databaseURL = databaseURL
  }

  func prepare(calendar: Calendar, now: Date) async throws -> ConnectionAnalyticsLedgerSnapshot {
    let persistence = try requirePersistence()
    try pruneIfNeeded(calendar: calendar, now: now, persistence: persistence)
    return try snapshot(calendar: calendar, now: now, persistence: persistence)
  }

  func setHistoryEnabled(
    _ isEnabled: Bool,
    calendar: Calendar,
    now: Date
  ) async throws -> ConnectionAnalyticsLedgerSnapshot {
    let persistence = try requirePersistence()
    try persistence.setHistoryEnabled(isEnabled)
    return try snapshot(calendar: calendar, now: now, persistence: persistence)
  }

  func record(
    _ aggregates: [ConnectionAttributionAggregate],
    maximumPairCountPerDay: Int,
    calendar: Calendar,
    now: Date
  ) async throws -> ConnectionAnalyticsLedgerSnapshot {
    precondition(maximumPairCountPerDay > 0)
    let persistence = try requirePersistence()
    guard try persistence.isHistoryEnabled() else {
      return try snapshot(calendar: calendar, now: now, persistence: persistence)
    }
    try persistence.transaction {
      for group in Dictionary(grouping: coalesced(aggregates), by: { $0.key.localDay }).values {
        try record(
          group,
          maximumPairCount: maximumPairCountPerDay,
          persistence: persistence
        )
      }
      try pruneIfNeeded(calendar: calendar, now: now, persistence: persistence)
    }
    return try snapshot(calendar: calendar, now: now, persistence: persistence)
  }

  func records(localDay: String) async throws -> [ConnectionAttributionRecord] {
    try requirePersistence().records(localDay: localDay)
  }

  func trend(
    query: ConnectionAnalyticsTrendQuery,
    calendar: Calendar,
    now: Date
  ) async throws -> ConnectionAnalyticsTrend {
    let days = try recentLocalDays(calendar: calendar, now: now)
    let storedPoints = try requirePersistence().trend(
      query: query,
      since: days.first ?? ""
    )
    let storedByDay = Dictionary(
      uniqueKeysWithValues: storedPoints.map { ($0.localDay, $0) }
    )
    return ConnectionAnalyticsTrend(
      points: days.map { localDay in
        storedByDay[localDay]
          ?? ConnectionAnalyticsTrendPoint(localDay: localDay, bytes: .zero)
      }
    )
  }

  func clearHistory(
    calendar: Calendar,
    now: Date
  ) async throws -> ConnectionAnalyticsLedgerSnapshot {
    let persistence = try requirePersistence()
    try persistence.transaction {
      try persistence.clearHistory()
    }
    return try snapshot(calendar: calendar, now: now, persistence: persistence)
  }

  private func requirePersistence() throws -> ConnectionAnalyticsLedgerPersistence {
    if let persistence {
      return persistence
    }
    let persistence = try ConnectionAnalyticsLedgerPersistence(databaseURL: databaseURL)
    self.persistence = persistence
    return persistence
  }

  private func record(
    _ aggregates: [ConnectionAttributionAggregate],
    maximumPairCount: Int,
    persistence: ConnectionAnalyticsLedgerPersistence
  ) throws {
    guard let localDay = aggregates.first?.key.localDay else {
      return
    }
    let overflowKey = ConnectionAttributionStorageKey(
      localDay: localDay,
      applicationName: ConnectionAttributionLabel.overflow,
      hostname: ConnectionAttributionLabel.overflow
    )
    let existingKeys = try persistence.existingKeys(localDay: localDay)
    let regularExistingCount = existingKeys.filter { $0 != overflowKey }.count
    var remainingRegularSlots = max(maximumPairCount - 1 - regularExistingCount, 0)
    var overflowBytes = TrafficBytes.zero

    for aggregate in aggregates.sorted(by: Self.keyOrder) {
      if aggregate.key == overflowKey || existingKeys.contains(aggregate.key) {
        try persistence.upsert(aggregate)
      } else if remainingRegularSlots > 0 {
        try persistence.upsert(aggregate)
        remainingRegularSlots -= 1
      } else {
        overflowBytes = overflowBytes + aggregate.bytes
      }
    }
    if overflowBytes != .zero {
      try persistence.upsert(
        ConnectionAttributionAggregate(key: overflowKey, bytes: overflowBytes)
      )
    }
  }

  private func coalesced(
    _ aggregates: [ConnectionAttributionAggregate]
  ) -> [ConnectionAttributionAggregate] {
    var bytesByKey: [ConnectionAttributionStorageKey: TrafficBytes] = [:]
    for aggregate in aggregates {
      bytesByKey[aggregate.key] = (bytesByKey[aggregate.key] ?? .zero) + aggregate.bytes
    }
    return bytesByKey.map {
      ConnectionAttributionAggregate(key: $0.key, bytes: $0.value)
    }
  }

  private func pruneIfNeeded(
    calendar: Calendar,
    now: Date,
    persistence: ConnectionAnalyticsLedgerPersistence
  ) throws {
    let localDay = ConnectionAnalyticsCalendar.localDay(for: now, calendar: calendar)
    guard localDay != lastPrunedLocalDay else {
      return
    }
    guard let cutoffDate = calendar.date(byAdding: .day, value: -29, to: now) else {
      throw ConnectionAnalyticsError.database("无法计算归因历史保留日期")
    }
    try persistence.prune(
      before: ConnectionAnalyticsCalendar.localDay(for: cutoffDate, calendar: calendar)
    )
    lastPrunedLocalDay = localDay
  }

  private func snapshot(
    calendar: Calendar,
    now: Date,
    persistence: ConnectionAnalyticsLedgerPersistence
  ) throws -> ConnectionAnalyticsLedgerSnapshot {
    let days = try recentLocalDays(calendar: calendar, now: now)
    let storedDays = try persistence.dailyTotals(since: days.first ?? "")
    let storedByDay = Dictionary(uniqueKeysWithValues: storedDays.map { ($0.localDay, $0) })
    return ConnectionAnalyticsLedgerSnapshot(
      isHistoryEnabled: try persistence.isHistoryEnabled(),
      recentDays: days.map {
        storedByDay[$0]
          ?? ConnectionAnalyticsDay(localDay: $0, bytes: .zero, coverage: .empty)
      }
    )
  }

  private func recentLocalDays(calendar: Calendar, now: Date) throws -> [String] {
    try (0..<30).reversed().map { offset in
      guard let date = calendar.date(byAdding: .day, value: -offset, to: now) else {
        throw ConnectionAnalyticsError.database("无法计算最近归因日期")
      }
      return ConnectionAnalyticsCalendar.localDay(for: date, calendar: calendar)
    }
  }

  private static func keyOrder(
    _ left: ConnectionAttributionAggregate,
    _ right: ConnectionAttributionAggregate
  ) -> Bool {
    if left.key.applicationName != right.key.applicationName {
      return left.key.applicationName < right.key.applicationName
    }
    return left.key.hostname < right.key.hostname
  }
}
