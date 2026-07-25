import SwiftUI

struct AppHelpLinksMenu: View {
  var body: some View {
    Menu {
      navigationLink(.prepareMihomo)
      navigationLink(.mihomoControllerConfiguration)

      Divider()

      navigationLink(.userGuide)
      navigationLink(.releases)
      navigationLink(.issueReport)
    } label: {
      Image(systemName: "questionmark.circle")
        .frame(width: 24, height: 20)
        .contentShape(Rectangle())
    }
    .menuStyle(.borderlessButton)
    .menuIndicator(.hidden)
    .controlSize(.small)
    .fixedSize()
    .help("帮助与文档")
    .accessibilityLabel("帮助与文档")
  }

  private func navigationLink(_ link: AppHelpLink) -> some View {
    Link(destination: link.destination) {
      Label(link.title, systemImage: link.systemImage)
    }
  }
}

enum AppHelpLink: CaseIterable {
  case prepareMihomo
  case mihomoControllerConfiguration
  case userGuide
  case releases
  case issueReport

  var title: String {
    switch self {
    case .prepareMihomo:
      "准备 Mihomo"
    case .mihomoControllerConfiguration:
      "Mihomo 服务配置"
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
