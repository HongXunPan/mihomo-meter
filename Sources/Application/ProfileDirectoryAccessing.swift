import Foundation

struct ProfileDirectoryBookmarkResolution: Equatable, Sendable {
  let directoryURL: URL
  let isStale: Bool
}

@MainActor
protocol ProfileDirectoryAuthorizing {
  func chooseDirectory() -> URL?
}

@MainActor
protocol ProfileDirectoryBookmarkStoring {
  func loadBookmark() -> Data?
  func saveBookmark(_ bookmark: Data)
  func deleteBookmark()
}

@MainActor
protocol ProfileDirectorySecurityScoping {
  func makeReadOnlyBookmark(for directoryURL: URL) throws -> Data
  func resolveBookmark(_ bookmark: Data) throws -> ProfileDirectoryBookmarkResolution
  func startAccessing(_ directoryURL: URL) -> Bool
  func stopAccessing(_ directoryURL: URL)
}

@MainActor
protocol ProfileDirectoryObserving {
  func startObserving(
    directoryURL: URL,
    onChange: @escaping @MainActor () -> Void
  ) throws
  func stopObserving()
}
