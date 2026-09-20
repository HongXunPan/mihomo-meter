import SwiftUI

struct StatusMenuQuotaTrendView: View {
  @ObservedObject var controller: RuntimeQuotaTrackingController
  @ObservedObject var profileQuotaController: ProfileQuotaTrackingController
  @ObservedObject var state: StatusMenuQuotaTrendState

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      StatusMenuQuotaTrendHeaderView(
        target: target,
        targets: targets,
        controller: profileQuotaController,
        state: state
      )

      Divider()

      if let target {
        if let quota = target.quota {
          StatusMenuQuotaMetricsView(
            quota: quota,
            target: target,
            state: state,
            status: profileStatus
          ) { cycleID in
            await confirmCurrentCycle(cycleID, for: target)
          }
        } else {
          if target.pendingCycleConfirmation != nil {
            StatusMenuQuotaStatusView(
              target: target,
              status: profileStatus,
              referenceDate: state.referenceDate
            ) { cycleID in
              await confirmCurrentCycle(cycleID, for: target)
            }
          }

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

  private var targets: [StatusMenuQuotaTrendTarget] {
    StatusMenuQuotaTrendTarget.available(
      controller: controller,
      profileQuotaController: profileQuotaController
    )
  }

  private var target: StatusMenuQuotaTrendTarget? {
    targets.first(where: { $0.id == state.selectedTargetID })
      ?? targets.first(where: \.isCurrent)
      ?? targets.first
  }

  private var profileStatus: ProfileQuotaStatusPresentation? {
    guard let target,
      let item = profileQuotaController.snapshot.profiles.first(where: { $0.id == target.id })
    else {
      return nil
    }
    return ProfileQuotaStatusPresentation(item: item, relativeTo: state.referenceDate)
  }

  private func confirmCurrentCycle(
    _ cycleID: UUID,
    for target: StatusMenuQuotaTrendTarget
  ) async -> String? {
    if profileQuotaController.snapshot.profiles.contains(where: { $0.id == target.id }) {
      return await profileQuotaController.confirmCurrentCycle(
        subscriptionID: target.id,
        cycleID: cycleID
      )
    }
    return await controller.confirmCurrentCycle(cycleID: cycleID)
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
