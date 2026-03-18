import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @AppStorage(AppSettings.scalePercentage) private var scalePercentage = AppSettings.defaultScalePercentage
    @AppStorage(AppSettings.outputFormat) private var outputFormat = AppSettings.defaultOutputFormat
    @AppStorage(AppSettings.jpegQuality) private var jpegQuality = AppSettings.defaultJpegQuality
    @AppStorage(AppSettings.watchFolderPath) private var watchFolderPath = AppSettings.defaultWatchFolderPath
    @AppStorage(AppSettings.launchAtLogin) private var launchAtLogin = false

    var body: some View {
        Form {
            // MARK: - Resize
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Slider(value: scaleBinding, in: 10...100, step: 1) {
                            Text(String(localized: "scale"))
                        }
                        Text("\(scalePercentage)%")
                            .monospacedDigit()
                            .frame(width: 44, alignment: .trailing)
                    }
                    Text(String(localized: "scale_description \(scalePercentage)"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } header: {
                Text(String(localized: "resize_section"))
            }

            // MARK: - Output Format
            Section {
                Picker(String(localized: "format"), selection: $outputFormat) {
                    Text(String(localized: "format_png")).tag("png")
                    Text("JPEG").tag("jpeg")
                }
                .pickerStyle(.menu)

                if outputFormat == "jpeg" {
                    HStack {
                        Slider(value: qualityBinding, in: 10...100, step: 1) {
                            Text(String(localized: "quality"))
                        }
                        Text("\(jpegQuality)%")
                            .monospacedDigit()
                            .frame(width: 44, alignment: .trailing)
                    }
                }
            } header: {
                Text(String(localized: "output_section"))
            }

            // MARK: - Watch Folder
            Section {
                HStack {
                    Text(displayPath)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer()
                    Button(String(localized: "change_folder")) {
                        selectFolder()
                    }
                }
            } header: {
                Text(String(localized: "watch_folder_section"))
            }

            // MARK: - Shortcut
            Section {
                KeyRecorderView()
            } header: {
                Text(String(localized: "shortcut_section"))
            }

            // MARK: - General
            Section {
                Toggle(String(localized: "launch_at_login"), isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { newValue in
                        setLaunchAtLogin(newValue)
                    }
            } header: {
                Text(String(localized: "general_section"))
            }
        }
        .formStyle(.grouped)
        .frame(width: 420, height: 440)
    }

    private var displayPath: String {
        (watchFolderPath as NSString).abbreviatingWithTildeInPath
    }

    private var scaleBinding: Binding<Double> {
        Binding(
            get: { Double(scalePercentage) },
            set: { scalePercentage = Int($0) }
        )
    }

    private var qualityBinding: Binding<Double> {
        Binding(
            get: { Double(jpegQuality) },
            set: { jpegQuality = Int($0) }
        )
    }

    private func selectFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = String(localized: "select_folder_message")

        if panel.runModal() == .OK, let url = panel.url {
            watchFolderPath = url.path
        }
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            print("Failed to \(enabled ? "register" : "unregister") launch at login: \(error)")
        }
    }
}
