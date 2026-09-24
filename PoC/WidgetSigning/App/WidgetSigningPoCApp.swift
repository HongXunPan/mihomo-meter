import SwiftUI
import WidgetKit

@main
struct WidgetSigningPoCApp: App {
  @State private var status = "等待写入共享快照"

  var body: some Scene {
    WindowGroup {
      VStack(alignment: .leading, spacing: 16) {
        Text("WidgetKit 自签名验证")
          .font(.headline)
        Text(status)
          .textSelection(.enabled)
        Button("重新写入测试快照") {
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
    guard
      let container = FileManager.default.containerURL(
        forSecurityApplicationGroupIdentifier: WidgetSigningPoCConstants.groupIdentifier
      )
    else {
      status = "共享容器不可用"
      return
    }

    do {
      let value = "主应用写入：\(Date().formatted(date: .numeric, time: .standard))"
      try value.write(
        to: container.appendingPathComponent(WidgetSigningPoCConstants.snapshotFilename),
        atomically: true,
        encoding: .utf8
      )
      status = "写入完成\n\(WidgetSigningPoCDiagnostics.inspect())"
      WidgetCenter.shared.reloadTimelines(ofKind: WidgetSigningPoCConstants.widgetKind)
    } catch {
      status =
        "写入失败：\(WidgetSigningPoCDiagnostics.errorCode(error))\n"
        + WidgetSigningPoCDiagnostics.inspect()
    }
  }
}
