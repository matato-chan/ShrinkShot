import Foundation

enum AppSettings {
    static let isEnabled = "isEnabled"
    static let scalePercentage = "scalePercentage"
    static let outputFormat = "outputFormat"
    static let jpegQuality = "jpegQuality"
    static let watchFolderPath = "watchFolderPath"
    static let launchAtLogin = "launchAtLogin"
    static let hotkeyKeyCode = "hotkeyKeyCode"
    static let hotkeyModifiers = "hotkeyModifiers"
    static let defaultScalePercentage = 50
    static let defaultOutputFormat = "png"
    static let defaultJpegQuality = 75
    static let defaultWatchFolderPath = NSHomeDirectory() + "/Desktop"

    static func registerDefaults() {
        UserDefaults.standard.register(defaults: [
            isEnabled: true,
            scalePercentage: defaultScalePercentage,
            outputFormat: defaultOutputFormat,
            jpegQuality: defaultJpegQuality,
            watchFolderPath: defaultWatchFolderPath,
            launchAtLogin: false
        ])
    }
}
