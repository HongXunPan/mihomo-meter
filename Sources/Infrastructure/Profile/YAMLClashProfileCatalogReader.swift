import Foundation
import Yams

protocol ClashProfileCatalogReading: Sendable {
  func readCatalog(in directoryURL: URL) throws -> ClashProfileCatalog
}

struct YAMLClashProfileCatalogReader: ClashProfileCatalogReading {
  private static let profilesFileName = "profiles.yaml"
  private static let maximumFileSize = 2 * 1_024 * 1_024

  func readCatalog(in directoryURL: URL) throws -> ClashProfileCatalog {
    do {
      let fileURL = directoryURL.appendingPathComponent(Self.profilesFileName, isDirectory: false)
      let values = try fileURL.resourceValues(
        forKeys: [.fileSizeKey, .isRegularFileKey, .isSymbolicLinkKey]
      )
      guard values.isRegularFile == true, values.isSymbolicLink != true else {
        throw ClashProfileCatalogReaderError.invalidProfilesFile
      }
      guard let fileSize = values.fileSize, fileSize <= Self.maximumFileSize else {
        throw ClashProfileCatalogReaderError.profilesFileTooLarge
      }

      let data = try Data(contentsOf: fileURL)
      guard let contents = String(data: data, encoding: .utf8) else {
        throw ClashProfileCatalogReaderError.invalidTextEncoding
      }
      let document = try YAMLDecoder().decode(ClashProfilesDocument.self, from: contents)
      return try catalog(from: document)
    } catch let error as ClashProfileCatalogReaderError {
      throw error
    } catch {
      if error is DecodingError || error is YamlError {
        throw ClashProfileCatalogReaderError.invalidYAML
      }
      throw ClashProfileCatalogReaderError.invalidProfilesFile
    }
  }

  private func catalog(from document: ClashProfilesDocument) throws -> ClashProfileCatalog {
    var profiles: [ClashProfile] = []
    var ignoredRemoteProfileCount = 0
    var seenUIDs: Set<String> = []

    for item in document.items ?? [] where item.type?.lowercased() == "remote" {
      guard
        let uid = item.uid,
        let name = item.name,
        let urlText = item.url,
        let url = URL(string: urlText),
        let profile = try? ClashProfile(uid: uid, name: name, subscriptionURL: url)
      else {
        ignoredRemoteProfileCount += 1
        continue
      }
      guard seenUIDs.insert(profile.uid).inserted else {
        throw ClashProfileCatalogReaderError.duplicateUID
      }
      profiles.append(profile)
    }

    return ClashProfileCatalog(
      currentUID: normalized(document.current),
      profiles: profiles,
      ignoredRemoteProfileCount: ignoredRemoteProfileCount
    )
  }

  private func normalized(_ value: String?) -> String? {
    guard let value else {
      return nil
    }
    let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
    return normalized.isEmpty ? nil : normalized
  }
}

private struct ClashProfilesDocument: Decodable {
  let current: String?
  let items: [ClashProfileItem]?
}

private struct ClashProfileItem: Decodable {
  let uid: String?
  let type: String?
  let name: String?
  let url: String?
}

enum ClashProfileCatalogReaderError: Error, Equatable, LocalizedError {
  case invalidProfilesFile
  case profilesFileTooLarge
  case invalidTextEncoding
  case invalidYAML
  case duplicateUID

  var errorDescription: String? {
    switch self {
    case .invalidProfilesFile:
      "所选目录中没有可读取的 profiles.yaml。"
    case .profilesFileTooLarge:
      "profiles.yaml 超出安全读取上限。"
    case .invalidTextEncoding, .invalidYAML:
      "profiles.yaml 格式无效，无法读取 Profile。"
    case .duplicateUID:
      "profiles.yaml 包含重复 UID，已停止身份映射。"
    }
  }
}
