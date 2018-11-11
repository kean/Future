<p align="left"><img src="https://cloud.githubusercontent.com/assets/1567433/19490843/61cd2460-9579-11e6-9269-6cdebdf2a1cb.png" height="100"/>

<p align="left">
<img src="https://img.shields.io/cocoapods/v/Pill.svg?label=version">
<img src="https://img.shields.io/badge/supports-CocoaPods%20%7C%20Carthage%20%7C%20SwiftPM-green.svg">
<img src="https://img.shields.io/cocoapods/p/Pill.svg?style=flat)">
<a href="https://travis-ci.org/kean/Pill"><img src="https://img.shields.io/travis/kean/Pill/master.svg"></a>
</p>

A streamlined `Future<Value, Error>` implementation with typed errors and a Swifty API.

## Requirements

- iOS 9.0 / watchOS 2.0 / OS X 10.11 / tvOS 9.0
- Xcode 10
- Swift 4.2

## Quick Start

To access the result of the `Future`, use `func on(success:failure:completion:)`:

```swift
let future = Future<Int, Error>(value: 1)

future.on(
    success: { print("value: \($0)" },
    failure: { print("error: \($0)" },
    completion: { print("either succeeded or failed" }
)
```

By default, all the callbacks are called on the main queue. To observe changes on a different queue use `func observeOn(_queue:)`:

```swift
future.observeOn(DispatchQueue.global())
    .on(success: { print("value: \($0)" })
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

### Creating Futures

Using `Promise`:

```swift
func someAsyncOperation(args) -> Future<Value, Error> {
    let promise = Promise<Value, Error>()
    someAsyncOperationWithCallback(args) { result -> Void in
        // when finished...
        promise.succeed(result: result)
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

With a value:

```swift
let future = Future<Int, Error>(value: 1)
```

With an error:

```swift
let future = Future<Int, Error>(error: Error.unknown)
```

### Zip

Use  `static func zip(_lhs:_rhs:)` to combine the result of two futures:

```swift
let user: Future<User, Error>
let avatar: Future<UIImage, Error>

Future.zip(user, avatar).on(success: { user, avatar in
    // use both values
})
```

### Synchronous Inspection

```swift
class Future {
    var isPending: Bool
    var value: T?
    var error: Error?
}
```

## License

Pill is available under the MIT license. See the LICENSE file for more info.
