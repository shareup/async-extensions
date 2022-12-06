# AsyncExtensions

The AsyncExtensions target is a growing collection of useful functions and classes that take advantage of [Swift's new Concurrency features](https://developer.apple.com/documentation/swift/swift_standard_library/concurrency).

The AsyncExtensions package also inlcudes the AsyncTestExtensions target, which contains async-friendly wrappers around XCTest assertions.

## AsyncExtensions includes

- `AsyncInputStream`: A convenient wrapper around [`InputStream`](https://developer.apple.com/documentation/foundation/inputstream) allowing for simple, type-safe access to stream data.
- `CombineAsyncStream`: A backported version of [`AsyncPublisher`](https://developer.apple.com/documentation/combine/asyncpublisher), which creates an `AsyncStream` from a Combine Publisher and is only supported on iOS 15+.
- `Future`: A thread-safe implemention of a future that is useful when briding traditional Swift code with code employing Swift Concurrency.
- `Sequence.asyncMap()` and `Sequence.concurrentMap()`: Extensions allowing for applying async transformations to `Sequence`.
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

## Installation

To use AsyncExtensions, add a dependency to your Package.swift file:

```swift
let package = Package(
  dependencies: [
    .package(
      url: "https://github.com/shareup/async-extensions.git",
      from: "2.2.0"
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

CombineAsyncStream was created by Marin Todorov. It was released on his blog at https://trycombine.com/posts/combine-async-sequence-2/.

SequenceExtensions were heavily inspired by CollectionConcurrencyKit by John Sundell at https://github.com/JohnSundell/CollectionConcurrencyKit.
