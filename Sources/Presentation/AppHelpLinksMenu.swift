import AppKit
import SwiftUI

struct AppHelpLinksMenu: View {
  var body: some View {
    Menu {
      navigationLink(.userGuide)

      Divider()

      navigationLink(.prepareMihomo)
      navigationLink(.subscriptionConfiguration)
      navigationLink(.mihomoControllerConfiguration)

      Divider()

      navigationLink(.releases)

      Button(action: openDiagnosticLogDirectory) {
        Label("打开诊断日志文件夹", systemImage: "doc.text.magnifyingglass")
      }

      navigationLink(.issueReport)
    } label: {
      Label("帮助", systemImage: "questionmark.circle")
    }
    .menuStyle(.borderlessButton)
    .controlSize(.small)
    .fixedSize()
    .help("打开 Mihomo Meter 帮助")
    .accessibilityLabel("帮助")
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

struct AppHelpCommands: Commands {
  var body: some Commands {
    CommandGroup(replacing: .help) {
      Link(AppHelpLink.userGuide.title, destination: AppHelpLink.userGuide.destination)

      Divider()

      Link(AppHelpLink.prepareMihomo.title, destination: AppHelpLink.prepareMihomo.destination)
      Link(
        AppHelpLink.subscriptionConfiguration.title,
        destination: AppHelpLink.subscriptionConfiguration.destination
      )
      Link(
        AppHelpLink.mihomoControllerConfiguration.title,
        destination: AppHelpLink.mihomoControllerConfiguration.destination
      )

      Divider()

      Link(AppHelpLink.releases.title, destination: AppHelpLink.releases.destination)

      Button("打开诊断日志文件夹") {
        NSWorkspace.shared.open(AppDiagnosticLogger.defaultDirectoryURL())
      }

      Link(AppHelpLink.issueReport.title, destination: AppHelpLink.issueReport.destination)
    }
  }
}

@MainActor
final class AppHelpMenuController: NSObject {
  let menuItem: NSMenuItem

  override init() {
    menuItem = NSMenuItem(title: "帮助", action: nil, keyEquivalent: "")
    super.init()

    let submenu = NSMenu(title: "帮助")
    appendLink(.userGuide, to: submenu)
    submenu.addItem(.separator())
    appendLink(.prepareMihomo, to: submenu)
    appendLink(.subscriptionConfiguration, to: submenu)
    appendLink(.mihomoControllerConfiguration, to: submenu)
    submenu.addItem(.separator())
    appendLink(.releases, to: submenu)

    let diagnosticLogItem = NSMenuItem(
      title: "打开诊断日志文件夹",
      action: #selector(openDiagnosticLogDirectory),
      keyEquivalent: ""
    )
    diagnosticLogItem.target = self
    submenu.addItem(diagnosticLogItem)

    appendLink(.issueReport, to: submenu)
    menuItem.submenu = submenu
  }

  private func appendLink(_ link: AppHelpLink, to menu: NSMenu) {
    let item = NSMenuItem(
      title: link.title,
      action: #selector(openLink),
      keyEquivalent: ""
    )
    item.target = self
    item.representedObject = link.destination as NSURL
    menu.addItem(item)
  }

  @objc private func openLink(_ sender: NSMenuItem) {
    guard let destination = sender.representedObject as? NSURL else {
      return
    }
    NSWorkspace.shared.open(destination as URL)
  }

  @objc private func openDiagnosticLogDirectory() {
    NSWorkspace.shared.open(AppDiagnosticLogger.defaultDirectoryURL())
  }
}

enum AppHelpLink: CaseIterable {
  case userGuide
  case prepareMihomo
  case subscriptionConfiguration
  case mihomoControllerConfiguration
  case releases
  case issueReport

  var title: String {
    switch self {
    case .userGuide:
      "Mihomo Meter 使用指南（Wiki）"
    case .prepareMihomo:
      "第一次使用：从零开始"
    case .subscriptionConfiguration:
      "配置订阅地址与余额追踪"
    case .mihomoControllerConfiguration:
      "Mihomo 官方 Controller 配置"
    case .releases:
      "版本发布与下载"
    case .issueReport:
      "问题反馈"
    }
  }

  var systemImage: String {
    switch self {
    case .userGuide:
      "book.closed"
    case .prepareMihomo:
      "server.rack"
    case .subscriptionConfiguration:
      "link"
    case .mihomoControllerConfiguration:
      "network"
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
    case .userGuide:
      "https://github.com/HongXunPan/mihomo-meter/wiki"
    case .prepareMihomo:
      "https://github.com/HongXunPan/mihomo-meter/wiki/%E5%87%86%E5%A4%87-Mihomo"
    case .subscriptionConfiguration:
      "https://github.com/HongXunPan/mihomo-meter/wiki/%E9%85%8D%E7%BD%AE%E8%AE%A2%E9%98%85%E5%9C%B0%E5%9D%80"
    case .mihomoControllerConfiguration:
      "https://wiki.metacubex.one/config/general/"
    case .releases:
      "https://github.com/HongXunPan/mihomo-meter/releases"
    case .issueReport:
      "https://github.com/HongXunPan/mihomo-meter/issues/new/choose"
    }
  }
}
