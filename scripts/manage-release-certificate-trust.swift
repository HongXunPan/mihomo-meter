import Darwin
import Foundation
import Security

enum TrustOperation: String {
  case add
  case remove
}

func fail(_ message: String) -> Never {
  fputs("\(message)\n", stderr)
  exit(EXIT_FAILURE)
}

func loadCertificate(at path: String) throws -> SecCertificate {
  let fileURL = URL(fileURLWithPath: path)
  let fileData = try Data(contentsOf: fileURL)
  let certificateData: Data

  if let pemText = String(data: fileData, encoding: .utf8),
    pemText.contains("-----BEGIN CERTIFICATE-----")
  {
    let base64Body =
      pemText
      .components(separatedBy: .newlines)
      .filter { !$0.hasPrefix("-----") }
      .joined()
    guard let decodedData = Data(base64Encoded: base64Body) else {
      throw CocoaError(.fileReadCorruptFile)
    }
    certificateData = decodedData
  } else {
    certificateData = fileData
  }

  guard
    let certificate = SecCertificateCreateWithData(
      nil,
      certificateData as CFData
    )
  else {
    throw CocoaError(.fileReadCorruptFile)
  }
  return certificate
}

guard CommandLine.arguments.count == 3 else {
  fail("用法：manage-release-certificate-trust <add|remove> <证书路径>")
}
guard let operation = TrustOperation(rawValue: CommandLine.arguments[1]) else {
  fail("信任操作必须是 add 或 remove。")
}

let certificate: SecCertificate
do {
  certificate = try loadCertificate(at: CommandLine.arguments[2])
} catch {
  fail("无法读取发布证书：\(error.localizedDescription)")
}

let status: OSStatus
switch operation {
case .add:
  status = SecTrustSettingsSetTrustSettings(certificate, .admin, nil)
case .remove:
  status = SecTrustSettingsRemoveTrustSettings(certificate, .admin)
}

if status != errSecSuccess
  && !(operation == .remove && status == errSecItemNotFound)
{
  fail("更新管理员证书信任失败，Security 状态码：\(status)")
}
