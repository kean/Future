// The MIT License (MIT)
//
// Copyright (c) 2016 Alexander Grebenyuk (github.com/kean).

import XCTest
import Foundation
import Pill


// MARK: XCTestCase

extension XCTestCase {
    func test(_ description: String? = nil, _ block: (Void) -> Void = {}) -> Void {
        block()
    }
    
    func expect(_ description: String = "GenericExpectation", _ block: (_ fulfill: @escaping (Void) -> Void) -> Void) {
        let expectation = self.expectation(description: description)
        block({ expectation.fulfill() })
    }

    func makeExpectation() -> XCTestExpectation {
        return self.expectation(description: "GenericExpectation")
    }

    func expectNotification(_ name: Notification.Name, object: AnyObject? = nil, handler: XCNotificationExpectationHandler? = nil) -> XCTestExpectation {
        return self.expectation(forNotification: name.rawValue, object: object, handler: handler)
    }

    func wait(_ timeout: TimeInterval = 2.0, handler: XCWaitCompletionHandler? = nil) {
        self.waitForExpectations(timeout: timeout, handler: handler)
    }
}

func rnd() -> Int {
    return Int(arc4random())
}

func rnd(_ uniform: Int) -> Int {
    return Int(arc4random_uniform(UInt32(uniform)))
}


// MARK: Promise

enum Error: Swift.Error {
    case dummy
    case e1
    case e2
}

let dummy = 1

extension Promise {
    class func tuple() -> (promise: Promise, fulfill: (T) -> Void, reject: (Error) -> Void) {
        var fulfill: ((T) -> Void)!
        var reject: ((Error) -> Void)!
        let promise = self.init { fulfill = $0; reject = $1 }
        return (promise, fulfill, reject)
    }
    
    class func fulfilled() -> Promise<Int> {
        return Promise<Int>() { fulfill, _ in
            DispatchQueue.global().async {
                fulfill(dummy)
            }
        }
    }
}
