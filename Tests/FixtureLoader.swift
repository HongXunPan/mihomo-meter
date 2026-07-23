import Foundation

enum FixtureLoader {
  static func data(named name: String, fileExtension: String = "json") throws -> Data {
    let bundle = Bundle(for: BundleToken.self)
    guard let url = bundle.url(forResource: name, withExtension: fileExtension) else {
      throw FixtureLoaderError.missingFixture(name)
    }

    return try Data(contentsOf: url)
  }
}

private final class BundleToken {}

enum FixtureLoaderError: Error, Equatable {
  case missingFixture(String)
}
