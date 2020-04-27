# Future 1.x

## Future 1.4.0

*April 27, 2019*

- Add Linux support - [#12](https://github.com/kean/Future/pull/12), by [Joseph Heck](https://github.com/heckj)

## Future 1.3.0

*November 20, 2019*

- Remove `FutureCompatible.swift` from the framework

## Future 1.2.0

*November 19, 2019*

- Fix Xcode warnings – [9](https://github.com/kean/FutureX/pull/9)
- Add Installation Guide and [**API Reference**](https://kean-org.github.io/docs/future/reference/1.2.0/index.html)
- Remove CocoaPods support
- Drop the `X`

## FutureX 1.1.1

*September 1, 2019*

- Add a version number compatible with Swift Package Manager

## FutureX 1.1.0

*August 5, 2019*

- Replace custom `Future.Result` type with `Swift.Result`

## FutureX 1.0.0

*August 4, 2019*

- Add Swift 5.0 support
- Add SwiftPM 5.0 support
- Remove Swift 4.0 and Swift 4.1 support
- Remove iOS 9, tvOS 9, watchOS 2.0, macOS 10.10 and macOS 10.11 support

# Future 0.x

## FutureX 0.17

*April 7, 2019*

Refined `on` method to attach callbacks. There are just two minor changes:

- Completion closure signature is now `() -> Void` instead of `(Result) -> Void`. Completion is designed to be used in addition to `success` and `failure` to do things like hiding activity indicators. That's why the `Result` variant never really made sense. If you'd like to use `Result` instead, use `future.materialize().on { result in }`.
- Add a `func on(success: (Value) -> Void)` method. Now `future.on { }` (with a trailing closure) is inferred by the compiler to add `success` closure. Previously, it used to attach `completion` closure. This change makes it a little bit nices to attach callbacks to futures that can't produce errors (`Future<_, Never>`).

There is also a change in the project structure. We now use a single multi-platform target instead of four separate targets - one for each platform.

## FutureX 0.16

*December 15, 2018*

- Add  `Future` initializer which takes a throwing closure:  `init(catching body: () throws -> Value)`. This feature was added in the first FutureX PR [#1](https://github.com/kean/FutureX/pull/1), thanks to [@moto0000](https://github.com/moto0000)!
- Add `castError` variant which takes an error type as an argument
- Add `Scheduler.default` which can be used to change the default scheduler which is `Scheduler.main`

## FutureX 0.15

*November 24, 2018*

- `on` no longer returns `Future` to enable future extensions, discourage putting side effects in the middle of the chain, and simplify scheduleing model
- `CancellationToken.noOp` renamed to `CancellationToken.none`.
- Add `FutureCompatible` and `FutureExtension`

## FutureX 0.14

*November 22, 2018*

- Method `observe(on:)` is more flexible, it can now  be used to runs transformations like `map`, `tryMap` on a specified queue (and actually any other transformation too, it composes really well with them).
- Instead of a convenience `Future { succeed, fail in }` we now have `Future { promise in }` which is consistent with the regular way you create Promise/Future pair and also more flexible and performant.
- Inline the first handler in `Promise`. It's very often when there is only one observer for each `Promise`. These operations are now up to 15% faster.
- Implement `CustomDebugStringConvertible` for `Promise`

## FutureX 0.13

*November 21, 2018*

This release is all about performance and quality of life improvements.

### Ergonomic Improvements

- Supercharged `flatMap`. Add variants which allow combinations of `Future<T, E>.flatMap { Future<T, Never> }` and `Future<T, Never>.flatMap { Future<T, E> }`
- Instead of a convoluted  `on(scheduler:success:failure:completion:)` method to change a scheduler you now call a separate `observe(on scheduler:)` or `observe(on queue:)` (new!) method before attaching callbacks. The `observe(on:)` methods are almost instanteneous thanks to the fact that `Future` is a `struct` now.
- Creating promises is now simpler: `Promise<Int, Error>()` instead of `Future<Int, Error>.promise`
- `Future(value: 1)` now compiles and automatically infers type to be `Future<Int, Never>`
- Rename `attemptMap` to `tryMap`, implement `tryMap` in terms of `flatMap`
- Remove `ignoreError`, `materialize` is a better alternative
- Attaching two callbacks via the same `on` would result in these callbacks called on the same run of run loop on the selected queue/scheduler
- Add convenience `Future.init(result:)`, `Promise.resolve(result:)`
- Implement `CancellationTokenSource` using `Future`, simpler implementation

### Performance Improvements

- `Future` is a struct now. `Future(value:)` and `Future(error:)` are now 2.5x times faster
- Optimize the way internal Promise handlers are managed - it's just one array instead of two now, attaching callbacks 30% faster, resolve 30% faster
- Slightly increase the performance of all composition functions (by using `observe` directly)
- Resolving promises concurrently from multiple threads is now up to 5x times faster

## FutureX 0.12

*November 18, 2018*

- Remove `Scheduler` enum, it's a simple function now. See [**Threading**](https://github.com/kean/FutureX#threading) for more info.
- Add Swift Package Manager support
- Update README.md

## FutureX 0.11

*November 17, 2018*

### FutureCocoa

- Make FutureCocoa available on macOS, watchOS and tvOS
- Add FutureCocoa README.md
- Add NSObject.fx.deallocated

## FutureX 0.10.1

*November 17, 2018*

- Fix module name in FutureX.podspec

## FutureX 0.10

*November 17, 2018*

FutureX is a completely new beast. It has a new name and it a new goal - to provide the best future implementation in Swift.

### Future

There are a lot of improvements in the core part of the frameworks:

- Add custom `Scheduler` instead of `DispatchQueue`. By default the callbacks are now run with `.main(immediate: true)` strategy. It runs immediately if on the main thread, otherwise asynchronously on the main thread. The rationale is provided in [README](https://github.com/kean/FutureX).
- Method `on` now returns self so that you can continue the chain. The returned result is marked as discardable.
- `Promise` is now nested in `Future<Value, Error>` like other types like `Result`. To create a promise call `Future<Value, Error>.promise`.
- Move `zip`, `reduce` to `extension Future where Value == Any, Error == Any` so that `Future` would be a simple namespace (inspired by RxSwift)
- Remove `isPending`
- Make `Future<Value, Error>.Result` `Equatable`
- Rewrite README

### Future Additions

There are also lots of bonus additions:

- `first`
- `after`: Returns a future which succeeds after a given time interval.
- `retry`
- `castError`
- `ignoreError`
- `materialize` that uses built-in `Never` to indicate that the error is not possible
- `castError`
- `mapThrowing`

### CancellationToken

FutureX now ships with a  `CancellationToken` implementation. See rational in [README](https://github.com/kean/FutureX).

### FutureCocoa

An initial version of Future extensions for native frameworks.

## Pill 0.9

*November 17, 2018*

- Add `wait` method that blocks the current thread and waits until the future receives a result
- Make `Future.Result` type public
- Pass result in the completion

## Pill 0.8.1

*November 17, 2018*

- Documentation improvements

## Pill 0.8

*November 14, 2018*

- `map`, `flatMap`, `mapError`, `flatMapError` now run on the queue on which the future was resolved. It increases the performance of a typical chain by up to 3 times and also simplifies debugging - there are less `queue.async` operations performed.
- `map` and `mapError` now no longer require intermediate `Future` instance to be created, increased performance by up to 40%.
- Remove `observeOn`. It was introducing unwanted state in `Future`. To observe success/failure on a different queue use a new `queue` parameter (`DispatchQueue.main` by default) of `on` method. 

## Pill 0.7

*November 12, 2018*

- Add `zip` with three arguments

## Pill 0.6

*November 12, 2018*

Pill 0.6 is a complete reimagining of the library. See [a post](https://kean.github.io/post/future) for a complete overview of the changes.

- Add typed errors - `Future<Value, Error>`, `Promise<Value, Error>`
- Adopt functional Swift naming: `map`, `flatMap` instead of `then`
- Add new methods: `zip`, `reduce`
- Add `observeOn` method to observe changes on differnet dispatch queues
- Fix an issue where then/catch callbacks could be executed in a different from registration order
- Remove `throws` support (not type-safe)

## Pill 0.5

*November 12, 2018*

Updated to Swift 4.2

## Pill 0.4

*December 23, 2017*

Improve performance:
- `Promise` creation is **2x** faster.
- `then(_:)`, `catch(_:)` methods are now **1.4x** faster.

## Pill 0.3

*October 17, 2017*

- Swift 4
- `Handlers` and `State` are nested types now (private)

## Pill 0.2

*October 21, 2016*

Initial public version.

## Pill 0.1

*October 21, 2016*

Initial version.
