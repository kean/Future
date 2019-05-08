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
public struct Future<Value, Error: Swift.Error> {
    public typealias Result = Swift.Result<Value, Error>

    private enum Resolver {
        // A future is resolved by a promise. Promise is a class, it has locks,
        // array of handlers, etc.
        case promise(Promise)

        // A future is already resolved with a result. There are no locks, no
        // classes - no allocations needed when creating a future like that.
        case result(Result)
    }

    private let resolver: Resolver
    private let scheduler: ScheduleWork?

    // MARK: Create

    /// Creates a new, pending future.
    ///
    /// - parameter closure: The closure is called immediately on the current
    /// thread. You should start an asynchronous task and call either `succeed`
    /// or `fail` when it completes.
    public init(_ closure: (_ promise: Promise) -> Void) {
        let promise = Promise()
        self.init(resolver: .promise(promise))
        closure(promise)
    }

    private init(resolver: Resolver, scheduler: ScheduleWork? = nil) {
        self.resolver = resolver
        self.scheduler = scheduler
    }

    /// Creates a future with a given value.
    public init(value: Value) {
        self.init(result: .success(value))
    }

    /// Creates a future with a given error.
    public init(error: Error) {
        self.init(result: .failure(error))
    }

    /// Creates a future with a given result.
    public init(result: Result) {
        self.init(resolver: .result(result))
    }

    // MARK: Callbacks

    /// Returns a new future which dispatches the callbacks on the given scheduler.
    /// This includes both `on` method and the composition functions like `map`.
    public func observe(on queue: DispatchQueue) -> Future {
        return Future(resolver: resolver, scheduler: Scheduler.async(on: queue))
    }

    /// Returns a new future which dispatches the callbacks on the given scheduler.
    /// This includes both `on` method and the composition functions like `map`.
    public func observe(on scheduler: @escaping ScheduleWork) -> Future {
        return Future(resolver: resolver, scheduler: scheduler)
    }

    /// Attach callbacks to the future. If the future already has a result,
    /// callbacks are executed immediatelly. If the future doesn't have a result
    /// yet, callbacks will be executed when the future is resolved.
    ///
    /// By default, the callbacks are run on `Scheduler.main` which runs immediately
    /// if on the main thread, otherwise asynchronously on the main thread.
    ///
    /// - parameters:
    ///   - success: Gets called when the future is resolved successfully.
    ///   - failure: Gets called when the future is resolved with an error.
    ///   - completion: Gets called when the future is resolved.
    public func on(success: ((Value) -> Void)? = nil, failure: ((Error) -> Void)? = nil, completion: (() -> Void)? = nil) {
        let scheduler = self.scheduler ?? Scheduler.default
        _cascade { result in
            scheduler {
                switch result {
                case let .success(value): success?(value)
                case let .failure(error): failure?(error)
                }
                completion?()
            }
        }
    }

    /// Attaches a callback that gets called when the future gets resolved
    /// successfully. See `func on(success:failure:completion:)` for more info.
    public func on(success: @escaping (Value) -> Void) {
        // Disambiguates so that `on` with a trailing closure selects a
        // `success` closure, not a `completion`.
        on(success: success, failure: nil, completion: nil)
    }

    func cascade(completion: @escaping (Result) -> Void) {
        if let scheduler = self.scheduler {
            _cascade { result in
                scheduler { completion(result) }
            }
        } else {
            _cascade(completion: completion)
        }
    }

    private func _cascade(completion: @escaping (Result) -> Void) {
        switch resolver {
        case let .promise(promise):
            promise.observe(completion: completion)
        case let .result(result):
            completion(result)
        }
    }

    /// A convenience method which is used for implementing cascades of futures.
    ///
    /// It calls `cascade(completion:)` directly but technically it could be
    /// implemented in terms of public methods without much of a performance hit:
    ///
    ///     future.observe(on: Scheduler.immediate).on(completion: { ... })
    ///
    func cascade(success: @escaping (Value) -> Void, failure: @escaping (Error) -> Void) {
        cascade { result in
            switch result {
            case let .success(value): success(value)
            case let .failure(error): failure(error)
            }
        }
    }

    // MARK: Synchronous Inspection

    /// Returns the value if the future has a value.
    public var value: Value? {
        guard let result = result else { return nil }
        switch result {
        case let .success(value): return value
        case .failure: return nil
        }
    }

    /// Returns the error if the future has an error.
    public var error: Error? {
        guard let result = result else { return nil }
        switch result {
        case .success: return nil
        case let .failure(error): return error
        }
    }

    /// Returns the result if the future completed.
    public var result: Result? {
        switch resolver {
        case let .promise(promise):
            return promise.result
        case let .result(result):
            return result
        }
    }
}

extension Future where Error == Never {
    /// A special variant that doesn't require a `failure` closure -
    /// `Future<Value, Never>` can't produce an error.
    func cascade(success: @escaping (Value) -> Void) {
        cascade(success: success, failure: { _ in fatalError("Future<Value, Never> can't produce an error") })
    }
}

// MARK: - Disambiguate Init

extension Future where Error == Never {
    /// Creates a future with the given value and automatically assigns `Error`
    /// to be `Never`.
    public init(value: Value) {
        self.init(result: .success(value))
    }
}

// MARK: - Map, FlatMap

extension Future {

    /// Returns a future with the result of mapping the given closure over the
    /// current future's value.
    public func map<NewValue>(_ transform: @escaping (Value) -> NewValue) -> Future<NewValue, Error> {
        // Technically the same as `flatMap { Future<NewValue, Error>(value: transform($0) }`
        // but this implementation is optimized for performance.
        let promise = Future<NewValue, Error>.Promise()
        cascade(success: { promise.succeed(value: transform($0)) }, failure: promise.fail)
        return promise.future
    }

    // Allow:
    // Future<T, E>.flatMap { Future<U, E> }
    // Future<T, E>.flatMap { Future<U, Never> }

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
        let promise = Future<NewValue, Error>.Promise()
        cascade(success: { transform($0).cascade(completion: promise.resolve) }, failure: promise.fail)
        return promise.future
    }

    public func flatMap<NewValue>(_ transform: @escaping (Value) -> Future<NewValue, Never>) -> Future<NewValue, Error> {
        // Technically the same as `flatMap { transform($0).castError() }`, but
        // we're doing it from scratch to avoid additional allocations from `castError`
        let promise = Future<NewValue, Error>.Promise()
        cascade(success: { transform($0).cascade(success: promise.succeed) }, failure: promise.fail)
        return promise.future
    }
}

extension Future where Error == Never {
    // Allow:
    // Future<T, Never>.flatMap { Future<U, E> }
    // Future<T, Never>.flatMap { Future<U, Never> } // disambiguate

    public func flatMap<NewValue, NewError>(_ transform: @escaping (Value) -> Future<NewValue, NewError>) -> Future<NewValue, NewError> {
        let promise = Future<NewValue, NewError>.Promise()
        cascade(success: { transform($0).cascade(completion: promise.resolve) })
        return promise.future
    }

    public func flatMap<NewValue>(_ transform: @escaping (Value) -> Future<NewValue, Never>) -> Future<NewValue, Never> {
        let promise = Future<NewValue, Never>.Promise()
        cascade(success: { transform($0).cascade(success: promise.succeed) })
        return promise.future
    }
}

// MARK: - MapError, FlatMapError

extension Future {
    /// Returns a future with the error which is the result of mapping the given
    /// closure over the current future's error.
    public func mapError<NewError>(_ transform: @escaping (Error) -> NewError) -> Future<Value, NewError> {
        let promise = Future<Value, NewError>.Promise()
        cascade(success: promise.succeed, failure: { promise.fail(error: transform($0)) })
        return promise.future
    }

    /// Returns a future which is eventually resolved with the result of the
    /// future returned by the `transform` closure. The `transform` closure is
    /// called when the current future receives an error.
    ///
    /// Allows you to continue the chain of futures by "recovering" from an error
    /// with a new future.
    public func flatMapError<NewError>(_ transform: @escaping (Error) -> Future<Value, NewError>) -> Future<Value, NewError> {
        let promise = Future<Value, NewError>.Promise()
        cascade(success: promise.succeed, failure: { transform($0).cascade(completion: promise.resolve) })
        return promise.future
    }
}

// MARK: - Zip

extension Future where Value == Any, Error == Swift.Error {

    /// Returns a future which succeedes when all the given futures succeed. If
    /// any of the futures fail, the returned future also fails with that error.
    public static func zip<V1, V2, E>(_ f1: Future<V1, E>, _ f2: Future<V2, E>) -> Future<(V1, V2), E> {
        let promise = Future<(V1, V2), E>.Promise()
        func success(value: Any) {
            guard let v1 = f1.value, let v2 = f2.value else { return }
            promise.succeed(value: (v1, v2))
        }
        f1.cascade(success: success, failure: promise.fail)
        f2.cascade(success: success, failure: promise.fail)
        return promise.future
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

extension Future where Value == Any, Error == Swift.Error {

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

// MARK: - Promise

extension Future {

    /// A promise to provide a result later.
    public final class Promise: CustomDebugStringConvertible {
        private var memoizedResult: Result? // nil when pending
        private var inlinedHandler: ((Result) -> Void)?
        private var handlers: [(Result) -> Void]?
        private let lock = NSLock()

        /// Creates a new pending promise.
        public init() {}

        /// Returns a future associated with the promise.
        public var future: Future {
            return Future(resolver: .promise(self))
        }

        /// Sends a value to the associated future.
        public func succeed(value: Value) {
            resolve(result: .success(value))
        }

        /// Sends an error to the associated future.
        public func fail(error: Error) {
            resolve(result: .failure(error))
        }

        /// Sends a result to the associated future.
        public func resolve(result: Result) {
            lock.lock()
            guard self.memoizedResult == nil else {
                lock.unlock(); return // Already resolved
            }
            self.memoizedResult = result
            let inlinedHandler = self.inlinedHandler
            let handlers = self.handlers
            self.inlinedHandler = nil
            self.handlers = nil
            lock.unlock()

            inlinedHandler?(result)
            handlers?.forEach { $0(result) }
        }

        func observe(completion: @escaping (Result) -> Void) {
            lock.lock()
            guard let result = self.memoizedResult else {
                if inlinedHandler == nil {
                    inlinedHandler = completion
                } else {
                    // Create handlers lazily - in some cases they are no needed
                    handlers = handlers ?? []
                    handlers?.append(completion)
                }
                lock.unlock(); return // Still pending, handlers attached
            }
            lock.unlock()

            completion(result)
        }

        /// Returns the result if the future completed.
        var result: Result? {
            lock.lock(); defer { lock.unlock() }
            return memoizedResult
        }

        // MARK: CustomDebugStringConvertible

        public var debugDescription: String {
            lock.lock(); defer { lock.unlock() }
            if let result = self.memoizedResult {
                return "Promise<\(Value.self), \(Error.self)> { .resolved(result: \(result)) }"
            } else {
                let handlerCount = (handlers?.count ?? 0) + (inlinedHandler != nil ? 1 : 0)
                return "Promise<\(Value.self), \(Error.self)> { .pending(handlers: \(handlerCount)) }"
            }
        }
    }
}

/// A convenience typealias to make constructing promises easier.
public typealias Promise<Value, Error: Swift.Error> = Future<Value, Error>.Promise

// MARK: - Scheduler

public typealias ScheduleWork = (_ work: @escaping () -> Void) -> Void

public enum Scheduler {
    /// `Scheduler.main` by default. Change the scheduler to change the default
    /// behavior where callbacks attached via `on` method are always called on
    /// the main thread.
    public static var `default` = Scheduler.main

    /// If the task finishes on the main thread, the callbacks are executed
    /// immediately. Otherwise, they are dispatched to be executed
    /// asynchronously on the main thread.
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

// MARK: - Catching Init

extension Future where Error == Swift.Error {
    /// Creates a future by evaluating the given throwing closure, capturing the
    /// returned value as a success, or any thrown error as a failure.
    public init(catching body: () throws -> Value) {
        self.init(result: Result(catching: body))
    }
}
