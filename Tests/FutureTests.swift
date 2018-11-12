// The MIT License (MIT)
//
// Copyright (c) 2016-2018 Alexander Grebenyuk (github.com/kean).

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
        let expectation = self.expectation()
        future.on(
            success: { _ in
                XCTAssertTrue(Thread.isMainThread)
            },
            failure: { _ in
                XCTAssertTrue(Thread.isMainThread)
            },
            completion: {
                XCTAssertTrue(Thread.isMainThread)
                expectation.fulfill()
            }
        )
        wait()
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
        let expectation = self.expectation()
        future.on(
            success: { _ in
                XCTAssertFalse(Thread.isMainThread)
            },
            failure: { _ in
                XCTAssertFalse(Thread.isMainThread)
            },
            completion: {
                XCTAssertFalse(Thread.isMainThread)
                expectation.fulfill()
            }
        )
        wait()
    }

    func testObserveOnFlatMap() {
        // GIVEN a future with a a custom observe queue
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
        let expectation = self.expectation()
        future.on(
            success: { _ in
                XCTAssertFalse(Thread.isMainThread)
            },
            failure: { _ in
                XCTAssertFalse(Thread.isMainThread)
            },
            completion: {
                XCTAssertFalse(Thread.isMainThread)
                expectation.fulfill()
            }
        )
        wait()
    }

    func testObserveOnTheSameQueue() {
        let future = Future<Int, MyError>(value: 1)

        // WHEN calling observeOn
        let new = future.observeOn(DispatchQueue.main)

        // EXPECT on(...) to be called on the global queue
        let expectation = self.expectation()
        new.on(
            success: { _ in
                XCTAssertTrue(Thread.isMainThread)
            },
            completion: {
                XCTAssertTrue(Thread.isMainThread)
                expectation.fulfill()
            }
        )
        wait()
    }

    // MARK: Synchronous Inspection

    func testSynchronousInspectionPending() {
        // GIVEN a pending promise
        let promise = Promise<Int, MyError>()
        let future = promise.future

        // EXPECT future to be pending
        XCTAssertTrue(future.isPending)
        XCTAssertNil(future.value)
        XCTAssertNil(future.error)
    }

    func testSynchronousInspectionSuccess() {
        // GIVEN successful future
        let future = Future<Int, MyError>(value: 1)

        // EXPECT future to return value
        XCTAssertFalse(future.isPending)
        XCTAssertEqual(future.value, 1)
        XCTAssertNil(future.error)
    }

    func testSynchronousInspectionFailure() {
        // GIVEN failed future
        let future = Future<Int, MyError>(error: .e1)

        // EXPECT future to return value
        XCTAssertFalse(future.isPending)
        XCTAssertNil(future.value)
        XCTAssertEqual(future.error, .e1)
    }
}

class MapErrorTest: XCTestCase {
    func testMapError() {
        // GIVEN failed future
        let future = Future<Int, MyError>(error: .e1)

        // WHEN mapping error
        let mapped = future.mapError { _ in
            return "e1"
        }

        // EXPECT mapped future to return a new error
        let expectation = self.expectation()
        mapped.on(failure: { error in
            XCTAssertEqual(mapped.error, "e1")
            expectation.fulfill()
        })

        wait()
    }
}

class Zip2Tests: XCTestCase {
    // MARK: Zip (Tuple)

    func testBothSucceed() {
        let (promises, futures) = setUpFutures()

        // WHEN zipping two futures
        let result = Future.zip(futures.0, futures.1)

        // EXPECT "zipped" future to succeed
        let expectation = self.expectation()
        result.on(
            success: { v1, v2 in
                XCTAssertEqual(v1, 1)
                XCTAssertEqual(v2, 2)
                expectation.fulfill()
            },
            failure: { _ in
                XCTFail()
            }
        )

        // WHEN first both succeed
        promises.0.succeed(value: 1)
        DispatchQueue.global().async {
            promises.1.succeed(value: 2)
        }

        wait()
    }

    func testFirstFails() {
        let (promises, futures) = setUpFutures()

        // WHEN zipping two futures
        let result = Future.zip(futures.0, futures.1)

        // EXPECT "zipped" future to fail
        let expectation = self.expectation()
        result.on(
            success: { _ in
                XCTFail()
            },
            failure: { error in
                XCTAssertEqual(.e1, error)
                expectation.fulfill()
            }
        )

        // WHEN first succeed, second fails
        promises.0.succeed(value: 1)
        promises.1.fail(error: .e1)

        wait()
    }

    func testSecondFails() {
        let (promises, futures) = setUpFutures()

        // WHEN zipping two futures
        let result = Future.zip(futures.0, futures.1)

        // EXPECT "zipped" future to fail
        let expectation = self.expectation()
        result.on(
            success: { _ in
                XCTFail()
            },
            failure: { error in
                XCTAssertEqual(.e1, error)
                expectation.fulfill()
            }
        )

        // WHEN first succeed, second fails
        promises.1.succeed(value: 1)
        promises.0.fail(error: .e1)

        wait()
    }
}

class Zip3Tests: XCTestCase {
    func testAllSucceed() {
        let (promises, futures) = setUpFutures()

        // WHEN zipping two futures
        let result = Future.zip(futures.0, futures.1, futures.2)

        // EXPECT "zipped" future to succeed
        let expectation = self.expectation()
        result.on(
            success: { v1, v2, v3 in
                XCTAssertEqual(v1, 1)
                XCTAssertEqual(v2, 2)
                XCTAssertEqual(v3, 3)
                expectation.fulfill()
            },
            failure: { _ in
                XCTFail()
            }
        )

        // WHEN all succeed
        promises.0.succeed(value: 1)
        DispatchQueue.global().async {
            promises.2.succeed(value: 3)
        }
        DispatchQueue.global().async {
            promises.1.succeed(value: 2)
        }

        wait()
    }

    func testThirdFails() {
        let (promises, futures) = setUpFutures()

        // WHEN zipping two futures
        let result = Future.zip(futures.0, futures.1, futures.2)

        // EXPECT "zipped" future to fail
        let expectation = self.expectation()
        result.on(
            success: { _ in
                XCTFail()
            },
            failure: { error in
                XCTAssertEqual(.e1, error)
                expectation.fulfill()
            }
        )

        // WHEN first succeed, second fails
        promises.0.succeed(value: 1)
        promises.1.succeed(value: 2)
        promises.2.fail(error: .e1)

        wait()
    }
}

class ZipIntoArrayTests: XCTestCase {
    func testBothSucceed() {
        let (promises, futures) = setUpFutures()

        // GIVEN array of three zipped futures
        let result = Future.zip([futures.0, futures.1, futures.2])

        // EXPECT "zipped" future to succeed
        let expectation = self.expectation()
        result.on(
            success: { value in
                XCTAssertTrue(value == [1, 2, 3])
                expectation.fulfill()
            },
            failure: { _ in
                XCTFail()
            }
        )

        // WHEN all futures succeed
        promises.0.succeed(value: 1)
        DispatchQueue.global().async {
            promises.2.succeed(value: 3)
        }
        DispatchQueue.global().async {
            promises.1.succeed(value: 2)
        }

        wait()
    }

    func testFailsImmediatellyIfThirdFails() {
        let (promises, futures) = setUpFutures()

        // GIVEN array of three zipped futures
        let result = Future.zip([futures.0, futures.1, futures.2])

        // EXPECT the resulting future to fail
        let expectation = self.expectation()
        result.on(failure: { error in
            XCTAssertEqual(error, .e1)
            expectation.fulfill()
        })

        // WHEN third future fails
        promises.2.fail(error: .e1)

        wait()
    }
}

class ReduceTests: XCTestCase {
    func testBothSucceed() {
        let (promises, futures) = setUpFutures()

        // WHEN reducing two futures
        let result = Future.reduce(0, [futures.0, futures.1], +)

        // EXPECT reduce to combine the results of all futures
        let expectation = self.expectation()

        result.on(success: { value in
            XCTAssertEqual(value, 3)
            expectation.fulfill()
        })

        // WHEN both succeed
        promises.0.succeed(value: 1)
        promises.1.succeed(value: 2)

        wait()
    }

    func testFirstFails() {
        let (promises, futures) = setUpFutures()

        // WHEN reducing two futures
        let result = Future.reduce(0, [futures.0, futures.1], +)

        // EXPECT the resuling future to fail
        let expectation = self.expectation()
        result.on(failure: { error in
            XCTAssertEqual(error, .e1)
            expectation.fulfill()
        })

        // WHEN first fails
        promises.1.succeed(value: 1)
        promises.0.fail(error: .e1)

        wait()
    }

    func testSecondFails() {
        let (promises, futures) = setUpFutures()

        // WHEN reducing two futures
        let result = Future.reduce(0, [futures.0, futures.1], +)

        // EXPECT the resuling future to fail
        let expectation = self.expectation()
        result.on(failure: { error in
            XCTAssertEqual(error, .e1)
            expectation.fulfill()
        })

        // WHEN second fails
        promises.0.succeed(value: 1)
        promises.1.fail(error: .e1)

        wait()
    }
}

private typealias P = Promise<Int, MyError>
private typealias F = Future<Int, MyError>

private func setUpFutures() -> (promises: (P, P, P), futures: (F, F, F)) {
    let promises = (P(), P(), P())
    let futures = (promises.0.future, promises.1.future, promises.2.future)
    return (promises, futures)
}
