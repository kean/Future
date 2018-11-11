// The MIT License (MIT)
//
// Copyright (c) 2017-2018 Alexander Grebenyuk (github.com/kean).

import XCTest
import Pill

// Tests migrated from JS https://github.com/promises-aplus/promises-tests

class APlusTests: XCTestCase {
        
    func test_2_1_2() {
        test("2.1.2.1: When fulfilled, a promise: must not transition to any other state.") {

            expect("trying to fulfill then immediately fulfill with a different value") { finish in
                let promise = Promise<Int, MyError>() { fulfill, _ in
                    fulfill(0)
                    fulfill(1)
                }
                promise.map {
                    XCTAssertEqual($0, 0)
                    finish()
                }
            }

            expect("trying to fulfill then immediately reject") { finish in
                let promise = Promise<Int, MyError>() { fulfill, reject in
                    fulfill(0)
                    reject(MyError.e1)
                }
                promise.map {
                    XCTAssertEqual($0, 0)
                    finish()
                }
            }

            expect("trying to fulfill then reject, delayed") { finish in
                let promise = Promise<Int, MyError>() { fulfill, reject in
                    after(ticks: 5) {
                        fulfill(0)
                        reject(MyError.e1)
                    }
                }
                promise.map {
                    XCTAssertEqual($0, 0)
                    finish()
                }
            }

            expect("trying to fulfill immediately then reject delayed") { finish in
                let promise = Promise<Int, MyError>() { fulfill, reject in
                    fulfill(0)
                    after(ticks: 5) {
                        reject(MyError.e1)
                    }
                }
                promise.map {
                    XCTAssertEqual($0, 0)
                    finish()
                }
            }
        }
    }
    
    func test_2_1_3() {
        test("2.1.3.1: When rejected, a promise: must not transition to any other state.") {

            expect("reject then reject with different error") { finish in
                let promise = Promise<Int, MyError>() { _, reject in
                    reject(MyError.e1)
                    reject(MyError.e2)
                }
                promise.catch {
                    XCTAssertEqual($0, MyError.e1)
                    finish()
                }
            }

            expect("trying to reject then immediately fulfill") { finish in
                let promise = Promise<Int, MyError>() { fulfill, reject in
                    reject(MyError.e1)
                    fulfill(1)
                }
                promise.catch {
                    XCTAssertEqual($0, MyError.e1)
                    finish()
                }
            }

            expect("trying to reject then fulfill, delayed") { finish in
                let promise = Promise<Int, MyError>() { fulfill, reject in
                    after(ticks: 5) {
                        reject(MyError.e1)
                        fulfill(1)
                    }
                }
                promise.catch {
                    XCTAssertEqual($0, MyError.e1)
                    finish()
                }
            }

            expect("trying to reject immediately then fulfill delayed") { finish in
                let promise = Promise<Int, MyError>() { fulfill, reject in
                    reject(MyError.e1)
                    after(ticks: 5) {
                        fulfill(1)
                    }
                }
                promise.catch {
                    XCTAssertEqual($0, MyError.e1)
                    finish()
                }
            }
        }
    }

    func test_2_2_1() {
        test("2.2.1: Both `onFulfilled` and `onRejected` are optional arguments.")

        // Doesn't make sense in Swift
    }

    func test_2_2_2() {
        test("2.2.2: If `onFulfilled` is a function") {

            test("2.2.2.1: it must be called after `promise` is fulfilled, with `promise`’s fulfillment value as its first argument.") {
                expect("fulfill delayed") { finish in
                    Promise<Int, MyError>.fulfilledAsync().map {
                        XCTAssertEqual($0, sentinel)
                        finish()
                    }
                }

                expect("fulfill immediately") { finish in
                    Promise<Int, MyError>(value: sentinel).map {
                        XCTAssertEqual($0, sentinel)
                        finish()
                    }
                }
            }

            test("2.2.2.2: it must not be called before `promise` is fulfilled") {
                expect("fulfilled after a delay") { finish in
                    let (promise, fulfill, _) = Promise<Int, MyError>.deferred()

                    var called = false
                    promise.map { _ -> Void in
                        called = true
                        finish()
                    }
                    promise.catch { _ in
                        XCTFail()
                    }
                    after(ticks: 5) {
                        XCTAssertFalse(called)
                        fulfill(1)
                    }
                }

                expect("never fulfilled") { finish in
                    let (promise, _, _) = Promise<Int, MyError>.deferred()

                    promise.map { _ -> Void in
                        XCTFail()
                    }
                    after(ticks: 5) {
                        finish()
                    }
                }
            }

            test("2.2.2.3: it must not be called more than once.") {
                expect("already-fulfilled") { finish in
                    let promise = Promise<Int, MyError>(value: sentinel)

                    var timesCalled = 0
                    promise.map { _ -> Void in
                        timesCalled += 1
                        XCTAssertEqual(timesCalled, 1)
                    }

                    after(ticks: 20) {
                        finish()
                        XCTAssertEqual(timesCalled, 1)
                    }
                }

                expect("trying to fulfill a pending promise more than once, immediately") { finish in
                    let (promise, fulfill, _) = Promise<Int, MyError>.deferred()

                    var timesCalled = 0
                    promise.map { _ -> Void in
                        timesCalled += 1
                        XCTAssertEqual(timesCalled, 1)
                    }

                    fulfill(1)
                    fulfill(2)
                    fulfill(1)

                    after(ticks: 20) {
                        finish()
                        XCTAssertEqual(timesCalled, 1)
                    }
                }

                expect("trying to fulfill a pending promise more than once, delayed") { finish in
                    let (promise, fulfill, _) = Promise<Int, MyError>.deferred()

                    var timesCalled = 0
                    promise.map { _ -> Void in
                        timesCalled += 1
                        XCTAssertEqual(timesCalled, 1)
                    }

                    after(ticks: 5) {
                        fulfill(1)
                        fulfill(2)
                        fulfill(1)
                    }

                    after(ticks: 25) {
                        finish()
                        XCTAssertEqual(timesCalled, 1)
                    }
                }

                expect("trying to fulfill a pending promise more than once, immediately then delayed") { finish in
                    let (promise, fulfill, _) = Promise<Int, MyError>.deferred()

                    var timesCalled = 0
                    promise.map {
                        XCTAssertEqual($0, sentinel)
                        timesCalled += 1
                        XCTAssertEqual(timesCalled, 1)
                    }

                    fulfill(sentinel)

                    after(ticks: 5) {
                        fulfill(sentinel)
                    }

                    after(ticks: 25) {
                        finish()
                        XCTAssertEqual(timesCalled, 1)
                    }
                }

                expect("when multiple `then` calls are made, spaced apart in time") { finish in
                    let (promise, fulfill, _) = Promise<Int, MyError>.deferred()

                    var timesCalled = 0

                    after(ticks: 5) {
                        promise.map {
                            XCTAssertEqual($0, sentinel)
                            timesCalled += 1
                            XCTAssertEqual(timesCalled, 1)
                        }
                    }

                    after(ticks: 10) {
                        promise.map {
                            XCTAssertEqual($0, sentinel)
                            timesCalled += 1
                            XCTAssertEqual(timesCalled, 2)
                        }
                    }

                    after(ticks: 15) {
                        promise.map {
                            XCTAssertEqual($0, sentinel)
                            timesCalled += 1
                            XCTAssertEqual(timesCalled, 3)
                            finish()
                        }
                    }

                    after(ticks: 20) {
                        fulfill(sentinel)
                    }
                }

                expect("when `then` is interleaved with fulfillment") { finish in
                    let (promise, fulfill, _) = Promise<Int, MyError>.deferred()

                    var timesCalled = 0

                    promise.map {
                        XCTAssertEqual($0, sentinel)
                        timesCalled += 1
                        XCTAssertEqual(timesCalled, 1)
                    }

                    fulfill(sentinel)

                    promise.map {
                        XCTAssertEqual($0, sentinel)
                        timesCalled += 1
                        XCTAssertEqual(timesCalled, 2)
                        finish()
                    }
                }
            }
        }
    }

    func test_2_2_3() {
        test("2.2.3: If `onRejected` is a function,") {
            test("2.2.3.1: it must be called after `promise` is rejected, with `promise`’s rejection reason as its first argument.") {
                expect("rejected after delay") { finish in
                    Promise<Int, MyError>.rejectedAsync().catch {
                        XCTAssertEqual($0, MyError.e1)
                        finish()
                    }
                }

                expect("already-rejected") { finish in
                    Promise<Int, MyError>(error: MyError.e1).catch {
                        XCTAssertEqual($0, MyError.e1)
                        finish()
                    }
                }
            }

            test("2.2.3.2: it must not be called before `promise` is rejected") {

                expect("rejected after a delay") { finish in
                    let (promise, _, reject) = Promise<Int, MyError>.deferred()

                    var called = false
                    promise.catch { _ -> Void in
                        called = true
                        finish()
                    }
                    promise.map { _ in
                        XCTFail()
                    }
                    after(ticks: 5) {
                        XCTAssertFalse(called)
                        reject(MyError.e1)
                    }
                }

                expect("never rejected") { finish in
                    let (promise, _, _) = Promise<Int, MyError>.deferred()

                    promise.catch { _ -> Void in
                        XCTFail()
                    }
                    after(ticks: 5) {
                        finish()
                    }
                }
            }

            test("2.2.3.3: it must not be called more than once.") {
                expect("already-rejected") { finish in
                    let promise = Promise<Int, MyError>(error: MyError.e1)

                    var timesCalled = 0
                    promise.catch {
                        XCTAssertEqual($0, MyError.e1)
                        timesCalled += 1
                        XCTAssertEqual(timesCalled, 1)
                    }

                    after(ticks: 25) {
                        finish()
                        XCTAssertEqual(timesCalled, 1)
                    }
                }

                expect("trying to reject a pending promise more than once, immediately") { finish in
                    let (promise, _, reject) = Promise<Int, MyError>.deferred()

                    var timesCalled = 0
                    promise.catch {
                        XCTAssertEqual($0, .e1)
                        timesCalled += 1
                        XCTAssertEqual(timesCalled, 1)
                    }

                    reject(MyError.e1)
                    reject(MyError.e1)

                    after(ticks: 25) {
                        finish()
                        XCTAssertEqual(timesCalled, 1)
                    }
                }

                expect("trying to reject a pending promise more than once, delayed") { finish in
                    let (promise, _, reject) = Promise<Int, MyError>.deferred()

                    var timesCalled = 0
                    promise.catch {
                        XCTAssertEqual($0, MyError.e1)
                        timesCalled += 1
                        XCTAssertEqual(timesCalled, 1)
                    }

                    after(ticks: 5) {
                        reject(MyError.e1)
                        reject(MyError.e1)
                    }

                    after(ticks: 25) {
                        finish()
                        XCTAssertEqual(timesCalled, 1)
                    }
                }

                expect("trying to reject a pending promise more than once, immediately then delayed") { finish in
                    let (promise, _, reject) = Promise<Int, MyError>.deferred()

                    var timesCalled = 0
                    promise.catch {
                        XCTAssertEqual($0, MyError.e1)
                        timesCalled += 1
                        XCTAssertEqual(timesCalled, 1)
                    }

                    reject(MyError.e1)
                    after(ticks: 5) {
                        reject(MyError.e1)
                    }

                    after(ticks: 25) {
                        finish()
                        XCTAssertEqual(timesCalled, 1)
                    }
                }

                expect("when multiple `then` calls are made, spaced apart in time") { finish in
                    let (promise, _, reject) = Promise<Int, MyError>.deferred()

                    var timesCalled = 0
                    promise.catch {
                        XCTAssertEqual($0, MyError.e1)
                        timesCalled += 1
                        XCTAssertEqual(timesCalled, 1)
                    }

                    after(ticks: 5) {
                        promise.catch {
                            XCTAssertEqual($0, MyError.e1)
                            timesCalled += 1
                            XCTAssertEqual(timesCalled, 2)
                        }
                    }

                    after(ticks: 10) {
                        promise.catch {
                            XCTAssertEqual($0, MyError.e1)
                            timesCalled += 1
                            XCTAssertEqual(timesCalled, 3)
                            finish()
                        }
                    }

                    after(ticks: 15) {
                        reject(MyError.e1)
                    }
                }

                expect("when `then` is interleaved with rejection") { finish in
                    let (promise, _, reject) = Promise<Int, MyError>.deferred()

                    var timesCalled = 0
                    promise.catch {
                        XCTAssertEqual($0, MyError.e1)
                        timesCalled += 1
                        XCTAssertEqual(timesCalled, 1)
                    }

                    reject(MyError.e1)

                    promise.catch {
                        XCTAssertEqual($0, MyError.e1)
                        timesCalled += 1
                        XCTAssertEqual(timesCalled, 2)
                        finish()
                    }
                }
            }
        }
    }

    func test_2_2_4() {
        test("2.2.4: `onFulfilled` or `onRejected` must not be called until the execution context stack contains only " +
        "platform code.") {
            test("`then` returns before the promise becomes fulfilled or rejected") {
                expect("`then`") { finish in
                    let promise = Promise<Int, MyError>(value: sentinel)

                    var thenHasReturned = false

                    promise.map { _ in
                        XCTAssertEqual(thenHasReturned, true)
                        finish()
                    }
                    
                    thenHasReturned = true;
                }

                expect("`catch`") { finish in
                    let promise = Promise<Int, MyError>(error: MyError.e1)

                    var catchHasReturned = false

                    promise.catch { _ in
                        XCTAssertEqual(catchHasReturned, true)
                        finish()
                    }

                    catchHasReturned = true;
                }
            }

            test("Clean-stack execution ordering tests (fulfillment case)") {
                test("when `onFulfilled` is added immediately before the promise is fulfilled") {
                    let (promise, fulfill, _) = Promise<Int, MyError>.deferred()

                    var thenCalled = false;

                    promise.map { _ in
                        thenCalled = true;
                    }

                    fulfill(sentinel)

                    XCTAssertEqual(thenCalled, false)
                }

                test("when `onFulfilled` is added immediately after the promise is fulfilled") {
                    let (promise, fulfill, _) = Promise<Int, MyError>.deferred()

                    var thenCalled = false;

                    fulfill(sentinel)

                    promise.map { _ in
                        thenCalled = true;
                    }
                    
                    XCTAssertEqual(thenCalled, false)
                }

                expect("when one `onFulfilled` is added inside another `onFulfilled`") { finish in
                    let promise = Promise<Int, MyError>(value: sentinel)

                    var firstOnFulfilledFinished = false

                    promise.map { _ in
                        promise.map { _ in
                            XCTAssertEqual(firstOnFulfilledFinished, true)
                            finish()
                        }
                        firstOnFulfilledFinished = true
                    }
                }

                expect("when `onFulfilled` is added inside an `onRejected`") { finish in
                    let promise = Promise<Int, MyError>(error: MyError.e1)
                    let promise2 = Promise<Int, MyError>(value: sentinel)

                    var firstOnRejectedFinished = false

                    promise.catch { _ in
                        promise2.map { _ in
                            XCTAssertEqual(firstOnRejectedFinished, true)
                            finish()
                        }
                        firstOnRejectedFinished = true
                    }
                }

                expect("when the promise is fulfilled asynchronously") { finish in
                    let (promise, fulfill, _) = Promise<Int, MyError>.deferred()

                    var firstStackFinished = false

                    after(ticks: 1) {
                        fulfill(sentinel)
                        firstStackFinished = true
                    }

                    promise.map { _ in
                        XCTAssertEqual(firstStackFinished, true)
                        finish()
                    }
                }
            }

            test("Clean-stack execution ordering tests (rejection case)") {
                test("when `onRejected` is added immediately before the promise is rejected") {
                    let (promise, _, reject) = Promise<Int, MyError>.deferred()

                    var catchCalled = false;

                    promise.catch { _ in
                        catchCalled = true;
                    }

                    reject(MyError.e1)

                    XCTAssertEqual(catchCalled, false)
                }

                test("when `onRejected` is added immediately after the promise is rejected") {
                    let (promise, _, reject) = Promise<Int, MyError>.deferred()

                    var catchCalled = false;

                    reject(MyError.e1)

                    promise.catch { _ in
                        catchCalled = true;
                    }

                    XCTAssertEqual(catchCalled, false)
                }

                expect("when one `onRejected` is added inside another `onRejected`") { finish in
                    let promise = Promise<Int, MyError>(error: MyError.e1)

                    var firstOnRejectedFinished = false

                    promise.catch { _ in
                        promise.catch { _ in
                            XCTAssertEqual(firstOnRejectedFinished, true)
                            finish()
                        }
                        firstOnRejectedFinished = true
                    }
                }

                expect("when `onRejected` is added inside an `onFulfilled`") { finish in
                    let promise = Promise<Int, MyError>(value: sentinel)
                    let promise2 = Promise<Int, MyError>(error: MyError.e1)

                    var firstOnFulfilledFinished = false

                    promise.map { _ in
                        promise2.catch { _ in
                            XCTAssertEqual(firstOnFulfilledFinished, true)
                            finish()
                        }
                        firstOnFulfilledFinished = true
                    }
                }

                expect("when the promise is rejected asynchronously") { finish in
                    let (promise, _, reject) = Promise<Int, MyError>.deferred()

                    var firstStackFinished = false

                    after(ticks: 1) {
                        reject(MyError.e1)
                        firstStackFinished = true
                    }
                    
                    promise.catch { _ in
                        XCTAssertEqual(firstStackFinished, true)
                        finish()
                    }
                }
            }
        }
    }

    func test_2_2_5() {
        test("2.2.5 `onFulfilled` and `onRejected` must be called as functions (i.e. with no `this` value).")

        // Doesn't make sense in Swift
    }



    func test_2_2_6() {
        test("2.2.6: `then` may be called multiple times on the same promise.") {
            test("2.2.6.1: If/when `promise` is fulfilled, all respective `onFulfilled` callbacks must execute in the order of their originating calls to `then`.") {
                expect("multiple boring fulfillment handlers") { finish in
                    let promise = Promise<Int, MyError>.fulfilledAsync()

                    let finisher = Finisher(finish, 3)

                    promise.map {
                        XCTAssertEqual($0, sentinel)
                        finisher.finish()
                    }

                    promise.map {
                        XCTAssertEqual($0, sentinel)
                        finisher.finish()
                    }

                    promise.map {
                        XCTAssertEqual($0, sentinel)
                        finisher.finish()
                    }
                }

                test("multiple fulfillment handlers, one of which throws") {
                    // Doesn't make sense in Pill, cause it doesn't allow throws (yet?)
                }

                expect("results in multiple branching chains with their own fulfillment values") { finish in
                    let finisher = Finisher(finish, 3)

                    let promise = Promise<Int, MyError>.fulfilledAsync()

                    promise.map { val -> Int in
                        XCTAssertEqual(val, sentinel)
                        return 2
                    }.map {
                        XCTAssertEqual($0, 2)
                        finisher.finish()
                    }

                    promise.map { val -> Int in
                        XCTAssertEqual(val, sentinel)
                        return 3
                    }.map {
                        XCTAssertEqual($0, 3)
                        finisher.finish()
                    }

                    promise.map { val -> Int in
                        XCTAssertEqual(val, sentinel)
                        return 4
                    }.map {
                        XCTAssertEqual($0, 4)
                        finisher.finish()
                    }
                }

                expect("`onFulfilled` handlers are called in the original order") { finish in
                    let promise = Promise<Int, MyError>.fulfilledAsync()
                    var callCount = 0

                    promise.map {
                        XCTAssertEqual($0, sentinel)
                        callCount += 1
                        XCTAssertEqual(callCount, 1)
                    }


                    promise.map {
                        XCTAssertEqual($0, sentinel)
                        callCount += 1
                        XCTAssertEqual(callCount, 2)
                    }

                    promise.map {
                        XCTAssertEqual($0, sentinel)
                        callCount += 1
                        XCTAssertEqual(callCount, 3)
                        finish()
                    }

                    promise.catch { _ in XCTFail() }
                }

                expect("even when one handler is added inside another handle") { finish in
                    let promise = Promise<Int, MyError>.fulfilledAsync()
                    var callCount = 0

                    promise.map {
                        XCTAssertEqual($0, sentinel)
                        callCount += 1
                        XCTAssertEqual(callCount, 1)
                        
                        promise.map {
                            XCTAssertEqual($0, sentinel)
                            callCount += 1
                            XCTAssertEqual(callCount, 2)
                            
                            promise.map {
                                XCTAssertEqual($0, sentinel)
                                callCount += 1
                                XCTAssertEqual(callCount, 3)
                                finish()
                            }
                        }
                    }
                }
            }

            test("2.2.6.2: If/when `promise` is rejected, all respective `onRejected` callbacks must execute in the order of their originating calls to `then`.") {
                expect("multiple boring rejection handlers") { finish in
                    let promise = Promise<Int, MyError>.rejectedAsync()

                    let finisher = Finisher(finish, 3)

                    promise.catch {
                        XCTAssertEqual($0, MyError.e1)
                        finisher.finish()
                    }

                    promise.catch {
                        XCTAssertEqual($0, MyError.e1)
                        finisher.finish()
                    }

                    promise.catch {
                        XCTAssertEqual($0, MyError.e1)
                        finisher.finish()
                    }
                }

                test("multiple rejection handlers, one of which throws") {
                    // Doesn't make sense in Pill, cause it doesn't allow throws (yet?)
                }

                expect("`onRejected` handlers are called in the original order") { finish in
                    let promise = Promise<Int, MyError>.rejectedAsync()
                    var callCount = 0

                    promise.catch {
                        XCTAssertEqual($0, MyError.e1)
                        callCount += 1
                        XCTAssertEqual(callCount, 1)
                    }


                    promise.catch {
                        XCTAssertEqual($0, MyError.e1)
                        callCount += 1
                        XCTAssertEqual(callCount, 2)
                    }

                    promise.catch {
                        XCTAssertEqual($0, MyError.e1)
                        callCount += 1
                        XCTAssertEqual(callCount, 3)
                        finish()
                    }

                    promise.map { _ in XCTFail() }
                }

                expect("even when one handler is added inside another handle") { finish in
                    let promise = Promise<Int, MyError>.rejectedAsync()
                    var callCount = 0

                    promise.catch {
                        XCTAssertEqual($0, MyError.e1)
                        callCount += 1
                        XCTAssertEqual(callCount, 1)

                        promise.catch {
                            XCTAssertEqual($0, MyError.e1)
                            callCount += 1
                            XCTAssertEqual(callCount, 2)
                            
                            promise.catch {
                                XCTAssertEqual($0, MyError.e1)
                                callCount += 1
                                XCTAssertEqual(callCount, 3)
                                finish()
                            }
                        }
                    }
                }
            }
        }

        func test_2_2_7() {
            test("2.2.7: `then` must return a promise: `promise2 = promise1.then(onFulfilled, onRejected)") {

                test("is a promise") {
                    // Doesn't make sense in Swift
                }
                
                test("2.2.7.1: If either `onFulfilled` or `onRejected` returns a value `x`, run the Promise Resolution procedure `[[Resolve]](promise2, x)`") {
                    // See separate 3.3 tests
                }
                
                test("2.2.7.2: If either `onFulfilled` or `onRejected` throws an exception `e`, `promise2` must be rejected with `e` as the reason.") {
                    // We don't test that since we don't allow then/catch to throw
                }
                
                test("2.2.7.3: If `onFulfilled` is not a function and `promise1` is fulfilled, `promise2` must be fulfilled with the same value.") {
                    // Doesn't make sense in Swift
                }
                
                test("2.2.7.4: If `onRejected` is not a function and `promise1` is rejected, `promise2` must be rejected with the same reason.") {
                    // Doesn't make sense in Swift
                }
            }
        }
        
        func test_2_3_1() {
            test("2.3.1: If `promise` and `x` refer to the same object, reject `promise` with a `TypeError' as the reason.") {
                // First of, this is really a fatal error which is a result of
                // a programmatic error - it's not 'just an error'.
                // Second of, Pill doesn't (yet) support this since it seems
                // like an overkill at this point.
            }
        }
        
        func test_2_3_2() {
            test("2.3.2: If `x` is a promise, adopt its state") {
                test("2.3.2.1: If `x` is pending, `promise` must remain pending until `x` is fulfilled or rejected.") {
                    expect("via return from a fulfilled promise") { finish in
                        let promise = Promise(value: 1).flatMap { _ in
                            return Promise<Int, MyError> { (_,_) in } // pending
                        }
                        promise.finally {
                            XCTFail()
                        }
                        after(ticks: 20) {
                            finish()
                        }
                    }
                 
                    expect("via return from a rejected promise") { finish in
                        let promise = Promise<Int, MyError>(error: MyError.e1).recover { _ in
                            return Promise<Int, MyError> { (_,_) in } // pending
                        }
                        promise.finally {
                            XCTFail()
                        }
                        after(ticks: 20) {
                            finish()
                        }
                    }
                }

                test("2.3.2.2: If/when `x` is fulfilled, fulfill `promise` with the same value.") {
                    expect("`x` is already-fulfilled") { finish in
                        let promise = Promise<Int, MyError>(value: sentinel).map { return $0 }
                        promise.map {
                            XCTAssertEqual($0, sentinel)
                            finish()
                        }
                    }

                    expect("`x` is eventually-fulfilled") { finish in
                        let promise = Promise<Int, MyError>.fulfilledAsync().map { return $0 }
                        promise.map {
                            XCTAssertEqual($0, sentinel)
                            finish()
                        }
                    }
                }


                test("2.3.2.3: If/when `x` is rejected, reject `promise` with the same reason.") {
                    expect("`x` is already-rejected") { finish in
                        let promise = Promise<Int, MyError>(error: MyError.e1).map { _ in }
                        promise.catch {
                            XCTAssertEqual($0, MyError.e1)
                            finish()
                        }
                    }

                    expect("`x` is eventually-rejected") { finish in
                        let promise = Promise<Int, MyError>.rejectedAsync().map { _ in }
                        promise.catch {
                            XCTAssertEqual($0, MyError.e1)
                            finish()
                        }
                    }
                }
            }
        }

        func test_2_3_3() {
            test("2.3.3: Otherwise, if `x` is an object or function,") {
                // Most of those tests doesn't make sense in Swift
                // FIXME: Get back to it later, there might be some usefull tests
            }
        }

        func test_2_3_4() {
            test("2.3.4: If `x` is not an object or function, fulfill `promise` with `x`") {
                // Doesn't make sense in Swift
            }
        }
    }
}
