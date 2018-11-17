// The MIT License (MIT)
//
// Copyright (c) 2016-2018 Alexander Grebenyuk (github.com/kean).

import XCTest
import Foundation
import Pill
import PillExtensions

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
        let p1 = Future<Int, MyError>.promise
        let p2 = Future<Int, MyError>.promise

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
        let p1 = Future<Int, MyError>.promise
        let p2 = Future<Int, MyError>.promise

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

    func testAfterCompletesOnMainQueueByDefault() {
        let expectation = self.expectation()
        // WHEN no passing a custom queue
        Future.after(seconds: 0.001).on(scheduler: .immediate, success: {
            XCTAssertTrue(Thread.isMainThread)
            expectation.fulfill()
        })
        wait()
    }

    func testAfterCompletesOnGivenQueue() {
        let expectation = self.expectation()
        // WHEN setting a custom queue
        Future.after(seconds: 0.001, on: .global()).on(scheduler: .immediate, success: {
            XCTAssertFalse(Thread.isMainThread)
            expectation.fulfill()
        })
        wait()
    }

    func testAfterAndWait() {
        let after = Future.after(seconds: 0.001, on: .global())
        XCTAssertNotNil(after.wait())
    }
}
