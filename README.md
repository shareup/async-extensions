# AsyncExtensions

The AsyncExtensions target is a growing collection of useful functions and classes that take advantage of [Swift's new Concurrency features](https://developer.apple.com/documentation/swift/swift_standard_library/concurrency).

The AsyncExtensions package also inlcudes the AsyncTestExtensions target, which contains async-friendly wrappers around XCTest assertions.

## AsyncExtensions includes

- `AsyncInputStream`: A convenient wrapper around [`InputStream`](https://developer.apple.com/documentation/foundation/inputstream) allowing for simple, type-safe access to stream data.

## AsyncTestExtensions includes

- `AssertEqual()`
- `AssertTrue()`
- `AssertFalse()`
- `AssertNil()`
- `AssertNotNil()`
- `AssertThrowsError()`
- `AssertNoThrow()`

## Installation

To use AsyncExtensions, add a dependency to your Package.swift file:

```swift
let package = Package(
  dependencies: [
    .package(
      name: "AsyncExtensions",
      url: "https://github.com/shareup/async-extensions.git",
      from: "1.1.0"
    )
  ]
)
```

To use AsyncTestExtensions in a test target, add it as a dependency:

```swift
.testTarget(
  name: "MyTests",
  dependencies: [
    .product(name: "AsyncTestExtensions", package: "AsyncExtensions")
  ]
)
```

## License

The license for Database is the standard MIT licence. You can find it in the LICENSE file.
