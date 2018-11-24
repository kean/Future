// The MIT License (MIT)
//
// Copyright (c) 2016-2018 Alexander Grebenyuk (github.com/kean).

import Foundation

// MARK: - CancellationTokenSource

/// Manages cancellation tokens and signals them when cancellation is requested.
///
/// All `CancellationTokenSource` methods are thread safe.
public struct CancellationTokenSource {

    private let promise = Promise<Void, Never>()

    /// Returns `true` if cancellation has been requested.
    public var isCancelling: Bool {
        return promise.future.value != nil
    }

    /// Creates a new token associated with the source.
    public var token: CancellationToken {
        return CancellationToken(source: self)
    }

    /// Initializes the `CancellationTokenSource` instance.
    public init() {}

    fileprivate func register(_ closure: @escaping () -> Void) {
        promise.future.on(success: closure)
    }

    /// Communicates a request for cancellation to the managed tokens.
    public func cancel() {
        promise.succeed(value: ())
    }
}

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

    /// Returns a token which is never cancelled.
    public static var none: CancellationToken {
        return CancellationToken(source: nil)
    }

    internal init(source: CancellationTokenSource?) {
        self.source = source
    }
}
