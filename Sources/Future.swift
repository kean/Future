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

    /// Create a new, pending promise.
    public static var promise: Promise {
        return Promise()
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
    ///   - scheduler: A scheduler on which the callbacks are called. By default,
    ///     `Scheduler.main` which runs immediately if on the main thread,
    ///     otherwise asynchronously on the main thread.
    ///   - success: Gets called when the future has a value.
    ///   - failure: Gets called when the future has an error.
    ///   - completion: Gets called when the future has any result.
    /// - returns: Returns self so that you can continue the chain.
    @discardableResult
    public func on(scheduler: @escaping ScheduleWork = Scheduler.main, success: ((Value) -> Void)? = nil, failure: ((Error) -> Void)? = nil, completion: ((Result) -> Void)? = nil) -> Future {
        observe(success: { value in scheduler { success?(value); completion?(.success(value)) } },
                failure: { error in scheduler { failure?(error); completion?(.failure(error)) } })
        return self
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
    /// `cascade` is just a slight convenience and a performance optimization,
    /// the users have an analog of `cascade`: `on(scheduler: .immediate)`
    private func cascade(_ future: Future) {
        observe(success: future.succeed, failure: future.fail)
    }

    private func cascade<NewValue>(_ future: Future<NewValue, Error>, success: @escaping (Value) -> Void) {
        observe(success: success, failure: future.fail)
    }

    private func cascade<NewError>(_ future: Future<Value, NewError>, failure: @escaping (Error) -> Void) {
        observe(success: future.succeed , failure: failure)
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

// MARK: - Map, FlatMap, MapError, FlatMapError

extension Future {

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
        f1.cascade(future, success: success)
        f2.cascade(future, success: success)
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
    }

    private struct Handlers {
        var success = [(Value) -> Void]()
        var failure = [(Error) -> Void]()
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
