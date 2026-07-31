import SwiftUI

struct SubscriptionQuotaSummaryView: View {
  @ObservedObject var controller: RuntimeQuotaTrackingController
  @ObservedObject var profileQuotaController: ProfileQuotaTrackingController

  @State private var showsConfirmation = false

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      header
      if hasTrackedProfiles {
        ProfileQuotaProgressListView(controller: profileQuotaController)
      } else if let subscription = controller.snapshot.subscription {
        SubscriptionQuotaProgressRow(
          title: subscription.name,
          isCurrent: true,
          quota: controller.snapshot.latestQuota,
          status: nil,
          forecast: controller.snapshot.trends.depletionForecast
        )

        if controller.snapshot.latestQuota == nil || controller.snapshot.isPaused {
          SubscriptionQuotaObservationNoticeView(controller: controller)
        }

        confirmationAction
      } else {
        SubscriptionQuotaObservationNoticeView(controller: controller)

        emptyState
        confirmationAction
      }
    }
    .confirmationDialog(
      confirmationTitle,
      isPresented: $showsConfirmation
    ) {
      Button(confirmationActionTitle) {
        Task {
          if controller.snapshot.subscription == nil {
            await controller.enableTracking()
          } else {
            await controller.resumeTracking()
          }
        }
      }
      Button("取消", role: .cancel) {}
    } message: {
      Text(confirmationMessage)
    }
  }

  private var header: some View {
    HStack {
      Label("订阅余额", systemImage: "chart.line.downtrend.xyaxis")
        .font(.headline)

      Link(destination: AppHelpLink.subscriptionConfiguration.destination) {
        Label("配置指引", systemImage: "questionmark.circle")
      }
      .font(.caption)
      .accessibilityHint("了解订阅地址来源和两种余额追踪方式")

      Spacer()

      if hasTrackedProfiles {
        Text("精确追踪 \(profileQuotaController.snapshot.profiles.count)")
          .font(.caption2.weight(.medium))
          .foregroundStyle(MihomoColorToken.brandPrimary)
      } else if controller.snapshot.isActive {
        Text("轻量追踪")
          .font(.caption2.weight(.medium))
          .foregroundStyle(MihomoColorToken.brandPrimary)
      } else if controller.snapshot.isPaused {
        Text("已暂停")
          .font(.caption2.weight(.medium))
          .foregroundStyle(MihomoColorToken.statusWarning)
      }
    }
  }

  private var emptyState: some View {
    Text(emptyMessage)
      .font(.caption)
      .foregroundStyle(.secondary)
      .fixedSize(horizontal: false, vertical: true)
      .frame(maxWidth: .infinity, minHeight: 42, alignment: .center)
  }

  @ViewBuilder
  private var confirmationAction: some View {
    if canConfirmTracking {
      Button(confirmationActionTitle) {
        showsConfirmation = true
      }
      .buttonStyle(.borderedProminent)
      .controlSize(.small)
      .frame(maxWidth: .infinity, alignment: .trailing)
    }
  }

  private var canConfirmTracking: Bool {
    guard controller.snapshot.observationStatus == .available else {
      return false
    }
    return controller.snapshot.subscription == nil || controller.snapshot.isPaused
  }

  private var hasTrackedProfiles: Bool {
    !profileQuotaController.snapshot.profiles.isEmpty
  }

  private var emptyMessage: String {
    controller.snapshot.subscription == nil
      ? "轻量模式不需要目录权限，只观察 Mihomo 当前暴露的唯一有效配额。"
      : "等待第一条有效配额快照。"
  }

  private var confirmationTitle: String {
    controller.snapshot.subscription == nil ? "启用当前运行订阅追踪？" : "继续轻量追踪？"
  }

  private var confirmationActionTitle: String {
    controller.snapshot.subscription == nil ? "启用轻量追踪" : "确认并继续"
  }

  private var confirmationMessage: String {
    "请确认你通常只使用一个订阅 Profile。轻量模式无法识别 Profile UID，出现零个、多个或来源变化时会自动暂停，不会猜测归属。"
  }
}
