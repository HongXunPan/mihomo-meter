import Foundation

struct ConnectionSnapshotDecoder: Sendable {
  func decode(_ message: URLSessionWebSocketTask.Message) throws -> MihomoConnectionsSnapshot {
    let data: Data
    switch message {
    case .data(let messageData):
      data = messageData
    case .string(let text):
      guard let messageData = text.data(using: .utf8) else {
        throw ConnectionStreamError.malformedMessage
      }
      data = messageData
    @unknown default:
      throw ConnectionStreamError.malformedMessage
    }

    do {
      return try JSONDecoder().decode(MihomoConnectionsSnapshot.self, from: data)
    } catch {
      throw ConnectionStreamError.unsupportedResponse
    }
  }
}
