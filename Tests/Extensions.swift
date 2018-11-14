// The MIT License (MIT)
//
// Copyright (c) 2016-2018 Alexander Grebenyuk (github.com/kean).

import XCTest
import Foundation
import Pill


// MARK: XCTestCase

var descriptions = [String]() // stack of test descriptions

extension XCTestCase {
    func test(_ description: String, _ block: () -> Void = {}) -> Void {
        precondition(Thread.isMainThread)

        descriptions.append(description)
        block()
        descriptions.removeLast()
    }
    
    func expect(_ description: String = "GenericExpectation", count: Int = 1, file: StaticString = #file, line: UInt = #line, _ block: (_ fulfill: @escaping () -> Void) -> Void) {
        precondition(Thread.isMainThread)

        descriptions.append(description)
        let expectation = self.expectation(description: descriptions.joined(separator: " -> "))
        expectation.expectedFulfillmentCount = count
        descriptions.removeLast()

        block({ expectation.fulfill() })

        wait()
    }

    func expectation() -> XCTestExpectation {
        return self.expectation(description: "GenericExpectation")
    }

    func expectNotification(_ name: Notification.Name, object: AnyObject? = nil, handler: XCTNSNotificationExpectation.Handler? = nil) -> XCTestExpectation {
        return self.expectation(forNotification: NSNotification.Name(rawValue: name.rawValue), object: object, handler: handler)
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

enum MyError: Swift.Error {
    case e1
    case e2
}

let sentinel = 1

extension Future {    
    class func eventuallySuccessfull() -> Future<Int, Error> {
        return Future<Int, Error>() { success, _ in
            DispatchQueue.global().async {
                success(sentinel)
            }
        }
    }

    class func eventuallyFailed() -> Future<Int, MyError> {
        return Future<Int, MyError>() { _, fail in
            DispatchQueue.global().async {
                fail(MyError.e1)
            }
        }
    }
}
