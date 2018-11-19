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
    private var handlers: [(Result) -> Void]?

    // MARK: Create

    /// Creates a new, pending future.
    ///
    /// - parameter closure: The closure is called immediately on the current
    /// thread. You should start an asynchronous task and call either `succeed`
    /// or `fail` when it completes.
    public init(_ closure: (_ succeed: @escaping (Value) -> Void, _ fail: @escaping (Error) -> Void) -> Void) {
        closure(self.succeed, self.fail) // retain self
    }

    /// Create a new, pending promise.
    public static var promise: Promise {
        return Promise()
    }

    init() {}

    /// Creates a future with a given value.
    public convenience init(value: Value) {
        self.init(result: .success(value))
    }

    /// Creates a future with a given error.
    public convenience init(error: Error) {
        self.init(result: .failure(error))
    }

    /// Creates a future with a given result.
    public init(result: Result) {
        self.memoizedResult = result
    }

    // MARK: State Transitions

    func succeed(_ value: Value) {
        resolve(.success(value))
    }

    func fail(_ error: Error) {
        resolve(.failure(error))
    }

    func resolve(_ result: Result) {
        lock.lock()
        guard self.memoizedResult == nil else {
            lock.unlock(); return // Already resolved
        }
        self.memoizedResult = result
        let handlers = self.handlers
        self.handlers = nil
        lock.unlock()

        handlers?.forEach { $0(result) }
    }

    // MARK: Callbacks

    /// Attach callbacks to execute when the future has a result.
    ///
    /// See `on(scheduler:success:failure:completion:)` for more info.
    @discardableResult
    public func on(success: ((Value) -> Void)? = nil, failure: ((Error) -> Void)? = nil, completion: ((Result) -> Void)? = nil) -> Future {
        // We don't use a default argument because this results in a more convenience code completion.
        return self.on(scheduler:Scheduler.main, success: success, failure: failure, completion: completion)
    }

    /// Attach callbacks to execute when the future has a result.
    ///
    /// - parameters:
    ///   - scheduler: A scheduler on which the callbacks are called. By default,
    ///     `Scheduler.main` which runs immediately if on the main thread,
    ///     otherwise asynchronously on the main thread.
    ///   - success: Gets called when the future is resolved successfully.
    ///   - failure: Gets called when the future is resolved with an error.
    ///   - completion: Gets called when the future is resolved.
    /// - returns: Returns self so that you can continue the chain.
    @discardableResult
    public func on(scheduler: @escaping ScheduleWork, success: ((Value) -> Void)? = nil, failure: ((Error) -> Void)? = nil, completion: ((Result) -> Void)? = nil) -> Future {
        observe { result in
            scheduler {
                switch result {
                case let .success(value): success?(value)
                case let .failure(error): failure?(error)
                }
                completion?(result)
            }
        }
        return self
    }

    func observe(completion: @escaping (Result) -> Void) {
        lock.lock()
        guard let result = self.memoizedResult else {
            // Create handlers lazily - in some cases they are no needed
            handlers = handlers ?? []
            handlers?.append(completion)
            lock.unlock(); return // Still pending, handlers attached
        }
        lock.unlock()

        completion(result)
    }

    // At convenience function which is used for implementing cascades of futures.
    // It calls `observe(completion:)` directly for performance but technically,
    // it could be implemented in terms of public `on(scheduler: Scheduler.immediate`.
    func observe(success: @escaping (Value) -> Void, failure: @escaping (Error) -> Void) {
        observe { result in
            switch result {
            case let .success(value): success(value)
            case let .failure(error): failure(error)
            }
        }
    }

    // MARK: Synchronous Inspection

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
}

extension Future where Error == Never {
    func observe(success: @escaping (Value) -> Void) {
        observe(success: success, failure: { _ in fatalError("Can never happen") })
    }
}

// MARK: - Disambiguate Init

extension Future where Error == Never {
    public convenience init(value: Value) {
        self.init(result: .success(value))
    }
}

// MARK: - Map, FlatMap

extension Future {

    /// Returns a future with the result of mapping the given closure over the
    /// current future's value.
    public func map<NewValue>(_ transform: @escaping (Value) -> NewValue) -> Future<NewValue, Error> {
        let future = Future<NewValue, Error>()
        observe(success: { future.succeed(transform($0)) }, failure: future.fail)
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
        observe(success: { transform($0).observe(completion: future.resolve) }, failure: future.fail)
        return future
    }

    // Allow:
    // Future<T, E>.flatMap { Future<T, Never> }

    public func flatMap<NewValue>(_ transform: @escaping (Value) -> Future<NewValue, Never>) -> Future<NewValue, Error> {
        let future = Future<NewValue, Error>()
        observe(success: { transform($0).observe(success: future.succeed) }, failure: future.fail)
        return future
    }
}

extension Future where Error == Never {
    // Allow:
    // Future<T, Never>.flatMap { Future<T, E> }
    // Future<T, Never>.flatMap { Future<T, Never } // disambiguate

    public func flatMap<NewValue, NewError>(_ transform: @escaping (Value) -> Future<NewValue, NewError>) -> Future<NewValue, NewError> {
        let future = Future<NewValue, NewError>()
        observe(success: { transform($0).observe(completion: future.resolve) })
        return future
    }

    public func flatMap<NewValue>(_ transform: @escaping (Value) -> Future<NewValue, Error>) -> Future<NewValue, Error> {
        let future = Future<NewValue, Error>()
        observe(success: { transform($0).observe(completion: future.resolve) })
        return future
    }
}

// MARK: - MapError, FlatMapError

extension Future {
    /// Returns a future with the error which is the result of mapping the given
    /// closure over the current future's error.
    public func mapError<NewError>(_ transform: @escaping (Error) -> NewError) -> Future<Value, NewError> {
        let future = Future<Value, NewError>()
        observe(success: future.succeed, failure: { future.fail(transform($0)) })
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
        observe(success: future.succeed, failure: { transform($0).observe(completion: future.resolve) })
        return future
    }
}

// MARK: - Zip

extension Future where Value == Any, Error == Any {

    /// Returns a future which succeedes when all the given futures succeed. If
    /// any of the futures fail, the returned future also fails with that error.
    public static func zip<V1, V2, E>(_ f1: Future<V1, E>, _ f2: Future<V2, E>) -> Future<(V1, V2), E> {
        let future = Future<(V1, V2), E>()
        func success(value: Any) {
            guard let v1 = f1.value, let v2 = f2.value else { return }
            future.succeed((v1, v2))
        }
        f1.observe(success: success, failure: future.fail)
        f2.observe(success: success, failure: future.fail)
        return future
    }

    /// Returns a future which succeedes when all the given futures succeed. If
    /// any of the futures fail, the returned future also fails with that error.
    public static func zip<V1, V2, V3, E>(_ f1: Future<V1, E>, _ f2: Future<V2, E>, _ f3: Future<V3, E>) -> Future<(V1, V2, V3), E> {
        return Future.zip(f1, Future.zip(f2, f3)).map { ($0.0, $0.1.0, $0.1.1) }
    }

    /// Returns a future which succeedes when all the given futures succeed. If
    /// any of the futures fail, the returned future also fails with that error.
    public static func zip<V, E>(_ futures: [Future<V, E>]) -> Future<[V], E> {
        return Future.reduce([V](), futures) { $0 + [$1] }
    }
}

// MARK: - Reduce

extension Future where Value == Any, Error == Any {

    /// Returns a future that succeeded when all the given futures succeed.
    /// The future contains the result of combining the `initialResult` with
    /// the values of all the given future. If any of the futures fail, the
    /// returned future also fails with that error.
    public static func reduce<V1, V2, E>(_ initialResult: V1, _ futures: [Future<V2, E>], _ combiningFunction: @escaping (V1, V2) -> V1) -> Future<V1, E> {
        return futures.reduce(Future<V1, E>(value: initialResult)) { lhs, rhs in
            return Future.zip(lhs, rhs).map(combiningFunction)
        }
    }
}

// MARK: - Result, Promise

extension Future {

    public enum Result {
        case success(Value), failure(Error)

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

    /// A promise to provide a result later.
    public struct Promise {
        /// The future associated with the promise.
        public let future = Future()

        /// Sends a value to the associated future.
        public func succeed(value: Value) {
            future.succeed(value)
        }

        /// Sends an error to the associated future.
        public func fail(error: Error) {
            future.fail(error)
        }

        /// Sends a result to the associated future.
        public func resolve(result: Result) {
            future.resolve(result)
        }
    }
}

extension Future.Result: Equatable where Value: Equatable, Error: Equatable { }

// MARK: - Scheduler

public typealias ScheduleWork = (_ work: @escaping () -> Void) -> Void

public enum Scheduler {
    /// Runs immediately if on the main thread, otherwise asynchronously on the main thread.
    public static let main: ScheduleWork = { work in
        Thread.isMainThread ? work() : DispatchQueue.main.async(execute: work)
    }

    /// Immediately executes the given closure.
    public static let immediate: ScheduleWork = { work in
        work()
    }

    /// Runs asynchronously on the given queue.
    public static func async(on queue: DispatchQueue, flags: DispatchWorkItemFlags = []) -> ScheduleWork {
        return { work in
            queue.async(flags: flags, execute: work)
        }
    }
}

// MARK: - Private

// Using the same lock across instances is safe because Future doesn't invoke
// any client code inside it.
private let lock = NSLock()
