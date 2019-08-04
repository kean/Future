<br/>

<p align="left"><img src="https://user-images.githubusercontent.com/1567433/50047319-05ebdb80-00b3-11e9-9524-09b7a84c36e8.png" height="70"/>
<p align="left">Streamlined <code>Future&lt;Value, Error&gt;</code> implementation</p>
<p align="left">
<img src="https://img.shields.io/cocoapods/v/FutureX.svg?label=version">
<img src="https://img.shields.io/badge/platforms-iOS%2C%20macOS%2C%20watchOS%2C%20tvOS-lightgrey.svg">
<img src="https://img.shields.io/badge/supports-CocoaPods%2C%20Carthage%2C%20SwiftPM-green.svg">
<a href="https://travis-ci.org/kean/FutureX"><img src="https://travis-ci.org/kean/FutureX.svg?branch=master"></a>
<img src="https://img.shields.io/badge/test%20coverage-100%25-brightgreen.svg">
</p>

<hr/>

**Future** represents a result of a task which may be available now, or in the future, or never. **Future**X provides a streamlined **`Future<Value, Error>`** type engineered with ergonomics and performance in mind.

Futures enable composition of tasks using familiar functions like `map`, `flatMap`, `zip`, `reduce` and others which are all easy to learn and use.

> <img src="https://user-images.githubusercontent.com/1567433/48973894-a584f380-f04a-11e8-88f8-b66c083a5bbb.png" width="40px"> <br/>
> Check out [**FutureX Community**](https://github.com/FutureXCommunity) for extensions for popular frameworks and more.

## Getting Started

- [**Quick Start Guide**](#quick-start-guide) ‣ 
[Overview](#quick-start-guide) · [Create Future](#create-future) · [Attach Callbacks](#attach-callbacks) · [`wait`](#wait)
- [**Functional Composition**](#functional-composition) ‣ [`map`](#map-flatmap) · [`flatMap`](#map-flatmap) · [`mapError`](#maperror-flatmaperror) · [`flatMapError`](#maperror-flatmaperror) · [`zip`](#zip) · [`reduce`](#reduce)
- [**Extensions**](#extensions) ‣ [`first`](#first) · [`forEach`](#foreach) · [`after`](#after) · [`retry`](#retry) · [`materialize`](#materialize)
- [**Threading**](#threading) · [**Cancellation**](#cancellation) · [**Async/Await**](#asyncawait) · [**Performance**](#performance)

## Quick Start Guide

Let's start with an overview of the available types. The central ones are of course `Future` and its `Result`:

```swift
struct Future<Value, Error> {
    var result: Result? { get }
    
    func on(success: ((Value) -> Void)?, failure: ((Error) -> Void)?, completion: (() -> Void)?)

    enum Result {
        case success(Value), failure(Error)
    }
}
```

> `Future` is parameterized with two generic arguments – `Value` and `Error`. This allows us to take advantage of Swift type-safety features and also model futures that never fail using `Never` – `Future<Value, Never>`.

### Create Future

To create a future you would normally use a `Promise`:

```swift
func someAsyncTask() -> Future<Value, Error> {
    let promise = Promise<Value, Error>()
    performAsyncTask { value, error in
        // If success
        promise.succeed(value: value)
        // If error
        promise.fail(error: error)
    }
    return promise.future
}
```

> `Promise` is thread-safe. You can call `succeed` or `fail` from any thread and any number of times – only the first result is sent to the `Future`.

If the result of the work is already available by the time the future is created use one of these initializers:

```swift
// Init with a value
Future(value: 1) // Inferred to be Future<Int, Never>
Future<Int, MyError>(value: 1)

// Init with an error
Future<Int, MyError>(error: .dataCorrupted)

// Init with a throwing closure
Future<Int, Error> {
    guard let value = Int(string) else {
        throw Error.dataCorrupted
    }
    return value
}
```

> These `init` methods require no allocations which makes them really fast, faster than allocation a  `Promise` instance.

### Attach Callbacks

To attach callbacks (each one is optional) to the `Future` use  `on` method:

```swift
let future: Future<Value, Error>
future.on(success: { print("received value: \($0)" },
          failure: { print("failed with error: \($0)" }),
          completion: { print("completed" })
```

If the future already has a result, callbacks are executed immediately. If the future doesn't have a result yet, callbacks will be executed when the future is resolved. The future guarantees that it can be resolved with only one result, the callbacks are also guaranteed to run only once. 

By default, the callbacks are run on the `.main` scheduler.  If the task finishes on the main thread, the callbacks are executed immediately. Otherwise, they are dispatched to be executed asynchronously on the main thread.

> See [**Threading**](#threading) for a rationale and more info.

### `wait`

Use `wait` method to block the current thread and wait until the future receives a result:

```swift
let result = future.wait() // Mostly useful for testing and debugging
```

### `result`

If the future already has a result you can read it synchronously:

```swift
struct Future<Value, Error> {
    var value: Value? { get }
    var error: Error? { get }
    var result: Result? { get }
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

If you are not familiar with `flatMap`, at first it might be hard to wrap your head around it. But when it clicks, using it becomes second nature.

<img src="https://user-images.githubusercontent.com/1567433/50041360-e2457880-0053-11e9-8496-a3cfc71c0b0a.png" width="640px">

> There is actually not one, but a few `flatMap` variations. The extra ones allow you to seamlessly mix futures that can produce an error and the ones that can't. 

### `mapError`, `flatMapError`

`Future` has typed errors. To convert from one error type to another use `mapError`:

```swift
let request: Future<Data, URLError>
request.mapError(MyError.init(urlError:))
```

Use `flatMapError` to "recover" from an error.

> If you have a future that never produces an error (`Future<_, Never>`) you can cast it to the future which can produce _any_ error using `castError` method. In most cases, this is not needed though.

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

## Extensions

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
    future.on(success: { print("work is completed") })
}
```

### `after`

Use `after` to produce a value after a given time interval.

```swift
Future.after(seconds: 2.5).on { print("2.5 seconds passed") })
```

### `retry`

Use `retry` to perform the given number of attempts to finish the work successfully.

```swift
func startSomeWork() -> Future<Value, Error>

Future.retry(attempts: 3, delay: .seconds(3), startSomeWork)
```

Retry is flexible. It allows you to specify multiple delay strategies including exponential backoff, to inspect the error before retrying and more.

### `materialize`

This one is fascinating. It converts `Future<Value, Error>` to `Future<Future<Value, Error>.Result, Never>` – a future which never fails. It always succeeds with the result of the initial future. Now, why would you want to do that? Turns out `materialize` composes really well with other functions like `zip`, `reduce`, `first`, etc. All of these functions fail as soon as one of the given futures fails. But with `materialize` you can change the behavior of these functions so that they would wait until all futures are resolved, no matter successfully or with an error.

> Notice that we use native `Never` type to represent a situation when error can never be produced.

```swift
Future.zip(futures.map { $0.materialize() }).on { results in
    // All futures are resolved and we get the list of all of the results -
    // either values or errors.
}
```

## Threading

On iOS users expect UI renders to happen synchronously. To accommodate that, by default, the callbacks are run using `Scheduler.main`. It runs work immediately if on the main thread, otherwise asynchronously on the main thread. The design is similar to the reactive frameworks like RxSwift. It opens a whole new area for using futures which are traditionally asynchronous by design. 

There are three schedulers available:

```swift
enum Scheduler {
    /// If the task finishes on the main thread, the callbacks are executed
    /// immediately. Otherwise, they are dispatched to be executed
    /// asynchronously on the main thread.
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

> Please keep in mind that only the future returned directly by `observe(on:)` is guaranteed to run its continuations on the given queue (or scheduler).

## Cancellation

Cancellation is a concern orthogonal to `Future`. Think about `Future` as a simple callback replacement – callbacks don't support cancellation.

FutureX implements a [`CancellationToken`](https://kean.github.io/post/cancellation-token) pattern for cooperative cancellation of async tasks. A token is created through a cancellation token source.

```swift
let cts = CancellationTokenSource()
asyncWork(token: cts.token).on(success: {
    // To prevent closure from running when task is cancelled use `isCancelling`:
    guard !cts.isCancelling else { return }
    
    // Do something with the result
}) 

// At some point later, can be on the other thread:
cts.cancel()
```

To cancel multiple async tasks, you can pass the same token to all of them.

Implementing async tasks that support cancellation is easy:

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

> `CancellationTokenSource` itself is built using `Future`  and benefits from all of its performance optimizations.

## Async/Await

Async/await is often built on top of futures. When [async/await](https://gist.github.com/lattner/429b9070918248274f25b714dcfc7619) support is eventually added to Swift, it would be relatively easy to replace the code that uses futures with async/await.

> There is a [(blocking) version](https://gist.github.com/kean/24a3d0c2538647b33006b344ebc283a7) of async/await built on top FutureX. It's not meant to be used in production.

## Performance

Every feature in FutureX is engineered with performance in mind.

We avoid dynamic dispatch, reduce the number of allocations and deallocations, avoid doing unnecessary work and lock as less as possible. Methods are often implemented in a sometimes less elegant but more performant way.

There are also some key design differences that give FutureX an edge over other frameworks. One example is `Future` type itself which is designed as struct which allows some common operations to be performed without a single allocation.

## Requirements

| FutureX          | Swift             | Xcode               | Platforms                                         |
|------------------|-------------------|---------------------|---------------------------------------------------|
| FutureX 1.1      | Swift 5.0         | Xcode 10.2          | iOS 10.0 / watchOS 3.0 / macOS 10.12 / tvOS 10.0  |
| FutureX 1.0      | Swift 4.2 – 5.0   | Xcode 10.1 – 10.2   | iOS 10.0 / watchOS 3.0 / macOS 10.12 / tvOS 10.0  |
| FutureX 0.17     | Swift 4.0 – 4.2   | Xcode 9.2 – 10.1    |  iOS 9.0 / watchOS 2.0 / macOS 10.11 / tvOS 9.0   | 

## License

FutureX is available under the MIT license. See the LICENSE file for more info.
