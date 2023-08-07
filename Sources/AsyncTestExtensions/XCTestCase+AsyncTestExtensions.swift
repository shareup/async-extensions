import AsyncExtensions
import Foundation
import XCTest

public extension XCTestCase {
    func task<ChildTaskResult>(
        timeout: TimeInterval = 2,
        priority: TaskPriority? = nil,
        operation: @escaping () async throws -> ChildTaskResult
    ) -> Task<ChildTaskResult, Error> {
        Task(priority: priority) {
            try await withThrowingTaskGroup(
                of: ChildTaskResult.self
            ) { group in
                group.addTask {
                    try Task.checkCancellation()
                    let timeout = Double(NSEC_PER_SEC) * timeout
                    try await Task.sleep(nanoseconds: UInt64(timeout))
                    try Task.checkCancellation()
                    throw TimeoutError()
                }

                group.addTask {
                    try Task.checkCancellation()
                    let value = try await operation()
                    try Task.checkCancellation()
                    return value
                }

                do {
                    for try await value in group {
                        group.cancelAll()
                        return value
                    }
                } catch {
                    group.cancelAll()
                    throw error
                }

                preconditionFailure()
            }
        }
    }
}
