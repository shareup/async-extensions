import Combine
import Foundation
import Synchronized

public extension Publisher where Failure == Never {
    /// Wraps the receiver in an `AsyncStream<Output>` while using
    /// a buffering policy of `.bufferingNewest(1)`, which means
    /// it only buffers the newest value.
    var asyncValues: AsyncStream<Output> {
        asyncStream(bufferingPolicy: .bufferingNewest(1))
    }

    @available(
        *,
        deprecated,
        renamed: "allAsyncValues",
        message: "Use allAsyncValues instead"
    )
    var allValues: AsyncStream<Output> {
        allAsyncValues
    }

    /// Wraps the receiver in an `AsyncStream<Output>` using
    /// an unbounded buffering policy.
    ///
    /// The advantage of using `allValues` over `values` is
    /// `allValues` is guaranteed to provide every value
    /// produced by the receiver, whereas `values` only
    /// requests a single value with every iteration.
    var allAsyncValues: AsyncStream<Output> {
        asyncStream(bufferingPolicy: .unbounded)
    }

    private func asyncStream(
        bufferingPolicy: AsyncStream<Output>.Continuation.BufferingPolicy
    ) -> AsyncStream<Output> {
        let state = Locked<State>(.waiting)

        return AsyncStream<Output>(
            Output.self,
            bufferingPolicy: bufferingPolicy
        ) { cont in
            cont.onTermination = { _ in
                state.access { $0.cancel() }
            }

            let sub = self.sink(
                receiveCompletion: { _ in
                    cont.finish()
                    state.access { $0.cancel() }
                },
                receiveValue: { cont.yield($0) }
            )

            state.access { $0.start(sub) }
        }
    }
}

public extension Publisher where Failure: Error {
    /// Wraps the receiver in an `AsyncThrowingStream<Output, Error>`
    /// while using a buffering policy of `.bufferingNewest(1)`, which
    /// means it only buffers the newest value.
    var asyncValues: AsyncThrowingStream<Output, Error> {
        asyncStream(bufferingPolicy: .bufferingNewest(1))
    }

    @available(
        *,
        deprecated,
        renamed: "allAsyncValues",
        message: "Use allAsyncValues instead"
    )
    var allValues: AsyncThrowingStream<Output, Error> {
        allAsyncValues
    }

    /// Wraps the receiver in an `AsyncThrowingStream<Output, Error>`
    /// using an unbounded buffering policy.
    ///
    /// The advantage of using `allValues` over `values` is
    /// `allValues` is guaranteed to provide every value
    /// produced by the receiver, whereas `values` only
    /// requests a single value with every iteration.
    var allAsyncValues: AsyncThrowingStream<Output, Error> {
        asyncStream(bufferingPolicy: .unbounded)
    }

    private typealias BufferingPolicy<T, E: Error> =
        AsyncThrowingStream<T, E>.Continuation.BufferingPolicy

    private func asyncStream(
        bufferingPolicy: BufferingPolicy<Output, Error>
    ) -> AsyncThrowingStream<Output, Error> {
        let state = Locked<State>(.waiting)

        return AsyncThrowingStream<Output, Error>(
            Output.self,
            bufferingPolicy: bufferingPolicy
        ) { cont in
            cont.onTermination = { _ in
                state.access { $0.cancel() }
            }

            let sub = self.sink(
                receiveCompletion: { completion in
                    defer { state.access { $0.cancel() } }

                    switch completion {
                    case .finished:
                        cont.finish()

                    case let .failure(error):
                        cont.finish(throwing: error)
                    }
                },
                receiveValue: { cont.yield($0) }
            )

            state.access { $0.start(sub) }
        }
    }
}

private enum State {
    case running(AnyCancellable)
    case terminal
    case waiting

    var isTerminal: Bool {
        guard case .terminal = self else {
            return false
        }
        return true
    }

    mutating func cancel() {
        switch self {
        case let .running(sub):
            sub.cancel()
            self = .terminal

        case .terminal:
            break

        case .waiting:
            self = .terminal
        }
    }

    mutating func start(_ subscription: AnyCancellable) {
        switch self {
        case .running:
            assertionFailure()

        case .terminal:
            break

        case .waiting:
            self = .running(subscription)
        }
    }
}
