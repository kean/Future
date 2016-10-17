// The MIT License (MIT)
//
// Copyright (c) 2016 Alexander Grebenyuk (github.com/kean).

import XCTest
import Pill

// Tests were migrated from JS https://github.com/promises-aplus/promises-tests

class APlusTests: XCTestCase {
    
    func testThatPromiseIsCreatedInPendingState() {
        XCTAssertEqual(Promise<Void>() { _ in }.isPending, true)
    }
    
    func test_2_1_2() {
        test("2.1.2.1: When fulfilled, a promise: must not transition to any other state.") {

            expect("trying to fulfill then immediately fulfill with a different value") { finish in
                let promise = Promise<Int>() { fulfill, _ in
                    fulfill(0)
                    fulfill(1)
                }
                promise.completion {
                    XCTAssertEqual($0.value, 0)
                    finish()
                }
            }

            expect("trying to fulfill then immediately reject") { finish in
                let promise = Promise<Int>() { fulfill, reject in
                    fulfill(0)
                    reject(Error.e1)
                }
                promise.completion {
                    XCTAssertEqual($0.value, 0)
                    finish()
                }
            }

            expect("trying to fulfill then reject, delayed") { finish in
                let promise = Promise<Int>() { fulfill, reject in
                    after(ticks: 5) {
                        fulfill(0)
                        reject(Error.e1)
                    }
                }
                promise.completion {
                    XCTAssertEqual($0.value, 0)
                    finish()
                }
            }

            expect("trying to fulfill immediately then reject delayed") { finish in
                let promise = Promise<Int>() { fulfill, reject in
                    fulfill(0)
                    after(ticks: 5) {
                        reject(Error.e1)
                    }
                }
                promise.completion {
                    XCTAssertEqual($0.value, 0)
                    finish()
                }
            }
        }
    }
    
    func test_2_1_3() {
        test("2.1.3.1: When rejected, a promise: must not transition to any other state.") {

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

            expect("trying to reject then immediately fulfill") { finish in
                let promise = Promise<Int>() { fulfill, reject in
                    reject(Error.e1)
                    fulfill(1)
                }
                promise.completion {
                    XCTAssertEqual($0.error as? Error, Error.e1)
                    finish()
                }
            }

            expect("trying to reject then fulfill, delayed") { finish in
                let promise = Promise<Int>() { fulfill, reject in
                    after(ticks: 5) {
                        reject(Error.e1)
                        fulfill(1)
                    }
                }
                promise.completion {
                    XCTAssertEqual($0.error as? Error, Error.e1)
                    finish()
                }
            }

            expect("trying to reject immediately then fulfill delayed") { finish in
                let promise = Promise<Int>() { fulfill, reject in
                    reject(Error.e1)
                    after(ticks: 5) {
                        fulfill(1)
                    }
                }
                promise.completion {
                    XCTAssertEqual($0.error as? Error, Error.e1)
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
                    Promise<Int>.fulfilledAsync().then {
                        XCTAssertEqual($0, dummy)
                        finish()
                    }
                }

                expect("fulfill immediately") { finish in
                    Promise<Int>(value: dummy).then {
                        XCTAssertEqual($0, dummy)
                        finish()
                    }
                }
            }

            test("2.2.2.2: it must not be called before `promise` is fulfilled") {
                expect("fulfilled after a delay") { finish in
                    let (promise, fulfill, _) = Promise<Int>.deferred()

                    var called = false
                    promise.then { _ -> Void in
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
                    let (promise, _, _) = Promise<Int>.deferred()

                    promise.then { _ -> Void in
                        XCTFail()
                    }
                    after(ticks: 5) {
                        finish()
                    }
                }
            }

            test("2.2.2.3: it must not be called more than once.") {
                expect("already-fulfilled") { finish in
                    let promise = Promise<Int>(value: dummy)

                    var timesCalled = 0
                    promise.then { _ -> Void in
                        timesCalled += 1
                        XCTAssertEqual(timesCalled, 1)
                    }

                    after(ticks: 20) {
                        finish()
                        XCTAssertEqual(timesCalled, 1)
                    }
                }

                expect("trying to fulfill a pending promise more than once, immediately") { finish in
                    let (promise, fulfill, _) = Promise<Int>.deferred()

                    var timesCalled = 0
                    promise.then { _ -> Void in
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
                    let (promise, fulfill, _) = Promise<Int>.deferred()

                    var timesCalled = 0
                    promise.then { _ -> Void in
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
                    let (promise, fulfill, _) = Promise<Int>.deferred()

                    var timesCalled = 0
                    promise.then {
                        XCTAssertEqual($0, dummy)
                        timesCalled += 1
                        XCTAssertEqual(timesCalled, 1)
                    }

                    fulfill(dummy)

                    after(ticks: 5) {
                        fulfill(dummy)
                    }

                    after(ticks: 25) {
                        finish()
                        XCTAssertEqual(timesCalled, 1)
                    }
                }

                expect("when multiple `then` calls are made, spaced apart in time") { finish in
                    let (promise, fulfill, _) = Promise<Int>.deferred()

                    var timesCalled = 0

                    after(ticks: 5) {
                        promise.then {
                            XCTAssertEqual($0, dummy)
                            timesCalled += 1
                            XCTAssertEqual(timesCalled, 1)
                        }
                    }

                    after(ticks: 10) {
                        promise.then {
                            XCTAssertEqual($0, dummy)
                            timesCalled += 1
                            XCTAssertEqual(timesCalled, 2)
                        }
                    }

                    after(ticks: 15) {
                        promise.then {
                            XCTAssertEqual($0, dummy)
                            timesCalled += 1
                            XCTAssertEqual(timesCalled, 3)
                            finish()
                        }
                    }

                    after(ticks: 20) {
                        fulfill(dummy)
                    }
                }

                expect("when `then` is interleaved with fulfillment") { finish in
                    let (promise, fulfill, _) = Promise<Int>.deferred()

                    var timesCalled = 0

                    promise.then {
                        XCTAssertEqual($0, dummy)
                        timesCalled += 1
                        XCTAssertEqual(timesCalled, 1)
                    }

                    fulfill(dummy)

                    promise.then {
                        XCTAssertEqual($0, dummy)
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
                    Promise<Int>.rejectedAsync().catch {
                        XCTAssertEqual($0 as! Error, Error.e1)
                        finish()
                    }
                }

                expect("already-rejected") { finish in
                    Promise<Int>(error: Error.e1).catch {
                        XCTAssertEqual($0 as! Error, Error.e1)
                        finish()
                    }
                }
            }

            test("2.2.3.2: it must not be called before `promise` is rejected") {

                expect("rejected after a delay") { finish in
                    let (promise, _, reject) = Promise<Int>.deferred()

                    var called = false
                    promise.catch { _ -> Void in
                        called = true
                        finish()
                    }
                    promise.then { _ in
                        XCTFail()
                    }
                    after(ticks: 5) {
                        XCTAssertFalse(called)
                        reject(Error.e1)
                    }
                }

                expect("never rejected") { finish in
                    let (promise, _, _) = Promise<Int>.deferred()

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
                    let promise = Promise<Int>(error: Error.e1)

                    var timesCalled = 0
                    promise.catch {
                        XCTAssertEqual($0 as? Error, Error.e1)
                        timesCalled += 1
                        XCTAssertEqual(timesCalled, 1)
                    }

                    after(ticks: 25) {
                        finish()
                        XCTAssertEqual(timesCalled, 1)
                    }
                }

                expect("trying to reject a pending promise more than once, immediately") { finish in
                    let (promise, _, reject) = Promise<Int>.deferred()

                    var timesCalled = 0
                    promise.catch {
                        XCTAssertEqual($0 as? Error, Error.e1)
                        timesCalled += 1
                        XCTAssertEqual(timesCalled, 1)
                    }

                    reject(Error.e1)
                    reject(Error.e1)

                    after(ticks: 25) {
                        finish()
                        XCTAssertEqual(timesCalled, 1)
                    }
                }

                expect("trying to reject a pending promise more than once, delayed") { finish in
                    let (promise, _, reject) = Promise<Int>.deferred()

                    var timesCalled = 0
                    promise.catch {
                        XCTAssertEqual($0 as? Error, Error.e1)
                        timesCalled += 1
                        XCTAssertEqual(timesCalled, 1)
                    }

                    after(ticks: 5) {
                        reject(Error.e1)
                        reject(Error.e1)
                    }

                    after(ticks: 25) {
                        finish()
                        XCTAssertEqual(timesCalled, 1)
                    }
                }

                expect("trying to reject a pending promise more than once, immediately then delayed") { finish in
                    let (promise, _, reject) = Promise<Int>.deferred()

                    var timesCalled = 0
                    promise.catch {
                        XCTAssertEqual($0 as? Error, Error.e1)
                        timesCalled += 1
                        XCTAssertEqual(timesCalled, 1)
                    }

                    reject(Error.e1)
                    after(ticks: 5) {
                        reject(Error.e1)
                    }

                    after(ticks: 25) {
                        finish()
                        XCTAssertEqual(timesCalled, 1)
                    }
                }

                expect("when multiple `then` calls are made, spaced apart in time") { finish in
                    let (promise, _, reject) = Promise<Int>.deferred()

                    var timesCalled = 0
                    promise.catch {
                        XCTAssertEqual($0 as? Error, Error.e1)
                        timesCalled += 1
                        XCTAssertEqual(timesCalled, 1)
                    }

                    after(ticks: 5) {
                        promise.catch {
                            XCTAssertEqual($0 as? Error, Error.e1)
                            timesCalled += 1
                            XCTAssertEqual(timesCalled, 2)
                        }
                    }

                    after(ticks: 10) {
                        promise.catch {
                            XCTAssertEqual($0 as? Error, Error.e1)
                            timesCalled += 1
                            XCTAssertEqual(timesCalled, 3)
                            finish()
                        }
                    }

                    after(ticks: 15) {
                        reject(Error.e1)
                    }
                }

                expect("when `then` is interleaved with rejection") { finish in
                    let (promise, _, reject) = Promise<Int>.deferred()

                    var timesCalled = 0
                    promise.catch {
                        XCTAssertEqual($0 as? Error, Error.e1)
                        timesCalled += 1
                        XCTAssertEqual(timesCalled, 1)
                    }

                    reject(Error.e1)

                    promise.catch {
                        XCTAssertEqual($0 as? Error, Error.e1)
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
                    let promise = Promise<Int>(value: dummy)

                    var thenHasReturned = false

                    promise.then { _ in
                        XCTAssertEqual(thenHasReturned, true)
                        finish()
                    }
                    
                    thenHasReturned = true;
                }

                expect("`catch`") { finish in
                    let promise = Promise<Int>(error: Error.e1)

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
                    let (promise, fulfill, _) = Promise<Int>.deferred()

                    var thenCalled = false;

                    promise.then { _ in
                        thenCalled = true;
                    }

                    fulfill(dummy)

                    XCTAssertEqual(thenCalled, false)
                }

                test("when `onFulfilled` is added immediately after the promise is fulfilled") {
                    let (promise, fulfill, _) = Promise<Int>.deferred()

                    var thenCalled = false;

                    fulfill(dummy)

                    promise.then { _ in
                        thenCalled = true;
                    }
                    
                    XCTAssertEqual(thenCalled, false)
                }

                expect("when one `onFulfilled` is added inside another `onFulfilled`") { finish in
                    let promise = Promise<Int>(value: dummy)

                    var firstOnFulfilledFinished = false

                    promise.then { _ in
                        promise.then { _ in
                            XCTAssertEqual(firstOnFulfilledFinished, true)
                            finish()
                        }
                        firstOnFulfilledFinished = true
                    }
                }

                expect("when `onFulfilled` is added inside an `onRejected`") { finish in
                    let promise = Promise<Int>(error: Error.e1)
                    let promise2 = Promise<Int>(value: dummy)

                    var firstOnRejectedFinished = false

                    promise.catch { _ in
                        promise2.then { _ in
                            XCTAssertEqual(firstOnRejectedFinished, true)
                            finish()
                        }
                        firstOnRejectedFinished = true
                    }
                }

                expect("when the promise is fulfilled asynchronously") { finish in
                    let (promise, fulfill, _) = Promise<Int>.deferred()

                    var firstStackFinished = false

                    after(ticks: 1) {
                        fulfill(dummy)
                        firstStackFinished = true
                    }

                    promise.then { _ in
                        XCTAssertEqual(firstStackFinished, true)
                        finish()
                    }
                }
            }

            test("Clean-stack execution ordering tests (rejection case)") {
                test("when `onRejected` is added immediately before the promise is rejected") {
                    let (promise, _, reject) = Promise<Int>.deferred()

                    var catchCalled = false;

                    promise.catch { _ in
                        catchCalled = true;
                    }

                    reject(Error.e1)

                    XCTAssertEqual(catchCalled, false)
                }

                test("when `onRejected` is added immediately after the promise is rejected") {
                    let (promise, _, reject) = Promise<Int>.deferred()

                    var catchCalled = false;

                    reject(Error.e1)

                    promise.catch { _ in
                        catchCalled = true;
                    }

                    XCTAssertEqual(catchCalled, false)
                }

                expect("when one `onRejected` is added inside another `onRejected`") { finish in
                    let promise = Promise<Int>(error: Error.e1)

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
                    let promise = Promise<Int>(value: dummy)
                    let promise2 = Promise<Int>(error: Error.e1)

                    var firstOnFulfilledFinished = false

                    promise.then { _ in
                        promise2.catch { _ in
                            XCTAssertEqual(firstOnFulfilledFinished, true)
                            finish()
                        }
                        firstOnFulfilledFinished = true
                    }
                }

                expect("when the promise is rejected asynchronously") { finish in
                    let (promise, _, reject) = Promise<Int>.deferred()

                    var firstStackFinished = false

                    after(ticks: 1) {
                        reject(Error.e1)
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
                    let promise = Promise<Int>.fulfilledAsync()

                    let finisher = Finisher(finish, 3)

                    promise.then {
                        XCTAssertEqual($0, dummy)
                        finisher.finish()
                    }

                    promise.then {
                        XCTAssertEqual($0, dummy)
                        finisher.finish()
                    }

                    promise.then {
                        XCTAssertEqual($0, dummy)
                        finisher.finish()
                    }
                }

                test("multiple fulfillment handlers, one of which throws") {
                    // Doesn't make sense in Pill, cause it doesn't allow throws (yet?)
                }

                expect("results in multiple branching chains with their own fulfillment values") { finish in
                    let finisher = Finisher(finish, 3)

                    let promise = Promise<Int>.fulfilledAsync()

                    promise.then { val -> Int in
                        XCTAssertEqual(val, dummy)
                        return 2
                    }.then {
                        XCTAssertEqual($0, 2)
                        finisher.finish()
                    }

                    promise.then { val -> Int in
                        XCTAssertEqual(val, dummy)
                        return 3
                    }.then {
                        XCTAssertEqual($0, 3)
                        finisher.finish()
                    }

                    promise.then { val -> Int in
                        XCTAssertEqual(val, dummy)
                        return 4
                    }.then {
                        XCTAssertEqual($0, 4)
                        finisher.finish()
                    }
                }

                expect("`onFulfilled` handlers are called in the original order") { finish in
                    let promise = Promise<Int>.fulfilledAsync()
                    var callCount = 0

                    promise.then {
                        XCTAssertEqual($0, dummy)
                        callCount += 1
                        XCTAssertEqual(callCount, 1)
                    }


                    promise.then {
                        XCTAssertEqual($0, dummy)
                        callCount += 1
                        XCTAssertEqual(callCount, 2)
                    }

                    promise.then {
                        XCTAssertEqual($0, dummy)
                        callCount += 1
                        XCTAssertEqual(callCount, 3)
                        finish()
                    }

                    promise.catch { _ in XCTFail() }
                }

                expect("even when one handler is added inside another handle") { finish in
                    let promise = Promise<Int>.fulfilledAsync()
                    var callCount = 0

                    promise.then {
                        XCTAssertEqual($0, dummy)
                        callCount += 1
                        XCTAssertEqual(callCount, 1)
                        
                        promise.then {
                            XCTAssertEqual($0, dummy)
                            callCount += 1
                            XCTAssertEqual(callCount, 2)
                            
                            promise.then {
                                XCTAssertEqual($0, dummy)
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
                    let promise = Promise<Int>.rejectedAsync()

                    let finisher = Finisher(finish, 3)

                    promise.catch {
                        XCTAssertEqual($0 as? Error, Error.e1)
                        finisher.finish()
                    }

                    promise.catch {
                        XCTAssertEqual($0 as? Error, Error.e1)
                        finisher.finish()
                    }

                    promise.catch {
                        XCTAssertEqual($0 as? Error, Error.e1)
                        finisher.finish()
                    }
                }

                test("multiple rejection handlers, one of which throws") {
                    // Doesn't make sense in Pill, cause it doesn't allow throws (yet?)
                }

                expect("`onRejected` handlers are called in the original order") { finish in
                    let promise = Promise<Int>.rejectedAsync()
                    var callCount = 0

                    promise.catch {
                        XCTAssertEqual($0 as? Error, Error.e1)
                        callCount += 1
                        XCTAssertEqual(callCount, 1)
                    }


                    promise.catch {
                        XCTAssertEqual($0 as? Error, Error.e1)
                        callCount += 1
                        XCTAssertEqual(callCount, 2)
                    }

                    promise.catch {
                        XCTAssertEqual($0 as? Error, Error.e1)
                        callCount += 1
                        XCTAssertEqual(callCount, 3)
                        finish()
                    }

                    promise.then { _ in XCTFail() }
                }

                expect("even when one handler is added inside another handle") { finish in
                    let promise = Promise<Int>.rejectedAsync()
                    var callCount = 0

                    promise.catch {
                        XCTAssertEqual($0 as? Error, Error.e1)
                        callCount += 1
                        XCTAssertEqual(callCount, 1)

                        promise.catch {
                            XCTAssertEqual($0 as? Error, Error.e1)
                            callCount += 1
                            XCTAssertEqual(callCount, 2)
                            
                            promise.catch {
                                XCTAssertEqual($0 as? Error, Error.e1)
                                callCount += 1
                                XCTAssertEqual(callCount, 3)
                                finish()
                            }
                        }
                    }
                }
            }
        }

        func testChaining() {
            test("2.2.7: `then` must return a promise: `promise2 = promise1.then(onFulfilled, onRejected)") {

                expect("`then` returns promise") { finish in
                    let promise = Promise<Int>.fulfilledAsync()
                    var callCount = 0

                    let promise2 = promise.then {
                        XCTAssertEqual($0, dummy)
                        callCount += 1
                        XCTAssertEqual(callCount, 1)
                    }

                    promise2.catch { _ in XCTFail() }

                    promise2.then {
                        XCTAssertEqual($0, dummy)
                        callCount += 1
                        XCTAssertEqual(callCount, 2)
                        finish()
                    }
                }
            }

            test("2.3.2: If `x` is a promise, adopt its state") {
                expect("2.3.2.1: If `x` is pending, `promise` must remain pending until `x` is fulfilled or rejected.") { finish in
                    let promise = Promise<Int>() { _ in }
                    let promise2 = promise.then { _ in
                        XCTFail()
                    }
                    XCTAssertTrue(promise.isPending)
                    XCTAssertTrue(promise2.isPending)
                    after(ticks: 4) {
                        finish()
                    }
                }
            }

            test("2.3.2.2: If/when `x` is fulfilled, fulfill `promise` with the same value.") {
                expect("`x` is already-fulfilled") { finish in
                    let promise = Promise<Int>(value: dummy)
                    let promise2 = promise.then { _ in }
                    promise2.then {
                        XCTAssertEqual($0, dummy)
                        finish()
                    }
                }

                expect("`x` is eventually-fulfilled") { finish in
                    let promise = Promise<Int>.fulfilledAsync()
                    let promise2 = promise.then { _ in }
                    promise2.then {
                        XCTAssertEqual($0, dummy)
                        finish()
                    }
                }
            }

            test("2.3.2.3: If/when `x` is rejected, reject `promise` with the same reason.") {
                expect("`x` is already-rejected") { finish in
                    let promise = Promise<Int>(error: Error.e1)
                    let promise2 = promise.then { _ in }
                    promise2.catch {
                        XCTAssertEqual($0 as? Error, Error.e1)
                        finish()
                    }
                }

                expect("`x` is eventually-rejected") { finish in
                    let promise = Promise<Int>.rejectedAsync()
                    let promise2 = promise.then { _ in }
                    promise2.catch {
                        XCTAssertEqual($0 as? Error, Error.e1)
                        finish()
                    }
                }
            }
        }
    }
}
