import Combine
import Foundation

// CombineAsyncStream was created by Marin Todorov. It was
// released on his blog at:
// https://trycombine.com/posts/combine-async-sequence-2/

// MARK: - CombineAsyncStream

public final class CombineAsyncStream<Upstream: Publisher>:
    AsyncSequence where Upstream.Failure == Never
{
    public typealias Element = Upstream.Output
    public typealias AsyncIterator = CombineAsyncStream<Upstream>

    public func makeAsyncIterator() -> Self { self }

    private let stream: AsyncStream<Upstream.Output>
    private lazy var iterator = stream.makeAsyncIterator()
    private var cancellable: AnyCancellable?

    public init(_ upstream: Upstream) {
        var subscription: AnyCancellable?

        stream = AsyncStream<Upstream.Output>(
            Upstream.Output
                .self
        ) { continuation in
            subscription = upstream
                .handleEvents(receiveCancel: { continuation.finish() })
                .sink(
                    receiveCompletion: { completion in
                        switch completion {
                        case .failure:
                            preconditionFailure()

                        case .finished:
                            continuation.finish()
                        }
                    },
                    receiveValue: { continuation.yield($0) }
                )
        }

        cancellable = subscription
    }

    public func cancel() {
        cancellable?.cancel()
        cancellable = nil
    }
}

extension CombineAsyncStream: AsyncIteratorProtocol {
    public func next() async -> Upstream.Output? {
        await iterator.next()
    }
}

public extension Publisher where Self.Failure == Never {
    var asyncValues: CombineAsyncStream<Self> {
        CombineAsyncStream(self)
    }
}

// MARK: - CombineAsyncThrowingStream

public final class CombineAsyncThrowingStream<Upstream: Publisher>: AsyncSequence {
    public typealias Element = Upstream.Output
    public typealias AsyncIterator = CombineAsyncThrowingStream<Upstream>

    public func makeAsyncIterator() -> Self { self }

    private let stream: AsyncThrowingStream<Upstream.Output, Error>
    private lazy var iterator = stream.makeAsyncIterator()
    private var cancellable: AnyCancellable?

    public init(_ upstream: Upstream) {
        var subscription: AnyCancellable?

        stream = AsyncThrowingStream<Upstream.Output, Error>(
            Upstream.Output
                .self
        ) { continuation in
            subscription = upstream
                .handleEvents(receiveCancel: { continuation.finish(throwing: nil) })
                .sink(
                    receiveCompletion: { completion in
                        switch completion {
                        case let .failure(error):
                            continuation.finish(throwing: error)

                        case .finished:
                            continuation.finish(throwing: nil)
                        }
                    },
                    receiveValue: { continuation.yield($0) }
                )
        }

        cancellable = subscription
    }

    public func cancel() {
        cancellable?.cancel()
        cancellable = nil
    }
}

extension CombineAsyncThrowingStream: AsyncIteratorProtocol {
    public func next() async throws -> Upstream.Output? {
        try await iterator.next()
    }
}

public extension Publisher {
    var asyncValues: CombineAsyncThrowingStream<Self> {
        CombineAsyncThrowingStream(self)
    }
}
