<p align="left"><img src="https://cloud.githubusercontent.com/assets/1567433/19490843/61cd2460-9579-11e6-9269-6cdebdf2a1cb.png" height="100"/>

<p align="left">
<img src="https://img.shields.io/cocoapods/v/Pill.svg?label=version">
<img src="https://img.shields.io/badge/platforms-iOS%2C%20macOS%2C%20watchOS%2C%20tvOS-lightgrey.svg">
<img src="https://img.shields.io/badge/supports-CocoaPods%2C%20Carthage%2C%20SwiftPM-green.svg">
<a href="https://travis-ci.org/kean/Pill"><img src="https://img.shields.io/travis/kean/Pill/master.svg"></a>
<img src="https://img.shields.io/badge/test%20coverage-100%25-brightgreen.svg">
</p>

A streamlined `Future<Value, Error>` implementation.

## Future

A future represents a result of computation which may be available now, or in the future, or never. Essentially, a future is an object to which you attach callbacks, instead of passing callbacks into a function that performs a computation. 

Futures are easily composable. `Future<Value, Error>` provides a set of functions like `map`, `flatMap`, `zip`, `reduce` and more to compose futures. 

## Quick Start

To attach a callback to the `Future` use  `on(success:failure:completion:)` method:

```swift
let user: Future<User, Error>

user.on(success: { print("received entity: \($0)" },
        failure: { print("failed with error: \($0)" })
        
// As an alternative observe a completion:
user.on(completion: { print("completed with result: \($0)" })   
```

By default the callbacks are run with `.main(immediate: true)` strategy. It runs immediately if on the main thread, otherwise asynchronously on the main thread. To change the scheduler pass one into the `on` method:

```swift
future.on(scheduler: .queue(.global()),
          success: { print("value: \($0)" })
```

### Mapping Values

Use familiar `map` and `flatMap` function to transform the future's values and chain futures:

```swift
let user: Future<User, Error>
func loadAvatar(url: URL) -> Future<UIImage, Error> {}

let avatar = user
    .map { $0.avatarURL }
    .flatMap(loadAvatar)
```

### Mapping Errors

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

### Creating Futures

Using `Promise`:

```swift
func someAsyncOperation(args) -> Future<Value, Error> {
    let promise = Promise<Value, Error>()
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

### Wait

Use `wait` method to block the current thread and wait until the future receives a result:

```swift
let result = future.wait()
```

### Synchronous Inspection

```swift
class Future<Value, Error> {
    var isPending: Bool { get }
    var value: Value? { get }
    var error: Error? { get }
    var result: Result<Value, Error> { get }
}
```

### Threading

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

### Cancelation

Pill considers cancellation to be a concern orthogonal to `Future`. There are multiple cancellation approaches. There are arguments for failing futures with an error on cancelation, there is also an argument for never resolving futures when the associated work gets canceled. In order to implement cancelation you might want to consider  [`CancellationToken`](https://kean.github.io/post/cancellation-token) or other similar patterns.

### Anti-Patterns

Avoid nesting futures, as this is the issue that futures are designed to solve:

```swift
loadUser().on(success: { user in
    loadAvatar(url: user.avatarUrl).on(success: { avatar in
        print("avatar loaded")
    }   
}
```

## Requirements

- iOS 9.0 / watchOS 2.0 / OS X 10.11 / tvOS 9.0
- Xcode 10
- Swift 4.2

## License

Pill is available under the MIT license. See the LICENSE file for more info.
