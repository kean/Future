<p align="left"><img src="https://user-images.githubusercontent.com/1567433/48664312-0b96d700-ea9d-11e8-9bd7-716879fa8dbf.png" height="60"/>
<p align="left">A streamlined <code>Future&lt;Value, Error&gt;</code> implementation with functional interface</p>
<p align="left">
<img src="https://img.shields.io/cocoapods/v/FutureX.svg?label=version">
<img src="https://img.shields.io/badge/platforms-iOS%2C%20macOS%2C%20watchOS%2C%20tvOS-lightgrey.svg">
<img src="https://img.shields.io/badge/supports-CocoaPods%2C%20Carthage%2C%20SwiftPM-green.svg">
<a href="https://travis-ci.org/kean/FutureX"><img src="https://travis-ci.org/kean/FutureX.svg?branch=master"></a>
<img src="https://img.shields.io/badge/test%20coverage-100%25-brightgreen.svg">
</p>

<hr/>

A future represents a result of a computation which may be available now, or in the future, or never.  `FutureX` provides a streamlined `Future<Value, Error>` with functional interface. Futures enable easy composition of asynchronous operations thanks to function like `map`, `flatMap`, `zip`, `reduce` and many others.

## Getting Started

- [**Quick Start Guide**](#quick-start-guide)
  * [Create Future](#create-future)
  * [Attach Callbacks](#attach-callbacks)
  * [Wait, Result](#wait-result)
- [**Functional Composition**](#functional-composition)
  * [Map, FlatMap](#map-flatmap)
  * [MapError, FlatMapError](#maperror-flatmaperror)
  * [Zip, Reduce](#zip-reduce)
- [**Additions**](#additions)
  * [First, ForEach](#first-foreach)
  * [After, Retry](#after-retry)
  * [Materialize](#materialize)
- [**Threading**](#threading)
- [**Cancellation**](#cancellation)
 
## Quick Start Guide

### Create Future

Using `Promise`:

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

Using a convenience init method:

```swift
let future = Future<Int, Error> { succeed, fail in
    someAsyncOperationWithCallback { value, error in
        // Succeed or fail
    }
}
```

With a value or an error:

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

### Wait, Result

Use `wait` method to block the current thread and wait until the future receives a result:

```swift
let result = future.wait() // Mostly useful for testing and debugging
```

If the future already has a result you can read it synchronously:

```swift
class Future<Value, Error> {
    var value: Value? { get }
    var error: Error? { get }
    var result: Result<Value, Error> { get }
}
```

## Functional Composition

### Map, FlatMap

Use familiar `map` and `flatMap` function to transform the future's values and chain futures:

```swift
let user: Future<User, Error>
func loadAvatar(url: URL) -> Future<UIImage, Error>

let avatar = user
    .map { $0.avatarURL }
    .flatMap(loadAvatar)
```

### MapError, FlatMapError

`Future` has typed errors. To convert from one error type to another use `mapError`:

```swift
let request: Future<Data, URLError>
request.mapError(MyError.init(urlError:))
```

Use `flatMapError` to "recover" from an error.

### Zip, Reduce

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

### First, ForEach

Use `first` to wait for a first future to succeed:

```swift
let requests: [Future<Value, Error>]
Future.first(requests).on(success: { print("got response!") })
```

Use `forEach` to perform the work in a sequence:

```swift
// `startWork` is a function that returns a future
Future.forEach([startWork, startOtherWork]) { future in
    // In the callback you can subscribe to each future when work is started
    future.on(success: { print("some work completed") })
}
```

### After, Retry

Use `after` to produce a value after a given time interval.

```swift
Future.after(seconds: 2).on { _ in print("2 seconds have passed") })
```

Use `retry` to perform the given number of attempts to finish the work successfully.

```swift
func startSomeWork() -> Future<Value, Error>

Future.retry(attempts: 3, delay: .seconds(3), startSomeWork)
```

Retry is flexible. It allows you to specify multiple delay strategies including exponential backoff, to inspect the error before retrying and more.

### Materialize

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

## Cancellation

The framework wouldn't be complete without cancellation. FutureX considers cancellation to be a concern orthogonal to `Future`. It implements a [`CancellationToken`](https://kean.github.io/post/cancellation-token) pattern for cooperative cancellation of asynchronous operations:

```swift
let cts = CancellationTokenSource()
getUser(token: cts.token).flatMap { user in
    getAvatar(user.avatarUrl, token: cts.token)
}

// At some point in the future:
cts.cancel()

// Both asynchronous operations are cancelled.
```

## Requirements

- iOS 9.0 / watchOS 2.0 / OS X 10.11 / tvOS 9.0
- Xcode 10
- Swift 4.2

## License

FutureX is available under the MIT license. See the LICENSE file for more info.
