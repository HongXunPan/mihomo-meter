import SwiftUI

struct QuotaCumulativeTrendHoverView: View {
  static let cardWidth: CGFloat = 270

  let displayPoint: QuotaCumulativeTrendDisplayPoint
  let breakReason: QuotaCumulativeTrendDisplaySegment.BreakReason?
  var isCompact = false

  var body: some View {
    Group {
      if isCompact {
        content
      } else {
        content
          .frame(width: Self.cardWidth - 18, alignment: .leading)
          .padding(9)
          .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
          .overlay {
            RoundedRectangle(cornerRadius: 8)
              .stroke(Color(nsColor: .separatorColor).opacity(0.7), lineWidth: 0.5)
          }
          .shadow(color: .black.opacity(0.12), radius: 5, y: 2)
          .fixedSize(horizontal: true, vertical: true)
      }
    }
    .accessibilityElement(children: .combine)
  }

  private var content: some View {
    VStack(alignment: .leading, spacing: isCompact ? 2 : 5) {
      Text(SubscriptionQuotaFormatter.trendTimestamp(displayPoint.point.date))
        .font(.caption2.weight(.medium))
        .foregroundStyle(.secondary)

      Text(cumulativeSummary)
        .font(.caption.monospacedDigit())
        .lineLimit(1)

      Text(comparisonSummary)
        .font(.caption2)
        .foregroundStyle(comparisonTone)
        .fixedSize(horizontal: false, vertical: true)
    }
    .frame(maxWidth: isCompact ? .infinity : nil, alignment: .leading)
  }

  private var cumulativeSummary: String {
    let traffic = displayPoint.point.traffic
    return "累计 ↓\(SubscriptionQuotaFormatter.bytes(traffic.downloadBytes)) "
      + "↑\(SubscriptionQuotaFormatter.bytes(traffic.uploadBytes)) · "
      + "总消耗 \(SubscriptionQuotaFormatter.bytes(traffic.usedBytes))"
  }

  private var comparisonSummary: String {
    guard let previousPoint = displayPoint.previousPoint,
      let delta = displayPoint.delta
    else {
      if breakReason == .counterRegression {
        return "累计值回退后的首个点，无可比较增量"
      }
      return "本周期首个展示点，无可比较增量"
    }

    return "\(SubscriptionQuotaFormatter.trendTimestamp(previousPoint.date))–"
      + "\(SubscriptionQuotaFormatter.trendTimestamp(displayPoint.point.date)) · "
      + "\(SubscriptionQuotaFormatter.preciseDuration(delta.duration)) "
      + "↓\(SubscriptionQuotaFormatter.bytes(delta.downloadBytes)) "
      + "↑\(SubscriptionQuotaFormatter.bytes(delta.uploadBytes)) · "
      + "合计 \(SubscriptionQuotaFormatter.bytes(delta.totalBytes))"
  }

  private var comparisonTone: Color {
    breakReason == .counterRegression ? .orange : .secondary
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
      breakReason: breakReason
    )
    .offset(x: horizontalOffset, y: plotFrame.minY + 8)
    .allowsHitTesting(false)
  }

  private var horizontalOffset: CGFloat {
    let inset: CGFloat = 8
    if selectedX <= plotFrame.midX {
      return max(
        plotFrame.minX + inset,
        plotFrame.maxX - QuotaCumulativeTrendHoverView.cardWidth - inset
      )
    }
    return plotFrame.minX + inset
  }
}
