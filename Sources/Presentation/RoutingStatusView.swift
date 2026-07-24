import SwiftUI

struct RoutingStatusView: View {
  @ObservedObject var monitor: TrafficMonitor
  @Binding var showsRuntimeDetails: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("路由状态")
        .font(.headline)

      statusRow(
        title: "实际出口",
        value: proxySummary,
        help: proxyDetails
      )
      statusRow(
        title: "运行方式",
        value: runtimeSummary
      )
      statusRow(
        title: "命中规则",
        value: ruleSummary,
        help: ruleDetails
      )

      DisclosureGroup(isExpanded: $showsRuntimeDetails) {
        RuntimeDetailsView(monitor: monitor)
          .padding(.top, 8)
          .padding(.leading, 14)
      } label: {
        Text("运行详情")
      }
      .padding(.top, 2)
      .font(.caption)
      .accessibilityValue(showsRuntimeDetails ? "已展开" : "已折叠")
      .accessibilityHint("显示 Mihomo 运行配置和原始 Proxy 速度")
    }
  }

  private var proxySummary: String {
    compactSummary(
      monitor.activeProxyLeaves,
      emptyValue: "未检测到可确认出口",
      unit: "个出口"
    )
  }

  private var proxyDetails: String {
    monitor.activeProxyLeaves.isEmpty
      ? proxySummary
      : monitor.activeProxyLeaves.joined(separator: "、")
  }

  private var ruleSummary: String {
    compactSummary(
      monitor.activeRuleTypes,
      emptyValue: "暂无活动规则",
      unit: "类规则"
    )
  }

  private var ruleDetails: String {
    monitor.activeRuleTypes.isEmpty
      ? ruleSummary
      : monitor.activeRuleTypes.joined(separator: "、")
  }

  private var runtimeSummary: String {
    guard let configuration = monitor.runtimeConfiguration else {
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

  private func compactSummary(
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

  private func modeTitle(_ mode: String) -> String {
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
