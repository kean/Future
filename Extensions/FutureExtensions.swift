// The MIT License (MIT)
//
// Copyright (c) 2016-2018 Alexander Grebenyuk (github.com/kean).

import Pill

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
        let promise = Future<Value, Error>.promise
        for future in futures {
            future.on(scheduler: .immediate, success: promise.succeed, failure: promise.fail)
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
        let promise = Future.promise
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

// MARK: - Materialize

extension Future {
    /// Returns a future that always succeeds with the `Result` which contains
    /// either a success or a failure of the underlying future.
    public func materialize() -> Future<Result, Never> {
        let promise = Future<Result, Never>.promise
        on(scheduler: .immediate, completion: promise.succeed)
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

// MARK: - Ignore Error

extension Future {
    /// Returns a future which never resolves in case the underlying future
    /// fails with an error.
    public func ignoreError() -> Future<Value, Never> {
        return flatMapError { _ in Future<Value, Never>.promise.future }
    }
}
