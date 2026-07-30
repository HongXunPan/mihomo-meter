import SwiftUI

struct RoutingStatusPresentation {
  let proxySummary: String
  let proxyDetails: String
  let ruleSummary: String
  let ruleDetails: String
  let runtimeSummary: String

  init(
    activeProxyLeaves: [String],
    activeRuleTypes: [String],
    runtimeConfiguration: MihomoRuntimeConfiguration?
  ) {
    proxySummary = Self.compactSummary(
      activeProxyLeaves,
      emptyValue: "未检测到可确认出口",
      unit: "个出口"
    )
    proxyDetails =
      activeProxyLeaves.isEmpty
      ? proxySummary
      : activeProxyLeaves.joined(separator: "、")
    ruleSummary = Self.compactSummary(
      activeRuleTypes,
      emptyValue: "暂无活动规则",
      unit: "类规则"
    )
    ruleDetails =
      activeRuleTypes.isEmpty
      ? ruleSummary
      : activeRuleTypes.joined(separator: "、")
    runtimeSummary = Self.runtimeSummary(runtimeConfiguration)
  }

  var statusSummary: String {
    [proxySummary, runtimeSummary].joined(separator: " · ")
  }

  var statusSummaryHelp: String {
    [proxyDetails, runtimeSummary].joined(separator: " · ")
  }

  private static func compactSummary(
    _ values: [String],
    emptyValue: String,
    unit: String
  ) -> String {
    guard let first = values.first else {
      return emptyValue
    }
    guard values.count > 1 else {
      return first
    }
    return "\(first) 等 \(values.count)\(unit)"
  }

  private static func runtimeSummary(
    _ configuration: MihomoRuntimeConfiguration?
  ) -> String {
    guard let configuration else {
      return "—"
    }

    var components: [String] = []
    if let mode = configuration.mode {
      components.append(modeTitle(mode))
    }
    if let isTunEnabled = configuration.tun?.isEnabled {
      components.append(isTunEnabled ? "TUN" : "TUN 关闭")
    }
    return components.isEmpty ? "—" : components.joined(separator: " · ")
  }

  private static func modeTitle(_ mode: String) -> String {
    switch mode.lowercased() {
    case "rule":
      "Rule"
    case "global":
      "Global"
    case "direct":
      "Direct"
    default:
      mode
    }
  }
}

struct RoutingStatusView: View {
  @ObservedObject var monitor: TrafficMonitor

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      statusRow(
        title: "实际出口",
        value: presentation.proxySummary,
        help: presentation.proxyDetails
      )
      statusRow(
        title: "运行方式",
        value: presentation.runtimeSummary
      )
      statusRow(
        title: "命中规则",
        value: presentation.ruleSummary,
        help: presentation.ruleDetails
      )

      Divider()

      Text("运行详情")
        .font(.caption.weight(.semibold))

      RuntimeDetailsView(monitor: monitor)
    }
    .padding(12)
    .accessibilityElement(children: .contain)
    .accessibilityLabel("路由状态")
  }

  private var presentation: RoutingStatusPresentation {
    RoutingStatusPresentation(
      activeProxyLeaves: monitor.activeProxyLeaves,
      activeRuleTypes: monitor.activeRuleTypes,
      runtimeConfiguration: monitor.runtimeConfiguration
    )
  }

  private func statusRow(
    title: String,
    value: String,
    help: String? = nil
  ) -> some View {
    HStack(alignment: .firstTextBaseline, spacing: 12) {
      Text(title)
        .foregroundStyle(.secondary)

      Spacer(minLength: 12)

      Text(value)
        .lineLimit(1)
        .truncationMode(.middle)
        .help(help ?? value)
    }
    .font(.caption)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("\(title)，\(help ?? value)")
  }
}
