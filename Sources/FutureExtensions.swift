// The MIT License (MIT)
//
// Copyright (c) 2016-2018 Alexander Grebenyuk (github.com/kean).

import Foundation

// MARK: - First

extension Future {

    /// Waits for the first future to resolve. If the first future to resolve
    /// fails, the returned future also fails.
    public static func first(_ futures: Future...) -> Future {
        return self.first(futures)
    }

    /// Waits for the first future to resolve. If the first future to resolve
    /// fails, the returned future also fails.
    public static func first(_ futures: [Future]) -> Future {
        let promise = Future.Promise()
        for future in futures {
            future.cascade(completion: promise.resolve)
        }
        return promise.future
    }
}

// MARK: - After

extension Future where Value == Void, Error == Never {

    /// Returns a future which succeeds after a given time interval.
    ///
    /// - parameters:
    ///     - seconds: The time interval after which the future succeeds.
    ///     - queue: The queue on which futures succeeds, `.global` by default.
    public static func after(seconds: TimeInterval, on queue: DispatchQueue = .global()) -> Future<Void, Never> {
        return after(deadline: .now() + seconds, on: queue)
    }

    /// Returns a future which succeeds after a given time interval.
    ///
    /// - parameters:
    ///     - interval: The time interval after which the future succeeds.
    ///     - queue: The queue on which futures succeeds, `.global` by default.
    public static func after(_ interval: DispatchTimeInterval, on queue: DispatchQueue = .global()) -> Future<Void, Never> {
        return after(deadline: .now() + interval, on: queue)
    }

    private static func after(deadline: DispatchTime, on queue: DispatchQueue = .global()) -> Future<Void, Never> {
        let promise = Promise()
        queue.asyncAfter(deadline: deadline, execute: promise.succeed) // Never produces an error
        return promise.future
    }
}

// MARK: - Retry

extension Future {

    public enum Delay {
        case seconds(TimeInterval)
        case exponential(initial: TimeInterval, multiplier: Double, maxDelay: TimeInterval)
        case custom(closure: (Int) -> TimeInterval)

        func delay(attempt: Int) -> TimeInterval {
            switch self {
            case .seconds(let seconds): return seconds
            case .exponential(let initial, let multiplier, let maxDelay):
                // if it's first attempt, simply use initial delay, otherwise calculate delay
                let delay = attempt == 1 ? initial : initial * pow(multiplier, Double(attempt - 1))
                return min(maxDelay, delay)
            case .custom(let closure): return closure(attempt)
            }
        }
    }

    /// Performs the given number of attempts to finish the work successfully.
    ///
    /// - parameters:
    ///     - attempts: The number of attempts to make. Pass `2` to retry once
    ///     the first attempt fails.
    ///     - delay: The delay after which to retry.
    ///     - shouldRetry: Inspects the error to determine if retry is possible.
    ///         By default always returns `true`.
    ///     - work: The work to perform. Make sure to create a new future each
    ///         time the closure is called.
    public static func retry(attempts: Int, delay: Delay, shouldRetry: @escaping (_ error: Error) -> Bool = { _ in true }, _ work: @escaping () -> Future) -> Future {
        assert(attempts > 1, "Invalid number of attempts")
        var attemptsCounter = 0
        func attempt() -> Future {
            attemptsCounter += 1
            return work().flatMapError { error in
                guard attemptsCounter < attempts, shouldRetry(error) else {
                    return Future(error: error)
                }
                let delay = delay.delay(attempt: attemptsCounter)
                return Future<Void, Never>.after(seconds: delay)
                    .castError()
                    .flatMap(attempt)
            }
        }
        return attempt()
    }
}

// MARK: - ForEach

extension Future {

    /// Performs futures sequentially. If one of the future fail, the resulting
    /// future also fails.
    ///
    /// - returns: A future which completes when all of the given futures complete.
    @discardableResult
    public static func forEach(_ futures: [() -> Future], _ subscribe: @escaping (Future) -> Void) -> Future<Void, Error> {
        let initial = Future<Void, Error>(value: ())
        return futures.reduce(initial) { result, next in
            result.flatMap { _ -> Future<Void, Error> in
                let future = next()
                subscribe(future)
                return future.asVoid()
            }
        }
    }
}

// MARK: - Materialize

extension Future {

    /// Returns a future that always succeeds with the `Result` which contains
    /// either a success or a failure of the underlying future.
    public func materialize() -> Future<Result, Never> {
        let promise = Future<Result, Never>.Promise()
        cascade(completion: promise.succeed)
        return promise.future
    }
}

// MARK: - TryMap

extension Future where Error == Swift.Error {

    /// Returns a future with the result of mapping the given closure over the
    /// current future's value. If the `transform` closure throws, the resulting
    /// future also throws.
    public func tryMap<NewValue>(_ transform: @escaping (Value) throws -> NewValue) -> Future<NewValue, Error> {
        // This could be implemented in terms of `flatMap` by to avoid additional
        // allocation and indirection we use `observe` directly.
        //
        //  return flatMap { value in
        //      do { return Future<NewValue, Error>(value: try transform(value)) }
        //      catch { return Future<NewValue, Error>(error: error) }
        // }

        let promise = Future<NewValue, Error>.Promise()
        cascade(success: { value in
            do { promise.succeed(value: try transform(value)) }
            catch { promise.fail(error: error) }
        }, failure: promise.fail)
        return promise.future
    }
}

// MARK: - Cast

extension Future where Error == Never {

    /// Safely casts a `Future<Value, Never>` - which can't produce an
    /// error - to `Future<Value, NewError>` which can. The returned future never
    /// actually produces an error but it makes it easier to compose it with the
    /// ones that can.
    public func castError<NewError>() -> Future<Value, NewError> {
        return mapError { _ in fatalError("Future<Value, Never> can't produce an error") }
    }
}

extension Future {

    /// Casts the future to `Future<Void, Error>`.
    public func asVoid() -> Future<Void, Error> {
        return map { _ in () }
    }
}

// MARK: - Wait

extension Future {

    /// Waits for the future's result. The current thread blocks until the result
    /// is received.
    ///
    /// - note: This methods waits for the completion on the private dispatch
    /// queue so it's safe to call it from any thread. But avoid blocking the
    /// main thread!
    public func wait() -> Result {
        let semaphore = DispatchSemaphore(value: 0)
        observe(on: waitQueue).on(completion: { _
            in semaphore.signal()
        })
        semaphore.wait()
        return result! // Must have result at this point
    }
}

private let waitQueue = DispatchQueue(label:  "com.github.kean.futurex.wait-queue", attributes: .concurrent)
