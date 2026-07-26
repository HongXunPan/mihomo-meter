import AppKit
import SwiftUI

struct SubscriptionQuotaStatisticsView: View {
  @ObservedObject var controller: RuntimeQuotaTrackingController
  @ObservedObject var profileController: ClashProfileDirectoryController

  @State private var window = QuotaTrendWindow.week
  @State private var showsProfileManager = false

  var body: some View {
    VStack(spacing: 0) {
      header
        .padding(.horizontal, 20)
        .padding(.vertical, 16)

      Divider()

      ScrollView {
        VStack(alignment: .leading, spacing: 16) {
          SubscriptionQuotaObservationNoticeView(controller: controller)
          content
        }
        .padding(20)
      }
    }
    .frame(minWidth: 680, minHeight: 520)
    .sheet(isPresented: $showsProfileManager) {
      ProfileTrackingManagementView(controller: profileController)
    }
  }

  private var header: some View {
    HStack(alignment: .center, spacing: 16) {
      VStack(alignment: .leading, spacing: 3) {
        Text("订阅余额")
          .font(.title2.weight(.semibold))
        Text("按订阅 Profile 观察机场剩余流量；不与本机 Proxy 流量对账。")
          .font(.caption)
          .foregroundStyle(.secondary)
      }

      Spacer()

      Picker("趋势窗口", selection: $window) {
        Text("24 小时").tag(QuotaTrendWindow.day)
        Text("7 天").tag(QuotaTrendWindow.week)
        Text("30 天").tag(QuotaTrendWindow.month)
      }
      .pickerStyle(.segmented)
      .labelsHidden()
      .frame(width: 260)

      Button("管理 Profile") {
        showsProfileManager = true
      }
    }
  }

  @ViewBuilder
  private var content: some View {
    if hasContent {
      LazyVGrid(
        columns: [GridItem(.adaptive(minimum: 300, maximum: 420), spacing: 16)],
        alignment: .leading,
        spacing: 16
      ) {
        if let subscription = controller.snapshot.subscription,
          let quota = controller.snapshot.latestQuota
        {
          VStack(alignment: .leading, spacing: 14) {
            HStack {
              VStack(alignment: .leading, spacing: 2) {
                Text(subscription.name)
                  .font(.headline)
                Text("当前运行订阅 · 未绑定 Profile UID")
                  .font(.caption2)
                  .foregroundStyle(.secondary)
              }
              Spacer()
              Image(systemName: "dot.radiowaves.left.and.right")
                .foregroundStyle(.cyan)
            }

            Divider()

            SubscriptionQuotaMetricsView(
              quota: quota,
              trend: controller.snapshot.trends.trend(for: window)
            )
          }
          .padding(16)
          .background(
            Color(nsColor: .controlBackgroundColor),
            in: RoundedRectangle(cornerRadius: 12)
          )
        }

        ForEach(profileController.snapshot.selectedProfiles) { profile in
          ClashProfileIdentityCard(profile: profile)
        }
      }
    } else {
      VStack(spacing: 10) {
        Image(systemName: "chart.line.downtrend.xyaxis")
          .font(.system(size: 30))
          .foregroundStyle(.secondary)
        Text("尚无订阅余额记录")
          .font(.headline)
        Text("可在状态栏弹窗启用轻量追踪，或管理需要精确识别的 Profile。")
          .font(.caption)
          .foregroundStyle(.secondary)

        Button("管理 Profile") {
          showsProfileManager = true
        }
      }
      .frame(maxWidth: .infinity, minHeight: 260, alignment: .center)
    }
  }

  private var hasContent: Bool {
    controller.snapshot.latestQuota != nil
      || !profileController.snapshot.selectedProfiles.isEmpty
  }
}
