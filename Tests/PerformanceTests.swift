// The MIT License (MIT)
//
// Copyright (c) 2016-2018 Alexander Grebenyuk (github.com/kean).

import XCTest
import Foundation
import Pill

class PromisePerformanceTests: XCTestCase {
    func testCreation() {
        measure {
            for _ in 0..<100_000 {
                let _ = Future<Int, Void> { (_,_) in
                    return // do nothing
                }
            }
        }
    }

    func testOnValue() {
        let futures = (0..<50_000).map { _ in Future<Int, Void>(value: 1) }

        let expectation = self.expectation()
        var finished = 0

        measure {
            for promise in futures {
                promise.on(success: { _ in
                    finished += 1
                    if finished == futures.count {
                        expectation.fulfill()
                    }

                    return // do nothing
                })
            }
        }

        wait() // wait so that next test aren't affected
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

    func testObserveOnTheSameQueue() {
        let futures = (0..<50_000).map { _ in Future<Int, Void>(value: 1) }

        measure {
            for future in futures {
                // We expect this to be instantaneous thanks to the performance
                // optimization
                _ = future.observeOn(.main)
            }
        }
    }
}

