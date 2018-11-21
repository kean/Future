// The MIT License (MIT)
//
// Copyright (c) 2016-2018 Alexander Grebenyuk (github.com/kean).

import XCTest
import Foundation
import Future

class FirstTests: XCTestCase {
    func testOne() {
        /// GIVEN a single resolved future
        let future = Future<Int, MyError>(value: 1)

        /// EXPECT first to succeed
        let first = Future.first(future)
        XCTAssertEqual(first.wait().value, 1)
    }

    func testTwo() {
        /// GIVEN two resolved futures
        let f1 = Future<Int, MyError>(value: 1)
        let f2 = Future<Int, MyError>(value: 2)

        /// EXPECT first to succeed
        let first = Future.first(f1, f2)
        XCTAssertEqual(first.wait().value, 1)
    }

    func testEmptyArray() {
        let future = Future<Int, MyError>.first([])
        XCTAssertNil(future.result)

        // EXPECT to never fulfil, but it can be created
    }

    func testTwoSecondFails() {
        let p1 = Promise<Int, MyError>()
        let p2 = Promise<Int, MyError>()

        let first = Future.first(p1.future, p2.future)

        // WHEN the second future fails
        DispatchQueue.global().async {
            p2.fail(error: .e1)
        }

        // EXPECT the "first" future to fail
        let expectation = self.expectation()
        first.on(failure: {
            XCTAssertEqual($0, .e1)
            expectation.fulfill()
        })
        wait()
    }

    func testTwoSecondFailsWait() {
        let p1 = Promise<Int, MyError>()
        let p2 = Promise<Int, MyError>()

        let first = Future.first(p1.future, p2.future)

        // WHEN the second future fails
        DispatchQueue.global().async {
            p2.fail(error: .e1)
        }

        // EXPECT the "first" future to fail
        XCTAssertEqual(first.wait().error, .e1)
    }
}

class AfterTests: XCTestCase {
    func testAfter() {
        let expectation = self.expectation()
        Future.after(seconds: 0.001).on(success: {
            XCTAssertTrue(Thread.isMainThread)
            expectation.fulfill()
        })
        wait()
    }

    func testAfterDispatchTime() {
        let expectation = self.expectation()
        Future.after(.milliseconds(10)).on(success: {
            XCTAssertTrue(Thread.isMainThread)
            expectation.fulfill()
        })
        wait()
    }

    func testAfterAndWait() {
        let after = Future.after(seconds: 0.001, on: .global())
        XCTAssertNotNil(after.wait())
    }
}

class RetryTests: XCTestCase {

    func testDefaultRetry() {
        let retrier = RetryingFuture.failing()

        let future = Future.retry(attempts: 2, delay: .seconds(0.00001), retrier.work)

        let expecation = self.expectation()
        future.on(
            success: { _ in XCTFail() },
            failure: { error in
                XCTAssertEqual(error, .e1)
                expecation.fulfill()
            }
        )

        wait()

        // EXPECT to perform to attempts
        XCTAssertEqual(retrier.attemptsCount, 2)
    }

    // Test that `Future` never dispatches to the main queue internally.
    func testWait() {
        let retrier = RetryingFuture.failing()

        let future = Future.retry(attempts: 2, delay: .seconds(0.00001), retrier.work)

        XCTAssertEqual(future.wait().error, .e1)
    }

    class RetryingFuture {
        var attemptsCount = 0

        typealias Work = () -> Future<Int, MyError>
        enum Attempts {
            case infinite(Work)
            case predefined([Work])
        }
        let attempts: Attempts

        init(attempts: Attempts) {
            self.attempts = attempts
        }

        func work() -> Future<Int, MyError> {
            attemptsCount += 1
            switch attempts {
            case let .infinite(work):
                return work()
            case let .predefined(attempts):
                if attempts.count < attemptsCount {
                    XCTFail()
                    return Promise<Int, MyError>().future
                }
                return attempts[attemptsCount-1]()
            }
        }

        // Factory Methods

        static func infinite(_ work: @escaping Work) -> RetryingFuture {
            return RetryingFuture(attempts: .infinite(work))
        }

        static func failing() -> RetryingFuture {
            return RetryingFuture.infinite {
                Future<Int, MyError>(error: .e1)
            }
        }
    }
}

class TryMapTests: XCTestCase {
    func testTryMap() {
        let future = Future<Int, Swift.Error>(value: 1)

        let result = future.tryMap { _ in
            throw URLError(.unknown)
        }

        XCTAssertEqual(result.error as? URLError, URLError(.unknown))
    }
}

class ForEachTests: XCTestCase {
    func testForEach() {
        let futures: [() -> Future<Int, MyError>] = [
            { Future<Int, MyError>(value: 1) },
            { Future<Int, MyError>(value: 2) }
        ]

        var expected = [1, 2]
        let result = Future.forEach(futures) { future in
            XCTAssertEqual(future.value, expected.first)
            expected.removeFirst()
        }

        XCTAssertNotNil(result.value)
    }

    func testForEachSecondFails() {
        func testForEach() {
            let futures: [() -> Future<Int, MyError>] = [
                { Future<Int, MyError>(value: 1) },
                { Future<Int, MyError>(error: .e1) }
            ]

            var expected: [Future<Int, MyError>.Result] = [.success(1), .failure(.e1)]
            let result = Future.forEach(futures) { future in
                XCTAssertEqual(future.result, expected.first)
                expected.removeFirst()
            }

            XCTAssertEqual(result.error, .e1)
        }
    }
}

class MaterializeTests: XCTestCase {
    func testSuccess() {
        let future = Future<Int, MyError>(value: 1)
        XCTAssertEqual(future.materialize().value?.value, 1)
    }

    func testFailure() {
        let future = Future<Int, MyError>(error: .e1)
        XCTAssertEqual(future.materialize().value?.error, .e1)
    }
}
