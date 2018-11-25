<p align="left"><img src="https://user-images.githubusercontent.com/1567433/48920624-35d00680-ee9a-11e8-829b-47b0e9529d52.png" height="100"/>
<p align="left">A streamlined <code>Future&lt;Value, Error&gt;</code> implementation</p>
<p align="left">
<img src="https://img.shields.io/cocoapods/v/FutureX.svg?label=version">
<img src="https://img.shields.io/badge/platforms-iOS%2C%20macOS%2C%20watchOS%2C%20tvOS-lightgrey.svg">
<img src="https://img.shields.io/badge/supports-CocoaPods%2C%20Carthage%2C%20SwiftPM-green.svg">
<a href="https://travis-ci.org/kean/FutureX"><img src="https://travis-ci.org/kean/FutureX.svg?branch=master"></a>
<img src="https://img.shields.io/badge/test%20coverage-100%25-brightgreen.svg">
</p>

<hr/>

A **future** represents a result of a computation which may be available now, or in the future, or never. **FutureX** provides a streamlined **`Future<Value, Error>`** implementation. Futures enable easy composition of async tasks thanks to functions like `map`, `flatMap`, `zip`, `reduce` and many others.

FutureX is designed with ergonomics and performance in mind. It uses familiar functional terms so it's easy to learn and use. 

> <img src="https://user-images.githubusercontent.com/1567433/48973894-a584f380-f04a-11e8-88f8-b66c083a5bbb.png" width="40px"> <br/>
> Check out [**FutureX Community**](https://github.com/FutureXCommunity) for extensions for popular frameworks and more.

## Getting Started

- [**Quick Start Guide**](#quick-start-guide)
  * [Create Future](#create-future)
  * [Attach Callbacks](#attach-callbacks)
  * [`wait`](#wait), [`result`](#result)
- [**Functional Composition**](#functional-composition)
  * [`map`](#map-flatmap), [`flatMap`](#map-flatmap)
  * [`mapError`](#maperror-flatmaperror), [`flatMapError`](#maperror-flatmaperror)
  * [`zip`](#zip), [`reduce`](#reduce)
- [**Additions**](#additions)
  * [`first`](#first), [`forEach`](#foreach)
  * [`after`](#after), [`retry`](#retry)
  * [`materialize`](#materialize)
- [**Threading**](#threading)
- [**Cancellation**](#cancellation)
- [**Async/Await**](#asyncawait)
- [**Performance**](#performance)
 
## Quick Start Guide

Let's start with a quick overview of the types:

<img src="https://user-images.githubusercontent.com/1567433/48986011-26a5be80-f10f-11e8-8962-ee0e68c91c4e.png" width="680px">

### Create Future

The most common way to create a future is by using `Promise`:

```swift
func someAsyncOperation() -> Future<Value, Error> {
    let promise = Promise<Value, Error>()
    someAsyncOperationWithCallback { value, error in
        // If success
        promise.succeed(result: value)
        // If error
        promise.fail(error: error)
    }
    return promise.future
}
```

Sometimes a convenience `init` method comes handy:

```swift
Future<Int, Error> { promise in
    someAsyncOperationWithCallback { value, error in
        // Resolve the promise
    }
}
```

In some cases you need to create a future which already has a result:

```swift
Future(value: 1) // Automatically inferred to be Future<Int, Never>
Future<Int, MyError>(value: 1)
Future<Int, MyError>(error: .unknown)
```

### Attach Callbacks

To attach callbacks to the `Future` use  `on` method:

```swift
let future: Future<Value, Error>
future.on(success: { print("received value: \($0)" },
          failure: { print("failed with error: \($0)" }),
          completion: { print("completed with result: \($0)" })
```

Each callback is optional - you don't have to attach all at the same time. The future guarantees that it can be resolved with only one result, the callbacks are also guaranteed to run only once. 

By default the callbacks are run on `.main` scheduler. It runs immediately if on the main thread, otherwise asynchronously on the main thread. 

> See [**Threading**](#threading) for a rationale and more info.

### `wait`

Use `wait` method to block the current thread and wait until the future receives a result:

```swift
let result = future.wait() // Mostly useful for testing and debugging
```

### `result`

If the future already has a result you can read it synchronously:

```swift
class Future<Value, Error> {
    var value: Value? { get }
    var error: Error? { get }
    var result: Result<Value, Error> { get }
}
```

## Functional Composition

### `map`, `flatMap`

Use familiar `map` and `flatMap` function to transform the future's values and chain futures:

```swift
let user: Future<User, Error>
func loadAvatar(url: URL) -> Future<UIImage, Error>

let avatar = user
    .map { $0.avatarURL }
    .flatMap(loadAvatar)
```

If you are not familiar with `flatMap` it might be hard to wrap your head around it. But when it clicks, using it becomes second nature.

<img src="https://user-images.githubusercontent.com/1567433/48986010-26a5be80-f10f-11e8-8a98-00eae179f4ac.png" width="640px">

### `mapError`, `flatMapError`

`Future` has typed errors. To convert from one error type to another use `mapError`:

```swift
let request: Future<Data, URLError>
request.mapError(MyError.init(urlError:))
```

Use `flatMapError` to "recover" from an error.

### `zip`

Use  `zip`  to combine the result of up to three futures in a single future:

```swift
let user: Future<User, Error>
let avatar: Future<UIImage, Error>

Future.zip(user, avatar).on(success: { user, avatar in
    // use both values
})
```

Or to wait for the result of multiple futures:

```swift
Future.zip([future1, future2]).on(success: { values in
    // use an array of values
})
```

### `reduce`

Use `reduce` to combine the results of multiple futures:

```swift
let future1 = Future(value: 1)
let future2 = Future(value: 2)

Future.reduce(0, [future1, future2], +).on(success: { value in
    print(value) // prints "3"
})
```

## Additions

In addition to the primary interface, there is also a set of extensions to `Future` which includes multiple convenience functions. Not all of them are mentioned here, look into `FutureExtensions.swift` to find more!

### `first`

Use `first` to wait for a first future to succeed:

```swift
let requests: [Future<Value, Error>]
Future.first(requests).on(success: { print("got response!") })
```

### `forEach`

Use `forEach` to perform the work in a sequence:

```swift
// `startWork` is a function that returns a future
Future.forEach([startWork, startOtherWork]) { future in
    // In the callback you can subscribe to each future when work is started
    future.on(success: { print("some work completed") })
}
```

### `after`

Use `after` to produce a value after a given time interval.

```swift
Future.after(seconds: 2).on { _ in print("2 seconds have passed") })
```

### `retry`

Use `retry` to perform the given number of attempts to finish the work successfully.

```swift
func startSomeWork() -> Future<Value, Error>

Future.retry(attempts: 3, delay: .seconds(3), startSomeWork)
```

Retry is flexible. It allows you to specify multiple delay strategies including exponential backoff, to inspect the error before retrying and more.

### `materialize`

This one is fascinating. It converts `Future<Value, Error>` to `Future<Future<Value, Error>.Result, Never>` - a future which never fails. It always succeeds with the result of the initial future. Now, why would you want to do that? Turns out `materialize` composes really well with other functions like `zip`, `reduce`, `first`, etc. All of these functions fail as soon as one of the given futures fail, but with `materialize` you can change the behavior of these functions so that they would wait until all futures are resolved, no matter successfully or with an error.

> Notice that we use native `Never` type to represent a situation when error can never be produced.

```swift
Future.zip(futures.map { $0.materialize() }).on(success: { results in
    // All futures are resolved and we get the list of all of the results -
    // either values or errors.
})
```

## Threading

On iOS users expect UI renders to happen synchronously. To accommodate that, by default, the callbacks are run using `Scheduler.main`. It runs work immediately if on the main thread, otherwise asynchronously on the main thread. The design is similar to the reactive frameworks like RxSwift. It opens a whole new area for using futures which are traditionally asynchronous by design. 

There are three schedulers available:

```swift
enum Scheduler {
    /// Runs immediately if on the main thread, otherwise asynchronously on the main thread.
    static var main: ScheduleWork

    /// Immediately executes the given closure.
    static var immediate: ScheduleWork

    /// Runs asynchronously on the given queue.
    static func async(on queue: DispatchQueue, flags: DispatchWorkItemFlags = []) -> ScheduleWork
}
```

`ScheduleWork` is just a function so you can easily provide a custom implementation.

To change the scheduler on which callbacks are called use `observe(on:)`:

```swift
// There are two variants, one with `DispatchQueue`, one with `Scheduler`.
// Here's the one with `DispatchQueue`:
future.observe(on: .global())
    on(success: { print("value: \($0)" })
```

You can also use `observe(on:)` to perform transformations like `map`, `tryMap` and others on background queues:

```swift
future.observe(on: .global())
    .map { /* heavy operation */ }
```

Please keep in mind that only the future returns directly by `observe(on:)` is guaranteed to run its continuations on the given queue (or scheduler).

## Cancellation

Cancellation is a concern orthogonal to `Future`. Think about `Future` as a simple callback replacement - callbacks don't support cancellation.

FutureX implements a [`CancellationToken`](https://kean.github.io/post/cancellation-token) pattern for cooperative cancellation of async tasks. A token is created through a cancellation token source.

```swift
let cts = CancellationTokenSource()
asyncWork(token: cts.token).on(success: {
    // Operation finished
}) 

// At some point later, can be on the other thread:
cts.cancel()
```

To cancel multiple async tasks, you can pass the same token to all of them. Implementing async tasks that support cancellation is easy:

```swift
func loadData(with url: URL, _ token: CancellationToken = .none) -> Future<Data, URLError> {
    let promise = Promise<Data, URLError>()
    let task = URLSession.shared.dataTask(with: url) { data, error in
        // Handle response
    }
    token.register(task.cancel)
    return promise.future
}
```

The task has full control over cancellation. You can ignore it, you can fail a promise with a specific error, return a partial result, or not resolve a promise at all.

## Async/Await

Async/await is often built on top of futures. When [async/await](https://gist.github.com/lattner/429b9070918248274f25b714dcfc7619) support is eventually added to Swift, it would be relatively easy to replace the code that uses futures with async/await.

> There is a [fake (blocking) version](https://gist.github.com/kean/24a3d0c2538647b33006b344ebc283a7) of async/await built for FutureX. It's not meant to be used in production.

## Performance

Performance is a top priority for FutureX. Every feature was built with performance in mind.

We avoid dynamic dispatch, reduce the number of allocations and deallocations, avoid doing any unnecessary work, implement methods in sometimes less elegant but more performant way, avoid locking as much as possible, and more. There are also some key design differences that give FutureX an edge over other frameworks.

## Requirements

- iOS 9.0 / watchOS 2.0 / OS X 10.11 / tvOS 9.0
- Xcode 10
- Swift 4.2

## License

FutureX is available under the MIT license. See the LICENSE file for more info.
