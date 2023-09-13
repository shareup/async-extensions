# AsyncExtensions

The AsyncExtensions target is a growing collection of useful functions and classes that take advantage of [Swift's new Concurrency features](https://developer.apple.com/documentation/swift/swift_standard_library/concurrency).

The AsyncExtensions package also inlcudes the AsyncTestExtensions target, which contains async-friendly wrappers around XCTest assertions.

## AsyncExtensions includes

- `AsyncInputStream`: A convenient wrapper around [`InputStream`](https://developer.apple.com/documentation/foundation/inputstream) allowing for simple, type-safe access to stream data.
- `AsyncOutputStream`: A convenient wrapper around [`OutputStream`](https://developer.apple.com/documentation/foundation/outputstream) allowing for simple, type-safe streaming of data.
- `Publisher.allValues`: Creates an `AsyncStream` from a Combine Publisher. It buffers all of the publisher's output, ensuring the `AsyncStream` will produce everything the publisher publishes.
- `Future`: A thread-safe implemention of a future that is useful when briding traditional Swift code with code employing Swift Concurrency.
- `Sequence.asyncMap()` and `Sequence.concurrentMap()`: Extensions allowing for applying async transformations to `Sequence`.
- `TaskStore`: A thread-safe store for `Task`, which can help when migrating from Combine publishers to Swift Concurrency.
- `TimeoutError`: A simple error intending to represent a timeout. Modelled after [`CancellationError`](https://developer.apple.com/documentation/swift/cancellationerror).

## AsyncTestExtensions includes

- `AssertEqual()`
- `AssertEqualEventually()`
- `AssertTrue()`
- `AssertTrueEventually()`
- `AssertFalse()`
- `AssertNil()`
- `AssertNotNil()`
- `AssertThrowsError()`
- `AssertNoThrow()`
- `XCTestCase.task()`
- `XCTestCase.serialized()`
- `XCTestCase.yield()`

## Installation

To use AsyncExtensions, add a dependency to your Package.swift file:

```swift
let package = Package(
  dependencies: [
    .package(
      url: "https://github.com/shareup/async-extensions.git",
      from: "4.1.0"
    )
  ]
)
```

To use AsyncTestExtensions in a test target, add it as a dependency:

```swift
.testTarget(
  name: "MyTests",
  dependencies: [
    .product(name: "AsyncTestExtensions", package: "async-extensions")
  ]
)
```

## License

The license for AsyncExtensions is the standard MIT licence. You can find it in the LICENSE file.

SequenceExtensions were heavily inspired by CollectionConcurrencyKit by John Sundell at https://github.com/JohnSundell/CollectionConcurrencyKit.

The main serial executor XCTestCase extensions were taken from swift-concurrency-extras by Point-Free at https://github.com/pointfreeco/swift-concurrency-extras.
