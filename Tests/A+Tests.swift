// The MIT License (MIT)
//
// Copyright (c) 2016-2018 Alexander Grebenyuk (github.com/kean).

import XCTest
import Future

// Tests migrated from JS https://github.com/promises-aplus/promises-tests

class APlusTests: XCTestCase {
        
    func test_2_1_2() {
        describe("2.1.2.1: When fulfilled, a promise: must not transition to any other state.") {

            expect("trying to fulfill then immediately fulfill with a different value") { finish in
                let future = Future<Int, MyError> { promise in
                    promise.succeed(value: 0)
                    promise.succeed(value: 1)
                }
                future.on(success: {
                    XCTAssertEqual($0, 0)
                    finish()
                })
            }

            expect("trying to fulfill then immediately reject") { finish in
                let future = Future<Int, MyError> { promise in
                    promise.succeed(value: 0)
                    promise.fail(error: MyError.e1)
                }
                future.on(success: {
                    XCTAssertEqual($0, 0)
                    finish()
                })
            }

            expect("trying to fulfill then reject, delayed") { finish in
                let future = Future<Int, MyError> { promise in
                    after(ticks: 5) {
                        promise.succeed(value: 0)
                        promise.fail(error: .e1)
                    }
                }
                future.on(success: {
                    XCTAssertEqual($0, 0)
                    finish()
                })
            }

            expect("trying to fulfill immediately then reject delayed") { finish in
                let future = Future<Int, MyError> { promise in
                    promise.succeed(value: 0)
                    after(ticks: 5) {
                        promise.fail(error: MyError.e1)
                    }
                }
                future.on(success: {
                    XCTAssertEqual($0, 0)
                    finish()
                })
            }
        }
    }
    
    func test_2_1_3() {
        describe("2.1.3.1: When rejected, a promise: must not transition to any other state.") {

            expect("reject then reject with different error") { finish in
                let future = Future<Int, MyError> { promise in
                    promise.fail(error: MyError.e1)
                    promise.fail(error: MyError.e2)
                }
                future.on(failure: {
                    XCTAssertEqual($0, MyError.e1)
                    finish()
                })
            }

            expect("trying to reject then immediately fulfill") { finish in
                let future = Future<Int, MyError> { promise in
                    promise.fail(error: MyError.e1)
                    promise.succeed(value: 1)
                }
                future.on(failure: {
                    XCTAssertEqual($0, MyError.e1)
                    finish()
                })
            }

            expect("trying to reject then fulfill, delayed") { finish in
                let future = Future<Int, MyError> { promise in
                    after(ticks: 5) {
                        promise.fail(error: MyError.e1)
                        promise.succeed(value: 1)
                    }
                }
                future.on(failure: {
                    XCTAssertEqual($0, MyError.e1)
                    finish()
                })
            }

            expect("trying to reject immediately then fulfill delayed") { finish in
                let future = Future<Int, MyError>() { promise in
                    promise.fail(error: MyError.e1)
                    after(ticks: 5) {
                        promise.succeed(value: 1)
                    }
                }
                future.on(failure: {
                    XCTAssertEqual($0, MyError.e1)
                    finish()
                })
            }
        }
    }

    func test_2_2_1() {
        describe("2.2.1: Both `onFulfilled` and `onRejected` are optional arguments.")

        // Doesn't make sense in Swift
    }

    func test_2_2_2() {
        describe("2.2.2: If `onFulfilled` is a function") {

            describe("2.2.2.1: it must be called after `promise` is fulfilled, with `promise`’s fulfillment value as its first argument.") {
                expect("fulfill delayed") { finish in
                    Future<Int, MyError>.eventuallySuccessfull().on(success: {
                        XCTAssertEqual($0, sentinel)
                        finish()
                    })
                }

                expect("fulfill immediately") { finish in
                    Future<Int, MyError>(value: sentinel).on(success: {
                        XCTAssertEqual($0, sentinel)
                        finish()
                    })
                }
            }

            describe("2.2.2.2: it must not be called before `promise` is fulfilled") {
                expect("fulfilled after a delay") { finish in
                    let promise = Promise<Int, MyError>()
                    let future = promise.future

                    var called = false
                    future.on(success: { _ in
                        called = true
                        finish()
                    })
                    future.on(failure: { _ in
                        XCTFail()
                    })
                    after(ticks: 5) {
                        XCTAssertFalse(called)
                        promise.succeed(value: 1)
                    }
                }

                expect("never fulfilled") { finish in
                    let future = Promise<Int, MyError>()

                    future.future.on(success: { _ in
                        XCTFail()
                    })
                    after(ticks: 5) {
                        finish()
                    }
                }
            }

            describe("2.2.2.3: it must not be called more than once.") {
                expect("already-fulfilled") { finish in
                    let future = Future<Int, MyError>(value: sentinel)

                    var timesCalled = 0
                    future.on(success: { _ in
                        timesCalled += 1
                        XCTAssertEqual(timesCalled, 1)
                    })

                    after(ticks: 20) {
                        finish()
                        XCTAssertEqual(timesCalled, 1)
                    }
                }

                expect("trying to fulfill a pending promise more than once, immediately") { finish in
                    let promise = Promise<Int, MyError>()
                    let future = promise.future

                    var timesCalled = 0
                    future.on(success: { _ in
                        timesCalled += 1
                        XCTAssertEqual(timesCalled, 1)
                    })

                    promise.succeed(value: 1)
                    promise.succeed(value: 2)
                    promise.succeed(value: 1)

                    after(ticks: 20) {
                        finish()
                        XCTAssertEqual(timesCalled, 1)
                    }
                }

                expect("trying to fulfill a pending promise more than once, delayed") { finish in
                    let promise = Promise<Int, MyError>()
                    let future = promise.future

                    var timesCalled = 0
                    future.on(success: { _ in
                        timesCalled += 1
                        XCTAssertEqual(timesCalled, 1)
                    })

                    after(ticks: 5) {
                        promise.succeed(value: 1)
                        promise.succeed(value: 2)
                        promise.succeed(value: 1)
                    }

                    after(ticks: 25) {
                        finish()
                        XCTAssertEqual(timesCalled, 1)
                    }
                }

                expect("trying to fulfill a pending promise more than once, immediately then delayed") { finish in
                    let promise = Promise<Int, MyError>()
                    let future = promise.future

                    var timesCalled = 0
                    future.on(success: {
                        XCTAssertEqual($0, sentinel)
                        timesCalled += 1
                        XCTAssertEqual(timesCalled, 1)
                    })

                    promise.succeed(value: sentinel)

                    after(ticks: 5) {
                        promise.succeed(value: sentinel)
                    }

                    after(ticks: 25) {
                        finish()
                        XCTAssertEqual(timesCalled, 1)
                    }
                }

                expect("when multiple `then` calls are made, spaced apart in time") { finish in
                    let promise = Promise<Int, MyError>()
                    let future = promise.future

                    var timesCalled = 0

                    after(ticks: 5) {
                        future.on(success: {
                            XCTAssertEqual($0, sentinel)
                            timesCalled += 1
                            XCTAssertEqual(timesCalled, 1)
                        })
                    }

                    after(ticks: 10) {
                        future.on(success: {
                            XCTAssertEqual($0, sentinel)
                            timesCalled += 1
                            XCTAssertEqual(timesCalled, 2)
                        })
                    }

                    after(ticks: 15) {
                        future.on(success: {
                            XCTAssertEqual($0, sentinel)
                            timesCalled += 1
                            XCTAssertEqual(timesCalled, 3)
                            finish()
                        })
                    }

                    after(ticks: 20) {
                        promise.succeed(value: sentinel)
                    }
                }

                expect("when `then` is interleaved with fulfillment") { finish in
                    let promise = Promise<Int, MyError>()
                    let future = promise.future

                    var timesCalled = 0

                    future.on(success: {
                        XCTAssertEqual($0, sentinel)
                        timesCalled += 1
                        XCTAssertEqual(timesCalled, 1)
                    })

                    promise.succeed(value: sentinel)

                    future.on(success: {
                        XCTAssertEqual($0, sentinel)
                        timesCalled += 1
                        XCTAssertEqual(timesCalled, 2)
                        finish()
                    })
                }
            }
        }
    }

    func test_2_2_3() {
        describe("2.2.3: If `onRejected` is a function,") {
            describe("2.2.3.1: it must be called after `promise` is rejected, with `promise`’s rejection reason as its first argument.") {
                expect("rejected after delay") { finish in
                    Future<Int, MyError>.eventuallyFailed().on(failure: {
                        XCTAssertEqual($0, MyError.e1)
                        finish()
                    })
                }

                expect("already-rejected") { finish in
                    Future<Int, MyError>(error: MyError.e1).on(failure: {
                        XCTAssertEqual($0, MyError.e1)
                        finish()
                    })
                }
            }

            describe("2.2.3.2: it must not be called before `promise` is rejected") {

                expect("rejected after a delay") { finish in
                    let promise = Promise<Int, MyError>()
                    let future = promise.future

                    var called = false
                    future.on(failure: { _ in
                        called = true
                        finish()
                    })
                    future.on(success: { _ in
                        XCTFail()
                    })
                    after(ticks: 5) {
                        XCTAssertFalse(called)
                        promise.fail(error: MyError.e1)
                    }
                }

                expect("never rejected") { finish in
                    let promise = Promise<Int, MyError>()
                    let future = promise.future

                    future.on(failure: { _ in
                        XCTFail()
                    })
                    after(ticks: 5) {
                        finish()
                    }
                }
            }

            describe("2.2.3.3: it must not be called more than once.") {
                expect("already-rejected") { finish in
                    let future = Future<Int, MyError>(error: MyError.e1)

                    var timesCalled = 0
                    future.on(failure: {
                        XCTAssertEqual($0, MyError.e1)
                        timesCalled += 1
                        XCTAssertEqual(timesCalled, 1)
                    })

                    after(ticks: 25) {
                        finish()
                        XCTAssertEqual(timesCalled, 1)
                    }
                }

                expect("trying to reject a pending promise more than once, immediately") { finish in
                    let promise = Promise<Int, MyError>()
                    let future = promise.future

                    var timesCalled = 0
                    future.on(failure: {
                        XCTAssertEqual($0, .e1)
                        timesCalled += 1
                        XCTAssertEqual(timesCalled, 1)
                    })

                    promise.fail(error: MyError.e1)
                    promise.fail(error: MyError.e1)

                    after(ticks: 25) {
                        finish()
                        XCTAssertEqual(timesCalled, 1)
                    }
                }

                expect("trying to reject a pending promise more than once, delayed") { finish in
                    let promise = Promise<Int, MyError>()
                    let future = promise.future

                    var timesCalled = 0
                    future.on(failure: {
                        XCTAssertEqual($0, MyError.e1)
                        timesCalled += 1
                        XCTAssertEqual(timesCalled, 1)
                    })

                    after(ticks: 5) {
                        promise.fail(error: MyError.e1)
                        promise.fail(error: MyError.e1)
                    }

                    after(ticks: 25) {
                        finish()
                        XCTAssertEqual(timesCalled, 1)
                    }
                }

                expect("trying to reject a pending promise more than once, immediately then delayed") { finish in
                    let promise = Promise<Int, MyError>()
                    let future = promise.future

                    var timesCalled = 0
                    future.on(failure: {
                        XCTAssertEqual($0, MyError.e1)
                        timesCalled += 1
                        XCTAssertEqual(timesCalled, 1)
                    })

                    promise.fail(error: MyError.e1)
                    after(ticks: 5) {
                        promise.fail(error: MyError.e1)
                    }

                    after(ticks: 25) {
                        finish()
                        XCTAssertEqual(timesCalled, 1)
                    }
                }

                expect("when multiple `then` calls are made, spaced apart in time") { finish in
                    let promise = Promise<Int, MyError>()
                    let future = promise.future

                    var timesCalled = 0
                    future.on(failure: {
                        XCTAssertEqual($0, MyError.e1)
                        timesCalled += 1
                        XCTAssertEqual(timesCalled, 1)
                    })

                    after(ticks: 5) {
                        future.on(failure: {
                            XCTAssertEqual($0, MyError.e1)
                            timesCalled += 1
                            XCTAssertEqual(timesCalled, 2)
                        })
                    }

                    after(ticks: 10) {
                        future.on(failure: {
                            XCTAssertEqual($0, MyError.e1)
                            timesCalled += 1
                            XCTAssertEqual(timesCalled, 3)
                            finish()
                        })
                    }

                    after(ticks: 15) {
                        promise.fail(error: MyError.e1)
                    }
                }

                expect("when `then` is interleaved with rejection") { finish in
                    let promise = Promise<Int, MyError>()
                    let future = promise.future

                    var timesCalled = 0
                    future.on(failure: {
                        XCTAssertEqual($0, MyError.e1)
                        timesCalled += 1
                        XCTAssertEqual(timesCalled, 1)
                    })

                    promise.fail(error: MyError.e1)

                    future.on(failure: {
                        XCTAssertEqual($0, MyError.e1)
                        timesCalled += 1
                        XCTAssertEqual(timesCalled, 2)
                        finish()
                    })
                }
            }
        }
    }

    func test_2_2_5() {
        describe("2.2.5 `onFulfilled` and `onRejected` must be called as functions (i.e. with no `this` value).")

        // Doesn't make sense in Swift
    }

    func test_2_2_6() {
        describe("2.2.6: `then` may be called multiple times on the same promise.") {
            describe("2.2.6.1: If/when `promise` is fulfilled, all respective `onFulfilled` callbacks must execute in the order of their originating calls to `then`.") {
                expect("multiple boring fulfillment handlers", count: 3) { finish in
                    let future = Future<Int, MyError>.eventuallySuccessfull()

                    future.on(success: {
                        XCTAssertEqual($0, sentinel)
                        finish()
                    })

                    future.on(success: {
                        XCTAssertEqual($0, sentinel)
                        finish()
                    })

                    future.on(success: {
                        XCTAssertEqual($0, sentinel)
                        finish()
                    })
                }

                describe("multiple fulfillment handlers, one of which throws") {
                    // Doesn't make sense in FutureX, cause it doesn't allow throws (yet?)
                }

                expect("results in multiple branching chains with their own fulfillment values", count: 3) { finish in
                    let future = Future<Int, MyError>.eventuallySuccessfull()

                    future.map { val -> Int in
                        XCTAssertEqual(val, sentinel)
                        return 2
                    }.on(success: {
                        XCTAssertEqual($0, 2)
                        finish()
                    })

                    future.map { val -> Int in
                        XCTAssertEqual(val, sentinel)
                        return 3
                    }.on(success: {
                        XCTAssertEqual($0, 3)
                        finish()
                    })

                    future.map { val -> Int in
                        XCTAssertEqual(val, sentinel)
                        return 4
                    }.on(success: {
                        XCTAssertEqual($0, 4)
                        finish()
                    })
                }

//                expect("`onFulfilled` handlers are called in the original order") { finish in
//                    let future = Future<Int, MyError>.eventuallySuccessfull()
//                    var callCount = 0
//
//                    future.on(success: {
//                        XCTAssertEqual($0, sentinel)
//                        callCount += 1
//                        XCTAssertEqual(callCount, 1)
//                    })
//
//
//                    future.on(success: {
//                        XCTAssertEqual($0, sentinel)
//                        callCount += 1
//                        XCTAssertEqual(callCount, 2)
//                    })
//
//                    future.on(success: {
//                        XCTAssertEqual($0, sentinel)
//                        callCount += 1
//                        XCTAssertEqual(callCount, 3)
//                        finish()
//                    })
//
//                    future.on(failure: { _ in XCTFail() })
//                }

                expect("even when one handler is added inside another handle") { finish in
                    let future = Future<Int, MyError>.eventuallySuccessfull()
                    var callCount = 0

                    future.on(success: {
                        XCTAssertEqual($0, sentinel)
                        callCount += 1
                        XCTAssertEqual(callCount, 1)
                        
                        future.on(success: {
                            XCTAssertEqual($0, sentinel)
                            callCount += 1
                            XCTAssertEqual(callCount, 2)
                            
                            future.on(success: {
                                XCTAssertEqual($0, sentinel)
                                callCount += 1
                                XCTAssertEqual(callCount, 3)
                                finish()
                            })
                        })
                    })
                }
            }

            describe("2.2.6.2: If/when `promise` is rejected, all respective `onRejected` callbacks must execute in the order of their originating calls to `then`.") {
                expect("multiple boring rejection handlers", count: 3) { finish in
                    let future = Future<Int, MyError>.eventuallyFailed()

                    future.on(failure: {
                        XCTAssertEqual($0, MyError.e1)
                        finish()
                    })

                    future.on(failure: {
                        XCTAssertEqual($0, MyError.e1)
                        finish()
                    })

                    future.on(failure: {
                        XCTAssertEqual($0, MyError.e1)
                        finish()
                    })
                }

                describe("multiple rejection handlers, one of which throws") {
                    // Doesn't make sense in FutureX, cause it doesn't allow throws (yet?)
                }

//                expect("`onRejected` handlers are called in the original order") { finish in
//                    let future = Future<Int, MyError>.eventuallyFailed()
//                    var callCount = 0
//
//                    future.on(failure: {
//                        XCTAssertEqual($0, MyError.e1)
//                        callCount += 1
//                        XCTAssertEqual(callCount, 1)
//                    })
//
//                    future.on(failure: {
//                        XCTAssertEqual($0, MyError.e1)
//                        callCount += 1
//                        XCTAssertEqual(callCount, 2)
//                    })
//
//                    future.on(failure: {
//                        XCTAssertEqual($0, MyError.e1)
//                        callCount += 1
//                        XCTAssertEqual(callCount, 3)
//                        finish()
//                    })
//
//                    future.on(success: { _ in XCTFail() })
//                }

                expect("even when one handler is added inside another handle") { finish in
                    let future = Future<Int, MyError>.eventuallyFailed()
                    var callCount = 0

                    future.on(failure: {
                        XCTAssertEqual($0, MyError.e1)
                        callCount += 1
                        XCTAssertEqual(callCount, 1)

                        future.on(failure: {
                            XCTAssertEqual($0, MyError.e1)
                            callCount += 1
                            XCTAssertEqual(callCount, 2)
                            
                            future.on(failure: {
                                XCTAssertEqual($0, MyError.e1)
                                callCount += 1
                                XCTAssertEqual(callCount, 3)
                                finish()
                            })
                        })
                    })
                }
            }
        }

        func test_2_2_7() {
            describe("2.2.7: `then` must return a promise: `promise2 = promise1.then(onFulfilled, onRejected)") {

                describe("is a promise") {
                    // Doesn't make sense in Swift
                }
                
                describe("2.2.7.1: If either `onFulfilled` or `onRejected` returns a value `x`, run the Promise Resolution procedure `[[Resolve]](promise2, x)`") {
                    // See separate 3.3 tests
                }
                
                describe("2.2.7.2: If either `onFulfilled` or `onRejected` throws an exception `e`, `promise2` must be rejected with `e` as the reason.") {
                    // We don't test that since we don't allow then/catch to throw
                }
                
                describe("2.2.7.3: If `onFulfilled` is not a function and `promise1` is fulfilled, `promise2` must be fulfilled with the same value.") {
                    // Doesn't make sense in Swift
                }
                
                describe("2.2.7.4: If `onRejected` is not a function and `promise1` is rejected, `promise2` must be rejected with the same reason.") {
                    // Doesn't make sense in Swift
                }
            }
        }
        
        func test_2_3_1() {
            describe("2.3.1: If `promise` and `x` refer to the same object, reject `promise` with a `TypeError' as the reason.") {
                // First of, this is really a fatal error which is a result of
                // a programmatic error - it's not 'just an error'.
                // Second of, FutureX doesn't (yet) support this since it seems
                // like an overkill at this point.
            }
        }
        
        func test_2_3_2() {
            describe("2.3.2: If `x` is a promise, adopt its state") {
                describe("2.3.2.1: If `x` is pending, `promise` must remain pending until `x` is fulfilled or rejected.") {
                    expect("via return from a fulfilled promise") { finish in
                        let future = Future(value: 1).flatMap { _ in
                            return Future<Int, MyError> { _ in } // pending
                        }
                        future.on(completion: { _ in
                            XCTFail()
                        })
                        after(ticks: 20) {
                            finish()
                        }
                    }
                 
                    expect("via return from a rejected promise") { finish in
                        let future = Future<Int, MyError>(error: MyError.e1).flatMapError { _ in
                            return Future<Int, MyError> { _ in } // pending
                        }
                        future.on(completion: { _ in
                            XCTFail()
                        })
                        after(ticks: 20) {
                            finish()
                        }
                    }
                }

                describe("2.3.2.2: If/when `x` is fulfilled, fulfill `promise` with the same value.") {
                    expect("`x` is already-fulfilled") { finish in
                        let future = Future<Int, MyError>(value: sentinel).map { return $0 }
                        future.on(success: {
                            XCTAssertEqual($0, sentinel)
                            finish()
                        })
                    }

                    expect("`x` is eventually-fulfilled") { finish in
                        let future = Future<Int, MyError>.eventuallySuccessfull().map { return $0 }
                        future.on(success: {
                            XCTAssertEqual($0, sentinel)
                            finish()
                        })
                    }
                }


                describe("2.3.2.3: If/when `x` is rejected, reject `promise` with the same reason.") {
                    expect("`x` is already-rejected") { finish in
                        let future = Future<Int, MyError>(error: MyError.e1).map { _ in }
                        future.on(failure: {
                            XCTAssertEqual($0, MyError.e1)
                            finish()
                        })
                    }

                    expect("`x` is eventually-rejected") { finish in
                        let future = Future<Int, MyError>.eventuallyFailed().map { _ in }
                        future.on(failure: {
                            XCTAssertEqual($0, MyError.e1)
                            finish()
                        })
                    }
                }
            }
        }

        func test_2_3_3() {
            describe("2.3.3: Otherwise, if `x` is an object or function,") {
                // Most of those tests doesn't make sense in Swift
                // FIXME: Get back to it later, there might be some usefull tests
            }
        }

        func test_2_3_4() {
            describe("2.3.4: If `x` is not an object or function, fulfill `promise` with `x`") {
                // Doesn't make sense in Swift
            }
        }
    }
}
