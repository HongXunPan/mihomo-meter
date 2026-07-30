import Combine
import Foundation

enum ConnectionAnalyticsTrendDimension: Equatable, Sendable {
  case application
  case hostname

  var title: String {
    switch self {
    case .application:
      "应用"
    case .hostname:
      "域名"
    }
  }
}

struct ConnectionAnalyticsTrendTarget: Equatable, Sendable {
  let dimension: ConnectionAnalyticsTrendDimension
  let name: String
  let query: ConnectionAnalyticsTrendQuery
  let inheritedFilterDescription: String?
}

enum ConnectionAnalyticsTrendLoadState: Equatable {
  case idle
  case loading
  case loaded(ConnectionAnalyticsTrend)
  case failed(message: String)
}

@MainActor
final class ConnectionAnalyticsTrendWindowModel: ObservableObject {
  typealias Loader =
    @MainActor (ConnectionAnalyticsTrendQuery) async throws -> ConnectionAnalyticsTrend

  @Published private(set) var target: ConnectionAnalyticsTrendTarget?
  @Published private(set) var state = ConnectionAnalyticsTrendLoadState.idle

  private let loader: Loader
  private var loadTask: Task<Void, Never>?

  init(loader: @escaping Loader) {
    self.loader = loader
  }

  func show(target: ConnectionAnalyticsTrendTarget) {
    self.target = target
    load(target: target)
  }

  func reload() {
    guard let target else {
      return
    }
    load(target: target)
  }

  func reset() {
    loadTask?.cancel()
    loadTask = nil
    target = nil
    state = .idle
  }

  private func load(target: ConnectionAnalyticsTrendTarget) {
    loadTask?.cancel()
    state = .loading
    loadTask = Task { [weak self] in
      guard let self else {
        return
      }
      do {
        let trend = try await loader(target.query)
        guard !Task.isCancelled, self.target == target else {
          return
        }
        state = .loaded(trend)
      } catch is CancellationError {
        return
      } catch {
        guard !Task.isCancelled, self.target == target else {
          return
        }
        state = .failed(message: error.localizedDescription)
      }
    }
  }
}
