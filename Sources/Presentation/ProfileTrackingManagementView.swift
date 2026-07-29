import SwiftUI

struct ProfileTrackingManagementView: View {
  @ObservedObject var controller: ClashProfileDirectoryController

  @Environment(\.dismiss) private var dismiss

  var body: some View {
    VStack(spacing: 0) {
      header
        .padding(20)

      Divider()

      content

      Divider()

      footer
        .padding(16)
    }
    .frame(width: 640, height: 540)
  }

  private var header: some View {
    HStack(alignment: .top, spacing: 16) {
      VStack(alignment: .leading, spacing: 4) {
        Text("管理追踪 Profile")
          .font(.title2.weight(.semibold))
        Text("只读解析 Clash Verge 的 Profile 身份；不会读取缓存配额或修改配置。")
          .font(.caption)
          .foregroundStyle(.secondary)
        Link("订阅地址与目录选择指引", destination: AppHelpLink.subscriptionConfiguration.destination)
          .font(.caption)
      }

      Spacer()

      Button("完成") {
        dismiss()
      }
      .keyboardShortcut(.defaultAction)
    }
  }

  @ViewBuilder
  private var content: some View {
    switch controller.snapshot.accessStatus {
    case .loading:
      ProgressView("正在恢复 Profile 目录权限…")
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    case .notAuthorized:
      authorizationState(
        title: "尚未授权 Profile 目录",
        message:
          "常见路径：~/Library/Application Support/io.github.clash-verge-rev.clash-verge-rev。"
          + "请选择根部包含 profiles.yaml、且 Profile 名称与当前 Clash Verge 一致的文件夹，不要选择文件本身。",
        actionTitle: "选择 Clash Verge 数据目录"
      )
    case .needsReauthorization:
      authorizationState(
        title: "需要重新授权目录",
        message: "保存的只读权限已失效或目录不可用，请重新选择包含 profiles.yaml 的 Clash Verge 数据目录。",
        actionTitle: "重新授权目录"
      )
    case .available:
      profileList
    case .failed(let message):
      VStack(spacing: 14) {
        Label(message, systemImage: "exclamationmark.triangle.fill")
          .foregroundStyle(MihomoColorToken.statusWarning)
          .fixedSize(horizontal: false, vertical: true)

        HStack {
          Button("重新读取") {
            Task { await controller.reload() }
          }
          Button("重新选择目录") {
            Task { await controller.authorizeDirectory() }
          }
        }
      }
      .padding(28)
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
  }

  private var profileList: some View {
    Group {
      if controller.snapshot.profiles.isEmpty {
        VStack(spacing: 10) {
          Image(systemName: "doc.questionmark")
            .font(.system(size: 28))
            .foregroundStyle(.secondary)
          Text("没有可选择的远程 Profile")
            .font(.headline)
          Text("仅显示带订阅地址的 remote Profile。")
            .font(.caption)
            .foregroundStyle(.secondary)
          Text("如果这里为空，请先在 Clash Verge 中导入远程 HTTPS 订阅；单节点链接和本地配置不会显示。")
            .font(.caption)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: 420)
          Link("查看订阅导入与排查方法", destination: AppHelpLink.subscriptionConfiguration.destination)
            .font(.caption)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
      } else {
        List(controller.snapshot.profiles) { profile in
          ProfileTrackingSelectionRow(controller: controller, profile: profile)
        }
        .listStyle(.inset)
      }
    }
  }

  private var footer: some View {
    HStack(spacing: 12) {
      VStack(alignment: .leading, spacing: 2) {
        Text("已追踪 \(controller.snapshot.trackedProfileCount) 个 Profile")
          .font(.caption.weight(.medium))
        Text("查询间隔由 Mihomo Meter 独立管理，不跟随 Clash Verge 自动刷新。")
          .font(.caption2)
          .foregroundStyle(.secondary)
      }

      Spacer()

      if controller.snapshot.accessStatus == .available {
        Button("更换目录") {
          Task { await controller.authorizeDirectory() }
        }
        Button("取消目录授权", role: .destructive) {
          controller.revokeDirectoryAccess()
        }
      }
    }
  }

  private func authorizationState(
    title: String,
    message: String,
    actionTitle: String
  ) -> some View {
    VStack(spacing: 12) {
      Image(systemName: "folder.badge.plus")
        .font(.system(size: 30))
        .foregroundStyle(.secondary)
      Text(title)
        .font(.headline)
      Text(message)
        .font(.caption)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
        .frame(maxWidth: 420)
      Button(actionTitle) {
        Task { await controller.authorizeDirectory() }
      }
      .buttonStyle(.borderedProminent)
      Link("如何找到并确认数据目录", destination: AppHelpLink.subscriptionConfiguration.destination)
        .font(.caption)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}

private struct ProfileTrackingSelectionRow: View {
  @ObservedObject var controller: ClashProfileDirectoryController
  let profile: ClashProfileSelectionItem

  var body: some View {
    HStack(spacing: 14) {
      Toggle(
        "",
        isOn: Binding(
          get: { profile.isSelected },
          set: { isSelected in
            Task {
              await controller.setTracking(isSelected, profileUID: profile.uid)
            }
          }
        )
      )
      .labelsHidden()
      .disabled(profile.availability == .unsupportedURL && !profile.isSelected)

      VStack(alignment: .leading, spacing: 3) {
        HStack(spacing: 6) {
          Text(profile.name)
            .font(.body.weight(.medium))
          if profile.isCurrent {
            Text("当前")
              .font(.caption2.weight(.semibold))
              .foregroundStyle(MihomoColorToken.brandPrimary)
          }
          availabilityBadge
        }

        Text(profile.subscriptionDomain ?? "原 Profile 已不在授权目录中")
          .font(.caption)
          .foregroundStyle(.secondary)
      }

      Spacer()

      if profile.isSelected, let interval = profile.refreshIntervalMinutes {
        Picker(
          "查询间隔",
          selection: Binding(
            get: { interval },
            set: { value in
              Task {
                await controller.setRefreshInterval(value, profileUID: profile.uid)
              }
            }
          )
        ) {
          ForEach(ClashProfileTrackingService.supportedIntervals, id: \.self) { value in
            Text(intervalTitle(value)).tag(value)
          }
        }
        .pickerStyle(.menu)
        .frame(width: 112)
        .disabled(profile.availability != .available)
      }
    }
    .padding(.vertical, 5)
  }

  @ViewBuilder
  private var availabilityBadge: some View {
    switch profile.availability {
    case .available:
      EmptyView()
    case .unsupportedURL:
      Text("仅支持 HTTPS")
        .font(.caption2)
        .foregroundStyle(MihomoColorToken.statusWarning)
    case .missing:
      Text("已从目录移除")
        .font(.caption2)
        .foregroundStyle(MihomoColorToken.statusWarning)
    }
  }

  private func intervalTitle(_ minutes: Int) -> String {
    "\(minutes / 60) 小时"
  }
}
