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
    ///     - queue: The queue on which futures succeeds, `.main` by default.
    public static func after(seconds: TimeInterval, on queue: DispatchQueue = .main) -> Future<Void, Never> {
        return after(deadline: .now() + seconds, on: queue)
    }

    /// Returns a future which succeeds after a given time interval.
    ///
    /// - parameters:
    ///     - interval: The time interval after which the future succeeds.
    ///     - queue: The queue on which futures succeeds, `.main` by default.
    public static func after(_ interval: DispatchTimeInterval, on queue: DispatchQueue = .main) -> Future<Void, Never> {
        return after(deadline: .now() + interval, on: queue)
    }

    private static func after(deadline: DispatchTime, on queue: DispatchQueue = .main) -> Future<Void, Never> {
        let promise = Future.promise
        queue.asyncAfter(deadline: deadline, execute: promise.succeed) // Never produces an error
        return promise.future
    }
}
