import AgentObservatoryCore
import CoreServices
import Foundation

final class SourceFileWatcher {
    private var stream: FSEventStreamRef?
    private var eventHandler: (([String]) -> Void)?

    deinit {
        stop()
    }

    func start(sources: [ScanSource], eventHandler: @escaping ([String]) -> Void) {
        stop()

        let watchPaths = Array(Set(sources.compactMap(watchPath(for:)))).sorted()
        guard !watchPaths.isEmpty else { return }

        self.eventHandler = eventHandler

        var context = FSEventStreamContext(
            version: 0,
            info: UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()),
            retain: nil,
            release: nil,
            copyDescription: nil
        )

        let callback: FSEventStreamCallback = { _, info, eventCount, eventPaths, _, _ in
            guard let info else { return }
            let watcher = Unmanaged<SourceFileWatcher>.fromOpaque(info).takeUnretainedValue()
            let paths: [String]
            if let pathArray = unsafeBitCast(eventPaths, to: NSArray.self) as? [String] {
                paths = pathArray
            } else {
                paths = []
            }

            let limitedPaths = Array(paths.prefix(Int(eventCount)).prefix(24))
            DispatchQueue.main.async {
                watcher.eventHandler?(limitedPaths)
            }
        }

        stream = FSEventStreamCreate(
            nil,
            callback,
            &context,
            watchPaths as CFArray,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            0.8,
            UInt32(kFSEventStreamCreateFlagUseCFTypes | kFSEventStreamCreateFlagFileEvents)
        )

        guard let stream else { return }
        FSEventStreamSetDispatchQueue(stream, DispatchQueue.main)
        FSEventStreamStart(stream)
    }

    func stop() {
        guard let stream else { return }
        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
        self.stream = nil
        eventHandler = nil
    }

    private func watchPath(for source: ScanSource) -> String? {
        let path = source.url.standardizedFileURL.path
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory) else {
            return nil
        }
        if isDirectory.boolValue {
            return path
        }
        return URL(fileURLWithPath: path).deletingLastPathComponent().standardizedFileURL.path
    }
}
