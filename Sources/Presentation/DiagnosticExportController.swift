import AppKit
import Combine
import Foundation
import UniformTypeIdentifiers

@MainActor
final class DiagnosticExportController: ObservableObject {
  @Published private(set) var isExporting = false
  @Published private(set) var statusMessage: String?
  @Published private(set) var errorMessage: String?

  private let logger: AppDiagnosticLogger

  init(logger: AppDiagnosticLogger) {
    self.logger = logger
  }

  func export(connectionState: MonitorConnectionState) {
    guard !isExporting else {
      return
    }

    isExporting = true
    statusMessage = nil
    errorMessage = nil

    Task {
      let events = await logger.diagnosticExportSnapshot()
      do {
        let report = DiagnosticExportReport(
          generatedAt: Date(),
          application: Self.currentEnvironment,
          connectionState: connectionState.diagnosticExportValue,
          events: events
        )
        let data = try report.encodedData()
        guard let destination = Self.chooseDestination() else {
          isExporting = false
          return
        }
        try data.write(to: destination, options: .atomic)
        statusMessage = "诊断信息已导出。"
      } catch {
        errorMessage = "无法导出诊断信息，请重新选择保存位置后再试。"
      }
      isExporting = false
    }
  }

  private static var currentEnvironment: DiagnosticExportEnvironment {
    DiagnosticExportEnvironment(
      platform: "macOS",
      version: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        ?? "unknown",
      build: Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown",
      operatingSystem: ProcessInfo.processInfo.operatingSystemVersionString,
      architecture: architecture
    )
  }

  private static var architecture: String {
    #if arch(arm64)
      "arm64"
    #elseif arch(x86_64)
      "x86_64"
    #else
      "unknown"
    #endif
  }

  private static func chooseDestination() -> URL? {
    let panel = NSSavePanel()
    panel.title = "导出诊断信息"
    panel.prompt = "导出"
    panel.allowedContentTypes = [.json]
    panel.allowsOtherFileTypes = false
    panel.canCreateDirectories = true
    panel.nameFieldStringValue = suggestedFileName
    return panel.runModal() == .OK ? panel.url : nil
  }

  private static var suggestedFileName: String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = .current
    formatter.dateFormat = "yyyyMMdd-HHmmss"
    return "Mihomo-Meter-Diagnostics-\(formatter.string(from: Date())).json"
  }
}

extension MonitorConnectionState {
  fileprivate var diagnosticExportValue: String {
    switch self {
    case .disconnected: "disconnected"
    case .connecting: "connecting"
    case .connected: "connected"
    case .stale: "stale"
    case .reconnecting: "reconnecting"
    case .authenticationFailed: "authentication_failed"
    case .unsupported: "unsupported"
    }
  }
}
