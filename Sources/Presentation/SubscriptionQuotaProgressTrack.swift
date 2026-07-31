import SwiftUI

struct SubscriptionQuotaProgressTrack: View {
  enum Style {
    case summary
    case compact

    var height: CGFloat {
      switch self {
      case .summary:
        56
      case .compact:
        7
      }
    }

    var cornerRadius: CGFloat {
      switch self {
      case .summary:
        9
      case .compact:
        height / 2
      }
    }

    var fillOpacity: Double {
      switch self {
      case .summary:
        0.18
      case .compact:
        1
      }
    }

    var trackOpacity: Double {
      switch self {
      case .summary:
        0.05
      case .compact:
        0.10
      }
    }

    var overQuotaTrackOpacity: Double {
      switch self {
      case .summary:
        0.08
      case .compact:
        0.20
      }
    }

    var showsBorder: Bool {
      switch self {
      case .summary:
        true
      case .compact:
        false
      }
    }
  }

  let fraction: Double?
  let isOverQuota: Bool
  let style: Style

  var body: some View {
    GeometryReader { geometry in
      ZStack(alignment: .leading) {
        RoundedRectangle(cornerRadius: style.cornerRadius, style: .continuous)
          .fill(trackColor)

        Rectangle()
          .fill(progressColor.opacity(style.fillOpacity))
          .frame(width: geometry.size.width * CGFloat(normalizedFraction))
          .frame(maxHeight: .infinity)
      }
      .clipShape(
        RoundedRectangle(cornerRadius: style.cornerRadius, style: .continuous)
      )
    }
    .frame(height: style.height)
    .overlay {
      if style.showsBorder {
        RoundedRectangle(cornerRadius: style.cornerRadius, style: .continuous)
          .stroke(progressColor.opacity(0.22), lineWidth: 0.75)
      }
    }
  }

  private var normalizedFraction: Double {
    min(max(fraction ?? 0, 0), 1)
  }

  private var trackColor: Color {
    if isOverQuota {
      return MihomoColorToken.statusDanger.opacity(style.overQuotaTrackOpacity)
    }
    return Color.primary.opacity(style.trackOpacity)
  }

  private var progressColor: Color {
    guard fraction != nil else {
      return MihomoColorToken.statusNeutral
    }
    return isOverQuota ? MihomoColorToken.statusDanger : MihomoColorToken.brandPrimary
  }
}
