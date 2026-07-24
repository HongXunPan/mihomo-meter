import Foundation

actor DebugDiagnosticLogger: AppDiagnosticLogging {
  static let shared = DebugDiagnosticLogger()

  let logFileURL: URL
  let archivedLogFileURL: URL

  private let directoryURL: URL
  private let maxFileSizeBytes: UInt64
  private let retentionInterval: TimeInterval
  private let sessionID = UUID().uuidString.lowercased()
  private let timestampFormatter: ISO8601DateFormatter

  init(
    directoryURL: URL = DebugDiagnosticLogger.defaultDirectoryURL(),
    maxFileSizeBytes: UInt64 = 512 * 1_024,
    retentionInterval: TimeInterval = 7 * 24 * 60 * 60
  ) {
    self.directoryURL = directoryURL
    self.maxFileSizeBytes = maxFileSizeBytes
    self.retentionInterval = retentionInterval
    logFileURL = directoryURL.appendingPathComponent("diagnostics.log")
    archivedLogFileURL = directoryURL.appendingPathComponent("diagnostics.previous.log")

    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    timestampFormatter = formatter
  }

  func record(_ event: AppDiagnosticEvent) {
    #if DEBUG
      let timestamp = timestampFormatter.string(from: Date())
      let line = "\(timestamp) session=\(sessionID) \(event.logMessage)\n"
      let data = Data(line.utf8)

      do {
        try FileManager.default.createDirectory(
          at: directoryURL,
          withIntermediateDirectories: true
        )
        try removeExpiredLogs(referenceDate: Date())
        try rotateIfNeeded(addingByteCount: data.count)
        try append(data)
      } catch {
        // 诊断日志不得影响应用启动、Keychain 或实时监控主流程。
      }
    #endif
  }

  private func append(_ data: Data) throws {
    guard FileManager.default.fileExists(atPath: logFileURL.path) else {
      try data.write(to: logFileURL, options: .atomic)
      return
    }

    let handle = try FileHandle(forWritingTo: logFileURL)
    defer {
      try? handle.close()
    }
    try handle.seekToEnd()
    try handle.write(contentsOf: data)
  }

  private func rotateIfNeeded(addingByteCount: Int) throws {
    guard FileManager.default.fileExists(atPath: logFileURL.path) else {
      return
    }

    let attributes = try FileManager.default.attributesOfItem(atPath: logFileURL.path)
    let currentSize = (attributes[.size] as? NSNumber)?.uint64Value ?? 0
    guard currentSize + UInt64(addingByteCount) > maxFileSizeBytes else {
      return
    }

    if FileManager.default.fileExists(atPath: archivedLogFileURL.path) {
      try FileManager.default.removeItem(at: archivedLogFileURL)
    }
    try FileManager.default.moveItem(at: logFileURL, to: archivedLogFileURL)
  }

  private func removeExpiredLogs(referenceDate: Date) throws {
    guard retentionInterval > 0 else {
      return
    }

    for fileURL in [logFileURL, archivedLogFileURL] {
      guard FileManager.default.fileExists(atPath: fileURL.path) else {
        continue
      }

      let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
      guard let modificationDate = attributes[.modificationDate] as? Date,
        referenceDate.timeIntervalSince(modificationDate) > retentionInterval
      else {
        continue
      }
      try FileManager.default.removeItem(at: fileURL)
    }
  }

  private static func defaultDirectoryURL() -> URL {
    let libraryURL =
      FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first
      ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library")

    return
      libraryURL
      .appendingPathComponent("Logs", isDirectory: true)
      .appendingPathComponent("MihomoMeter", isDirectory: true)
  }
}
