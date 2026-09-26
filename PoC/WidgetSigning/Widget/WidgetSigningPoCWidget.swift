import SwiftUI
import WidgetKit

private struct WidgetSigningPoCEntry: TimelineEntry {
  let date: Date
  let message: String
}

private struct WidgetSigningPoCProvider: TimelineProvider {
  func placeholder(in context: Context) -> WidgetSigningPoCEntry {
    WidgetSigningPoCEntry(date: Date(), message: "等待主应用测试快照")
  }

  func getSnapshot(
    in context: Context,
    completion: @escaping (WidgetSigningPoCEntry) -> Void
  ) {
    completion(makeEntry())
  }

  func getTimeline(
    in context: Context,
    completion: @escaping (Timeline<WidgetSigningPoCEntry>) -> Void
  ) {
    let entry = makeEntry()
    completion(
      Timeline(
        entries: [entry],
        policy: .after(entry.date.addingTimeInterval(15 * 60))
      )
    )
  }

  private func makeEntry() -> WidgetSigningPoCEntry {
    WidgetSigningPoCEntry(date: Date(), message: WidgetSigningPoCDiagnostics.inspect())
  }
}

private struct WidgetSigningPoCView: View {
  let entry: WidgetSigningPoCEntry

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Label("Mihomo Meter PoC", systemImage: "network")
        .font(.headline)
      Text(entry.message)
        .font(.caption2)
        .lineLimit(5)
      Spacer(minLength: 0)
      Text("路径诊断版 5 · 仅假数据")
        .font(.caption2)
        .foregroundStyle(.secondary)
    }
    .padding()
    .containerBackground(.background, for: .widget)
  }
}

@main
struct WidgetSigningPoCWidget: Widget {
  var body: some WidgetConfiguration {
    StaticConfiguration(
      kind: WidgetSigningPoCConstants.widgetKind,
      provider: WidgetSigningPoCProvider()
    ) { entry in
      WidgetSigningPoCView(entry: entry)
    }
    .configurationDisplayName("Mihomo Meter 签名 PoC")
    .description("验证固定自签名 Widget 对专用目录的只读访问，不展示真实流量。")
    .supportedFamilies([.systemSmall])
  }
}
