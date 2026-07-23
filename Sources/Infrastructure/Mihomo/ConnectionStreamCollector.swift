import Foundation

typealias ConnectionSnapshotHandler =
  @Sendable (MihomoConnectionsSnapshot) async -> Void

protocol ConnectionSnapshotCollecting: Sendable {
  func collect(
    endpoint: ControllerEndpoint,
    secret: String,
    onSnapshot: @escaping ConnectionSnapshotHandler
  ) async throws

  func cancel() async
}

actor ConnectionStreamCollector: ConnectionSnapshotCollecting {
  private let session: URLSession
  private let decoder: ConnectionSnapshotDecoder
  private var currentTask: URLSessionWebSocketTask?

  init(
    session: URLSession = .shared,
    decoder: ConnectionSnapshotDecoder = ConnectionSnapshotDecoder()
  ) {
    self.session = session
    self.decoder = decoder
  }

  func collect(
    endpoint: ControllerEndpoint,
    secret: String,
    onSnapshot: @escaping ConnectionSnapshotHandler
  ) async throws {
    let url = try endpoint.webSocketURL(
      path: "/connections",
      queryItems: [URLQueryItem(name: "interval", value: "500")]
    )
    var request = URLRequest(url: url)
    request.timeoutInterval = 5
    request.cachePolicy = .reloadIgnoringLocalCacheData
    if !secret.isEmpty {
      request.setValue("Bearer \(secret)", forHTTPHeaderField: "Authorization")
    }

    let task = session.webSocketTask(with: request)
    currentTask?.cancel(with: .goingAway, reason: nil)
    currentTask = task
    task.resume()

    defer {
      task.cancel(with: .goingAway, reason: nil)
      if currentTask === task {
        currentTask = nil
      }
    }

    do {
      try await withTaskCancellationHandler {
        while !Task.isCancelled {
          let message = try await task.receive()
          let snapshot = try decoder.decode(message)
          await onSnapshot(snapshot)
        }
        throw CancellationError()
      } onCancel: {
        task.cancel(with: .goingAway, reason: nil)
      }
    } catch is CancellationError {
      throw CancellationError()
    } catch let error as ConnectionStreamError {
      throw error
    } catch let error as URLError {
      throw ConnectionStreamError.network(error.code)
    } catch {
      throw ConnectionStreamError.closed
    }
  }

  func cancel() {
    currentTask?.cancel(with: .goingAway, reason: nil)
    currentTask = nil
  }
}

enum ConnectionStreamError: Error, Equatable, LocalizedError {
  case malformedMessage
  case unsupportedResponse
  case network(URLError.Code)
  case closed

  var errorDescription: String? {
    switch self {
    case .malformedMessage:
      "Controller 推送了无效 WebSocket 消息。"
    case .unsupportedResponse:
      "当前连接快照结构暂不受支持。"
    case .network:
      "Controller WebSocket 连接中断。"
    case .closed:
      "Controller WebSocket 已关闭。"
    }
  }
}
