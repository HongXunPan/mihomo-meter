import SwiftUI

struct ProfileQuotaAccordionView: View {
  @ObservedObject var controller: ProfileQuotaTrackingController

  @State private var expandedProfileID: UUID?
  @State private var hasInitializedExpansion = false

  var body: some View {
    VStack(spacing: 0) {
      ForEach(controller.snapshot.profiles) { item in
        ProfileQuotaAccordionRow(
          controller: controller,
          item: item,
          isExpanded: Binding(
            get: { expandedProfileID == item.id },
            set: { isExpanded in
              setExpansion(isExpanded, for: item.id)
            }
          )
        )

        if item.id != controller.snapshot.profiles.last?.id {
          Divider()
            .padding(.vertical, 8)
        }
      }
    }
    .onAppear {
      synchronizeExpansion(with: controller.snapshot.profiles)
    }
    .onChange(of: controller.snapshot.profiles) { profiles in
      synchronizeExpansion(with: profiles)
    }
  }

  private func setExpansion(_ isExpanded: Bool, for profileID: UUID) {
    withAnimation(.easeInOut(duration: 0.18)) {
      if isExpanded {
        expandedProfileID = profileID
      } else if expandedProfileID == profileID {
        expandedProfileID = nil
      }
      hasInitializedExpansion = true
    }
  }

  private func synchronizeExpansion(with profiles: [ProfileQuotaTrackingItem]) {
    if let expandedProfileID,
      profiles.contains(where: { $0.id == expandedProfileID })
    {
      return
    }
    guard !hasInitializedExpansion || expandedProfileID != nil else {
      return
    }
    expandedProfileID = profiles.first(where: \.isCurrent)?.id
    hasInitializedExpansion = true
  }
}

private struct ProfileQuotaAccordionRow: View {
  @ObservedObject var controller: ProfileQuotaTrackingController
  let item: ProfileQuotaTrackingItem
  @Binding var isExpanded: Bool

  private var status: ProfileQuotaStatusPresentation {
    ProfileQuotaStatusPresentation(item: item)
  }

  var body: some View {
    DisclosureGroup(isExpanded: $isExpanded) {
      VStack(alignment: .leading, spacing: 0) {
        Label(status.message, systemImage: status.symbolName)
          .font(.caption)
          .foregroundStyle(status.tone.color)
          .fixedSize(horizontal: false, vertical: true)

        if let quota = item.latestQuota {
          SubscriptionQuotaMetricsView(
            quota: quota,
            trend: item.trends.day,
            isCompact: true
          )
          .padding(.top, 10)

          if item.analysis.pendingCycleConfirmation != nil {
            QuotaCycleConfirmationView {
              await controller.confirmCurrentCycle(subscriptionID: item.id)
            }
            .padding(.top, 8)
          }
        } else {
          Text("取得第一条有效快照后显示剩余流量和走势。")
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, minHeight: 54, alignment: .center)
        }

        HStack {
          Text(
            SubscriptionQuotaFormatter.refreshInterval(
              item.subscription.refreshIntervalMinutes
            )
          )
          .font(.caption2)
          .foregroundStyle(.secondary)

          Spacer()

          Button {
            Task {
              await controller.refresh(subscriptionID: item.id)
            }
          } label: {
            Label("立即查询", systemImage: "arrow.clockwise")
          }
          .controlSize(.small)
          .disabled(!item.canRefresh)
          .help(refreshHelp)
        }
        .padding(.top, 8)
      }
      .padding(.top, 10)
      .padding(.leading, 14)
    } label: {
      HStack(spacing: 10) {
        VStack(alignment: .leading, spacing: 3) {
          HStack(spacing: 6) {
            Text(item.subscription.name)
              .font(.subheadline.weight(.semibold))
              .lineLimit(1)
            if item.isCurrent {
              Text("当前")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.blue)
            }
          }

          Text(collapsedSummary)
            .font(.caption2)
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }

        Spacer(minLength: 8)

        Image(systemName: status.symbolName)
          .foregroundStyle(status.tone.color)
      }
    }
    .accessibilityValue(isExpanded ? "已展开" : "已折叠")
    .accessibilityHint("显示这个 Profile 的剩余流量、走势和查询操作")
  }

  private var collapsedSummary: String {
    guard let quota = item.latestQuota else {
      return status.title
    }
    return "剩余 \(SubscriptionQuotaFormatter.bytes(quota.traffic.remainingBytes)) · \(status.title)"
  }

  private var refreshHelp: String {
    if item.canRefresh {
      return "立即通过 Mihomo 本地代理查询这个 Profile"
    }
    if let availableAt = item.manualRefreshAvailableAt {
      return "手动查询可用时间：\(SubscriptionQuotaFormatter.updatedAt(availableAt))"
    }
    return status.message
  }
}
