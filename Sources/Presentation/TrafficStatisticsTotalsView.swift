import SwiftUI

struct TrafficStatisticsTotalsView: View {
  let todayBytes: UInt64
  let lifetimeBytes: UInt64
  var activeCount: Int?

  var body: some View {
    HStack(spacing: 12) {
      metric(title: "今日 Proxy", value: TrafficStatisticsFormatter.bytes(todayBytes))
      Divider()
        .frame(height: 32)
      metric(title: "本机累计 Proxy", value: TrafficStatisticsFormatter.bytes(lifetimeBytes))

      if let activeCount {
        Divider()
          .frame(height: 32)
        metric(title: "进行中", value: "\(activeCount) 个")
      }
    }
    .padding(.vertical, 4)
  }

  private func metric(title: String, value: String) -> some View {
    VStack(alignment: .center, spacing: 3) {
      Text(title)
        .font(.caption2)
        .foregroundStyle(.secondary)
      Text(value)
        .font(.subheadline.monospacedDigit().weight(.semibold))
        .lineLimit(1)
    }
    .frame(maxWidth: .infinity, alignment: .center)
  }
}
