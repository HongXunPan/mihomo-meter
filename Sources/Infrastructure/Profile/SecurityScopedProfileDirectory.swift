import AppKit
import Foundation

@MainActor
final class SystemProfileDirectoryAuthorizer: ProfileDirectoryAuthorizing {
  func chooseDirectory() -> URL? {
    let panel = NSOpenPanel()
    panel.title = "选择 Clash Verge 数据目录"
    panel.message = "Mihomo Meter 只读取该目录中的 profiles.yaml，不会修改配置。"
    panel.prompt = "授权目录"
    panel.canChooseFiles = false
    panel.canChooseDirectories = true
    panel.allowsMultipleSelection = false
    panel.canCreateDirectories = false
    return panel.runModal() == .OK ? panel.url : nil
  }
}

@MainActor
final class UserDefaultsProfileDirectoryBookmarkStore: ProfileDirectoryBookmarkStoring {
  private static let bookmarkKey = "clashProfileDirectoryReadOnlyBookmark"

  private let userDefaults: UserDefaults

  init(userDefaults: UserDefaults) {
    self.userDefaults = userDefaults
  }

  func loadBookmark() -> Data? {
    userDefaults.data(forKey: Self.bookmarkKey)
  }

  func saveBookmark(_ bookmark: Data) {
    userDefaults.set(bookmark, forKey: Self.bookmarkKey)
  }

  func deleteBookmark() {
    userDefaults.removeObject(forKey: Self.bookmarkKey)
  }
}

@MainActor
struct SystemProfileDirectorySecurityScope: ProfileDirectorySecurityScoping {
  func makeReadOnlyBookmark(for directoryURL: URL) throws -> Data {
    try directoryURL.bookmarkData(
      options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess],
      includingResourceValuesForKeys: nil,
      relativeTo: nil
    )
  }

  func resolveBookmark(_ bookmark: Data) throws -> ProfileDirectoryBookmarkResolution {
    var isStale = false
    let directoryURL = try URL(
      resolvingBookmarkData: bookmark,
      options: [.withSecurityScope],
      relativeTo: nil,
      bookmarkDataIsStale: &isStale
    )
    return ProfileDirectoryBookmarkResolution(
      directoryURL: directoryURL,
      isStale: isStale
    )
  }

  func startAccessing(_ directoryURL: URL) -> Bool {
    directoryURL.startAccessingSecurityScopedResource()
  }

  func stopAccessing(_ directoryURL: URL) {
    directoryURL.stopAccessingSecurityScopedResource()
  }
}
