import SwiftUI

struct QuotaCumulativeTrendHoverView: View {
  static let preferredCardWidth: CGFloat = 320

  let displayPoint: QuotaCumulativeTrendDisplayPoint
  let breakReason: QuotaCumulativeTrendDisplaySegment.BreakReason?
  let isCompact: Bool
  let cardWidth: CGFloat

  init(
    displayPoint: QuotaCumulativeTrendDisplayPoint,
    breakReason: QuotaCumulativeTrendDisplaySegment.BreakReason?,
    isCompact: Bool = false,
    cardWidth: CGFloat = QuotaCumulativeTrendHoverView.preferredCardWidth
  ) {
    self.displayPoint = displayPoint
    self.breakReason = breakReason
    self.isCompact = isCompact
    self.cardWidth = cardWidth
  }

  var body: some View {
    Group {
      if isCompact {
        content
      } else {
        content
          .frame(width: max(cardWidth - 18, 1), alignment: .leading)
          .padding(9)
          .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
          .overlay {
            RoundedRectangle(cornerRadius: 8)
              .stroke(Color(nsColor: .separatorColor).opacity(0.7), lineWidth: 0.5)
          }
          .shadow(color: .black.opacity(0.12), radius: 5, y: 2)
      }
    }
    .accessibilityElement(children: .combine)
  }

  private var content: some View {
    VStack(alignment: .leading, spacing: isCompact ? 5 : 7) {
      header

      if !isCompact {
        Divider()
      }

      metricHeader
      metricRow(
        title: "累计",
        download: displayPoint.point.traffic.downloadBytes,
        upload: displayPoint.point.traffic.uploadBytes,
        total: displayPoint.point.traffic.usedBytes
      )
      metricRow(
        title: "较上点",
        download: displayPoint.delta?.downloadBytes,
        upload: displayPoint.delta?.uploadBytes,
        total: displayPoint.delta?.totalBytes
      )
    }
    .frame(maxWidth: isCompact ? .infinity : nil, alignment: .leading)
  }

  private var header: some View {
    HStack(alignment: .firstTextBaseline, spacing: 8) {
      Text(SubscriptionQuotaFormatter.trendInspectorTimestamp(displayPoint.point.date))
        .font(.caption.weight(.semibold))
        .foregroundStyle(.primary)

      Spacer(minLength: 8)

      Text(comparisonContext)
        .font(.caption2.monospacedDigit())
        .foregroundStyle(comparisonContextColor)
        .lineLimit(1)
        .minimumScaleFactor(0.8)
    }
  }

  private var metricHeader: some View {
    HStack(spacing: columnSpacing) {
      Color.clear
        .frame(width: rowTitleWidth, height: 1)
      metricHeaderCell(
        title: "下载",
        systemImage: "arrow.down",
        color: MihomoColorToken.trafficDownload
      )
      metricHeaderCell(
        title: "上传",
        systemImage: "arrow.up",
        color: MihomoColorToken.trafficUpload
      )
      metricHeaderCell(
        title: "总计",
        systemImage: "chart.line.uptrend.xyaxis",
        color: .primary
      )
    }
  }

  private func metricHeaderCell(
    title: String,
    systemImage: String,
    color: Color
  ) -> some View {
    Label(title, systemImage: systemImage)
      .font(.caption2.weight(.medium))
      .foregroundStyle(color)
      .lineLimit(1)
      .frame(maxWidth: .infinity, alignment: .leading)
  }

  private func metricRow(
    title: String,
    download: UInt64?,
    upload: UInt64?,
    total: UInt64?
  ) -> some View {
    HStack(spacing: columnSpacing) {
      Text(title)
        .font(.caption2)
        .foregroundStyle(.secondary)
        .lineLimit(1)
        .frame(width: rowTitleWidth, alignment: .leading)
      metricValue(download)
      metricValue(upload)
      metricValue(total)
    }
  }

  private func metricValue(_ value: UInt64?) -> some View {
    Text(value.map(SubscriptionQuotaFormatter.bytes) ?? "—")
      .font(.caption.monospacedDigit().weight(.semibold))
      .foregroundStyle(.primary)
      .lineLimit(1)
      .minimumScaleFactor(0.75)
      .frame(maxWidth: .infinity, alignment: .leading)
  }

  private var comparisonContext: String {
    guard let previousPoint = displayPoint.previousPoint else {
      if breakReason == .counterRegression {
        return "累计回退后首点 · 无比较增量"
      }
      return "本周期首点 · 无比较增量"
    }
    return SubscriptionQuotaFormatter.trendComparison(
      from: previousPoint.date,
      to: displayPoint.point.date
    )
  }

  private var comparisonContextColor: Color {
    breakReason == .counterRegression ? MihomoColorToken.statusWarning : .secondary
  }

  private var rowTitleWidth: CGFloat {
    isCompact ? 44 : 48
  }

  private var columnSpacing: CGFloat {
    isCompact ? 8 : 10
  }
}

struct QuotaCumulativeTrendHoverOverlay: View {
  let displayPoint: QuotaCumulativeTrendDisplayPoint
  let breakReason: QuotaCumulativeTrendDisplaySegment.BreakReason?
  let selectedX: CGFloat
  let plotFrame: CGRect

  var body: some View {
    QuotaCumulativeTrendHoverView(
      displayPoint: displayPoint,
      breakReason: breakReason,
      cardWidth: cardWidth
    )
    .offset(x: horizontalOffset, y: plotFrame.minY + 8)
    .allowsHitTesting(false)
  }

  private var horizontalOffset: CGFloat {
    let inset: CGFloat = 8
    if selectedX <= plotFrame.midX {
      return max(
        plotFrame.minX + inset,
        plotFrame.maxX - cardWidth - inset
      )
    }
    return plotFrame.minX + inset
  }

  private var cardWidth: CGFloat {
    min(
      QuotaCumulativeTrendHoverView.preferredCardWidth,
      max(plotFrame.width - 16, 1)
    )
  }
}
