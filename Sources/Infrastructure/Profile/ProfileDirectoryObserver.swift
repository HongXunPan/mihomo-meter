import Darwin
import Foundation

@MainActor
final class ProfileDirectoryObserver: ProfileDirectoryObserving {
  private static let debounceInterval = 0.4

  private var source: DispatchSourceFileSystemObject?
  private var debounceWorkItem: DispatchWorkItem?

  func startObserving(
    directoryURL: URL,
    onChange: @escaping @MainActor () -> Void
  ) throws {
    stopObserving()

    let descriptor = open(directoryURL.path, O_EVTONLY)
    guard descriptor >= 0 else {
      throw ProfileDirectoryObserverError.cannotOpenDirectory
    }

    let source = DispatchSource.makeFileSystemObjectSource(
      fileDescriptor: descriptor,
      eventMask: [.write, .rename, .delete, .extend, .attrib, .link],
      queue: .main
    )
    source.setEventHandler { [weak self] in
      self?.scheduleReload(onChange)
    }
    source.setCancelHandler {
      close(descriptor)
    }
    self.source = source
    source.resume()
  }

  func stopObserving() {
    debounceWorkItem?.cancel()
    debounceWorkItem = nil
    source?.cancel()
    source = nil
  }

  private func scheduleReload(_ onChange: @escaping @MainActor () -> Void) {
    debounceWorkItem?.cancel()
    let workItem = DispatchWorkItem {
      MainActor.assumeIsolated {
        onChange()
      }
    }
    debounceWorkItem = workItem
    DispatchQueue.main.asyncAfter(
      deadline: .now() + Self.debounceInterval,
      execute: workItem
    )
  }
}

enum ProfileDirectoryObserverError: Error, Equatable, LocalizedError {
  case cannotOpenDirectory

  var errorDescription: String? {
    "无法监听所选 Profile 目录。"
  }
}
