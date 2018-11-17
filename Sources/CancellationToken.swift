// The MIT License (MIT)
//
// Copyright (c) 2016-2018 Alexander Grebenyuk (github.com/kean).

import Foundation

// MARK: - CancellationTokenSource

/// Manages cancellation tokens and signals them when cancellation is requested.
///
/// All `CancellationTokenSource` methods are thread safe.
public final class CancellationTokenSource {
    /// Returns `true` if cancellation has been requested.
    public var isCancelling: Bool {
        lock.lock(); defer { lock.unlock() }
        return observers == nil
    }

    /// Creates a new token associated with the source.
    public var token: CancellationToken {
        return CancellationToken(source: self)
    }

    private var observers: ContiguousArray<() -> Void>? = []

    /// Initializes the `CancellationTokenSource` instance.
    init() {}

    fileprivate func register(_ closure: @escaping () -> Void) {
        if !tryRegister(closure) {
            closure()
        }
    }

    private func tryRegister(_ closure: @escaping () -> Void) -> Bool {
        lock.lock(); defer { lock.unlock() }
        observers?.append(closure)
        return observers != nil
    }

    /// Communicates a request for cancellation to the managed tokens.
    public func cancel() {
        if let observers = tryCancel() {
            observers.forEach { $0() }
        }
    }

    private func tryCancel() -> ContiguousArray<() -> Void>? {
        lock.lock(); defer { lock.unlock() }
        let observers = self.observers
        self.observers = nil // transition to `isCancelling` state
        return observers
    }
}

// We use the same lock across different tokens because the design of CTS
// prevents potential issues. For example, closures registered with a token
// are never executed inside a lock.
private let lock = NSLock()

/// Enables cooperative cancellation of operations.
///
/// You create a cancellation token by instantiating a `CancellationTokenSource`
/// object and calling its `token` property. You then pass the token to any
/// number of threads, tasks, or operations that should receive notice of
/// cancellation. When the owning object calls `cancel()`, the `isCancelling`
/// property on every copy of the cancellation token is set to `true`.
/// The registered objects can respond in whatever manner is appropriate.
///
/// All `CancellationToken` methods are thread safe.
public struct CancellationToken {
    fileprivate let source: CancellationTokenSource? // no-op when `nil`

    /// Returns `true` if cancellation has been requested for this token.
    /// Returns `false` if the source was deallocated.
    public var isCancelling: Bool {
        return source?.isCancelling ?? false
    }

    /// Registers the closure that will be called when the token is canceled.
    /// If this token is already cancelled, the closure will be run immediately
    /// and synchronously.
    public func register(_ closure: @escaping () -> Void) {
        source?.register(closure)
    }

    /// Returns a token which never gets cancelled.
    public static var noOp: CancellationToken {
        return CancellationToken(source: nil)
    }
}
