import Foundation

struct SemanticVersion: Comparable, CustomStringConvertible, Sendable {
  let major: Int
  let minor: Int
  let patch: Int

  init?(_ rawValue: String) {
    let normalizedValue =
      rawValue.hasPrefix("v")
      ? String(rawValue.dropFirst())
      : rawValue
    let components = normalizedValue.split(
      separator: ".",
      omittingEmptySubsequences: false
    )

    guard components.count == 3,
      let major = Self.parseComponent(components[0]),
      let minor = Self.parseComponent(components[1]),
      let patch = Self.parseComponent(components[2])
    else {
      return nil
    }

    self.major = major
    self.minor = minor
    self.patch = patch
  }

  var description: String {
    "\(major).\(minor).\(patch)"
  }

  static func < (lhs: SemanticVersion, rhs: SemanticVersion) -> Bool {
    (lhs.major, lhs.minor, lhs.patch) < (rhs.major, rhs.minor, rhs.patch)
  }

  private static func parseComponent(_ component: Substring) -> Int? {
    guard !component.isEmpty,
      component.utf8.allSatisfy({ (48...57).contains($0) }),
      component == "0" || !component.hasPrefix("0")
    else {
      return nil
    }
    return Int(component)
  }
}
