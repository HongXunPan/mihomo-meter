import CryptoKit
import Foundation

enum WidgetSigningPoCDiagnostics {
  static func inspect() -> String {
    guard let directory = WidgetSigningPoCSnapshotStore.directoryURL() else {
      return "用户主目录不可用；文件未检查"
    }

    let snapshotURL = directory.appendingPathComponent(WidgetSigningPoCConstants.snapshotFilename)
    let fileState = FileManager.default.fileExists(atPath: snapshotURL.path) ? "存在" : "不存在"
    let summary = "目录 \(fingerprint(for: directory)) · 文件\(fileState)"

    do {
      let value = try WidgetSigningPoCSnapshotStore.readSnapshot()
      return "\(summary)\n读取成功：\(value)"
    } catch {
      return "读取失败：\(errorCode(error))\n\(summary)"
    }
  }

  static func errorCode(_ error: any Error) -> String {
    let nsError = error as NSError
    let underlyingCode: String
    if let underlying = nsError.userInfo[NSUnderlyingErrorKey] as? NSError {
      let domain = underlying.domain == NSPOSIXErrorDomain ? "POSIX" : underlying.domain
      underlyingCode = "\(domain)/\(underlying.code)"
    } else {
      underlyingCode = "无"
    }
    return "主码 \(nsError.code) · 底层 \(underlyingCode)\n域 \(nsError.domain)"
  }

  private static func fingerprint(for directory: URL) -> String {
    let path = directory.resolvingSymlinksInPath().standardizedFileURL.path
    let digest = SHA256.hash(data: Data(path.utf8))
    return digest.prefix(4).map { String(format: "%02x", $0) }.joined()
  }
}
