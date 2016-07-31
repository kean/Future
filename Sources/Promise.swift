// The MIT License (MIT)
//
// Copyright (c) 2016 Alexander Grebenyuk (github.com/kean).

import Foundation

public class Promise<T> {
    private var state: State<T> = .pending(Handlers<T>())
    private var queue = DispatchQueue(label: "com.github.kean.Promise")
    
    public init(_ closure: @noescape (fulfill: (value: T) -> Void, reject: (error: ErrorProtocol) -> Void) -> Void) {
        closure(fulfill: { self.resolve(resolution: .fulfilled($0)) },
                reject: { self.resolve(resolution: .rejected($0)) })
    }
    
    public init(value: T) {
        state = .resolved(.fulfilled(value))
    }
    
    public init(error: ErrorProtocol) {
        state = .resolved(.rejected(error))
    }
    
    private func resolve(resolution: Resolution<T>) {
        queue.async {
            if case let .pending(handlers) = self.state {
                self.state = .resolved(resolution)
                handlers.objects.forEach { $0(resolution) }
            }
        }
    }
    
    public func completion(on queue: DispatchQueue = .main, _ closure: (resolution: Resolution<T>) -> Void) {
        let completion: (resolution: Resolution<T>) -> Void = { resolution in
            queue.async { closure(resolution: resolution) }
        }
        queue.async {
            switch self.state {
            case let .pending(handlers): handlers.objects.append(completion)
            case let .resolved(resolution): completion(resolution: resolution)
            }
        }
    }
}

public extension Promise {
    public func then(_ closure: (value: T) -> Void) -> Promise {
        return then(fulfilment: closure, rejection: nil)
    }
    
    public func then<U>(_ closure: (value: T) -> U) -> Promise<U> {
        return then { Promise<U>(value: closure(value: $0)) }
    }
    
    public func then<U>(_ closure: (value: T) -> Promise<U>) -> Promise<U> {
        return Promise<U>() { fulfill, reject in
            _ = then(
                fulfilment: {
                    _ = closure(value: $0).then(
                        fulfilment: { fulfill(value: $0) },
                        rejection: { reject(error: $0) })
                },
                rejection: { _ = reject(error: $0) }) // bubble up error
        }
    }
    
    public func `catch`(_ closure: (error: ErrorProtocol) -> Void) -> Promise {
        return then(fulfilment: nil, rejection: closure)
    }
    
    public func recover(_ closure: (error: ErrorProtocol) -> Promise) -> Promise {
        return Promise() { fulfill, reject in
            _ = then(
                fulfilment: { _ = fulfill(value: $0) }, // bubble up value
                rejection: {
                    _ = closure(error: $0).then(
                        fulfilment: { fulfill(value: $0) },
                        rejection: { reject(error: $0) })
            })
        }
    }
    
    public func then(fulfilment: ((value: T) -> Void)?, rejection: ((error: ErrorProtocol) -> Void)?) -> Promise {
        completion { resolution in
            switch resolution {
            case let .fulfilled(val): fulfilment?(value: val)
            case let .rejected(err): rejection?(error: err)
            }
        }
        return self
    }
}

// FIXME: make nested type when compiler adds support for it
private final class Handlers<T> {
    var objects = [(Resolution<T>) -> Void]()
}

private enum State<T> {
    case pending(Handlers<T>), resolved(Resolution<T>)
}

public enum Resolution<T> {
    case fulfilled(T), rejected(ErrorProtocol)
}
