import Foundation
import SQLite3

enum SQLiteConnectionError: Error, LocalizedError {
  case database(String)

  var errorDescription: String? {
    "本地数据库暂不可用。"
  }
}

final class SQLiteConnection {
  private(set) var handle: OpaquePointer?
  private let fileURL: URL

  init(fileURL: URL) throws {
    self.fileURL = fileURL
    try Self.prepareDirectory(for: fileURL)

    let flags = SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX
    guard sqlite3_open_v2(fileURL.path, &handle, flags, nil) == SQLITE_OK else {
      let message = handle.map { String(cString: sqlite3_errmsg($0)) } ?? "无法打开数据库"
      sqlite3_close(handle)
      handle = nil
      throw SQLiteConnectionError.database(message)
    }

    try execute("PRAGMA foreign_keys = ON")
    try execute("PRAGMA journal_mode = WAL")
    try execute("PRAGMA synchronous = NORMAL")
    try execute("PRAGMA busy_timeout = 3000")
    try protectDatabaseFiles()
  }

  deinit {
    close()
  }

  func close() {
    guard let handle else {
      return
    }
    sqlite3_close(handle)
    self.handle = nil
  }

  func execute(_ sql: String) throws {
    guard let handle else {
      throw SQLiteConnectionError.database("数据库连接已关闭")
    }

    var errorMessage: UnsafeMutablePointer<CChar>?
    let status = sqlite3_exec(handle, sql, nil, nil, &errorMessage)
    guard status == SQLITE_OK else {
      let message = errorMessage.map { String(cString: $0) } ?? "SQLite 执行失败"
      sqlite3_free(errorMessage)
      throw SQLiteConnectionError.database(message)
    }
  }

  func prepare(_ sql: String) throws -> SQLiteStatement {
    guard let handle else {
      throw SQLiteConnectionError.database("数据库连接已关闭")
    }
    return try SQLiteStatement(database: handle, sql: sql)
  }

  func transaction<Result>(_ body: () throws -> Result) throws -> Result {
    try execute("BEGIN IMMEDIATE")
    do {
      let result = try body()
      try execute("COMMIT")
      try protectDatabaseFiles()
      return result
    } catch {
      try? execute("ROLLBACK")
      throw error
    }
  }

  func protectDatabaseFiles() throws {
    for url in [
      fileURL,
      URL(fileURLWithPath: fileURL.path + "-wal"),
      URL(fileURLWithPath: fileURL.path + "-shm"),
    ] where FileManager.default.fileExists(atPath: url.path) {
      try FileManager.default.setAttributes(
        [.posixPermissions: 0o600],
        ofItemAtPath: url.path
      )
    }
  }

  private static func prepareDirectory(for fileURL: URL) throws {
    let directoryURL = fileURL.deletingLastPathComponent()
    try FileManager.default.createDirectory(
      at: directoryURL,
      withIntermediateDirectories: true,
      attributes: [.posixPermissions: 0o700]
    )
  }
}

final class SQLiteStatement {
  private var handle: OpaquePointer?
  private let database: OpaquePointer

  init(database: OpaquePointer, sql: String) throws {
    self.database = database
    guard sqlite3_prepare_v2(database, sql, -1, &handle, nil) == SQLITE_OK else {
      throw SQLiteConnectionError.database(String(cString: sqlite3_errmsg(database)))
    }
  }

  deinit {
    sqlite3_finalize(handle)
  }

  func bind(_ value: String?, at index: Int32) throws {
    let status: Int32
    if let value {
      let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
      status = sqlite3_bind_text(handle, index, value, -1, transient)
    } else {
      status = sqlite3_bind_null(handle, index)
    }
    try check(status)
  }

  func bind(_ value: Int64?, at index: Int32) throws {
    let status =
      value.map { sqlite3_bind_int64(handle, index, $0) }
      ?? sqlite3_bind_null(handle, index)
    try check(status)
  }

  func bind(_ value: Double?, at index: Int32) throws {
    let status =
      value.map { sqlite3_bind_double(handle, index, $0) }
      ?? sqlite3_bind_null(handle, index)
    try check(status)
  }

  @discardableResult
  func step() throws -> Int32 {
    let status = sqlite3_step(handle)
    guard status == SQLITE_ROW || status == SQLITE_DONE else {
      throw SQLiteConnectionError.database(String(cString: sqlite3_errmsg(database)))
    }
    return status
  }

  func text(at index: Int32) -> String? {
    sqlite3_column_text(handle, index).map { String(cString: $0) }
  }

  func int64(at index: Int32) -> Int64 {
    sqlite3_column_int64(handle, index)
  }

  func double(at index: Int32) -> Double {
    sqlite3_column_double(handle, index)
  }

  func isNull(at index: Int32) -> Bool {
    sqlite3_column_type(handle, index) == SQLITE_NULL
  }

  private func check(_ status: Int32) throws {
    guard status == SQLITE_OK else {
      throw SQLiteConnectionError.database(String(cString: sqlite3_errmsg(database)))
    }
  }
}
