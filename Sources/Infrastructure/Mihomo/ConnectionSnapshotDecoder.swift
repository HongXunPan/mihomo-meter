import Foundation

struct ConnectionSnapshotDecoder: Sendable {
  func decode(_ message: URLSessionWebSocketTask.Message) throws -> MihomoConnectionsSnapshot {
    try decodePayload(payload(from: message))
  }

  func decodeWithPayloadSize(
    _ message: URLSessionWebSocketTask.Message
  ) throws -> (snapshot: MihomoConnectionsSnapshot, payloadByteCount: Int) {
    let data = try payload(from: message)
    // 字节数取自解码已需生成的数据，避免为诊断再次遍历文本。
    return (try decodePayload(data), data.count)
  }

  private func payload(from message: URLSessionWebSocketTask.Message) throws -> Data {
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
    return data
  }

  private func decodePayload(_ data: Data) throws -> MihomoConnectionsSnapshot {
    do {
      return try JSONDecoder().decode(MihomoConnectionsSnapshot.self, from: data)
    } catch {
      throw ConnectionStreamError.unsupportedResponse
    }
  }
}
