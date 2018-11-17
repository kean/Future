<p align="left"><img src="https://user-images.githubusercontent.com/1567433/48661279-fa83a100-ea6f-11e8-8b4e-f93b7a337607.png" height="90"/>
<p align="left">
<img src="https://img.shields.io/cocoapods/v/FutureX.svg?label=version">
<img src="https://img.shields.io/badge/platforms-iOS%2C%20macOS%2C%20watchOS%2C%20tvOS-lightgrey.svg">
<img src="https://img.shields.io/badge/supports-CocoaPods%2C%20Carthage%2C%20SwiftPM-green.svg">
<a href="https://travis-ci.org/kean/FutureX"><img src="https://travis-ci.org/kean/FutureX.svg?branch=master"></a>
<img src="https://img.shields.io/badge/test%20coverage-100%25-brightgreen.svg">
</p>

<hr/>

A future represents a result of a computation which may be available now, or in the future, or never. Essentially, a future is an object to which you attach callbacks, instead of passing callbacks into a function that performs a computation. This might seem like a small distinction but it opens a whole world of possibilities. 

FutureX provides a streamlined `Future<Value, Error>` with functional interface. Futures enable easy composition of asynchronous operations thanks to function like `map`, `flatMap`, `zip`, `reduce` and many others. FutureX also provides a set of extensions to `Cocoa` APIs which allow you to start using futures in no time.

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
- [**FutureCocoa**](#futurecocoa)
 
## Quick Start Guide

### Create Future

Using `Promise`:

```swift
func someAsyncOperation(args) -> Future<Value, Error> {
    let promise = Future<Value, Error>.promise
    someAsyncOperationWithCallback(args) { value, error in
        // when finished...
        promise.succeed(result: value)
        // if error...
        promise.fail(error: error)
    }
    return promise.future
}
```

Using a convenience init method:

```swift
let future = Future<Int, Error> { succeed, fail in
    someAsyncOperationWithCallback { value, error in
        // succeed or fail
    }
}
```

With a value or an error:

```swift
Future<Int, Error>(value: 1)
Future<Int, Error>(error: Error.unknown)
```

### Attach Callbacks

To attach callbacks to the `Future` use  `on` method:

```swift
let future: Future<Value, Error>
future.on(success: { print("received value: \($0)" },
          failure: { print("failed with error: \($0)" }),
          completion: { print("completed with result: \($0)" })
```

The callbacks are optional - you don't have to attach all at the same time.  `on` returns `self` so that you can continue the chain.

By default the callbacks are run on `.main(immediate: true)` scheduler. It runs immediately if on the main thread, otherwise asynchronously on the main thread. To change the scheduler pass one into the `on` method:

> See [**Threading**](#threading) for a rationale and more info

```swift
future.on(scheduler: .queue(.global()),
          success: { print("value: \($0)" })
```

### Wait, Result

Use `wait` method to block the current thread and wait until the future receives a result:

```swift
let result = future.wait() // Mostly useful for testing and debugging
```

If the future already has a result you can read is synchronously:

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
func loadAvatar(url: URL) -> Future<UIImage, Error> {}

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
let future1 = Future<Int, Error>(value: 1)
let future2 = Future<Int, Error>(value: 2)

Future.reduce(0, [future1, future2], +).on(success: { value in
    print(value) // prints "3"
})
```

## Additions

In addition to the primary interface there is also a set of extensions to `Future` which include multiple convenience functions. Not all of them are mentioned here, look into `FutureExtensions.swift` to find more!

### First, ForEach

First waits for the first future to resolve:

```swift
let requests: [Future<Value, Error>]
Future.first(requests).on(success: { print("got response!") })
```

ForEach performs futures sequentially:

```swift
// `startWork` is a function that returns a future` 
Future.forEach([startWork, startOtherWork]) { future in
    // In the callback you can subscribe to each future when work is started
    future.on(success: { print("some work completed") })
}
```

### After, Retry

After returns a future which succeeds after a given time interval.

```swift
Future.after(seconds: 2).on(success: { print("2 seconds have passed") })
```

Retry performs the given number of attempts to finish the work successfully.

```swift
Future.retry(attempts: 3, delay: .seconds(3)) {
    startSomeWork()
}
```

Retry is very flexible, it allows you to specify multiple delay strategies including exponential backoff, to inspect the error before retrying and more.

### Materialize

This one is fascinating. It converts `Future<Value, Error>` to `Future<Future<Value, Error>.Result, Never>` - a future which never fails. It always succeeds with the result of the initial future. Now, why would you want to do that? Turns out `materialize` composes really well with other functions like `zip`, `reduce`, `first`, etc. All of these functions fail as soon as one of the given futures fail, but with `materialize` you can change the behavior of these functions so that they would wait until all futures are resolved, not matter successfully or with an error.

> Notice that we use native `Never` type to represent a situation when error can never be produced.

```swift
Future.zip(futures.map { $0.materialize() }).on(success: { results in
    // All futures are resolved and we get the list of all of the results -
    // either values or errors.
})
```

## Threading

On iOS users expect UI renders to happen synchronously. To accomodate that, by default, the callbacks are run with `.main(immediate: true)` strategy. It runs immediately if on the main thread, otherwise asynchronously on the main thread. The design is similar to the reactive frameworks like RxSwift. It opens a whole new area for using futures which are traditionally asynchronous by design. 

Overall there are three differnet schedulers available:

```swift
public enum Scheduler {
    /// Runs immediately if on the main thread, otherwise asynchronously on the main thread.
    case main(immediate: Bool)
    /// Runs asynchronously on the given queue.
    case queue(DispatchQueue)
    /// Immediately executes the given closure.
    case immediate
}
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

## FutureCocoa

FutureCocoa is a framework which provides a set of future extensions to classes in native Apple frameworks. It's in very early stages now, it only ships for iOS and contains a limited number of extensions. Stay tuned.

## Requirements

- iOS 9.0 / watchOS 2.0 / OS X 10.11 / tvOS 9.0
- Xcode 10
- Swift 4.2

## License

FutureX is available under the MIT license. See the LICENSE file for more info.
