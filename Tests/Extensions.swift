// The MIT License (MIT)
//
// Copyright (c) 2016 Alexander Grebenyuk (github.com/kean).

import XCTest
import Foundation
import Pill


// MARK: XCTestCase

var descriptions = [String]() // stack of test descriptions

extension XCTestCase {
    func test(_ description: String, _ block: (Void) -> Void = {}) -> Void {
        precondition(Thread.isMainThread)

        descriptions.append(description)
        block()
        descriptions.removeLast()
    }
    
    func expect(_ description: String = "GenericExpectation", _ block: (_ fulfill: @escaping (Void) -> Void) -> Void) {
        precondition(Thread.isMainThread)

        descriptions.append(description)
        let expectation = self.expectation(description: descriptions.joined(separator: " -> "))
        descriptions.removeLast()

        block({ expectation.fulfill() })

        wait()
    }

    func makeExpectation() -> XCTestExpectation {
        return self.expectation(description: "GenericExpectation")
    }

    func expectNotification(_ name: Notification.Name, object: AnyObject? = nil, handler: XCNotificationExpectationHandler? = nil) -> XCTestExpectation {
        return self.expectation(forNotification: name.rawValue, object: object, handler: handler)
    }

    func wait(_ timeout: TimeInterval = 2.0, handler: XCWaitCompletionHandler? = nil) {
        waitForExpectations(timeout: timeout, handler: handler)
    }
}

func rnd() -> Int {
    return Int(arc4random())
}

func rnd(_ uniform: Int) -> Int {
    return Int(arc4random_uniform(UInt32(uniform)))
}

func after(ticks: Int, execute body: @escaping () -> Void) {
    if ticks == 0 {
        body()
    } else {
        DispatchQueue.main.async {
            after(ticks: ticks - 1, execute: body)
        }
    }
}



// MARK: Promise

enum Error: Swift.Error {
    case e1
    case e2
}

let sentinel = 1

extension Promise {
    class func deferred() -> (promise: Promise, fulfill: (T) -> Void, reject: (Error) -> Void) {
        var fulfill: ((T) -> Void)!
        var reject: ((Error) -> Void)!
        let promise = self.init { fulfill = $0; reject = $1 }
        return (promise, fulfill, reject)
    }
    
    class func fulfilledAsync() -> Promise<Int> {
        return Promise<Int>() { fulfill, _ in
            DispatchQueue.global().async {
                fulfill(sentinel)
            }
        }
    }

    class func rejectedAsync() -> Promise<Int> {
        return Promise<Int>() { _, reject in
            DispatchQueue.global().async {
                reject(Error.e1)
            }
        }
    }
}

// MARK: Finisher

class Finisher {
    private var _count: Int
    private let _finish: (Void) -> Void

    init(_ finish: @escaping (Void) -> Void, _ count: Int) {
        self._finish = finish
        self._count = count
    }

    func finish() {
        _count -= 1
        XCTAssert(_count >= 0)
        if _count == 0 {
            _finish()
        }
    }
}
