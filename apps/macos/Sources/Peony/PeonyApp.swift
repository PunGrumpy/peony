import AppKit
import PeonyUI
import SwiftUI

@main
struct PeonyApp: App {
  @NSApplicationDelegateAdaptor private var delegate: AppDelegate

  init() {
    // Peony's accent, for sidebars, switches and default buttons. An asset catalog's AccentColor
    // would do this, but compiling one needs Xcode. Registered, not set, so an accent the user
    // picked in System Settings still wins. 6 is the system's pink, the nearest to Peony's rose.
    UserDefaults.standard.register(defaults: ["AppleAccentColor": 6, ControlServer.enabledKey: true])
  }

  var body: some Scene {
    MenuBarExtra {
      Panel(model: delegate.model)
    } label: {
      let menuBar = delegate.model.menuBar
      MenuBarLabel(filledPetals: menuBar.petals, title: menuBar.title)
    }
    .menuBarExtraStyle(.window)

    Window("Peony Settings", id: "settings") {
      SettingsView(model: delegate.model)
    }
    .windowToolbarStyle(.unified)
    .windowResizability(.contentMinSize)
    .defaultSize(width: 760, height: 540)

    Window("Peony Log", id: LogView.windowID) {
      LogView(lines: delegate.model.connection.log)
    }
    .windowResizability(.contentMinSize)
    .defaultSize(width: 640, height: 420)
  }
}

/// Binds the panel to live state and gives its actions a way to open windows.
private struct Panel: View {
  let model: AppModel
  @Environment(\.openWindow) private var openWindow

  var body: some View {
    PanelView(state: model.panelState, actions: model.actions(
      openSettings: { show("settings") },
      openLog: { show(LogView.windowID) }))
      .background(PanelAnchor())
  }

  private func show(_ id: String) {
    openWindow(id: id)
    NSApp.activate()
  }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
  let model = AppModel()

  func applicationWillTerminate(_ notification: Notification) {
    model.quit()
  }
}
