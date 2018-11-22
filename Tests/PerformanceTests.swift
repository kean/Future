// The MIT License (MIT)
//
// Copyright (c) 2016-2018 Alexander Grebenyuk (github.com/kean).

import XCTest
import Foundation
import Future

class FutureInitializationTests: XCTestCase {

    func testInitPending() {
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
}

class FutureCallbacksTests: XCTestCase {

    func testAttachCallbacksToResolved() {
        let futures = (0..<50_000).map { _ in Future(value: 1) }

        measure {
            for future in futures {
                future.on(success: { _ in },
                          failure: { _ in },
                          completion: { _ in })
            }
        }
    }

    func testAttachCallbacksToResolvedConcurrently() {
        let futures = Array(0..<10).map { _ in
            Array(0..<10000).map { _ in
                Future(value: 1)
            }
        }

        measure {
            DispatchQueue.concurrentPerform(iterations: 10) { iteration in
                for future in futures[iteration] {
                    future.on(success: { _ in },
                              failure: { _ in },
                              completion: { _ in })
                }
            }
        }
    }

    func testAttachCallbacksToPending() {
        let futures = (0..<50_000).map { _ in Promise<Int, Never>().future }

        measure {
            for future in futures {
                future.on(success: { _ in },
                          failure: { _ in },
                          completion: { _ in })
            }
        }
    }

    func testAttachCallbacksToPendingTwoTimes() {
        let futures = (0..<50_000).map { _ in Promise<Int, Never>().future }

        measure {
            for future in futures {
                future.on(success: { _ in },
                          failure: { _ in },
                          completion: { _ in })

                future.on(success: { _ in },
                          failure: { _ in },
                          completion: { _ in })
            }
        }
    }

    func testAttachCallbacksToPendingConcurrently() {
        let futures = Array(0..<10).map { _ in
            Array(0..<10000).map { _ in
                Promise<Int, Never>().future
            }
        }

        measure {
            DispatchQueue.concurrentPerform(iterations: 10) { iteration in
                for future in futures[iteration] {
                    future.on(success: { _ in },
                              failure: { _ in },
                              completion: { _ in })
                }
            }
        }
    }
}

class PromiseResolveTests: XCTestCase {

    func testSucceedWithOneCallback() {
        let items = (0..<100_000).map { _ in Promise<Int, Void>() }

        for item in items {
            item.future.on(success: { _ in })
        }

        measure {
            for item in items {
                item.succeed(value: 1)
            }
        }
    }

    func testSucceedWithTwoCallback() {
        let items = (0..<100_000).map { _ in Promise<Int, Void>() }

        for item in items {
            item.future.on(success: { _ in })
            item.future.on(success: { _ in })
        }

        measure {
            for item in items {
                item.succeed(value: 1)
            }
        }
    }

    func testSucceedFromMultipleThreads() {
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
}

class FutureChainsTests: XCTestCase {
    // Test how fast the whole chains take

    func testChain_Map_FlatMap_MapError() {
        measure {
            let expecation = self.expectation()
            expecation.expectedFulfillmentCount = 5000

            for _ in 0..<5000 {
                let future = Future<Int, Void>(value: 1)
                    .map { $0 + 1 }
                    .flatMap { Future<Int, Void>(value: $0 + 1) }
                    .mapError { $0 }

                future.on(success: { _ in expecation.fulfill() })
            }
            wait()
        }
    }

    func testZipArrayOf3() {
        measure {
            let expecation = self.expectation()
            expecation.expectedFulfillmentCount = 5000

            for _ in 0..<5000 {
                let future = Future.zip([
                    Future<Int, Void>(value: 1),
                    Future<Int, Void>(value: 2),
                    Future<Int, Void>(value: 4)]
                )

                future.on(success: { _ in expecation.fulfill() })
            }
            wait()
        }
    }

    func testZipArrayOf1000() {
        measure {
            let iterations = 10
            let futuresPerIteration = 1000

            let expecation = self.expectation()
            expecation.expectedFulfillmentCount = iterations

            let promises = Array(0..<iterations).map { _ in
                Array(0..<futuresPerIteration).map { _ in
                    Promise<Int, Never>()
                }
            }

            DispatchQueue.concurrentPerform(iterations: iterations) { iteration in
                let zip = Future.zip(promises[iteration].map { $0.future })
                zip.on(success: { _ in
                    expecation.fulfill()
                })
            }

            DispatchQueue.global().async {
                DispatchQueue.concurrentPerform(iterations: iterations) { iteration in
                    for promise in promises[iteration] {
                        promise.succeed(value: 1)
                    }
                }
            }

            wait()
        }
    }
}

class FutureMapPerformanceTests: XCTestCase {

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

class FutureFlatMapPerformanceTests: XCTestCase {

    func testFlatMapPending() {
        let futures = Array(0..<10000).map { _ in
            Promise<Int, Never>().future
        }

        measure {
            for future in futures {
                let _ = future.flatMap {
                    Future(value: $0)
                }
            }
        }
    }

    func testFlatMapResolvedReturnWithValue() {
        let futures = Array(0..<10000).map { _ in
            Future(value: 1)
        }

        measure {
            for future in futures {
                let _ = future.flatMap {
                    Future(value: $0)
                }
            }
        }
    }

    func testFlatMapResolvedReturnPending() {
        let futures = Array(0..<10000).map { _ in
            Future(value: 1)
        }

        measure {
            for future in futures {
                let _ = future.flatMap { _ in
                    Promise<Int, Never>().future // pending
                }
            }
        }
    }
}

class FutureMiscPerformanceTests: XCTestCase {
    func testObserveOn() {
        let futures = Array(0..<10000).map { _ in
            Future(value: 1)
        }

        let queue = DispatchQueue(label: "testObserveOn")
        measure {
            for future in futures {
                let _ = future.observe(on: queue)
            }
        }
    }
}
