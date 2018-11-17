// The MIT License (MIT)
//
// Copyright (c) 2016-2018 Alexander Grebenyuk (github.com/kean).

import Foundation
import Future

extension FutureExtension where Base: URLSession {
    /// Loads data and decodes an object from the response data.
    public func object<T: Decodable>(for url: URL, token: CancellationToken = .noOp) -> Future<T, Error> {
        return object(for: URLRequest(url: url), token: token)
    }

    /// Loads data and decodes an object from the response data.
    public func object<T: Decodable>(for request: URLRequest, token: CancellationToken = .noOp) -> Future<T, Error> {
        return data(for: request, token: token).mapThrowing { data in
            return try JSONDecoder().decode(T.self, from: data)
        }
    }

    /// Loads data for a given request.
    ///
    /// - parameter token: A cancellation token that can be used to cancel the
    /// request, `.noOp` token by default.
    public func data(for url: URL, token: CancellationToken = .noOp) -> Future<Data, Error> {
        return data(for: URLRequest(url: url), token: token)
    }

    /// Loads data for a given request.
    ///
    /// - parameter token: A cancellation token that can be used to cancel the
    /// request, `.noOp` token by default.
    public func data(for request: URLRequest, token: CancellationToken = .noOp) -> Future<Data, Error> {
        let promise = Future<Data, Error>.promise
        let task = base.dataTask(with: request) { (data, _, error) in
            if let data = data {
                promise.succeed(value: data)
            } else {
                promise.fail(error: error ?? URLError(.unknown))
            }
        }
        token.register(task.cancel)
        return promise.future
    }
}
