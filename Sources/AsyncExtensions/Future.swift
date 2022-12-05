import Foundation
import Synchronized

public final class Future<T: Sendable>: @unchecked Sendable {
    private let result = Locked<Result<T, Error>?>(nil)
    private let continuations = Locked<[UnsafeContinuation<T, Error>]>([])

    public init() {}

    public init(_ block: @escaping () async throws -> T) {
        Task {
            do {
                let value = try await block()
                self.resolve(value)
            } catch {
                self.fail(error)
            }
        }
    }

    public init(_ block: (@escaping (Result<T, Error>) -> Void) -> Void) {
        block { result in
            switch result {
            case let .success(value):
                self.resolve(value)

            case let .failure(error):
                self.fail(error)
            }
        }
    }

    public var value: T { get async throws {
        try await withUnsafeThrowingContinuation { cont in
            if let result = result.access({ $0 }) {
                cont.resume(with: result)
            } else {
                continuations.access { $0.append(cont) }
                // If the result was set while adding our continuation to
                // the array of continuations, we need to resume it.
                resumeContinuations()
            }
        }
    }}

    public func resolve(_ value: T) {
        result.access { result in
            guard result == nil else { return }
            result = .success(value)
        }
        resumeContinuations()
    }

    public func fail(_ error: Error) {
        result.access { result in
            guard result == nil else { return }
            result = .failure(error)
        }
        resumeContinuations()
    }

    private func resumeContinuations() {
        guard let result = result.access({ $0 }) else { return }
        let continuations = continuations.access { continuations in
            let conts = continuations
            continuations.removeAll()
            return conts
        }
        continuations.forEach { $0.resume(with: result) }
    }
}
