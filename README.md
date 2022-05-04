# AsyncExtensions

AsyncExtensions is a growing collection of useful functions and classes that take advantage of [Swift's new Concurrency features](https://developer.apple.com/documentation/swift/swift_standard_library/concurrency).

## Includes

- `AsyncInputStream`: A convenient wrapper around [`InputStream`](https://developer.apple.com/documentation/foundation/inputstream) allowing for simple, type-safe access to stream data.

## Installation

To use AsyncExtensions, add a dependency to your Package.swift file:

```swift
let package = Package(
  dependencies: [
    .package(url: "https://github.com/shareup/async-extensions.git", .upToNextMajor(from: "1.0.0"))
  ]
)
```

## License

The license for Database is the standard MIT licence. You can find it in the LICENSE file.
