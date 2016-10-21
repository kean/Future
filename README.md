<p align="left"><img src="https://cloud.githubusercontent.com/assets/1567433/19490843/61cd2460-9579-11e6-9269-6cdebdf2a1cb.png" height="100"/>

<p align="left">
<img src="https://img.shields.io/cocoapods/v/Pill.svg?label=version">
<img src="https://img.shields.io/badge/supports-CocoaPods%20%7C%20Carthage%20%7C%20SwiftPM-green.svg">
<img src="https://img.shields.io/cocoapods/p/Pill.svg?style=flat)">
<a href="https://travis-ci.org/kean/Pill"><img src="https://img.shields.io/travis/kean/Pill/master.svg"></a>
</p>

Micro Promise/A+ under 100 lines of code. Has all the essential features, adapted for Swift. Covered by Promise/A+ [test suite](https://github.com/promises-aplus/promises-tests).

## Requirements

- iOS 9.0 / watchOS 2.0 / OS X 10.11 / tvOS 9.0
- Xcode 8
- Swift 3

## API

### Promise/A+

Instead of a single `promise.then(onFulfilled, onRejected)` method Pill has a bunch of type-safe methods with the same functionality:

Equivalent to `onFulfilled`:

```swift
func then<U>(_ closure: @escaping (T) throws -> U) -> Promise<U>
func then<U>(_ closure: @escaping (T) throws -> Promise<U>) -> Promise<U>
```

Equivalent to `onRejected`:

```swift
func catch(_ closure: @escaping (Error) throws -> Void) -> Promise<T>
func recover(_ closure: @escaping (Error) throws -> T) -> Promise<T>
func recover(_ closure: @escaping (Error) throws -> Promise<T>) -> Promise<T>
```

Each of the `then` / `catch` methods also have an `on queue: DispatchQueue` parameter which is `.main` by default.

Additions:

```swift
func finally(_ closure: @escaping (Void) -> Void) -> Promise<T>
```

### Creating Promises

```swift
let promise = Promise { fulfill, reject in
    URLSession.shared.dataTask(with: url) { data, _, error in
        if let data = data {
            fulfill(data)
        } else {
            reject(error ?? Error.unknown)
        }
    }.resume()
}
```

Already fulfilled:

```swift
let promise = Promise(value: 1)
```

Already rejected:

```swift
let promise = Promise<Int>(error: Error.unknown)
```

### Synchronous Inspection

```swift
var isPending: Bool
var value: T?
var error: Error?
```

## License

Pill is available under the MIT license. See the LICENSE file for more info.
