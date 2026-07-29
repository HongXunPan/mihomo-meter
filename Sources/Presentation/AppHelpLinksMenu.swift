import AppKit
import SwiftUI

struct AppHelpLinksMenu: View {
  var body: some View {
    Menu {
      navigationLink(.prepareMihomo)
      navigationLink(.subscriptionConfiguration)
      navigationLink(.mihomoControllerConfiguration)

      Divider()

      navigationLink(.userGuide)
      navigationLink(.releases)

      Button(action: openDiagnosticLogDirectory) {
        Label("打开诊断日志文件夹", systemImage: "doc.text.magnifyingglass")
      }

      navigationLink(.issueReport)
    } label: {
      Label("帮助与文档", systemImage: "questionmark.circle")
    }
    .menuStyle(.borderlessButton)
    .controlSize(.small)
    .fixedSize()
    .help("打开帮助与文档")
    .accessibilityLabel("帮助与文档")
  }

  private func navigationLink(_ link: AppHelpLink) -> some View {
    Link(destination: link.destination) {
      Label(link.title, systemImage: link.systemImage)
    }
  }

  private func openDiagnosticLogDirectory() {
    NSWorkspace.shared.open(AppDiagnosticLogger.defaultDirectoryURL())
  }
}

enum AppHelpLink: CaseIterable {
  case prepareMihomo
  case subscriptionConfiguration
  case mihomoControllerConfiguration
  case userGuide
  case releases
  case issueReport

  var title: String {
    switch self {
    case .prepareMihomo:
      "第一次使用：从零开始"
    case .subscriptionConfiguration:
      "配置订阅地址与余额追踪"
    case .mihomoControllerConfiguration:
      "Mihomo 官方 Controller 配置"
    case .userGuide:
      "Mihomo Meter 使用指南"
    case .releases:
      "版本发布与下载"
    case .issueReport:
      "问题反馈"
    }
  }

  var systemImage: String {
    switch self {
    case .prepareMihomo:
      "server.rack"
    case .subscriptionConfiguration:
      "link"
    case .mihomoControllerConfiguration:
      "network"
    case .userGuide:
      "book.closed"
    case .releases:
      "arrow.down.circle"
    case .issueReport:
      "exclamationmark.bubble"
    }
  }

  var destination: URL {
    guard let destination = URL(string: destinationText) else {
      preconditionFailure("固定帮助链接无效。")
    }
    return destination
  }

  private var destinationText: String {
    switch self {
    case .prepareMihomo:
      "https://github.com/HongXunPan/mihomo-meter/wiki/%E5%87%86%E5%A4%87-Mihomo"
    case .subscriptionConfiguration:
      "https://github.com/HongXunPan/mihomo-meter/wiki/%E9%85%8D%E7%BD%AE%E8%AE%A2%E9%98%85%E5%9C%B0%E5%9D%80"
    case .mihomoControllerConfiguration:
      "https://wiki.metacubex.one/config/general/"
    case .userGuide:
      "https://github.com/HongXunPan/mihomo-meter/wiki"
    case .releases:
      "https://github.com/HongXunPan/mihomo-meter/releases"
    case .issueReport:
      "https://github.com/HongXunPan/mihomo-meter/issues/new/choose"
    }
  }
}
