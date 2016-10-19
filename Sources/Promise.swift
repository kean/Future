// The MIT License (MIT)
//
// Copyright (c) 2016 Alexander Grebenyuk (github.com/kean).

import Foundation

/// A promise is an object that represents an asynchronous task. Use `then()`
/// to get the result of the promise. Use `catch()` to catch errors.
///
/// Promises start in a *pending* state and either get *fulfilled* with a
/// value or get *rejected* with an error.
public final class Promise<T> {
    private var state: State<T> = .pending(Handlers<T>())
    private let lock = NSLock()

    // MARK: Creation

    /// Creates a new, pending promise.
    ///
    /// - parameter value: The provided closure is called immediately on the
    /// current thread. In the closure you should start an asynchronous task and
    /// call either `fulfill` or `reject` when it completes.
    public init(_ closure: (_ fulfill: @escaping (T) -> Void, _ reject: @escaping (Error) -> Void) -> Void) {
        closure({ self.resolve(.fulfilled($0)) }, { self.resolve(.rejected($0)) })
    }

    private func resolve(_ state: State<T>) {
        lock.lock(); defer { lock.unlock() }
        if case let .pending(handlers) = self.state {
            self.state = state
            // Handlers only contain `queue.async` calls which are fast
            // enough for a critical section (no real need to optimize this).
            switch state {
            case let .fulfilled(value): handlers.fulfill.forEach { $0(value) }
            case let .rejected(error): handlers.reject.forEach { $0(error) }
            default: return
            }
        }
    }
    
    /// Creates a promise fulfilled with a given value.
    public init(value: T) { state = .fulfilled(value) }

    /// Creates a promise rejected with a given error.
    public init(error: Error) { state = .rejected(error) }
    
    // MARK: Synchronous Inspection

    public var value: T? { // a bit of ninja coding
        if case let .fulfilled(val) = state { return val } else { return nil }
    }
    
    public var error: Error? {
        if case let .rejected(err) = state { return err } else { return nil }
    }

    // MARK: Callbacks
    
    private func observe(on queue: DispatchQueue, fulfill: @escaping (T) -> Void, reject: @escaping (Error) -> Void) {
        // `fulfill` and `reject` are called asynchronously on `queue`
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
    
    /// Transforms `Promise<T>` to `Promise<U>`.
    ///
    /// - parameter on: A queue on which the closure is run. `.main` by default.
    /// queue by default.
    /// - returns: A promise fulfilled with a value returns by the closure.
    @discardableResult public func then<U>(on queue: DispatchQueue = .main, _ closure: @escaping (T) -> U) -> Promise<U> {
        return _then(on: queue) { value, fulfill, _ in
            fulfill(closure(value))
        }
    }

    /// The provided closure executes asynchronously when the promise fulfills
    /// with a value. Allows you to chain promises.
    ///
    /// - parameter on: A queue on which the closure is run. `.main` by default.
    /// - returns: A promise that resolves with the resolution of the promise
    /// returned by the given closure.
    @discardableResult public func then<U>(on queue: DispatchQueue = .main, _ closure: @escaping (T) -> Promise<U>) -> Promise<U> {
        return _then(on: queue) { value, fulfill, reject in
            closure(value).observe(on: queue, fulfill: fulfill, reject: reject)
        }
    }
    
    /// Returns a new promise.
    /// - when `self` is fufilled the closure is called (you control it)
    /// - when `self` is rejected the promise is rejected
    private func _then<U>(on queue: DispatchQueue, _ closure: @escaping (T, @escaping (U) -> Void, @escaping (Error) -> Void) -> Void) -> Promise<U> {
        return Promise<U>() { fulfill, reject in
            observe(on: queue, fulfill: { closure($0, fulfill, reject) }, reject: reject)
        }
    }

    // MARK: Catch

    /// The provided closure executes asynchronously when the promise is
    /// rejected with an error.
    ///
    /// A promise bubbles up errors. It allows you to catch all errors returned
    /// by a chain of promises with a single `catch()`.
    ///
    /// - parameter on: A queue on which the closure is run. `.main` by default.
    @discardableResult public func `catch`(on queue: DispatchQueue = .main, _ closure: @escaping (Error) -> Void) -> Promise<T> {
        return _catch(on: queue) { error, _, reject in
            closure(error)
            reject(error)
        }
    }

    /// Unlike `catch` `recover` allows you to continue the chain of promises
    /// by recovering from the error by creating a new promise.
    ///
    /// - parameter on: A queue on which the closure is run. `.main` by default.
    @discardableResult public func recover(on queue: DispatchQueue = .main, _ closure: @escaping (Error) -> Promise<T>) -> Promise<T> {
        return _catch(on: queue) { error, fulfill, reject in
            closure(error).observe(on: queue, fulfill: fulfill, reject: reject)
        }
    }
    
    /// Returns a new promise.
    /// - when `self` is fufilled the promise is fulfilled
    /// - when `self` is rejected the closure is called (you control it)
    private func _catch(on queue: DispatchQueue, _ closure: @escaping (Error, @escaping (T) -> Void, @escaping (Error) -> Void) -> Void) -> Promise<T> {
        return Promise<T>() { fulfill, reject in
            observe(on: queue, fulfill: fulfill, reject: { closure($0, fulfill, reject) })
        }
    }
    
    // MARK: Finally
    
    @discardableResult public func finally(on queue: DispatchQueue = .main, _ closure: @escaping (Void) -> Void) -> Promise<T> {
        observe(on: queue, fulfill: { _ in closure() }, reject: { _ in closure() })
        return self
    }
}

private final class Handlers<T> { // boxed handlers
    var fulfill = [(T) -> Void]()
    var reject = [(Error) -> Void]()
}

private enum State<T> {
    case pending(Handlers<T>), fulfilled(T), rejected(Error)
}
