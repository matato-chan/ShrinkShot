import Foundation

final class FolderWatcher: ObservableObject {
    private var stream: FSEventStreamRef?
    private var currentWatchPath: String = ""
    private let compressor = ImageCompressor()
    private let queue = DispatchQueue(label: "com.shrinkshot.folderwatcher")
    /// 処理済み or 処理中のファイルパス（二度と処理しない）
    private var handledFiles: Set<String> = []

    init() {
        AppSettings.registerDefaults()
        startWatching()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleDefaultsChange),
            name: UserDefaults.didChangeNotification,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        stopWatching()
    }

    @objc private func handleDefaultsChange() {
        let newPath = resolveWatchFolder()
        guard newPath != currentWatchPath else { return }
        stopWatching()
        startWatching()
    }

    private func startWatching() {
        let folderPath = resolveWatchFolder()
        guard FileManager.default.fileExists(atPath: folderPath) else {
            print("Watch folder does not exist: \(folderPath)")
            return
        }

        currentWatchPath = folderPath
        let pathsToWatch = [folderPath] as CFArray

        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )

        guard let stream = FSEventStreamCreate(
            nil,
            fsEventCallback,
            &context,
            pathsToWatch,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            1.0,
            UInt32(kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagUseCFTypes)
        ) else {
            print("Failed to create FSEventStream")
            return
        }

        self.stream = stream
        FSEventStreamScheduleWithRunLoop(stream, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
        FSEventStreamStart(stream)
        print("Started watching: \(folderPath)")
    }

    private func stopWatching() {
        guard let stream = stream else { return }
        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
        self.stream = nil
    }

    private func resolveWatchFolder() -> String {
        return UserDefaults.standard.string(forKey: AppSettings.watchFolderPath)
            ?? AppSettings.defaultWatchFolderPath
    }

    fileprivate func handleFileEvent(path: String, flags: FSEventStreamEventFlags) {
        let isFile = flags & UInt32(kFSEventStreamEventFlagItemIsFile) != 0
        let isRenamed = flags & UInt32(kFSEventStreamEventFlagItemRenamed) != 0
        let isCreated = flags & UInt32(kFSEventStreamEventFlagItemCreated) != 0

        guard isFile, isRenamed || isCreated else { return }

        let filename = (path as NSString).lastPathComponent
        guard !filename.hasPrefix(".") else { return }
        guard path.lowercased().hasSuffix(".png") else { return }
        guard UserDefaults.standard.bool(forKey: AppSettings.isEnabled) else { return }

        queue.async { [weak self] in
            guard let self = self else { return }

            // 既に処理済み or 処理中なら即スキップ
            guard !self.handledFiles.contains(path) else { return }
            self.handledFiles.insert(path)

            // ファイルが安定するまで待つ
            Thread.sleep(forTimeInterval: 1.5)

            guard FileManager.default.fileExists(atPath: path) else {
                self.handledFiles.remove(path)
                return
            }

            self.processFile(at: path)
        }
    }

    private func processFile(at path: String) {
        let url = URL(fileURLWithPath: path)
        let settings = readSettings()
        let originalSize = (try? FileManager.default.attributesOfItem(atPath: path)[.size] as? Int) ?? 0

        let outputPath: String
        if settings.format == "jpeg" {
            outputPath = url.deletingPathExtension().appendingPathExtension("jpg").path
        } else {
            outputPath = path
        }
        // 出力先も処理済みに登録
        handledFiles.insert(outputPath)

        do {
            try compressor.compress(
                fileURL: url,
                scalePercentage: settings.scale,
                outputFormat: settings.format,
                jpegQuality: settings.quality
            )

            let newSize = (try? FileManager.default.attributesOfItem(atPath: outputPath)[.size] as? Int) ?? 0
            let ratio = originalSize > 0 ? Int(Double(newSize) / Double(originalSize) * 100) : 0
            print("Compressed: \(path) (\(originalSize / 1024)KB → \(newSize / 1024)KB, \(ratio)%)")
        } catch {
            print("Compression failed for \(path): \(error)")
        }
    }

    private func readSettings() -> (scale: Int, format: String, quality: Int) {
        let defaults = UserDefaults.standard
        return (
            scale: defaults.integer(forKey: AppSettings.scalePercentage),
            format: defaults.string(forKey: AppSettings.outputFormat) ?? "png",
            quality: defaults.integer(forKey: AppSettings.jpegQuality)
        )
    }
}

// MARK: - FSEvents Callback

private func fsEventCallback(
    streamRef: ConstFSEventStreamRef,
    clientCallBackInfo: UnsafeMutableRawPointer?,
    numEvents: Int,
    eventPaths: UnsafeMutableRawPointer,
    eventFlags: UnsafePointer<FSEventStreamEventFlags>,
    eventIds: UnsafePointer<FSEventStreamEventId>
) {
    guard let info = clientCallBackInfo else { return }
    let watcher = Unmanaged<FolderWatcher>.fromOpaque(info).takeUnretainedValue()

    guard let paths = unsafeBitCast(eventPaths, to: NSArray.self) as? [String] else { return }

    for i in 0..<numEvents {
        watcher.handleFileEvent(path: paths[i], flags: eventFlags[i])
    }
}
