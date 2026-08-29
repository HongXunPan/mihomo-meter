import SwiftUI

struct StatusMenuQuotaTrendView: View {
  @ObservedObject var controller: RuntimeQuotaTrackingController
  @ObservedObject var profileQuotaController: ProfileQuotaTrackingController
  @ObservedObject var state: StatusMenuQuotaTrendState

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      targetHeader

      if profileQuotaController.snapshot.profiles.count > 1 {
        TimelineView(.periodic(from: state.referenceDate, by: 1)) { context in
          refreshAllButton(relativeTo: context.date)
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
      }

      Divider()

      if let target {
        if let quota = target.quota {
          StatusMenuQuotaMetricsView(
            quota: quota,
            trends: target.trends,
            window: state.window,
            hoverState: state.hoverState,
            hoverContext: state.hoverContext,
            onSelectWindow: state.selectWindow
          )
        } else {
          emptyState(
            title: "等待有效配额",
            message: "查询成功并积累快照后显示累计用量走势。"
          )
        }
      } else {
        emptyState(
          title: "尚无可展示订阅",
          message: "请先启用轻量追踪或在统计窗口管理 Profile。"
        )
      }
    }
    .padding(14)
    .frame(
      width: StatusMenuLayout.quotaTrendSubmenuSize.width,
      height: StatusMenuLayout.quotaTrendSubmenuSize.height,
      alignment: .topLeading
    )
  }

  private var targetHeader: some View {
    HStack(spacing: 10) {
      VStack(alignment: .leading, spacing: 2) {
        HStack(spacing: 6) {
          Text(target?.title ?? "订阅走势")
            .font(.subheadline.weight(.semibold))
            .lineLimit(1)
            .truncationMode(.middle)
            .help(target?.title ?? "订阅走势")

          if target?.isCurrent == true {
            Text("当前")
              .font(.caption2.weight(.semibold))
              .foregroundStyle(MihomoColorToken.brandPrimary)
          }
        }

        targetTimingSummary
          .font(.caption2)
          .lineLimit(1)
          .truncationMode(.middle)
      }
      .frame(maxWidth: .infinity, alignment: .leading)

      profilePager

      if let profileItem {
        TimelineView(.periodic(from: state.referenceDate, by: 1)) { context in
          refreshButton(profileItem, relativeTo: context.date)
        }
      }
    }
    .frame(maxWidth: .infinity, minHeight: 36, alignment: .leading)
  }

  @ViewBuilder
  private var targetTimingSummary: some View {
    if let profileItem {
      let status = ProfileQuotaStatusPresentation(
        item: profileItem,
        relativeTo: state.referenceDate
      )
      Label(status.compactSummary, systemImage: status.symbolName)
        .foregroundStyle(status.tone.color)
        .help(status.message)
    } else if let quota = target?.quota {
      Text(
        "\(SubscriptionQuotaFormatter.updatedAt(quota.effectiveAt, relativeTo: state.referenceDate))更新"
          + " · 无独立查询计划"
      )
      .foregroundStyle(.secondary)
      .help("轻量追踪由 Mihomo 运行态观测驱动，不设置独立查询时间。")
    } else {
      Text("轻量追踪 · 等待有效配额")
        .foregroundStyle(.secondary)
    }
  }

  @ViewBuilder
  private var profilePager: some View {
    if targets.count > 1 {
      HStack(spacing: 2) {
        Button {
          state.selectPrevious(targetIDs: targetIDs)
        } label: {
          Image(systemName: "chevron.left")
        }
        .accessibilityLabel("上一个 Profile")
        .help("查看上一个 Profile")

        Text(targetIndexSummary)
          .font(.caption.monospacedDigit())
          .foregroundStyle(.secondary)
          .frame(minWidth: 28)
          .accessibilityLabel(targetIndexAccessibilitySummary)

        Button {
          state.selectNext(targetIDs: targetIDs)
        } label: {
          Image(systemName: "chevron.right")
        }
        .accessibilityLabel("下一个 Profile")
        .help("查看下一个 Profile")
      }
      .buttonStyle(.borderless)
      .controlSize(.small)
      .fixedSize()
    }
  }

  private var targets: [StatusMenuQuotaTrendTarget] {
    StatusMenuQuotaTrendTarget.available(
      controller: controller,
      profileQuotaController: profileQuotaController
    )
  }

  private var targetIDs: [UUID] {
    targets.map(\.id)
  }

  private var target: StatusMenuQuotaTrendTarget? {
    targets.first(where: { $0.id == state.selectedTargetID })
      ?? targets.first(where: \.isCurrent)
      ?? targets.first
  }

  private var profileItem: ProfileQuotaTrackingItem? {
    guard let target else {
      return nil
    }
    return profileQuotaController.snapshot.profiles.first { $0.id == target.id }
  }

  private var targetIndexSummary: String {
    guard targets.count > 1,
      let target,
      let index = targets.firstIndex(where: { $0.id == target.id })
    else {
      return "—"
    }
    return "\(index + 1)/\(targets.count)"
  }

  private var targetIndexAccessibilitySummary: String {
    guard let target,
      let index = targets.firstIndex(where: { $0.id == target.id })
    else {
      return "未选择 Profile"
    }
    return "当前第 \(index + 1) 个，共 \(targets.count) 个 Profile"
  }

  private func refreshButton(
    _ item: ProfileQuotaTrackingItem,
    relativeTo date: Date
  ) -> some View {
    let canRefresh = item.canRefresh(at: date)
    let status = ProfileQuotaStatusPresentation(item: item, relativeTo: date)
    return Button {
      Task {
        await profileQuotaController.refresh(subscriptionID: item.id)
      }
    } label: {
      Label("立即查询", systemImage: "arrow.clockwise")
    }
    .buttonStyle(.bordered)
    .controlSize(.small)
    .disabled(!canRefresh)
    .help(canRefresh ? "立即通过 Mihomo 本地代理查询这个 Profile" : status.message)
  }

  private func refreshAllButton(relativeTo date: Date) -> some View {
    let canRefresh =
      !profileQuotaController.snapshot.isRefreshingAll
      && profileQuotaController.snapshot.profiles.contains { $0.canRefresh(at: date) }
    return Button {
      Task {
        await profileQuotaController.refreshAll()
      }
    } label: {
      Label("立即查询全部", systemImage: "arrow.triangle.2.circlepath")
    }
    .buttonStyle(.bordered)
    .controlSize(.small)
    .disabled(!canRefresh)
    .help(canRefresh ? "立即查询所有当前可刷新的 Profile" : "当前没有可立即查询的 Profile")
  }

  private func emptyState(title: String, message: String) -> some View {
    VStack(spacing: 8) {
      Image(systemName: "chart.line.downtrend.xyaxis")
        .font(.system(size: 26))
        .foregroundStyle(.secondary)
      Text(title)
        .font(.subheadline.weight(.medium))
      Text(message)
        .font(.caption)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
  }
}

struct StatusMenuQuotaTrendTarget: Identifiable {
  let id: UUID
  let title: String
  let isCurrent: Bool
  let quota: SubscriptionQuotaSnapshot?
  let trends: RuntimeQuotaTrends

  @MainActor
  static func available(
    controller: RuntimeQuotaTrackingController,
    profileQuotaController: ProfileQuotaTrackingController
  ) -> [StatusMenuQuotaTrendTarget] {
    if !profileQuotaController.snapshot.profiles.isEmpty {
      return profileQuotaController.snapshot.profiles.map {
        StatusMenuQuotaTrendTarget(
          id: $0.id,
          title: $0.subscription.name,
          isCurrent: $0.isCurrent,
          quota: $0.latestQuota,
          trends: $0.trends
        )
      }
    }

    guard let subscription = controller.snapshot.subscription else {
      return []
    }
    return [
      StatusMenuQuotaTrendTarget(
        id: subscription.id,
        title: subscription.name,
        isCurrent: true,
        quota: controller.snapshot.latestQuota,
        trends: controller.snapshot.trends
      )
    ]
  }
}
