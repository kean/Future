// The MIT License (MIT)
//
// Copyright (c) 2017-2018 Alexander Grebenyuk (github.com/kean).

import XCTest
import Foundation
import Pill

class FutureTests: XCTestCase {

    // MARK: - Observe On

    func testObserveOnMainThreadByDefault() {
        // GIVEN the default promise
        let future = Future<Int, MyError>(value: 1)

        // EXPECT maps to be called on main queue
        _ = future.map { _ -> Int in
            XCTAssertTrue(Thread.isMainThread)
            return 2
        }

        // EXPECT on(...) to be called on the main queue
        future.on(
            value: { _ in
                XCTAssertTrue(Thread.isMainThread)
            },
            error: { _ in
                XCTAssertTrue(Thread.isMainThread)
            },
            completed: {
                XCTAssertTrue(Thread.isMainThread)
            }
        )
    }

    func testObserveOn() {
        // GIVEN the promise with a a custom observe queue
        let future = Future<Int, MyError>(value: 1)
            .observeOn(DispatchQueue.global())

        // EXPECT maps to be called on global queue
        _ = future.map { _ -> Int in
            XCTAssertFalse(Thread.isMainThread)
            return 2
        }

        // EXPECT on(...) to be called on the global queue
        future.on(
            value: { _ in
                XCTAssertFalse(Thread.isMainThread)
            },
            error: { _ in
                XCTAssertFalse(Thread.isMainThread)
            },
            completed: {
                XCTAssertFalse(Thread.isMainThread)
            }
        )
    }

    func testObserveOnFlatMap() {
        // GIVEN the promise with a a custom observe queue
        let future = Future<Int, MyError>(value: 1)
            .observeOn(DispatchQueue.global())
            .flatMap { value in
                return Future(value: value + 1)
            }

        // EXPECT maps to be called on global queue
        _ = future.map { _ -> Int in
            XCTAssertFalse(Thread.isMainThread)
            return 2
        }

        // EXPECT on(...) to be called on the global queue
        future.on(
            value: { _ in
                XCTAssertFalse(Thread.isMainThread)
            },
            error: { _ in
                XCTAssertFalse(Thread.isMainThread)
            },
            completed: {
                XCTAssertFalse(Thread.isMainThread)
            }
        )
    }
}
