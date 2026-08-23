import SwiftUI

@main
struct MihomoMeterApp: App {
  @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

  var body: some Scene {
    Settings {
      EmptyView()
    }
    .commands {
      CommandGroup(replacing: .appSettings) {
        Button("设置…") {
          appDelegate.showControllerSettings()
        }
        .keyboardShortcut(",", modifiers: .command)
      }

      AppHelpCommands()
    }
  }
}
