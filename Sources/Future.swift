// The MIT License (MIT)
//
// Copyright (c) 2017-2018 Alexander Grebenyuk (github.com/kean).

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
/// main queue (`DispatchQueue.main`). To change the queue use `observeOn` method
/// which creates a new future observed on the given queue.
public final class Future<Value, Error> {
    private var state: State = .pending
    private var handlers: Handlers? // nil when finished
    private let queue: DispatchQueue // queue on which events are observed

    // MARK: Create

    /// Creates a new, pending future.
    ///
    /// - parameter closure: The closure is called immediately on the current
    /// thread. You should start an asynchronous task and call either `succeed`
    /// or `fail` when it completes.
    public convenience init(_ closure: (_ succeed: @escaping (Value) -> Void, _ fail: @escaping (Error) -> Void) -> Void) {
        self.init(queue: .main, closure)
    }

    convenience init(queue: DispatchQueue, _ closure: (_ succeed: @escaping (Value) -> Void, _ fail: @escaping (Error) -> Void) -> Void) {
        self.init(queue: queue)
        closure({ self.succeed($0) }, { self.fail($0) }) // retain self
    }

    init(queue: DispatchQueue = .main) {
        self.queue = queue
        self.handlers = Handlers()
    }

    /// Creates a future with a given value.
    public init(value: Value) {
        self.queue = .main
        self.state = .success(value)
        // no need to create handlers
    }

    /// Creates a future with a given error.
    public init(error: Error) {
        self.queue = .main
        self.state = .failure(error)
        // no need to create handlers
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
    /// - parameter success: Gets called when the future has a value.
    /// - parameter failure: Gets called when the future has an error.
    /// - parameter completed: Gets called when the future has any result.
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
        return Future(queue: queue) { succeed, fail in
            observe(success: succeed, failure: fail)
        }
    }

    // MARK: Map
    
    /// The closure executes asynchronously when the future has a value.
    ///
    /// - returns: A future with a value returned by the closure.
    public func map<NewValue>(_ closure: @escaping (Value) -> NewValue) -> Future<NewValue, Error> {
        return flatMap { value in
            Future<NewValue, Error>(value: closure(value))
        }
    }

    /// The closure executes asynchronously when the future has a value.
    ///
    /// - returns: A future with a result of the future returned by the closure.
    public func flatMap<NewValue>(_ closure: @escaping (Value) -> Future<NewValue, Error>) -> Future<NewValue, Error> {
        return Future<NewValue, Error>(queue: queue) { succeed, fail in
            observe(success: { value in
                closure(value).observe(success: succeed, failure: fail)
            }, failure: fail)
        }
    }

    /// The closure executes asynchronously when the future fails.
    ///
    /// - returns: A future with an error returned by the closure.
    public func mapError<NewError>(_ closure: @escaping (Error) -> NewError) -> Future<Value, NewError> {
        return flatMapError { error in
            Future<Value, NewError>(error: closure(error))
        }
    }

    /// The closure executes asynchronously when the future fails.
    /// Allows you to continue the chain of futures by recovering from the error
    /// by creating a new future.
    ///
    /// - returns: A future with a result of the future returned by the closure.
    public func flatMapError<NewError>(_ closure: @escaping (Error) -> Future<Value, NewError>) -> Future<Value, NewError> {
        return Future<Value, NewError>(queue: queue) { succeed, fail in
            observe(success: succeed, failure: { error in
                closure(error).observe(success: succeed, failure: fail)
            })
        }
    }

    // MARK: Synchronous Inspection

    /// Returns true if the future is still pending.
    public var isPending: Bool {
        lock.lock(); defer { lock.unlock() }
        guard case .pending = state else { return false }
        return true
    }

    /// Returns the value if the future has a value.
    public var value: Value? {
        lock.lock(); defer { lock.unlock() }
        guard case let .success(value) = state else { return nil }
        return value
    }

    /// Returns the error if the future has an error.
    public var error: Error? {
        lock.lock(); defer { lock.unlock() }
        guard case let .failure(error) = state else { return nil }
        return error
    }

    // MARK: Zip

    /// Returns a future which succeedes when both futures succeed. If one of
    /// the futures fail, the returned future also fails immediately.
    ///
    /// - note: The resulting future is observed on the first future's queue.
    public static func zip<SecondValue>(_ lhs: Future<Value, Error>, _ rhs: Future<SecondValue, Error>) -> Future<(Value, SecondValue), Error> {
        var firstValue: Value?
        var secondValue: SecondValue?
        return Future<(Value, SecondValue), Error>(queue: lhs.queue) { succeed, fail in
            func succeedIfPossible() {
                // This is thread safe because both futures are observed on the
                // same queue.
                guard let firstValue = firstValue, let secondValue = secondValue else { return }
                succeed((firstValue, secondValue))
            }
            lhs.on(success: { value in
                firstValue = value
                succeedIfPossible()
            }, failure: fail) // whichever fails first

            rhs.observeOn(lhs.queue).on(success: { value in
                secondValue = value
                succeedIfPossible()
            }, failure: fail) // whichever fails first
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
    public static func reduce<SecondValue>(_ initialResult: Value, _ futures: [Future<SecondValue, Error>], _ combiningFunction: @escaping (Value, SecondValue) -> Value) -> Future<Value, Error> {
        return Future(value: initialResult).reduce(futures, combiningFunction)
    }

    /// Returns a future that succeeded only when all the provided futures
    /// succeed. The future contains the result of combining all of the
    /// values of the given futures. If any of the futures fail the resulting
    /// future also fails.
    ///
    /// - note: The resulting future is observed on the first future's queue.
    private func reduce<SecondValue>(_ futures: [Future<SecondValue, Error>], _ combiningFunction: @escaping (Value, SecondValue) -> Value) -> Future<Value, Error> {
        return futures.reduce(self) { lhs, rhs in
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
private let lock = NSLock()

/// A promise to provide a result later.
public struct Promise<Value, Error> {
    public let future: Future<Value, Error>

    public init(on queue: DispatchQueue = .main) {
        self.future = Future(queue: queue)
    }

    public func succeed(value: Value) {
        future.succeed(value)
    }

    public func fail(error: Error) {
        future.fail(error)
    }
}
