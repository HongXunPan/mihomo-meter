import SwiftUI

struct StatusMenuQuotaTrendHeaderView: View {
  let target: StatusMenuQuotaTrendTarget?
  let targets: [StatusMenuQuotaTrendTarget]
  @ObservedObject var controller: ProfileQuotaTrackingController
  @ObservedObject var state: StatusMenuQuotaTrendState

  var body: some View {
    TimelineView(.periodic(from: state.referenceDate, by: 1)) { context in
      VStack(alignment: .leading, spacing: 6) {
        HStack(spacing: 8) {
          HStack(spacing: 6) {
            Text(target?.title ?? "订阅走势")
              .font(.subheadline.weight(.semibold))
              .lineLimit(1)
              .truncationMode(.middle)
              .help(target?.title ?? "订阅走势")

            if target?.isCurrent == true {
              Text("当前")
                .font(.caption2.weight(.medium))
                .foregroundStyle(MihomoColorToken.brandPrimary)
                .fixedSize()
            }
          }
          .frame(maxWidth: .infinity, alignment: .leading)

          profilePager

          if let profileItem {
            refreshButton(profileItem, relativeTo: context.date)
              .fixedSize()
          }
        }

        HStack(spacing: 8) {
          timingSummary(relativeTo: context.date)
            .font(.caption2)
            .lineLimit(1)
            .truncationMode(.middle)
            .frame(maxWidth: .infinity, alignment: .leading)

          if controller.snapshot.profiles.count > 1 {
            refreshAllButton(relativeTo: context.date)
              .fixedSize()
          }
        }
      }
    }
    .frame(height: 44, alignment: .topLeading)
  }

  @ViewBuilder
  private func timingSummary(relativeTo date: Date) -> some View {
    if let profileItem {
      let status = ProfileQuotaStatusPresentation(item: profileItem, relativeTo: date)
      Label(status.compactSummary, systemImage: status.symbolName)
        .foregroundStyle(status.tone.color)
        .help(status.message)
    } else if let quota = target?.quota {
      Text(
        "\(SubscriptionQuotaFormatter.updatedAt(quota.effectiveAt, relativeTo: date))更新"
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
          state.selectPrevious(targetIDs: targets.map(\.id))
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
          state.selectNext(targetIDs: targets.map(\.id))
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

  private var profileItem: ProfileQuotaTrackingItem? {
    guard let target else {
      return nil
    }
    return controller.snapshot.profiles.first { $0.id == target.id }
  }

  private var targetIndexSummary: String {
    guard let target, let index = targets.firstIndex(where: { $0.id == target.id }) else {
      return "—"
    }
    return "\(index + 1)/\(targets.count)"
  }

  private var targetIndexAccessibilitySummary: String {
    guard let target, let index = targets.firstIndex(where: { $0.id == target.id }) else {
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
        await controller.refresh(subscriptionID: item.id)
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
      !controller.snapshot.isRefreshingAll
      && controller.snapshot.profiles.contains { $0.canRefresh(at: date) }
    return Button {
      Task {
        await controller.refreshAll()
      }
    } label: {
      Label("查询全部", systemImage: "arrow.triangle.2.circlepath")
        .font(.caption2)
    }
    .buttonStyle(.borderless)
    .controlSize(.small)
    .disabled(!canRefresh)
    .help(canRefresh ? "立即查询所有当前可刷新的 Profile" : "当前没有可立即查询的 Profile")
  }
}
