// The MIT License (MIT)
//
// Copyright (c) 2017-2018 Alexander Grebenyuk (github.com/kean).

import Foundation

/// A future represents a value which may be available now, or in the future,
/// or never. Use `on(value:)` to observe the result of the future. Use `on(error:)`
/// to observe error.
public final class Future<Value, Error> {
    private var state: State = .pending
    private var handlers: Handlers? // nil when finished
    private let queue: DispatchQueue // queue on which events are observed

    // MARK: Creation

    /// Creates a new, pending future.
    ///
    /// - parameter closure: The closure is called immediately on the current
    /// thread. You should start an asynchronous task and call either `fulfill`
    /// or `reject` when it completes.
    public convenience init(_ closure: (_ fulfill: @escaping (Value) -> Void, _ reject: @escaping (Error) -> Void) -> Void) {
        self.init(queue: .main, closure)
    }

    convenience init(queue: DispatchQueue, _ closure: (_ fulfill: @escaping (Value) -> Void, _ reject: @escaping (Error) -> Void) -> Void) {
        self.init(queue: queue)
        closure({ self.fulfill($0) }, { self.reject($0) }) // retain self
    }

    init(queue: DispatchQueue = .main) {
        self.queue = queue
        self.handlers = Handlers()
    }

    /// Creates a promise fulfilled with a given value.
    public init(value: Value) {
        self.queue = .main
        self.state = .success(value)
    }

    /// Creates a promise rejected with a given error.
    public init(error: Error) {
        self.queue = .main
        self.state = .failure(error)
    }

    // MARK: State Transitions

    func fulfill(_ value: Value) {
        _transitionToState(.success(value))
    }

    func reject(_ error: Error) {
        _transitionToState(.failure(error))
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
        case let .success(value): handlers?.success.forEach { $0(value) }
        case let .failure(error): handlers?.failure.forEach { $0(error) }
        }
        self.handlers = nil
    }

    // MARK: Callbacks

    /// Change the queue on which the promise callbacks are called. All callbacks
    /// are called on the main queue by default.
    public func observeOn(_ queue: DispatchQueue) -> Future {
        return Future(queue: queue) { fulfill, reject in
            _observe(success: fulfill, failure: reject)
        }
    }

    private func _observe(success: @escaping (Value) -> Void, failure: @escaping (Error) -> Void) {
        let queue = self.queue
        let success: (Value) -> Void = { value in queue.async { success(value) } }
        let failure: (Error) -> Void = { value in queue.async { failure(value) } }

        lock.lock(); defer { lock.unlock() }
        switch state {
        case .pending:
            handlers?.success.append(success)
            handlers?.failure.append(failure)
        case let .success(value): success(value)
        case let .failure(error): failure(error)
        }
    }

    // MARK: Map
    
    /// The given closure executes asynchronously when the promise is fulfilled.
    ///
    /// - returns: A promise fulfilled with a value returned by the closure.
    public func map<NewValue>(_ closure: @escaping (Value) -> NewValue) -> Future<NewValue, Error> {
        return flatMap { value in
            Future<NewValue, Error>(value: closure(value))
        }
    }

    /// The given closure executes asynchronously when the promise is fulfilled.
    ///
    /// - returns: A promise that resolves by the promise returned by the closure.
    public func flatMap<NewValue>(_ closure: @escaping (Value) -> Future<NewValue, Error>) -> Future<NewValue, Error> {
        return Future<NewValue, Error>(queue: queue) { fulfill, reject in
            _observe(success: { value in
                closure(value)._observe(success: fulfill, failure: reject)
            }, failure: reject)
        }
    }

    /// The given closure executes asynchronously when the promise is rejected.
    ///
    /// - returns: A promise rejected with an error returned by the closure..
    public func mapError<NewError>(_ closure: @escaping (Error) -> NewError) -> Future<Value, NewError> {
        return flatMapError { error in
            Future<Value, NewError>(error: closure(error))
        }
    }

    /// The given closure executes asynchronously when the promise is rejected.
    /// Allows you to continue the chain of promises by recovering from the error
    /// by creating a new promise.
    ///
    /// - returns: A promise that resolves by the promise returned by the closure.
    public func flatMapError<NewError>(_ closure: @escaping (Error) -> Future<Value, NewError>) -> Future<Value, NewError> {
        return Future<Value, NewError>(queue: queue) { fulfill, reject in
            _observe(success: fulfill, failure: { error in
                closure(error)._observe(success: fulfill, failure: reject)
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
        _observe(success: { value?($0); completed?() },
                 failure: { error?($0); completed?() })
    }

    // MARK: Synchronous Inspection

    /// Returns true if the future is still pending.
    public var isPending: Bool {
        lock.lock(); defer { lock.unlock() }
        guard case .pending = state else { return false }
        return true
    }

    /// Returns the value if the future received a value.
    public var value: Value? {
        lock.lock(); defer { lock.unlock() }
        guard case let .success(value) = state else { return nil }
        return value
    }

    /// Returns the error if the future received an error.
    public var error: Error? {
        lock.lock(); defer { lock.unlock() }
        guard case let .failure(error) = state else { return nil }
        return error
    }

    // MARK: State (Private)

    private enum State {
        case pending
        case success(Value)
        case failure(Error)
    }

    private struct Handlers {
        var success = [(Value) -> Void]()
        var failure = [(Error) -> Void]()
    }
}

// Using the same lock across instances is safe because Promise doesn't invoke
// any client code directly, it always does so after asynchronously dispatching
// the work to the provided dispatch queue.
private let lock = NSLock()

/// A promise to provide a result later.
public struct Promise<Value, Error> {
    public let future = Future<Value, Error>()

    public init() {}

    public func fulfill(value: Value) {
        future.fulfill(value)
    }

    public func reject(error: Error) {
        future.reject(error)
    }
}
