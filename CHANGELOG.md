## FutureX 0.10

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

- Add `wait` method that blocks the current thread and waits until the future receives a result
- Make `Future.Result` type public
- Pass result in the completion


## Pill 0.8.1

- Documentation improvements


## Pill 0.8

- `map`, `flatMap`, `mapError`, `flatMapError` now run on the queue on which the future was resolved. It increases the performance of a typical chain by up to 3 times and also simplifies debugging - there are less `queue.async` operations performed.
- `map` and `mapError` now no longer require intermediate `Future` instance to be created, increased performance by up to 40%.
- Remove `observeOn`. It was introducing unwanted state in `Future`. To observe success/failure on a different queue use a new `queue` parameter (`DispatchQueue.main` by default) of `on` method. 

## Pill 0.7

- Add `zip` with three arguments

## Pill 0.6

Pill 0.6 is a complete reimagining of the library. See [a post](https://kean.github.io/post/future) for a complete overview of the changes.

- Add typed errors - `Future<Value, Error>`, `Promise<Value, Error>`
- Adopt functional Swift naming: `map`, `flatMap` instead of `then`
- Add new methods: `zip`, `reduce`
- Add `observeOn` method to observe changes on differnet dispatch queues
- Fix an issue where then/catch callbacks could be executed in a different from registration order
- Remove `throws` support (not type-safe)

## Pill 0.5

Updated to Swift 4.2

## Pill 0.4

Improve performance:
- `Promise` creation is **2x** faster.
- `then(_:)`, `catch(_:)` methods are now **1.4x** faster.

## Pill 0.3

- Swift 4
- `Handlers` and `State` are nested types now (private)

## Pill 0.2

Initial public version.

## Pill 0.1

Initial version.
