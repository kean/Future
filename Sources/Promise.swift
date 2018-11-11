// The MIT License (MIT)
//
// Copyright (c) 2017-2018 Alexander Grebenyuk (github.com/kean).

import Foundation

/// A promise represents a value which may be available now, or in the future,
/// or never. Use `then()` to get the result of the promise. Use `catch()`
/// to catch errors.
///
/// Promises start in a *pending* state and either get *fulfilled* with a
/// value or get *rejected* with an error.
public final class Promise<T> {
    private var state: State = .pending
    private var handlers: Handlers? // nil when finished

    // MARK: Creation

    /// Creates a new, pending promise.
    ///
    /// - parameter closure: The closure is called immediately on the current
    /// thread. You should start an asynchronous task and call either `fulfill`
    /// or `reject` when it completes.
    public init(_ closure: (_ fulfill: @escaping (T) -> Void, _ reject: @escaping (Error) -> Void) -> Void) {
        handlers = Handlers()
        closure({ self._fulfill($0) }, { self._reject($0) }) // retain self
    }
    
    private func _fulfill(_ value: T) {
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
        let handlers = self.handlers! // handlers can't be nil at this point
        switch newState {
        case .pending: break // wait till promise is resovled
        case let .fulfilled(value): handlers.fulfill.forEach { $0(value) }
        case let .rejected(error): handlers.reject.forEach { $0(error) }
        }
        self.handlers = nil
    }

    /// Creates a promise fulfilled with a given value.
    public init(value: T) {
        state = .fulfilled(value)
    }

    /// Creates a promise rejected with a given error.
    public init(error: Error) {
        state = .rejected(error)
    }

    // MARK: Callbacks
    
    private func _observe(on queue: DispatchQueue, fulfill: @escaping (T) -> Void, reject: @escaping (Error) -> Void) {
        _register(fulfill: { value in queue.async { fulfill(value) } },
                  reject: { error in queue.async { reject(error) } })
    }

    /// Registers observers if pending. Returns state at the time or registration.
    private func _register(fulfill: @escaping (T) -> Void, reject: @escaping (Error) -> Void) {
        lock.lock(); defer { lock.unlock() }
        switch state {
        case .pending:
            handlers?.fulfill.append(fulfill)
            handlers?.reject.append(reject)
        case let .fulfilled(value): fulfill(value)
        case let .rejected(error): reject(error)
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
    public var isPending: Bool {
        lock.lock(); defer { lock.unlock() }
        guard case .pending = state else { return false }
        return true
    }

    /// Returns the `value` which promise was `fulfilled` with.
    public var value: T? {
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
        case fulfilled(T)
        case rejected(Error)
    }

    private struct Handlers {
        var fulfill = [(T) -> Void]()
        var reject = [(Error) -> Void]()
    }
}

// Using the same lock across instances is safe because Promise doesn't invoke
// any client code directly, it always does so after asynchronously dispatching
// the work to the provided dispatch queue.
private let lock = NSLock()
