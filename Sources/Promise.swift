// The MIT License (MIT)
//
// Copyright (c) 2017 Alexander Grebenyuk (github.com/kean).

import Foundation

/// A promise represents a value which may be available now, or in the future,
/// or never. Use `then()` to get the result of the promise. Use `catch()`
/// to catch errors.
///
/// Promises start in a *pending* state and either get *fulfilled* with a
/// value or get *rejected* with an error.
public final class Promise<T> {
    private var state: State = .pending(Handlers())
    private let lock = NSLock()

    // MARK: Creation

    /// Creates a new, pending promise.
    ///
    /// - parameter closure: The closure is called immediately on the current
    /// thread. You should start an asynchronous task and call either `fulfill`
    /// or `reject` when it completes.
    public init(_ closure: (_ fulfill: @escaping (T) -> Void, _ reject: @escaping (Error) -> Void) -> Void) {
        closure({ self._fulfill($0) }, { self._reject($0) })
    }
    
    private func _fulfill(_ value: T) {
        _resolve { handlers in
            state = .fulfilled(value)
            // Handlers only contain `queue.async` calls which are fast
            // enough for a critical section (no real need to optimize this).
            handlers.fulfill.forEach { $0(value) }
        }
    }
    
    private func _reject(_ error: Error) {
        _resolve { handlers in
            state = .rejected(error)
            handlers.reject.forEach { $0(error) }
        }
    }
    
    private func _resolve(_ closure: (Handlers) -> Void) {
        lock.lock(); defer { lock.unlock() }
        if case let .pending(handlers) = state { closure(handlers) }
    }
    
    /// Creates a promise fulfilled with a given value.
    public init(value: T) { state = .fulfilled(value) }

    /// Creates a promise rejected with a given error.
    public init(error: Error) { state = .rejected(error) }

    // MARK: Callbacks
    
    private func _observe(on queue: DispatchQueue, fulfill: @escaping (T) -> Void, reject: @escaping (Error) -> Void) {
        // `fulfill` and `reject` are called asynchronously on the `queue`
        let _fulfill: (T) -> Void = { value in queue.async { fulfill(value) } }
        let _reject: (Error) -> Void = { error in queue.async { reject(error) } }
        
        lock.lock(); defer { lock.unlock() }
        switch state {
        case let .pending(handlers):
            handlers.fulfill.append(_fulfill)
            handlers.reject.append(_reject)
        case let .fulfilled(value): _fulfill(value)
        case let .rejected(error): _reject(error)
        }
    }
    
    // MARK: Then
    
    /// The given closure executes asynchronously when the promise is fulfilled.
    ///
    /// - parameter on: A queue on which the closure is run. `.main` by default.
    /// - returns: A promise fulfilled with a value returned by the closure.
    @discardableResult public func then<U>(on queue: DispatchQueue = .main, _ closure: @escaping (T) throws -> U) -> Promise<U> {
        return _then(on: queue) { value, fulfill, _ in
            fulfill(try closure(value))
        }
    }

    /// The given closure executes asynchronously when the promise is fulfilled.
    ///
    /// - parameter on: A queue on which the closure is run. `.main` by default.
    /// - returns: A promise that resolves by the promise returned by the closure.
    @discardableResult public func then<U>(on queue: DispatchQueue = .main, _ closure: @escaping (T) throws -> Promise<U>) -> Promise<U> {
        return _then(on: queue) { value, fulfill, reject in
            try closure(value)._observe(on: queue, fulfill: fulfill, reject: reject)
        }
    }
    
    /// Returns a new promise.
    /// - when `self` is fufilled the closure is called (you control it)
    /// - when `self` is rejected the promise is rejected
    private func _then<U>(on queue: DispatchQueue, _ closure: @escaping (T, @escaping (U) -> Void, @escaping (Error) -> Void) throws -> Void) -> Promise<U> {
        return Promise<U>() { fulfill, reject in
            _observe(on: queue, fulfill: {
                do { try closure($0, fulfill, reject) } catch { reject(error) }
            }, reject: reject)
        }
    }

    // MARK: Catch

    /// The given closure executes asynchronously when the promise is rejected.
    ///
    /// A promise bubbles up errors. It allows you to catch all errors returned
    /// by a chain of promises with a single `catch()`.
    ///
    /// - parameter on: A queue on which the closure is run. `.main` by default.
    @discardableResult public func `catch`(on queue: DispatchQueue = .main, _ closure: @escaping (Error) throws -> Void) -> Promise<T> {
        return _catch(on: queue) { error, _, reject in
            try closure(error)
            reject(error) // If closure doesn't throw, bubble previous error up
        }
    }

    /// Unlike `catch` `recover` allows you to continue the chain of promises
    /// by recovering from the error by returning a new value.
    ///
    /// - parameter on: A queue on which the closure is run. `.main` by default.
    /// - returns: A promise fulfilled with a value returned by the closure.
    @discardableResult public func recover(on queue: DispatchQueue = .main, _ closure: @escaping (Error) throws -> T) -> Promise<T> {
        return _catch(on: queue) { error, fulfill, _ in
            fulfill(try closure(error))
        }
    }
    
    /// Unlike `catch` `recover` allows you to continue the chain of promises
    /// by recovering from the error by creating a new promise.
    ///
    /// - parameter on: A queue on which the closure is run. `.main` by default.
    /// - returns: A promise that resolves by the promise returned by the closure.
    @discardableResult public func recover(on queue: DispatchQueue = .main, _ closure: @escaping (Error) throws -> Promise<T>) -> Promise<T> {
        return _catch(on: queue) { error, fulfill, reject in
            try closure(error)._observe(on: queue, fulfill: fulfill, reject: reject)
        }
    }
    
    /// Returns a new promise.
    /// - when `self` is fufilled the promise is fulfilled
    /// - when `self` is rejected the closure is called (you control it)
    private func _catch(on queue: DispatchQueue, _ closure: @escaping (Error, @escaping (T) -> Void, @escaping (Error) -> Void) throws -> Void) -> Promise<T> {
        return Promise<T>() { fulfill, reject in
            _observe(on: queue, fulfill: fulfill, reject: {
                do { try closure($0, fulfill, reject) } catch { reject(error) }
            })
        }
    }
    
    // MARK: Finally
    
    /// The provided closure executes asynchronously when the promise is
    /// either fulfilled or rejected. Returns `self`.
    ///
    /// - parameter on: A queue on which the closure is run. `.main` by default.
    @discardableResult public func finally(on queue: DispatchQueue = .main, _ closure: @escaping () -> Void) -> Promise<T> {
        _observe(on: queue, fulfill: { _ in closure() }, reject: { _ in closure() })
        return self
    }
    
    // MARK: Synchronous Inspection
    
    /// Returns `true` the promise hasn't resolved yet.
    public var isPending: Bool { if case .pending(_) = _state { return true } else { return false } }
    
    /// Returns the `value` which promise was `fulfilled` with.
    public var value: T? { if case let .fulfilled(val) = _state { return val } else { return nil } }
    
    /// Returns the `error` which promise was `rejected` with.
    public var error: Error? { if case let .rejected(err) = _state { return err } else { return nil } }
    
    private var _state: State {
        lock.lock(); defer { lock.unlock() }
        return state
    }

    /// MARK: Helpers

    private final class Handlers { // boxed handlers
        var fulfill = [(T) -> Void]()
        var reject = [(Error) -> Void]()
    }

    private enum State {
        case pending(Handlers), fulfilled(T), rejected(Error)
    }
}
