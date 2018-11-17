<p align="left"><img src="https://user-images.githubusercontent.com/1567433/48660485-c05fd280-ea62-11e8-9d5b-0ac6207373e1.png" height="80"/>
<p align="left">
<img src="https://img.shields.io/cocoapods/v/Pill.svg?label=version">
<img src="https://img.shields.io/badge/platforms-iOS%2C%20macOS%2C%20watchOS%2C%20tvOS-lightgrey.svg">
<img src="https://img.shields.io/badge/supports-CocoaPods%2C%20Carthage%2C%20SwiftPM-green.svg">
<a href="https://travis-ci.org/kean/Pill"><img src="https://img.shields.io/travis/kean/Pill/master.svg"></a>
<img src="https://img.shields.io/badge/test%20coverage-100%25-brightgreen.svg">
</p>

A streamlined Future implementation with functional interface.

## Future

A future represents a result of computation which may be available now, or in the future, or never. Essentially, a future is an object to which you attach callbacks, instead of passing callbacks into a function that performs a computation. 

Futures are easily composable. `Future<Value, Error>` provides a set of functions like `map`, `flatMap`, `zip`, `reduce` and more to compose them.

## Getting Started

- [**Quick Start Guide**](#quick-start-guide)
  * [Create Future](#create-future)
  * [Attach Callbacks](#attach-callbacks)
  * [Wait, Result](#wait-result)
- [**Functional Composition**](#functional-composition)
  * [Map, FlatMap](#map-flatmap)
  * [MapError, FlatMapError](#maperror-flatmaperror)
  * [Zip, Reduce](#zip)
- [**Threading**](#threading)
- [**Cancelation**](#cancelation)
 
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

### Zip

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

### Reduce

Use `reduce` to combine the results of multiple futures:

```swift
let future1 = Future<Int, Error>(value: 1)
let future2 = Future<Int, Error>(value: 2)

Future.reduce(0, [future1, future2], +).on(success: { value in
    print(value) // prints "3"
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

## Cancelation

Pill considers cancellation to be a concern orthogonal to `Future`. There are multiple cancellation approaches. There are arguments for failing futures with an error on cancelation, there is also an argument for never resolving futures when the associated work gets canceled. In order to implement cancelation you might want to consider  [`CancellationToken`](https://kean.github.io/post/cancellation-token) or other similar patterns.

## Requirements

- iOS 9.0 / watchOS 2.0 / OS X 10.11 / tvOS 9.0
- Xcode 10
- Swift 4.2

## License

Pill is available under the MIT license. See the LICENSE file for more info.
