import Foundation
import Synchronized

@available(*, deprecated, message: "Use AsyncThrowingFuture instead.")
public typealias Future<T: Sendable> = AsyncThrowingFuture<T>

public final class AsyncThrowingFuture<T: Sendable>: @unchecked
Sendable {
    fileprivate typealias R = Result<T, Error>
    fileprivate typealias C = UnsafeContinuation<T, Error>
    fileprivate typealias Cs = [String: C]

    private let state = Locked(State())

    /// Creates a new, unresolved future.
    public init() {}

    /// Creates a new, unresolved future with the specified
    /// timeout. If the timeout elapses before the future
    /// resolves, it will fail with `TimeoutError`.
    public init(timeout: TimeInterval) {
        Task {
            await withThrowingTaskGroup(of: Void.self) { group in
                _ = group.addTaskUnlessCancelled { [weak self] in
                    // TODO: Replace this with `Clock` when iOS 16 is minimum
                    let timeoutNs = Double(NSEC_PER_SEC) * timeout
                    try await Task.sleep(nanoseconds: UInt64(timeoutNs))
                    self?.fail(TimeoutError())
                }

                _ = group.addTaskUnlessCancelled { [weak self] in
                    _ = try await self?.value
                }

                _ = await group.nextResult()
                group.cancelAll()
            }
        }
    }

    /// This property waits for the receiver to resolve
    /// or fail before returning the resolved value or
    /// throwing the error that caused the future to fail.
    /// Multiple callers can wait for the future at the same
    /// time, and each one will be notified upon resolution
    /// or failure of the future.
    ///
    /// If the enclosing `Task` where this property was called
    /// is cancelled, a `CancellationError` will be thrown for
    /// that caller only. The future itself will wait to resolve
    /// or fail for all other callers.
    public var value: T { get async throws {
        let id = UUID().uuidString

        return try await withTaskCancellationHandler(
            operation: {
                try await withUnsafeThrowingContinuation { cont in
                    let resultOrIsCancelled: (R?, Bool) =
                        state.access { state in
                            if state.cancelled.contains(id) {
                                return (nil, true)
                            } else if let result = state.result {
                                return (result, false)
                            } else {
                                state.continuations[id] = cont
                                return (nil, false)
                            }
                        }

                    if let result = resultOrIsCancelled.0 {
                        cont.resume(with: result)
                    } else if resultOrIsCancelled.1 {
                        cont.resume(throwing: CancellationError())
                    }

                    resumeContinuations()
                }
            },
            onCancel: {
                let cont = state.access { state in
                    state.cancelled.insert(id)
                    return state
                        .continuations
                        .removeValue(forKey: id)
                }
                cont?.resume(throwing: CancellationError())
            }
        )
    }}

    /// Resolves the receiver with the specified value. If the
    /// future has already been resolved or failed, this is
    /// a no-op.
    public func resolve(_ value: T) {
        state.access { state in
            guard state.result == nil else { return }
            state.result = .success(value)
        }
        resumeContinuations()
    }

    /// Fails the receiver with the specified error. If the
    /// future has already been resolved or failed, this is
    /// a no-op.
    public func fail(_ error: Error) {
        state.access { state in
            guard state.result == nil else { return }
            state.result = .failure(error)
        }
        resumeContinuations()
    }

    private func resumeContinuations() {
        let rAndCs: (R, Cs)? = state.access { state in
            guard let result = state.result else { return nil }
            let conts = state.continuations
            state.continuations.removeAll()
            return (result, conts)
        }

        guard let (result, continuations) = rAndCs else { return }
        continuations.forEach { $0.value.resume(with: result) }
    }
}

public extension AsyncThrowingFuture {
    /// This method waits for the receiver to resolve
    /// or fail before returning the a `Result` containing
    /// either the resolved value or the error that caused
    /// the future to fail. Multiple callers can wait for the
    /// future at the same time, and each one will be notified
    /// upon resolution or failure of the future.
    ///
    /// If the enclosing `Task` where this method was called
    /// is cancelled, a `CancellationError` will be thrown for
    /// that caller only. The future itself will wait to resolve
    /// or fail for all other callers.
    var result: Result<T, Error> { get async {
        do {
            let value = try await value
            return .success(value)
        } catch {
            return .failure(error)
        }
    }}
}

public extension AsyncThrowingFuture where T == Void {
    /// Resolves the receiver. If the future has already been
    /// resolved or failed, this is a no-op.
    func resolve() {
        resolve(())
    }
}

private extension AsyncThrowingFuture {
    struct State {
        var result: R?
        var continuations: Cs = [:]
        var cancelled: Set<String> = []
    }
}
