import Combine
import Foundation

enum TrafficStatisticsAvailability: Equatable {
  case loading
  case available
  case unavailable(message: String)

  var isAvailable: Bool {
    self == .available
  }
}

@MainActor
final class TrafficStatisticsController: ObservableObject, TrafficStatisticsRecording {
  @Published private(set) var snapshot = TrafficStatisticsSnapshot.empty
  @Published private(set) var availability = TrafficStatisticsAvailability.loading
  @Published private(set) var operationMessage: String?

  private let ledger: any TrafficLedgerStoring
  private let calendarOverride: Calendar?
  private let now: @MainActor () -> Date

  init(
    ledger: any TrafficLedgerStoring,
    calendar: Calendar? = nil,
    now: @escaping @MainActor () -> Date = Date.init
  ) {
    self.ledger = ledger
    calendarOverride = calendar
    self.now = now
  }

  var activeIntervals: [TrafficInterval] {
    snapshot.intervals.filter { $0.status == .active }
  }

  func prepare() async {
    do {
      snapshot = try await ledger.prepare(calendar: calendar, now: now())
      availability = .available
      operationMessage = nil
    } catch {
      setUnavailable(error)
    }
  }

  func beginMonitoring(version: String, at date: Date) async {
    guard availability.isAvailable else {
      return
    }
    do {
      snapshot = try await ledger.beginMonitoring(
        version: version,
        at: date,
        calendar: calendar
      )
    } catch {
      await interruptAfterStatisticsFailure(error)
    }
  }

  func record(_ observation: TrafficLedgerObservation) async {
    guard availability.isAvailable else {
      return
    }
    do {
      snapshot = try await ledger.record(observation, calendar: calendar)
    } catch {
      await interruptAfterStatisticsFailure(error)
    }
  }

  func interruptMonitoring(at date: Date) async {
    guard availability.isAvailable else {
      return
    }
    do {
      snapshot = try await ledger.interruptActiveIntervals(
        reason: .monitoringStopped,
        calendar: calendar,
        now: date
      )
    } catch {
      setUnavailable(error)
    }
  }

  func startInterval(name: String, note: String? = nil) async {
    await performUserOperation {
      try await ledger.startInterval(
        name: name,
        note: note,
        at: now(),
        calendar: calendar
      )
    }
  }

  func stopInterval(id: UUID) async {
    await performUserOperation {
      try await ledger.stopInterval(id: id, at: now(), calendar: calendar)
    }
  }

  func renameInterval(id: UUID, name: String) async {
    await performUserOperation {
      try await ledger.renameInterval(
        id: id,
        name: name,
        calendar: calendar,
        now: now()
      )
    }
  }

  func deleteInterval(id: UUID) async {
    await performUserOperation {
      try await ledger.deleteInterval(id: id, calendar: calendar, now: now())
    }
  }

  func clear() async {
    do {
      snapshot = try await ledger.clear(calendar: calendar, now: now())
      availability = .available
      operationMessage = nil
    } catch {
      setUnavailable(error)
    }
  }

  func prepareForApplicationTermination() async {
    do {
      snapshot = try await ledger.interruptActiveIntervals(
        reason: .applicationExit,
        calendar: calendar,
        now: now()
      )
    } catch {
      setUnavailable(error)
    }
  }

  func dismissOperationMessage() {
    operationMessage = nil
  }

  private var calendar: Calendar {
    calendarOverride ?? Calendar.autoupdatingCurrent
  }

  private func performUserOperation(
    _ operation: () async throws -> TrafficStatisticsSnapshot
  ) async {
    guard availability.isAvailable else {
      operationMessage = "本地统计暂不可用，当前操作未执行。"
      return
    }
    do {
      snapshot = try await operation()
      operationMessage = nil
    } catch {
      operationMessage = error.localizedDescription
    }
  }

  private func interruptAfterStatisticsFailure(_ error: any Error) async {
    let message = error.localizedDescription
    do {
      snapshot = try await ledger.interruptActiveIntervals(
        reason: .statisticsUnavailable,
        calendar: calendar,
        now: now()
      )
    } catch {
      // 原始故障优先展示，恢复中断失败将在下次启动时再次收口。
    }
    availability = .unavailable(message: message)
    operationMessage = message
  }

  private func setUnavailable(_ error: any Error) {
    let message = error.localizedDescription
    availability = .unavailable(message: message)
    operationMessage = message
  }
}
