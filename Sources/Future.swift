// The MIT License (MIT)
//
// Copyright (c) 2016-2018 Alexander Grebenyuk (github.com/kean).

import Foundation

/// A future represents a result of computation which may be available now, or
/// in the future, or never. Essentially, a future is an object to which you
/// attach callbacks, instead of passing callbacks into a function that performs
/// a computation.
///
/// To attach a callback to the `Future` use `on(success:failure:completion:)`
/// method:
///
/// ```
/// let user: Future<User, Error>
/// user.on(
///     success: { print("received entity: \($0)" },
///     failure: { print("failed with error: \($0)" },
///     completion: { print("either succeeded or failed" }
/// )
/// ```
///
/// Futures are easily composable. `Future<Value, Error>` provides a set of
/// functions like `map`, `flatMap`, `zip`, `reduce` and more to compose futures.
///
/// By default, all of the callbacks and composing functions are executed on the
/// main queue (`DispatchQueue.main`). To change the queue use `observeOn` method.
public final class Future<Value, Error> {
    private var state: State = .pending
    private var handlers: Handlers? // nil when finished
    private let queue: DispatchQueue // queue on which events are observed
    private let lock = locks[Int.random(in: 0..<lockCount)]

    // MARK: Create

    /// Creates a new, pending future.
    ///
    /// - parameter closure: The closure is called immediately on the current
    /// thread. You should start an asynchronous task and call either `succeed`
    /// or `fail` when it completes.
    /// - parameter queue: A queue on which the future is observed. `.main` by
    /// default.
    public convenience init(queue: DispatchQueue = .main, _ closure: (_ succeed: @escaping (Value) -> Void, _ fail: @escaping (Error) -> Void) -> Void) {
        self.init(queue: queue)
        closure(self.succeed, self.fail) // retain self
    }

    init(queue: DispatchQueue = .main) {
        self.queue = queue
        self.handlers = Handlers()
    }

    /// Creates a future with a given value.
    public convenience init(value: Value) {
        self.init(state: .success(value))
    }

    /// Creates a future with a given error.
    public convenience init(error: Error) {
        self.init(state: .failure(error))
    }

    private init(state: State) {
        self.queue = .main
        self.state = state
        // No need to create handlers
    }

    // MARK: State Transitions

    func succeed(_ value: Value) {
        transitionToState(.success(value))
    }

    func fail(_ error: Error) {
        transitionToState(.failure(error))
    }

    private func transitionToState(_ newState: State) {
        lock.lock(); defer { lock.unlock() }
        guard case .pending = self.state else {
            return // already finished
        }
        self.state = newState

        assert(handlers != nil)
        switch newState {
        case .pending: fatalError("Invalid transition")
        case let .success(value): handlers?.success.forEach { $0(value) }
        case let .failure(error): handlers?.failure.forEach { $0(error) }
        }
        self.handlers = nil
    }

    // MARK: Callbacks

    /// The given closures execute asynchronously when the future has a result.
    ///
    /// By default, all of the callbacks and composing functions are executed on
    /// the main queue (`DispatchQueue.main`). To change the queue use `observeOn`.
    ///
    /// - parameter success: Gets called when the future has a value.
    /// - parameter failure: Gets called when the future has an error.
    /// - parameter completion: Gets called when the future has any result.
    public func on(success: ((Value) -> Void)? = nil, failure: ((Error) -> Void)? = nil, completion: (() -> Void)? = nil) {
        observe(success: { success?($0); completion?() },
                failure: { failure?($0); completion?() })
    }

    private func observe(success: @escaping (Value) -> Void, failure: @escaping (Error) -> Void) {
        let queue = self.queue
        let success: (Value) -> Void = { value in queue.async { success(value) } }
        let failure: (Error) -> Void = { error in queue.async { failure(error) } }

        lock.lock(); defer { lock.unlock() }
        switch state {
        case .pending:
            assert(handlers != nil)
            handlers?.success.append(success)
            handlers?.failure.append(failure)
        case let .success(value): success(value)
        case let .failure(error): failure(error)
        }
    }

    /// Returns a new future which callbacks are observed on the given queue. The
    /// default queue is `.main` queue.
    ///
    /// - note: In case the given queue is the same as the current future's
    /// queue the method retuns the current future saving an allocation.
    public func observeOn(_ queue: DispatchQueue) -> Future {
        if queue === self.queue {
            return self // We're already on that queue
        }
        let future = Future(queue: queue)
        cascade(future)
        return future
    }

    /// Resolves the given future with the result of the current future.
    private func cascade(_ future: Future) {
        observe(success: future.succeed, failure: future.fail)
    }

    private func cascade<NewValue>(_ future: Future<NewValue, Error>, success: @escaping (Value) -> Void) {
        observe(success: success, failure: future.fail)
    }

    private func cascade<NewError>(_ future: Future<Value, NewError>, failure: @escaping (Error) -> Void) {
        observe(success: future.succeed , failure: failure)
    }

    // MARK: Map
    
    /// The closure executes asynchronously when the future has a value.
    ///
    /// - returns: A future with a value returned by the closure.
    public func map<NewValue>(_ closure: @escaping (Value) -> NewValue) -> Future<NewValue, Error> {
        let future = Future<NewValue, Error>(queue: queue)
        cascade(future, success: { future.succeed(closure($0)) })
        return future
    }

    /// The closure executes asynchronously when the future has a value.
    ///
    /// - returns: A future with a result of the future returned by the closure.
    public func flatMap<NewValue>(_ closure: @escaping (Value) -> Future<NewValue, Error>) -> Future<NewValue, Error> {
        let future = Future<NewValue, Error>(queue: queue)
        cascade(future, success: { closure($0).cascade(future) })
        return future
    }

    /// The closure executes asynchronously when the future fails.
    ///
    /// - returns: A future with an error returned by the closure.
    public func mapError<NewError>(_ closure: @escaping (Error) -> NewError) -> Future<Value, NewError> {
        let future = Future<Value, NewError>(queue: queue)
        cascade(future, failure: { future.fail(closure($0)) })
        return future
    }

    /// The closure executes asynchronously when the future fails.
    /// Allows you to continue the chain of futures by recovering from the error
    /// by creating a new future.
    ///
    /// - returns: A future with a result of the future returned by the closure.
    public func flatMapError<NewError>(_ closure: @escaping (Error) -> Future<Value, NewError>) -> Future<Value, NewError> {
        let future = Future<Value, NewError>(queue: queue)
        cascade(future, failure: { closure($0).cascade(future) })
        return future
    }

    // MARK: Synchronous Inspection

    /// Returns true if the future is still pending.
    public var isPending: Bool {
        guard case .pending = inspectState() else { return false }
        return true
    }

    /// Returns the value if the future has a value.
    public var value: Value? {
        guard case let .success(value) = inspectState() else { return nil }
        return value
    }

    /// Returns the error if the future has an error.
    public var error: Error? {
        guard case let .failure(error) = inspectState() else { return nil }
        return error
    }

    private func inspectState() -> State {
        lock.lock(); defer { lock.unlock() }
        return state
    }

    // MARK: Zip

    /// Returns a future which succeedes when both futures succeed. If one of
    /// the futures fails, the returned future also fails immediately.
    ///
    /// - note: The resulting future is observed on the first future's queue.
    public static func zip<V2>(_ f1: Future<Value, Error>, _ f2: Future<V2, Error>) -> Future<(Value, V2), Error> {
        let future = Future<(Value, V2), Error>(queue: f1.queue)
        func success(value: Any) {
            guard let v1 = f1.value, let v2 = f2.value else { return }
            future.succeed((v1, v2))
        }
        f1.cascade(future, success: success)
        f2.cascade(future, success: success)
        return future
    }

    /// Returns a future which succeedes when all three futures succeed. If one
    /// of `the futures fails, the returned future also fails immediately.
    ///
    /// - note: The resulting future is observed on the first future's queue.
    public static func zip<V2, V3>(_ f1: Future<Value, Error>, _ f2: Future<V2, Error>, _ f3: Future<V3, Error>) -> Future<(Value, V2, V3), Error> {
        return Future.zip(f1, Future<V2, Error>.zip(f2, f3)).map { value in
            return (value.0, value.1.0, value.1.1)
        }
    }

    /// Returns a future which succeedes when all of the given futures succeed.
    /// If one of the futures fail, the returned future also fails.
    ///
    /// - note: The resulting future is observed on the first future's queue.
    public static func zip(_ futures: [Future<Value, Error>]) -> Future<[Value], Error> {
        return Future<[Value], Error>.reduce([], futures) { result, value in
            result + [value]
        }
    }

    // MARK: Reduce

    /// Returns a future that succeeded only when all the provided futures
    /// succeed. The future contains the result of combining the
    /// `initialResult` with the values of all the given future. If any of the
    /// futures fail the resulting future also fails.
    ///
    /// - note: The resulting future is observed on the first future's queue.
    public static func reduce<V2>(_ initialResult: Value, _ futures: [Future<V2, Error>], _ combiningFunction: @escaping (Value, V2) -> Value) -> Future<Value, Error> {
        return futures.reduce(Future(value: initialResult)) { lhs, rhs in
            return Future.zip(lhs, rhs).map(combiningFunction)
        }
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

// Using the same lock across instances is safe because Future doesn't invoke
// any client code directly, it always does so after asynchronously dispatching
// the work to the provided dispatch queue.
private let lockCount = 10
private let locks = Array(0..<lockCount).map { _ in NSLock() }

/// A promise to provide a result later.
public struct Promise<Value, Error> {
    /// The future associated with the promise.
    public let future: Future<Value, Error>

    /// Initializer the promise, creates a future with a given queue.
    public init(queue: DispatchQueue = .main) {
        self.future = Future(queue: queue)
    }

    /// Sends a value to the associated future.
    public func succeed(value: Value) {
        future.succeed(value)
    }

    /// Sends an error to the associated future.
    public func fail(error: Error) {
        future.fail(error)
    }
}
