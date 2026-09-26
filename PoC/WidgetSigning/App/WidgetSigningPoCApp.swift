import SwiftUI
import WidgetKit

@main
struct WidgetSigningPoCApp: App {
  @State private var status = "等待写入文件快照"

  var body: some Scene {
    WindowGroup {
      VStack(alignment: .leading, spacing: 16) {
        Text("WidgetKit 文件权限验证")
          .font(.headline)
        Text(status)
          .textSelection(.enabled)
        Button("重新写入假快照") {
          writeSnapshot()
        }
      }
      .padding(24)
      .frame(minWidth: 360)
      .onAppear(perform: writeSnapshot)
    }
  }

  @MainActor
  private func writeSnapshot() {
    do {
      let value = try WidgetSigningPoCSnapshotStore.writeFakeSnapshot()
      status = "写入完成：\(value)\n\(WidgetSigningPoCDiagnostics.inspect())"
      WidgetCenter.shared.reloadTimelines(ofKind: WidgetSigningPoCConstants.widgetKind)
    } catch {
      status =
        "写入失败：\(WidgetSigningPoCDiagnostics.errorCode(error))\n"
        + WidgetSigningPoCDiagnostics.inspect()
    }
  }
}
