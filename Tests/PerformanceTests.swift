// The MIT License (MIT)
//
// Copyright (c) 2017 Alexander Grebenyuk (github.com/kean).

import XCTest
import Foundation
import Pill

class PromisePerformanceTests: XCTestCase {
    func testCreation() {
        measure {
            for _ in 0..<100_000 {
                let _ = Promise<Int> { (_,_) in
                    return // do nothing
                }
            }
        }
    }

    func testThen() {
        let promises = (0..<50_000).map { _ in Promise(value: 1) }

        let expectation = self.makeExpectation()
        var finished = 0

        measure {
            for promise in promises {
                promise.then { _ in
                    finished += 1
                    if finished == promises.count {
                        expectation.fulfill()
                    }

                    return // do nothing
                }
            }
        }

        wait() // wait so that next test aren't affected
    }

    func testFulfill() {
        let items = (0..<100_000).map { _ in Promise<Int>.deferred() }

        let expectation = self.makeExpectation()
        var finished = 0

        for item in items {
            item.promise.then { _ in
                finished += 1
                if finished == items.count {
                    expectation.fulfill()
                }

                return // do nothing
            }
        }

        measure {
            for item in items {
                item.fulfill(1)
            }
        }

        wait() // wait so that next test aren't affecteds
    }
}

