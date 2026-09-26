import Darwin
import Foundation

enum WidgetSigningPoCSnapshotStore {
  static func accountHomeURL() -> URL? {
    guard let account = getpwuid(getuid()), let homeDirectory = account.pointee.pw_dir else {
      return nil
    }

    let homePath = String(cString: homeDirectory)
    guard homePath.hasPrefix("/") else {
      return nil
    }

    return URL(fileURLWithPath: homePath, isDirectory: true)
  }

  static func directoryURL() -> URL? {
    guard let userHome = accountHomeURL() else {
      return nil
    }

    let supportDirectory = userHome.appendingPathComponent(
      "Library/Application Support", isDirectory: true
    )
    return supportDirectory.appendingPathComponent(
      WidgetSigningPoCConstants.snapshotDirectoryName, isDirectory: true
    )
  }

  static func writeFakeSnapshot() throws -> String {
    guard let directory = directoryURL() else {
      throw WidgetSigningPoCSnapshotError.userHomeUnavailable
    }

    let fileManager = FileManager.default
    try fileManager.createDirectory(
      at: directory,
      withIntermediateDirectories: true,
      attributes: [.posixPermissions: 0o700]
    )
    try fileManager.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directory.path)

    let snapshotURL = directory.appendingPathComponent(WidgetSigningPoCConstants.snapshotFilename)
    let value = "主应用写入：\(Date().formatted(date: .numeric, time: .standard))"
    try value.write(to: snapshotURL, atomically: true, encoding: .utf8)
    try fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: snapshotURL.path)
    return value
  }

  static func readSnapshot() throws -> String {
    guard let directory = directoryURL() else {
      throw WidgetSigningPoCSnapshotError.userHomeUnavailable
    }

    let snapshotURL = directory.appendingPathComponent(WidgetSigningPoCConstants.snapshotFilename)
    return try String(contentsOf: snapshotURL, encoding: .utf8)
  }
}

private enum WidgetSigningPoCSnapshotError: Error {
  case userHomeUnavailable
}
