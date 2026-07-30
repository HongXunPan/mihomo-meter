import Combine
import Foundation

enum ConnectionAnalyticsAvailability: Equatable {
  case loading
  case available
  case unavailable(message: String)

  var isAvailable: Bool {
    self == .available
  }
}

@MainActor
final class ConnectionAnalyticsController: ObservableObject, ConnectionAnalyticsHistoryClearing,
  ConnectionAnalyticsRecording
{
  @Published private(set) var snapshot = ConnectionAnalyticsLedgerSnapshot.empty
  @Published private(set) var selectedRecords: [ConnectionAttributionRecord] = []
  @Published private(set) var selectedLocalDay: String?
  @Published private(set) var availability = ConnectionAnalyticsAvailability.loading
  @Published private(set) var operationMessage: String?

  private let ledger: any ConnectionAnalyticsLedgerStoring
  private let calendarOverride: Calendar?
  private let now: @MainActor () -> Date
  private let flushIntervalNanoseconds: UInt64
  private let maximumPairCountPerDay: Int
  private var pendingBytesByKey: [ConnectionAttributionStorageKey: TrafficBytes] = [:]
  private var flushTask: Task<Void, Never>?

  init(
    ledger: any ConnectionAnalyticsLedgerStoring,
    calendar: Calendar? = nil,
    flushIntervalNanoseconds: UInt64 = 10_000_000_000,
    maximumPairCountPerDay: Int = 5_000,
    now: @escaping @MainActor () -> Date = Date.init
  ) {
    precondition(maximumPairCountPerDay > 0)
    self.ledger = ledger
    calendarOverride = calendar
    self.flushIntervalNanoseconds = flushIntervalNanoseconds
    self.maximumPairCountPerDay = maximumPairCountPerDay
    self.now = now
  }

  var isHistoryEnabled: Bool {
    snapshot.isHistoryEnabled
  }

  func prepare() async {
    do {
      snapshot = try await ledger.prepare(calendar: calendar, now: now())
      availability = .available
      operationMessage = nil
      selectedLocalDay = snapshot.recentDays.last?.localDay
      await reloadSelectedRecords()
    } catch {
      setUnavailable(error)
    }
  }

  func record(_ deltas: [ConnectionAttributionDelta], at date: Date) async {
    guard availability.isAvailable, isHistoryEnabled, !deltas.isEmpty else {
      return
    }
    let localDay = ConnectionAnalyticsCalendar.localDay(for: date, calendar: calendar)
    if pendingBytesByKey.keys.contains(where: { $0.localDay != localDay }) {
      await flushPending()
    }
    guard availability.isAvailable else {
      return
    }

    for delta in deltas where delta.bytes.total > 0 {
      let key = ConnectionAttributionStorageKey(
        localDay: localDay,
        applicationName: delta.metadata.applicationName
          ?? ConnectionAttributionLabel.unknownApplication,
        hostname: delta.metadata.hostname ?? ConnectionAttributionLabel.unknownHostname
      )
      pendingBytesByKey[key] = (pendingBytesByKey[key] ?? .zero) + delta.bytes
    }
    scheduleFlushIfNeeded()
  }

  func setHistoryEnabled(_ isEnabled: Bool) async {
    guard availability.isAvailable, isEnabled != self.isHistoryEnabled else {
      return
    }
    if !isEnabled {
      await flushPending()
    }
    guard availability.isAvailable else {
      return
    }
    do {
      snapshot = try await ledger.setHistoryEnabled(
        isEnabled,
        calendar: calendar,
        now: now()
      )
      operationMessage = nil
      if !isEnabled {
        cancelScheduledFlush()
      }
    } catch {
      setUnavailable(error)
    }
  }

  func selectDay(_ localDay: String) async {
    guard snapshot.recentDays.contains(where: { $0.localDay == localDay }) else {
      return
    }
    selectedLocalDay = localDay
    await reloadSelectedRecords()
  }

  func flushPending() async {
    cancelScheduledFlush()
    guard availability.isAvailable, !pendingBytesByKey.isEmpty else {
      return
    }
    let aggregates = pendingBytesByKey.map {
      ConnectionAttributionAggregate(key: $0.key, bytes: $0.value)
    }
    pendingBytesByKey = [:]

    do {
      snapshot = try await ledger.record(
        aggregates,
        maximumPairCountPerDay: maximumPairCountPerDay,
        calendar: calendar,
        now: now()
      )
      operationMessage = nil
      await reloadSelectedRecords()
    } catch {
      setUnavailable(error)
    }
  }

  @discardableResult
  func clearHistory() async -> Bool {
    cancelScheduledFlush()
    pendingBytesByKey = [:]
    guard availability.isAvailable else {
      operationMessage = "连接归因历史暂不可用，清空操作未执行。"
      return false
    }
    do {
      snapshot = try await ledger.clearHistory(calendar: calendar, now: now())
      selectedLocalDay = snapshot.recentDays.last?.localDay
      selectedRecords = []
      operationMessage = nil
      return true
    } catch {
      setUnavailable(error)
      return false
    }
  }

  func dismissOperationMessage() {
    operationMessage = nil
  }

  private var calendar: Calendar {
    calendarOverride ?? Calendar.autoupdatingCurrent
  }

  private func reloadSelectedRecords() async {
    guard availability.isAvailable, let selectedLocalDay else {
      selectedRecords = []
      return
    }
    do {
      selectedRecords = try await ledger.records(localDay: selectedLocalDay)
    } catch {
      setUnavailable(error)
    }
  }

  private func scheduleFlushIfNeeded() {
    guard flushTask == nil, !pendingBytesByKey.isEmpty else {
      return
    }
    flushTask = Task { [weak self] in
      guard let self else {
        return
      }
      do {
        try await Task.sleep(nanoseconds: flushIntervalNanoseconds)
      } catch {
        return
      }
      flushTask = nil
      await flushPending()
    }
  }

  private func cancelScheduledFlush() {
    flushTask?.cancel()
    flushTask = nil
  }

  private func setUnavailable(_ error: any Error) {
    cancelScheduledFlush()
    pendingBytesByKey = [:]
    let message = error.localizedDescription
    availability = .unavailable(message: message)
    operationMessage = message
  }
}
