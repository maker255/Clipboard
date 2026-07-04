import Foundation

public final class Debouncer {
    private let delay: TimeInterval
    private let queue: DispatchQueue
    private var workItem: DispatchWorkItem?

    public init(delay: TimeInterval, queue: DispatchQueue = .main) {
        self.delay = delay
        self.queue = queue
    }

    public func call(_ block: @escaping () -> Void) {
        workItem?.cancel()
        let item = DispatchWorkItem(block: block)
        workItem = item
        queue.asyncAfter(deadline: .now() + delay, execute: item)
    }

    public func cancel() {
        workItem?.cancel()
        workItem = nil
    }
}
