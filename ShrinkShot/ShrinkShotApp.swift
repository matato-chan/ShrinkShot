import SwiftUI

@main
struct ShrinkShotApp: App {
    @AppStorage(AppSettings.isEnabled) private var isEnabled = true
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var folderWatcher = FolderWatcher()

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(folderWatcher: folderWatcher)
        } label: {
            Image(systemName: isEnabled
                  ? "arrow.down.right.and.arrow.up.left"
                  : "arrow.up.left.and.arrow.down.right")
        }
        .menuBarExtraStyle(.menu)

        Settings {
            SettingsView()
        }
    }
}
