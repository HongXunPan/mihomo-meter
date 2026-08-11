import Foundation
import Security

enum AppCodeSigningInspector {
  // Security SDK 将 ad-hoc 签名标志定义为 0x0002，但该 C 枚举值未导入 Swift。
  private static let adHocSignatureFlag: UInt32 = 0x0002

  static func currentSummary() -> AppCodeSigningSummary {
    let fallbackIdentifier = Bundle.main.bundleIdentifier ?? "unknown"
    var dynamicCode: SecCode?
    let selfStatus = SecCodeCopySelf(SecCSFlags(rawValue: 0), &dynamicCode)
    guard selfStatus == errSecSuccess, let dynamicCode else {
      return AppCodeSigningSummary(
        identifier: fallbackIdentifier,
        teamIdentifier: nil,
        isAdHoc: nil,
        inspectionStatus: selfStatus
      )
    }

    var staticCode: SecStaticCode?
    let staticStatus = SecCodeCopyStaticCode(
      dynamicCode,
      SecCSFlags(rawValue: 0),
      &staticCode
    )
    guard staticStatus == errSecSuccess, let staticCode else {
      return AppCodeSigningSummary(
        identifier: fallbackIdentifier,
        teamIdentifier: nil,
        isAdHoc: nil,
        inspectionStatus: staticStatus
      )
    }

    var signingInformation: CFDictionary?
    let informationStatus = SecCodeCopySigningInformation(
      staticCode,
      SecCSFlags(rawValue: kSecCSSigningInformation),
      &signingInformation
    )
    guard informationStatus == errSecSuccess,
      let information = signingInformation as? [String: Any]
    else {
      return AppCodeSigningSummary(
        identifier: fallbackIdentifier,
        teamIdentifier: nil,
        isAdHoc: nil,
        inspectionStatus: informationStatus
      )
    }

    let identifier = information[kSecCodeInfoIdentifier as String] as? String
    let teamIdentifier = information[kSecCodeInfoTeamIdentifier as String] as? String
    let signatureFlags = (information[kSecCodeInfoFlags as String] as? NSNumber)?.uint32Value
    let isAdHoc = signatureFlags.map {
      $0 & adHocSignatureFlag != 0
    }

    return AppCodeSigningSummary(
      identifier: identifier ?? fallbackIdentifier,
      teamIdentifier: teamIdentifier,
      isAdHoc: isAdHoc,
      inspectionStatus: informationStatus
    )
  }
}
