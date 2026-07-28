import SwiftUI

struct ClashProfileIdentityCard: View {
  let profile: ClashProfileSelectionItem

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      HStack(alignment: .top) {
        VStack(alignment: .leading, spacing: 3) {
          HStack(spacing: 6) {
            Text(profile.name)
              .font(.headline)
            if profile.isCurrent {
              Text("当前")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(MihomoColorToken.statusInfo)
            }
          }
          Text(profile.subscriptionDomain ?? "Profile 已不在授权目录中")
            .font(.caption2)
            .foregroundStyle(.secondary)
        }

        Spacer()

        Image(systemName: statusSymbolName)
          .foregroundStyle(statusColor)
      }

      Divider()

      VStack(alignment: .leading, spacing: 5) {
        Text(statusTitle)
          .font(.subheadline.weight(.medium))
        Text(statusMessage)
          .font(.caption)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
    .padding(16)
    .background(
      Color(nsColor: .controlBackgroundColor),
      in: RoundedRectangle(cornerRadius: 12)
    )
  }

  private var statusTitle: String {
    switch profile.availability {
    case .available:
      "Profile 身份已绑定"
    case .unsupportedURL:
      "订阅地址不受支持"
    case .missing:
      "等待 Profile 恢复"
    }
  }

  private var statusMessage: String {
    switch profile.availability {
    case .available:
      let hours = (profile.refreshIntervalMinutes ?? 360) / 60
      return "Meter 查询间隔：\(hours) 小时。尚无主动查询快照。"
    case .unsupportedURL:
      return "指定 Profile 模式只允许通过 HTTPS 查询。"
    case .missing:
      return "保留原 UID 历史，不会自动绑定重新导入的新 UID。"
    }
  }

  private var statusSymbolName: String {
    profile.availability == .available ? "link" : "exclamationmark.triangle.fill"
  }

  private var statusColor: Color {
    profile.availability == .available
      ? MihomoColorToken.statusInfo : MihomoColorToken.statusWarning
  }
}
