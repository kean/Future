// The MIT License (MIT)
//
// Copyright (c) 2016-2018 Alexander Grebenyuk (github.com/kean).

import Foundation

/// A future represents a result of a task which may be available now, or
/// in the future, or never. Once the future receives the result, its state can
/// never be changed, either a value or an error is broadcasted to all observers.
///
/// To attach a callback to the `Future` use `on` method:
///
/// ```
/// let user: Future<User, Error>
///
/// user.on(success: { print("received entity: \($0)" },
///         failure: { print("failed with error: \($0)" })
///
/// // As an alternative observe a completion:
/// user.on(completion: { print("completed with result: \($0)" })
/// ```
///
/// Futures are easily composable. `Future<Value, Error>` provides a set of
/// functions like `map`, `flatMap`, `zip`, `reduce` and more to compose futures.
public final class Future<Value, Error> {
    private var memoizedResult: Result? // nil when pending
    private var handlers: Handlers?

    // MARK: Create

    /// Creates a new, pending future.
    ///
    /// - parameter closure: The closure is called immediately on the current
    /// thread. You should start an asynchronous task and call either `succeed`
    /// or `fail` when it completes.
    public init(_ closure: (_ succeed: @escaping (Value) -> Void, _ fail: @escaping (Error) -> Void) -> Void) {
        closure(self.succeed, self.fail) // retain self
    }

    init() {}

    /// Creates a future with a given value.
    public init(value: Value) {
        self.memoizedResult = .success(value)
    }

    /// Creates a future with a given error.
    public init(error: Error) {
        self.memoizedResult = .failure(error)
    }

    // MARK: State Transitions

    func succeed(_ value: Value) {
        resolve(with: .success(value))
    }

    func fail(_ error: Error) {
        resolve(with: .failure(error))
    }

    private func resolve(with result: Result) {
        lock.lock()
        guard self.memoizedResult == nil else {
            lock.unlock(); return // Already resolved
        }
        self.memoizedResult = result
        let handlers = self.handlers
        self.handlers = nil
        lock.unlock()

        switch result {
        case let .success(value): handlers?.success.forEach { $0(value) }
        case let .failure(error): handlers?.failure.forEach { $0(error) }
        }
    }

    // MARK: Callbacks

    /// The given closures execute asynchronously when the future has a result.
    ///
    /// - parameters:
    ///   - queue: A queue on which the callbacks are called. `.main` by default.
    ///   - success: Gets called when the future has a value.
    ///   - failure: Gets called when the future has an error.
    ///   - completion: Gets called when the future has any result.
    public func on(queue: DispatchQueue = .main, success: ((Value) -> Void)? = nil, failure: ((Error) -> Void)? = nil, completion: ((Result) -> Void)? = nil) {
        observe(success: { value in queue.async { success?(value); completion?(.success(value)) } },
                failure: { error in queue.async { failure?(error); completion?(.failure(error)) } })
    }

    private func observe(success: @escaping (Value) -> Void, failure: @escaping (Error) -> Void) {
        lock.lock()
        guard let result = self.memoizedResult else {
            // Create handlers lazily - in some cases they are no needed
            handlers = handlers ?? Handlers()
            handlers?.success.append(success)
            handlers?.failure.append(failure)
            lock.unlock(); return // Still pending, handlers attached
        }
        lock.unlock()

        switch result {
        case let .success(value): success(value)
        case let .failure(error): failure(error)
        }
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

    /// Returns a future with the result of mapping the given closure over the
    /// current future's value.
    public func map<NewValue>(_ transform: @escaping (Value) -> NewValue) -> Future<NewValue, Error> {
        let future = Future<NewValue, Error>()
        cascade(future, success: { future.succeed(transform($0)) })
        return future
    }

    /// Returns a future which is eventually resolved with the result of the
    /// future returned by the `transform` closure. The `transform` closure is
    /// called when the current future receives a value.
    ///
    /// Allows you to "chain" multiple async operations:
    ///
    /// ```
    /// let avatar = user
    ///     .map { $0.avatarURL }
    ///     .flatMap(loadAvatar)
    ///
    /// // user: Future<User, Error>
    /// // func loadAvatar(url: URL) -> Future<Avatar, Error>
    /// ```
    public func flatMap<NewValue>(_ transform: @escaping (Value) -> Future<NewValue, Error>) -> Future<NewValue, Error> {
        let future = Future<NewValue, Error>()
        cascade(future, success: { transform($0).cascade(future) })
        return future
    }

    /// Returns a future with the error which is the result of mapping the given
    /// closure over the current future's error.
    public func mapError<NewError>(_ transform: @escaping (Error) -> NewError) -> Future<Value, NewError> {
        let future = Future<Value, NewError>()
        cascade(future, failure: { future.fail(transform($0)) })
        return future
    }

    /// Returns a future which is eventually resolved with the result of the
    /// future returned by the `transform` closure. The `transform` closure is
    /// called when the current future receives an error.
    ///
    /// Allows you to continue the chain of futures by "recovering" from an error
    /// with a new future.
    public func flatMapError<NewError>(_ transform: @escaping (Error) -> Future<Value, NewError>) -> Future<Value, NewError> {
        let future = Future<Value, NewError>()
        cascade(future, failure: { transform($0).cascade(future) })
        return future
    }

    // MARK: Zip

    /// Returns a future which succeedes when all the given futures succeed. If
    /// any of the futures fail, the returned future also fails with that error.
    public static func zip<V2>(_ f1: Future<Value, Error>, _ f2: Future<V2, Error>) -> Future<(Value, V2), Error> {
        let future = Future<(Value, V2), Error>()
        func success(value: Any) {
            guard let v1 = f1.value, let v2 = f2.value else { return }
            future.succeed((v1, v2))
        }
        f1.cascade(future, success: success)
        f2.cascade(future, success: success)
        return future
    }

    /// Returns a future which succeedes when all the given futures succeed. If
    /// any of the futures fail, the returned future also fails with that error.
    public static func zip<V2, V3>(_ f1: Future<Value, Error>, _ f2: Future<V2, Error>, _ f3: Future<V3, Error>) -> Future<(Value, V2, V3), Error> {
        return Future.zip(f1, Future<V2, Error>.zip(f2, f3)).map { value in
            return (value.0, value.1.0, value.1.1)
        }
    }

    /// Returns a future which succeedes when all the given futures succeed. If
    /// any of the futures fail, the returned future also fails with that error.
    public static func zip(_ futures: [Future<Value, Error>]) -> Future<[Value], Error> {
        return Future<[Value], Error>.reduce([], futures) { result, value in
            result + [value]
        }
    }

    // MARK: Reduce

    /// Returns a future that succeeded when all the given futures succeed.
    /// The future contains the result of combining the `initialResult` with
    /// the values of all the given future. If any of the futures fail, the
    /// returned future also fails with that error.
    public static func reduce<V2>(_ initialResult: Value, _ futures: [Future<V2, Error>], _ combiningFunction: @escaping (Value, V2) -> Value) -> Future<Value, Error> {
        return futures.reduce(Future(value: initialResult)) { lhs, rhs in
            return Future.zip(lhs, rhs).map(combiningFunction)
        }
    }

    // MARK: Synchronous Inspection

    /// Returns true if the future is still pending.
    public var isPending: Bool {
        return result == nil
    }

    /// Returns the value if the future has a value.
    public var value: Value? {
        return result?.value
    }

    /// Returns the error if the future has an error.
    public var error: Error? {
        return result?.error
    }

    /// Returns the result if the future completed.
    public var result: Result? {
        lock.lock(); defer { lock.unlock() }
        return memoizedResult
    }

    // MARK: Wait

    /// Waits for the future's result. The current thread blocks until the result
    /// is received.
    ///
    /// - note: This methods waits for the completion on the private dispatch
    /// queue so it's safe to call it from any thread. But avoid blocking the
    /// main thread!
    public func wait() -> Result {
        let semaphore = DispatchSemaphore(value: 0)
        on(queue: waitQueue, completion: { _ in semaphore.signal() })
        semaphore.wait()
        return result! // Must have result at this point
    }

    // MARK: Result

    public enum Result {
        case success(Value)
        case failure(Error)

        /// Returns the value in case of success, `nil` otherwise.
        public var value: Value? {
            guard case let .success(value) = self else { return nil }
            return value
        }

        /// Returns the value in case of failure, `nil` otherwise.
        public var error: Error? {
            guard case let .failure(error) = self else { return nil }
            return error
        }
    }

    // MARK: Private

    private struct Handlers {
        var success = [(Value) -> Void]()
        var failure = [(Error) -> Void]()
    }
}

// Using the same lock across instances is safe because Future doesn't invoke
// any client code inside it.
private let lock = NSLock()

private let waitQueue = DispatchQueue(label:  "com.github.kean.pill.wait-queue", attributes: .concurrent)

/// A promise to provide a result later.
public struct Promise<Value, Error> {
    /// The future associated with the promise.
    public let future: Future<Value, Error>

    /// Initializer the promise and creates a future associated with it.
    public init() {
        self.future = Future()
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
