import SwiftUI

struct TrafficIntervalRow: View {
  let interval: TrafficInterval
  let isStatisticsAvailable: Bool
  let stop: () -> Void

  var body: some View {
    TimelineView(.periodic(from: .now, by: 1)) { context in
      VStack(alignment: .leading, spacing: 6) {
        HStack(spacing: 8) {
          Text(interval.name)
            .font(.subheadline.weight(.semibold))
            .lineLimit(1)

          Spacer(minLength: 8)

          if isStatisticsAvailable {
            Text(TrafficStatisticsFormatter.bytes(interval.proxyUsage.total))
              .font(.caption.monospacedDigit().weight(.medium))
              .foregroundStyle(MihomoColorToken.trafficProxy)
          } else {
            Label("不可用", systemImage: "exclamationmark.triangle.fill")
              .font(.caption2)
              .foregroundStyle(MihomoColorToken.statusWarning)
          }

          Button("停止", action: stop)
            .controlSize(.small)
            .disabled(!isStatisticsAvailable)
        }

        Text(timeDescription(now: context.date))
          .font(.caption2)
          .foregroundStyle(.secondary)
          .lineLimit(1)
      }
      .padding(.vertical, 8)
    }
  }

  private func timeDescription(now: Date) -> String {
    let duration = TrafficStatisticsFormatter.duration(from: interval.startedAt, to: now)
    return "\(TrafficStatisticsFormatter.dateTime(interval.startedAt)) 开始 · \(duration)"
  }
}
