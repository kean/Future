// The MIT License (MIT)
//
// Copyright (c) 2016-2018 Alexander Grebenyuk (github.com/kean).

import Foundation
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
            future.on(success: promise.succeed, failure: promise.fail)
        }
        return promise.future
    }
}
