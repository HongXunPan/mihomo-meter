import SwiftUI

struct LiveConnectionAnalyticsContextView: View {
  @Binding var selectedRoute: LiveConnectionRoute

  let connectionCount: Int
  let coverage: ConnectionAttributionCoverage
  let processMatchingMode: MihomoProcessMatchingMode?

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      routeSummary
      Divider()
      routeDetails
    }
    .padding(12)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
  }

  private var routeSummary: some View {
    ViewThatFits(in: .horizontal) {
      HStack(spacing: 12) {
        routePicker
        activeConnectionCount
        Spacer()
        privacySummary
      }

      VStack(alignment: .leading, spacing: 8) {
        routePicker
        HStack(spacing: 12) {
          activeConnectionCount
          Spacer()
          privacySummary
        }
      }
    }
  }

  private var routePicker: some View {
    Picker("连接路由", selection: $selectedRoute) {
      ForEach(LiveConnectionRoute.allCases) { route in
        Text(route.title).tag(route)
      }
    }
    .pickerStyle(.segmented)
    .frame(width: 220)
  }

  private var activeConnectionCount: some View {
    Text("\(connectionCount.formatted()) 条活动连接")
      .font(.caption)
      .foregroundStyle(.secondary)
      .monospacedDigit()
      .fixedSize()
  }

  private var privacySummary: some View {
    Label("本次连接会话 · 不保存明细", systemImage: "lock")
      .font(.caption)
      .foregroundStyle(.secondary)
      .fixedSize()
  }

  @ViewBuilder
  private var routeDetails: some View {
    switch selectedRoute {
    case .proxy:
      proxyDetails
    case .direct:
      directDetails
    }
  }

  private var proxyDetails: some View {
    let diagnostic = ApplicationIdentificationDiagnostic(
      mode: processMatchingMode,
      coverage: coverage
    )
    return VStack(alignment: .leading, spacing: 8) {
      ViewThatFits(in: .horizontal) {
        HStack(spacing: 18) {
          coverageMetrics
          Divider()
            .frame(height: 30)
          diagnosticSummary(diagnostic)
          Spacer(minLength: 0)
        }

        VStack(alignment: .leading, spacing: 8) {
          coverageMetrics
          diagnosticSummary(diagnostic)
        }
      }

      if diagnostic.shouldShowDetail {
        Text(diagnostic.detail)
          .font(.caption)
          .foregroundStyle(.secondary)
          .padding(.horizontal, 10)
          .padding(.vertical, 8)
          .frame(maxWidth: .infinity, alignment: .leading)
          .background(
            diagnostic.isWarning
              ? MihomoColorToken.statusWarningBackground
              : Color.secondary.opacity(0.07),
            in: RoundedRectangle(cornerRadius: 8)
          )
      }
    }
  }

  private var coverageMetrics: some View {
    HStack(spacing: 18) {
      coverageMetric("主机名", rate: coverage.hostnameRate)
      coverageMetric("应用", rate: coverage.applicationRate)
      coverageMetric("两者同时", rate: coverage.fullyIdentifiedRate)
    }
    .fixedSize()
  }

  private func diagnosticSummary(
    _ diagnostic: ApplicationIdentificationDiagnostic
  ) -> some View {
    HStack(spacing: 8) {
      Image(systemName: diagnostic.isWarning ? "exclamationmark.triangle.fill" : "info.circle")
        .foregroundStyle(
          diagnostic.isWarning ? MihomoColorToken.statusWarning : MihomoColorToken.statusNeutral
        )
      Text(diagnostic.title)
        .font(.callout.weight(.medium))
    }
    .accessibilityElement(children: .combine)
  }

  private var directDetails: some View {
    HStack(alignment: .top, spacing: 8) {
      Image(systemName: "arrow.triangle.branch")
        .foregroundStyle(MihomoColorToken.statusNeutral)
      Text("DIRECT 仅实时展示，不保存连接明细，也不计入 Proxy 统计与历史归因；主机名和应用是否可识别取决于 Mihomo 元数据。")
        .font(.caption)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
      Spacer(minLength: 0)
    }
    .accessibilityElement(children: .combine)
  }

  private func coverageMetric(_ title: String, rate: Double?) -> some View {
    VStack(alignment: .leading, spacing: 2) {
      Text(title)
        .font(.caption2)
        .foregroundStyle(.secondary)
      Text(TrafficRateFormatter.percentage(from: rate))
        .font(.callout.weight(.semibold))
        .monospacedDigit()
    }
  }
}
