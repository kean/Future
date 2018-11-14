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
