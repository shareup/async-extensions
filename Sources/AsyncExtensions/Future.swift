import Foundation
import Synchronized

public final class Future<T: Sendable>: @unchecked
Sendable {
    fileprivate typealias R = Result<T, Error>
    fileprivate typealias C = UnsafeContinuation<T, Error>
    fileprivate typealias Cs = [String: C]

    private let state = Locked(State())

    public init() {}

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

    public func resolve(_ value: T) {
        state.access { state in
            guard state.result == nil else { return }
            state.result = .success(value)
        }
        resumeContinuations()
    }

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

public extension Future {
    var result: Result<T, Error> { get async {
        do {
            let value = try await value
            return .success(value)
        } catch {
            return .failure(error)
        }
    }}
}

public extension Future where T == Void {
    func resolve() { resolve(()) }
}

private extension Future {
    struct State {
        var result: R?
        var continuations: Cs = [:]
        var cancelled: Set<String> = []
    }
}
