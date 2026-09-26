import CryptoKit
import Foundation

enum WidgetSigningPoCDiagnostics {
  static func inspect() -> String {
    guard let directory = WidgetSigningPoCSnapshotStore.directoryURL() else {
      return "用户主目录不可用；文件未检查"
    }

    let snapshotURL = directory.appendingPathComponent(WidgetSigningPoCConstants.snapshotFilename)
    let fileState = FileManager.default.fileExists(atPath: snapshotURL.path) ? "存在" : "不存在"
    let summary =
      "位置 \(locationState(for: directory))\n"
      + "目录 \(fingerprint(for: directory)) · 文件\(fileState)"

    do {
      let value = try WidgetSigningPoCSnapshotStore.readSnapshot()
      return "\(summary)\n读取成功：\(value)"
    } catch {
      return "\(summary)\n读取失败：\(errorCode(error))"
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

  private static func locationState(for directory: URL) -> String {
    guard let accountHome = WidgetSigningPoCSnapshotStore.accountHomeURL() else {
      return "账户主目录不可用"
    }

    let directoryPath = directory.resolvingSymlinksInPath().standardizedFileURL.path
    let accountHomePath = accountHome.resolvingSymlinksInPath().standardizedFileURL.path
    let processHomePath = URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
      .resolvingSymlinksInPath().standardizedFileURL.path

    if directoryPath.hasPrefix(accountHomePath + "/") {
      return accountHomePath == processHomePath ? "账户与进程主目录相同，需复核" : "用户目录"
    }
    if directoryPath.hasPrefix(processHomePath + "/") {
      return "进程沙盒容器"
    }
    return "其他位置"
  }
}
