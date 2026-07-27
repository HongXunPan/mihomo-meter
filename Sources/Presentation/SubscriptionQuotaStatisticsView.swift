import AppKit
import SwiftUI

struct SubscriptionQuotaStatisticsView: View {
  @ObservedObject var controller: RuntimeQuotaTrackingController
  @ObservedObject var profileQuotaController: ProfileQuotaTrackingController
  @ObservedObject var profileController: ClashProfileDirectoryController
  @ObservedObject var dataController: SubscriptionQuotaDataController

  @State private var window = QuotaTrendWindow.week
  @State private var showsProfileManager = false
  @State private var showsClearConfirmation = false

  var body: some View {
    VStack(spacing: 0) {
      header
        .padding(.horizontal, 20)
        .padding(.vertical, 16)

      Divider()

      ScrollView {
        VStack(alignment: .leading, spacing: 16) {
          if profileQuotaController.snapshot.profiles.isEmpty {
            SubscriptionQuotaObservationNoticeView(controller: controller)
          }
          content
        }
        .padding(20)
      }
    }
    .frame(minWidth: 680, minHeight: 520)
    .sheet(isPresented: $showsProfileManager) {
      ProfileTrackingManagementView(controller: profileController)
    }
    .confirmationDialog(
      "清空全部订阅余额数据？",
      isPresented: $showsClearConfirmation
    ) {
      Button("清空", role: .destructive) {
        Task {
          await dataController.clear()
        }
      }
      Button("取消", role: .cancel) {}
    } message: {
      Text("订阅身份、Profile 选择、快照、周期、变化事件和查询状态都会删除；Controller 配置与 Profile 目录授权会保留。")
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

      if !profileQuotaController.snapshot.profiles.isEmpty {
        Button {
          Task {
            await profileQuotaController.refreshAll()
          }
        } label: {
          Label(
            profileQuotaController.snapshot.isRefreshingAll ? "正在查询" : "全部查询",
            systemImage: "arrow.clockwise"
          )
        }
        .disabled(!canRefreshAnyProfile)
      }

      Button("管理 Profile") {
        showsProfileManager = true
      }

      Menu {
        Button("清空订阅余额数据", role: .destructive) {
          showsClearConfirmation = true
        }
        .disabled(dataController.isClearing || !hasContent)
      } label: {
        Image(systemName: "ellipsis.circle")
      }
      .menuStyle(.borderlessButton)
      .menuIndicator(.hidden)
      .accessibilityLabel("更多订阅余额操作")
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
        if profileQuotaController.snapshot.profiles.isEmpty,
          let subscription = controller.snapshot.subscription,
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

            QuotaEventSummaryView(analysis: controller.snapshot.analysis) {
              await controller.confirmCurrentCycle()
            }
          }
          .padding(16)
          .background(
            Color(nsColor: .controlBackgroundColor),
            in: RoundedRectangle(cornerRadius: 12)
          )
        }

        ForEach(profileQuotaController.snapshot.profiles) { item in
          ProfileQuotaCardView(
            controller: profileQuotaController,
            item: item,
            window: window
          )
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

    if let operationMessage = dataController.operationMessage {
      Label(operationMessage, systemImage: "exclamationmark.triangle.fill")
        .font(.caption)
        .foregroundStyle(.red)
    }
  }

  private var hasContent: Bool {
    controller.snapshot.latestQuota != nil
      || !profileQuotaController.snapshot.profiles.isEmpty
  }

  private var canRefreshAnyProfile: Bool {
    !profileQuotaController.snapshot.isRefreshingAll
      && profileQuotaController.snapshot.profiles.contains(where: \.canRefresh)
  }
}
