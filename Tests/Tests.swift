// The MIT License (MIT)
//
// Copyright (c) 2016 Alexander Grebenyuk (github.com/kean).

import XCTest
import Foundation
import Pill

class PromiseTests: XCTestCase {
    func testThrows() {
        expect("`then (T) -> U` can throw") { finish in
            Promise(value: 1).then { value -> Int in
                throw Error.e1
            }.catch {
                XCTAssertEqual($0 as? Error, Error.e1)
                finish()
            }
        }
        
        expect("`then (T) -> Promise<U>` can throw") { finish in
            Promise(value: 1).then { value -> Promise<Int> in
                throw Error.e1
            }.catch {
                XCTAssertEqual($0 as? Error, Error.e1)
                finish()
            }
        }
        
        expect("`catch` can throw") { finish in
            Promise<Int>(error: Error.e1).catch { _ in
                throw Error.e2
            }.catch {
                XCTAssertEqual($0 as? Error, Error.e2)
                finish()
            }
        }
    }
}
