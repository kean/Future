// The MIT License (MIT)
//
// Copyright (c) 2016-2018 Alexander Grebenyuk (github.com/kean).

import XCTest
import Foundation
import Future

class PromisePerformanceTests: XCTestCase {

    // MARK: - Init

    func testInit() {
        measure {
            for _ in 0..<100_000 {
                let _ = Future<Int, Void> { _ in
                    return // do nothing
                }
            }
        }
    }

    func testInitWithValue() {
        measure {
            for _ in 0..<100_000 {
                let _ = Future(value: 1)
            }
        }
    }

    func testInitWithError() {
        measure {
            for _ in 0..<100_000 {
                let _ = Future<Int, MyError>(error: .e1)
            }
        }
    }

    // MARK: - Attach Callbacks

    func testOnValue() {
        let futures = (0..<50_000).map { _ in Future(value: 1) }

        measure {
            for future in futures {
                future.on(success: { _ in
                    return // do nothing
                })
            }
        }
    }

    func testFulfill() {
        let items = (0..<100_000).map { _ in Promise<Int, Void>() }

        let expectation = self.expectation()
        var finished = 0

        for item in items {
            item.future.on(success: { _ in
                finished += 1
                if finished == items.count {
                    expectation.fulfill()
                }

                return // do nothing
            })
        }

        measure {
            for item in items {
                item.succeed(value: 1)
            }
        }

        wait() // wait so that next test aren't affecteds
    }

    func testAttachingCallbacksToResolvedFuture() {
        let futures = Array(0..<10000).map { _ in
            return Future(value: 1)
        }

        measure {
            for future in futures {
                future.on(success: { _ in })
            }
        }
    }

    // MARK: - Fulfilling From Multiple Threads

    func testResolveFromMultipleThreads() {
        let promises = Array(0..<10).map { _ in
            Array(0..<10000).map { _ in
                Promise<Int, Never>()
            }
        }

        measure {
            DispatchQueue.concurrentPerform(iterations: 10) { iteration in
                for promise in promises[iteration] {
                    promise.succeed(value: 1)
                }
            }
        }
    }

    // MARK: - How Long the Whole Chain Takes

    func testChain() {
        measure {
            var remaining = 5000
            let expecation = self.expectation()
            for _ in 0..<5000 {
                let future = Future<Int, Void>(value: 1)
                    .map { $0 + 1 }
                    .flatMap { Future<Int, Void>(value: $0 + 1) }
                    .mapError { $0 }

                future.on(success: { _ in
                    remaining -= 1
                    if remaining == 0 {
                        expecation.fulfill()
                    }
                })
            }
            wait()
        }
    }

    func testZip() {
        measure {
            var remaining = 5000
            let expecation = self.expectation()
            for _ in 0..<5000 {
                let future = Future.zip([
                    Future<Int, Void>(value: 1),
                    Future<Int, Void>(value: 2),
                    Future<Int, Void>(value: 4)]
                )

                future.on(success: { _ in
                    remaining -= 1
                    if remaining == 0 {
                        expecation.fulfill()
                    }
                })
            }
            wait()
        }
    }
}

class FutureOperatorsPerformanceTests: XCTestCase {
    func testMap() {
        let futures = Array(0..<10000).map { _ in
            Future(value: 1)
        }

        measure {
            for future in futures {
                let _ = future.map { $0 + 1}
            }
        }
    }
}
