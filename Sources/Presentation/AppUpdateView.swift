import SwiftUI

struct AppUpdateView: View {
  @ObservedObject var model: AppUpdateModel

  var body: some View {
    HStack(spacing: 5) {
      Text("版本 \(model.currentVersionText)")

      Text("·")
        .foregroundStyle(.tertiary)

      updateContent
    }
    .font(.caption2)
    .foregroundStyle(.secondary)
  }

  @ViewBuilder
  private var updateContent: some View {
    switch model.state {
    case .idle:
      checkButton(title: "检查更新")
    case .checking:
      HStack(spacing: 4) {
        ProgressView()
          .controlSize(.mini)
        Text("正在检查")
      }
    case .upToDate:
      checkButton(title: "已是最新版本")
        .help("再次检查更新")
    case .noRelease:
      checkButton(title: "暂无正式版本")
        .help("再次检查更新")
    case .updateAvailable(let release):
      Link(destination: release.pageURL) {
        Text(verbatim: "下载 v\(release.version)")
      }
    case .failed:
      checkButton(title: "重试检查")
    }
  }

  private func checkButton(title: String) -> some View {
    Button(title) {
      model.checkForUpdates()
    }
    .buttonStyle(.link)
    .controlSize(.mini)
  }
}
