# Pill

<p align="left">
<a href="https://github.com/Carthage/Carthage"><img src="https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat"></a>
</p>

Micro Promise under 100 sloc. Supports chaining, recovery, bubbles-up errors.

## Requirements

- iOS 8.0 / watchOS 2.0 / OS X 10.10 / tvOS 9.0
- Xcode 8, Swift 3

## Usage

```swift
cache.data(for: request)
    .recover { error in loadData(with: request) }
    .then { cache.setData($0, for: request) }
    .then { process(data: $0) }
    .catch { error in print("catched \(error)") }
```

## License

Pill is available under the MIT license. See the LICENSE file for more info.
