import SwiftUI

struct MenuBarView: View {
    @AppStorage(AppSettings.isEnabled) private var isEnabled = true
    @AppStorage(AppSettings.scalePercentage) private var scalePercentage = AppSettings.defaultScalePercentage
    @AppStorage(AppSettings.outputFormat) private var outputFormat = AppSettings.defaultOutputFormat
    @AppStorage(AppSettings.jpegQuality) private var jpegQuality = AppSettings.defaultJpegQuality
    @ObservedObject var folderWatcher: FolderWatcher

    var body: some View {
        Button {
            isEnabled.toggle()
        } label: {
            Text(isEnabled
                 ? String(localized: "auto_compress_on")
                 : String(localized: "auto_compress_off"))
        }

        Divider()

        Text(settingsSummary)
            .foregroundColor(.secondary)

        Divider()

        SettingsLink {
            Text(String(localized: "settings"))
        }
        .keyboardShortcut(",", modifiers: .command)

        Divider()

        Button(String(localized: "about")) {
            NSApplication.shared.orderFrontStandardAboutPanel()
            NSApplication.shared.activate(ignoringOtherApps: true)
        }

        Button(String(localized: "quit")) {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q", modifiers: .command)
    }

    private var settingsSummary: String {
        let scale = "\(scalePercentage)%"
        let format: String
        if outputFormat == "jpeg" {
            format = "JPEG \(jpegQuality)%"
        } else {
            format = "PNG"
        }
        return "\(scale) · \(format)"
    }
}
