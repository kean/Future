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
