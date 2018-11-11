// The MIT License (MIT)
//
// Copyright (c) 2017-2018 Alexander Grebenyuk (github.com/kean).

import Foundation

/// A promise represents a value which may be available now, or in the future,
/// or never. Use `on(value:)` to observe the result of the promise. Use `on(error:)`
/// to observe error.
///
/// Promises start in a *pending* state and either get *fulfilled* with a
/// value or get *rejected* with an error.
public final class Promise<Value, Error> {
    private var state: State = .pending
    private var handlers: Handlers? // nil when finished
    private let queue: DispatchQueue // Queue on which promise is observed

    // MARK: Creation

    /// Creates a new, pending promise.
    ///
    /// - parameter closure: The closure is called immediately on the current
    /// thread. You should start an asynchronous task and call either `fulfill`
    /// or `reject` when it completes.
    public convenience init(_ closure: (_ fulfill: @escaping (Value) -> Void, _ reject: @escaping (Error) -> Void) -> Void) {
        self.init(queue: .main, closure)
    }

    private init(queue: DispatchQueue, _ closure: (_ fulfill: @escaping (Value) -> Void, _ reject: @escaping (Error) -> Void) -> Void) {
        self.queue = queue
        self.handlers = Handlers()
        closure({ self._fulfill($0) }, { self._reject($0) }) // retain self
    }

    private func _fulfill(_ value: Value) {
        _transitionToState(.fulfilled(value))
    }

    private func _reject(_ error: Error) {
        _transitionToState(.rejected(error))
    }

    // Return handlers to call if promise was resolved. Returns nil otherwise.
    private func _transitionToState(_ newState: State) {
        lock.lock(); defer { lock.unlock() }
        guard case .pending = self.state else {
            return // already resolved
        }
        self.state = newState
        assert(handlers != nil)
        switch newState {
        case .pending: break // wait till promise is resovled
        case let .fulfilled(value): handlers?.fulfill.forEach { $0(value) }
        case let .rejected(error): handlers?.reject.forEach { $0(error) }
        }
        self.handlers = nil
    }

    /// Creates a promise fulfilled with a given value.
    public init(value: Value) {
        self.queue = .main
        self.state = .fulfilled(value)
    }

    /// Creates a promise rejected with a given error.
    public init(error: Error) {
        self.queue = .main
        self.state = .rejected(error)
    }

    // MARK: Callbacks

    /// Change the queue on which the promise callbacks are called. All callbacks
    /// are called on the main queue by default.
    public func observeOn(_ queue: DispatchQueue) -> Promise {
        return Promise(queue: queue) { fulfill, reject in
            _observe(fulfill: fulfill, reject: reject)
        }
    }

    private func _observe(fulfill: @escaping (Value) -> Void, reject: @escaping (Error) -> Void) {
        let queue = self.queue
        let fulfill: (Value) -> Void = { value in queue.async { fulfill(value) } }
        let reject: (Error) -> Void = { value in queue.async { reject(value) } }

        lock.lock(); defer { lock.unlock() }
        switch state {
        case .pending:
            handlers?.fulfill.append(fulfill)
            handlers?.reject.append(reject)
        case let .fulfilled(value): fulfill(value)
        case let .rejected(error): reject(error)
        }
    }

    // MARK: Map
    
    /// The given closure executes asynchronously when the promise is fulfilled.
    ///
    /// - returns: A promise fulfilled with a value returned by the closure.
    public func map<NewValue>(_ closure: @escaping (Value) -> NewValue) -> Promise<NewValue, Error> {
        return flatMap { value in
            Promise<NewValue, Error>(value: closure(value))
        }
    }

    /// The given closure executes asynchronously when the promise is fulfilled.
    ///
    /// - returns: A promise that resolves by the promise returned by the closure.
    public func flatMap<NewValue>(_ closure: @escaping (Value) -> Promise<NewValue, Error>) -> Promise<NewValue, Error> {
        return Promise<NewValue, Error>(queue: queue) { fulfill, reject in
            _observe(fulfill: { value in
                closure(value)._observe(fulfill: fulfill, reject: reject)
            }, reject: reject)
        }
    }

    /// The given closure executes asynchronously when the promise is rejected.
    ///
    /// - returns: A promise rejected with an error returned by the closure..
    public func mapError<NewError>(_ closure: @escaping (Error) -> NewError) -> Promise<Value, NewError> {
        return flatMapError { error in
            Promise<Value, NewError>(error: closure(error))
        }
    }

    /// The given closure executes asynchronously when the promise is rejected.
    /// Allows you to continue the chain of promises by recovering from the error
    /// by creating a new promise.
    ///
    /// - returns: A promise that resolves by the promise returned by the closure.
    public func flatMapError<NewError>(_ closure: @escaping (Error) -> Promise<Value, NewError>) -> Promise<Value, NewError> {
        return Promise<Value, NewError>(queue: queue) { fulfill, reject in
            _observe(fulfill: fulfill, reject: { error in
                closure(error)._observe(fulfill: fulfill, reject: reject)
            })
        }
    }

    // MARK: Observing Results

    /// The given closures execute asynchronously when the promise is resolved.
    ///
    /// - parameter queue: A queue on which the closures are run. `.main` by default.
    /// - parameter value: Gets called when promise is fulfilled.
    /// - parameter error: Gets called when promise is rejected.
    /// - parameter completed: Gets called when promise is resolved.
    public func on(value: ((Value) -> Void)? = nil, error: ((Error) -> Void)? = nil, completed: (() -> Void)? = nil) {
        _observe(fulfill: { value?($0); completed?() },
                 reject: { error?($0); completed?() })
    }

    // MARK: Synchronous Inspection

    /// Returns `true` the promise hasn't resolved yet.
    public var isPending: Bool {
        lock.lock(); defer { lock.unlock() }
        guard case .pending = state else { return false }
        return true
    }

    /// Returns the `value` which promise was `fulfilled` with.
    public var value: Value? {
        lock.lock(); defer { lock.unlock() }
        guard case let .fulfilled(value) = state else { return nil }
        return value
    }
    /// Returns the `error` which promise was `rejected` with.
    public var error: Error? {
        lock.lock(); defer { lock.unlock() }
        guard case let .rejected(error) = state else { return nil }
        return error
    }

    // MARK: State (Private)

    private enum State {
        case pending
        case fulfilled(Value)
        case rejected(Error)
    }

    private struct Handlers {
        var fulfill = [(Value) -> Void]()
        var reject = [(Error) -> Void]()
    }
}

// Using the same lock across instances is safe because Promise doesn't invoke
// any client code directly, it always does so after asynchronously dispatching
// the work to the provided dispatch queue.
private let lock = NSLock()
