import CryptoKit
import Foundation

enum WidgetSigningPoCDiagnostics {
  static func inspect() -> String {
    guard
      let container = FileManager.default.containerURL(
        forSecurityApplicationGroupIdentifier: WidgetSigningPoCConstants.groupIdentifier
      )
    else {
      return "容器不可用；文件未检查"
    }

    let snapshotURL = container.appendingPathComponent(WidgetSigningPoCConstants.snapshotFilename)
    let fileState = FileManager.default.fileExists(atPath: snapshotURL.path) ? "存在" : "不存在"
    let summary = "容器 \(fingerprint(for: container)) · 文件\(fileState)"

    do {
      let value = try String(contentsOf: snapshotURL, encoding: .utf8)
      return "\(summary)\n读取成功：\(value)"
    } catch {
      return "\(summary)\n读取失败：\(errorCode(error))"
    }
  }

  static func errorCode(_ error: any Error) -> String {
    let nsError = error as NSError
    return "\(nsError.domain)/\(nsError.code)"
  }

  private static func fingerprint(for container: URL) -> String {
    let path = container.resolvingSymlinksInPath().standardizedFileURL.path
    let digest = SHA256.hash(data: Data(path.utf8))
    return digest.prefix(4).map { String(format: "%02x", $0) }.joined()
  }
}
