import Foundation

public final class ScanCancellationToken: @unchecked Sendable {
    private let lock = NSLock()
    private var cancelled = false

    public init() {}

    public func cancel() {
        lock.withLock {
            cancelled = true
        }
    }

    public var isCancelled: Bool {
        lock.withLock {
            cancelled
        }
    }
}
