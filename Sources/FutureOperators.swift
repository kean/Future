// The MIT License (MIT)
//
// Copyright (c) 2016-2020 Alexander Grebenyuk (github.com/kean).

// MARK: - Map, FlatMap

extension Future {

    /// Returns a future with the result of mapping the given closure over the
    /// current future's value.
    public func map<NewValue>(_ transform: @escaping (Value) -> NewValue) -> Future<NewValue, Error> {
        // Technically the same as `flatMap { Future<NewValue, Error>(value: transform($0) }`
        // but this implementation is optimized for performance.
        let promise = Future<NewValue, Error>.Promise()
        cascade(success: { promise.succeed(value: transform($0)) }, failure: promise.fail)
        return promise.future
    }

    // Allow:
    // Future<T, E>.flatMap { Future<U, E> }
    // Future<T, E>.flatMap { Future<U, Never> }

    /// Returns a future which is eventually resolved with the result of the
    /// future returned by the `transform` closure. The `transform` closure is
    /// called when the current future receives a value.
    ///
    /// Allows you to "chain" multiple async operations:
    ///
    /// ```
    /// let avatar = user
    ///     .map { $0.avatarURL }
    ///     .flatMap(loadAvatar)
    ///
    /// // user: Future<User, Error>
    /// // func loadAvatar(url: URL) -> Future<Avatar, Error>
    /// ```
    public func flatMap<NewValue>(_ transform: @escaping (Value) -> Future<NewValue, Error>) -> Future<NewValue, Error> {
        let promise = Future<NewValue, Error>.Promise()
        cascade(success: { transform($0).cascade(completion: promise.resolve) }, failure: promise.fail)
        return promise.future
    }

    public func flatMap<NewValue>(_ transform: @escaping (Value) -> Future<NewValue, Never>) -> Future<NewValue, Error> {
        // Technically the same as `flatMap { transform($0).castError() }`, but
        // we're doing it from scratch to avoid additional allocations from `castError`
        let promise = Future<NewValue, Error>.Promise()
        cascade(success: { transform($0).cascade(success: promise.succeed) }, failure: promise.fail)
        return promise.future
    }
}

extension Future where Error == Never {

    // Allow:
    // Future<T, Never>.flatMap { Future<U, E> }
    // Future<T, Never>.flatMap { Future<U, Never> } // disambiguate

    public func flatMap<NewValue, NewError>(_ transform: @escaping (Value) -> Future<NewValue, NewError>) -> Future<NewValue, NewError> {
        let promise = Future<NewValue, NewError>.Promise()
        cascade(success: { transform($0).cascade(completion: promise.resolve) })
        return promise.future
    }

    public func flatMap<NewValue>(_ transform: @escaping (Value) -> Future<NewValue, Never>) -> Future<NewValue, Never> {
        let promise = Future<NewValue, Never>.Promise()
        cascade(success: { transform($0).cascade(success: promise.succeed) })
        return promise.future
    }
}

// MARK: - MapError, FlatMapError

extension Future {

    /// Returns a future with the error which is the result of mapping the given
    /// closure over the current future's error.
    public func mapError<NewError>(_ transform: @escaping (Error) -> NewError) -> Future<Value, NewError> {
        let promise = Future<Value, NewError>.Promise()
        cascade(success: promise.succeed, failure: { promise.fail(error: transform($0)) })
        return promise.future
    }

    /// Returns a future which is eventually resolved with the result of the
    /// future returned by the `transform` closure. The `transform` closure is
    /// called when the current future receives an error.
    ///
    /// Allows you to continue the chain of futures by "recovering" from an error
    /// with a new future.
    public func flatMapError<NewError>(_ transform: @escaping (Error) -> Future<Value, NewError>) -> Future<Value, NewError> {
        let promise = Future<Value, NewError>.Promise()
        cascade(success: promise.succeed, failure: { transform($0).cascade(completion: promise.resolve) })
        return promise.future
    }
}

// MARK: - Zip

extension Future where Value == Any, Error == Swift.Error {

    /// Returns a future which succeedes when all the given futures succeed. If
    /// any of the futures fail, the returned future also fails with that error.
    public static func zip<V1, V2, E>(_ f1: Future<V1, E>, _ f2: Future<V2, E>) -> Future<(V1, V2), E> {
        let promise = Future<(V1, V2), E>.Promise()
        func success(value: Any) {
            guard let v1 = f1.value, let v2 = f2.value else { return }
            promise.succeed(value: (v1, v2))
        }
        f1.cascade(success: success, failure: promise.fail)
        f2.cascade(success: success, failure: promise.fail)
        return promise.future
    }

    /// Returns a future which succeedes when all the given futures succeed. If
    /// any of the futures fail, the returned future also fails with that error.
    public static func zip<V1, V2, V3, E>(_ f1: Future<V1, E>, _ f2: Future<V2, E>, _ f3: Future<V3, E>) -> Future<(V1, V2, V3), E> {
        return Future.zip(f1, Future.zip(f2, f3)).map { ($0.0, $0.1.0, $0.1.1) }
    }

    /// Returns a future which succeedes when all the given futures succeed. If
    /// any of the futures fail, the returned future also fails with that error.
    public static func zip<V, E>(_ futures: [Future<V, E>]) -> Future<[V], E> {
        return Future.reduce([V](), futures) { $0 + [$1] }
    }
}

// MARK: - Reduce

extension Future where Value == Any, Error == Swift.Error {

    /// Returns a future that succeeded when all the given futures succeed.
    /// The future contains the result of combining the `initialResult` with
    /// the values of all the given future. If any of the futures fail, the
    /// returned future also fails with that error.
    public static func reduce<V1, V2, E>(_ initialResult: V1, _ futures: [Future<V2, E>], _ combiningFunction: @escaping (V1, V2) -> V1) -> Future<V1, E> {
        return futures.reduce(Future<V1, E>(value: initialResult)) { lhs, rhs in
            return Future.zip(lhs, rhs).map(combiningFunction)
        }
    }
}
