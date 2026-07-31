import Foundation

enum ConnectionApplicationNameNormalizer {
  static func applicationName(
    process: String?,
    processPath: String?
  ) -> String? {
    if let applicationBundleName = outermostApplicationBundleName(from: processPath) {
      return applicationBundleName
    }
    if let process = normalized(process) {
      return containsPathSeparator(process) ? fileName(from: process) : process
    }
    return fileName(from: processPath)
  }

  private static func outermostApplicationBundleName(from path: String?) -> String? {
    guard let path = normalized(path) else {
      return nil
    }
    for component in pathComponents(path) {
      guard component.lowercased().hasSuffix(".app"), component.count > 4 else {
        continue
      }
      let name = String(component.dropLast(4))
      if let normalizedName = normalized(name) {
        return normalizedName
      }
    }
    return nil
  }

  private static func fileName(from path: String?) -> String? {
    guard let path = normalized(path) else {
      return nil
    }
    return pathComponents(path).last.flatMap { normalized(String($0)) }
  }

  private static func pathComponents(_ path: String) -> [Substring] {
    path.split(whereSeparator: { $0 == "/" || $0 == "\\" })
  }

  private static func containsPathSeparator(_ value: String) -> Bool {
    value.contains("/") || value.contains("\\")
  }

  private static func normalized(_ value: String?) -> String? {
    guard let value else {
      return nil
    }
    let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !normalized.isEmpty, normalized.utf8.count <= 2_048 else {
      return nil
    }
    return normalized
  }
}
