import SwiftUI

struct AppUpdateView: View {
  @ObservedObject var model: AppUpdateModel

  var body: some View {
    HStack(spacing: 5) {
      Text("版本 \(model.currentVersionText)")

      Text("·")
        .foregroundStyle(.tertiary)

      Button("检查更新") {
        model.checkForUpdates()
      }
      .buttonStyle(.link)
      .controlSize(.mini)
      .disabled(!model.canCheckForUpdates)
      .help(
        model.canCheckForUpdates
          ? "检查、下载并安装可用更新"
          : "更新服务正在准备"
      )
    }
    .font(.caption2)
    .foregroundStyle(.secondary)
  }
}
