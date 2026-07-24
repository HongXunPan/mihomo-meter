import Darwin
import Foundation
import Security

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

guard CommandLine.arguments.count == 2 else {
  fail("用法：add-release-certificate-trust <证书路径>")
}

let certificate: SecCertificate
do {
  certificate = try loadCertificate(at: CommandLine.arguments[1])
} catch {
  fail("无法读取发布证书：\(error.localizedDescription)")
}

let status = SecTrustSettingsSetTrustSettings(certificate, .admin, nil)
if status != errSecSuccess {
  fail("添加管理员证书信任失败，Security 状态码：\(status)")
}
