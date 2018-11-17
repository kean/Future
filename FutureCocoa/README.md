# FutureCocoa

A set of future extensions for Apple native frameworks.

## Foundation

### URLSession

```swift
let user: Future<User, Error> = URLSession.shared.fx.object(for: url)

// With cancellation
let cts = CancellationTokenSource()
let data: Future<Data, Error> = URLSession.shared.fx.data(for: url, token: cts.token)
```

### NSObject

```swift
view.fx.deallocated.on(success: {
    print("view got deallocated")
})
```

## Requirements

- iOS 9.0 / watchOS 2.0 / OS X 10.11 / tvOS 9.0
- Xcode 10
- Swift 4.2

## License

FutureX is available under the MIT license. See the LICENSE file for more info.
