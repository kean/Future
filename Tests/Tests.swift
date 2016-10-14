// The MIT License (MIT)
//
// Copyright (c) 2016 Alexander Grebenyuk (github.com/kean).

import XCTest
import Pill

class BasicTests: XCTestCase {
    func test() {
        let promise = Promise() { fulfill, _ in
            DispatchQueue.global().async {
                fulfill(1)
            }
        }

        expect { fulfill in
            promise.then {
                XCTAssertEqual($0, 1)
                fulfill()
            }
        }

        wait()
    }
}

class APlusTests: XCTestCase {
    
    func testThatPromiseIsCreatedInPendingState() {
        XCTAssertEqual(Promise<Void>() { _ in }.isPending, true)
    }
    
    func testThatFulfilledPromiseDoesntTransitionToOtherStates() {
        test("2.1.2.1: When fulfilled, a promise: must not transition to any other state.")
        
        expect("fulfill then fulfill with different value") { finish in
            let promise = Promise<Int>() { fulfill, _ in
                fulfill(0)
                fulfill(1)
            }
            promise.completion {
                XCTAssertEqual($0.value, 0)
                finish()
            }
        }
        
        expect("fulfill then reject") { finish in
            let promise = Promise<Int>() { fulfill, reject in
                fulfill(0)
                reject(Error.dummy)
            }
            promise.completion {
                XCTAssertEqual($0.value, 0)
                finish()
            }
        }
        
        wait()
    }
    
    func testThatRejectedPromiseDoesntTransitionToOtherStates() {
        test("2.1.3.1: When rejected, a promise: must not transition to any other state.")
        
        expect("reject then reject with different error") { finish in
            let promise = Promise<Int>() { _, reject in
                reject(Error.e1)
                reject(Error.e2)
            }
            promise.completion {
                XCTAssertEqual($0.error as? Error, Error.e1)
                finish()
            }
        }
        
        expect("reject then fulfill") { finish in
            let promise = Promise<Int>() { fulfill, reject in
                reject(Error.e1)
                fulfill(1)
            }
            promise.completion {
                XCTAssertEqual($0.error as? Error, Error.e1)
                finish()
            }
        }
        
        wait()
    }
    
    func testThen() {
        test("2.2.2: If `onFulfilled` is a function,") {
            expect("2.2.2.1: it must be called after `promise` is fulfilled, with `promise`’s fulfillment value as its first argument.") { finish in
                Promise<Int>.fulfilled().then {
                    XCTAssertEqual($0, dummy)
                    finish()
                }
            }
            wait()
        }
    }
}
