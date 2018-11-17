// The MIT License (MIT)
//
// Copyright (c) 2016-2018 Alexander Grebenyuk (github.com/kean).

import Foundation
import Future

extension FutureExtension where Base: URLSession {
    /// Returns a future which signal when object is deallocated.
    var deallocated: Future<Void, Never> {
        let handler: DeinitHandler
        if let associatedHandler = objc_getAssociatedObject(base, &handle) as? DeinitHandler {
            handler = associatedHandler
        } else {
            handler = DeinitHandler()
            objc_setAssociatedObject(base, &handle, handler, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
        return handler.promise.future
    }
}

private var handle: UInt8 = 0

private class DeinitHandler: NSObject {
    deinit {
        promise.succeed(value: ())
    }

    let promise = Future<Void, Never>.promise
}
