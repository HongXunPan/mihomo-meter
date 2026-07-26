import Foundation

enum QuotaLedgerLocation {
  static func defaultDatabaseURL(fileManager: FileManager = .default) -> URL {
    let applicationSupport =
      fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
      ?? fileManager.homeDirectoryForCurrentUser
      .appendingPathComponent("Library/Application Support", isDirectory: true)
    return
      applicationSupport
      .appendingPathComponent("Mihomo Meter", isDirectory: true)
      .appendingPathComponent("quota.sqlite3")
  }
}
