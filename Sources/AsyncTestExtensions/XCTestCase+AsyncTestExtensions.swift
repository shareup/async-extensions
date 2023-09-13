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

// The following code is adapted from swift-concurrency-extras
// https://github.com/pointfreeco/swift-concurrency-extras

#if !os(WASI) && !os(Windows)

    public extension XCTestCase {
        /// Perform an operation on the main serial executor.
        ///
        /// Some asynchronous code is [notoriously
        /// difficult](https://forums.swift.org/t/reliably-testing-code-that-adopts-swift-concurrency/57304)
        /// to test in Swift due to how suspension points are processed by the runtime. This
        /// function
        /// attempts to run all tasks spawned in the given operation serially and
        /// deterministically. It
        /// makes asynchronous tests faster and less flakey.
        ///
        /// ```swift
        /// await withMainSerialExecutor {
        ///   // Everything performed in this scope is performed serially...
        /// }
        /// ```
        ///
        /// See <doc:ReliablyTestingAsync> for more information on why this tool is needed to
        /// test
        /// async code and how to use it.
        ///
        /// > Warning: This API is only intended to be used from tests to make them more
        /// reliable. Please do
        /// > not use it from application code.
        /// >
        /// > We say that it "_attempts_ to run all tasks spawned in an operation serially and
        /// > deterministically" because under the hood it relies on a global, mutable variable
        /// in the Swift
        /// > runtime to do its job, and there are no scoping _guarantees_ should this mutable
        /// variable change
        /// > during the operation.
        ///
        /// - Parameter operation: An operation to be performed on the main serial executor.
        @MainActor
        func serialized(
            @_implicitSelfCapture operation: @MainActor @Sendable () async throws -> Void
        ) async rethrows {
            let didUseMainSerialExecutor = uncheckedUseMainSerialExecutor
            defer { uncheckedUseMainSerialExecutor = didUseMainSerialExecutor }
            uncheckedUseMainSerialExecutor = true
            try await operation()
        }

        /// Perform an operation on the main serial executor.
        ///
        /// A synchronous version of ``withMainSerialExecutor(operation:)-79jpc`` that can be
        /// used in
        /// `XCTestCase.invokeTest` to ensure all async tests are performed serially:
        ///
        /// ```swift
        /// class BaseTestCase: XCTestCase {
        ///   override func invokeTest() {
        ///     withMainSerialExecutor {
        ///       super.invokeTest()
        ///     }
        ///   }
        /// }
        /// ```
        ///
        /// - Parameter operation: An operation to be performed on the main serial executor.
        func serialized(
            @_implicitSelfCapture operation: () throws -> Void
        ) rethrows {
            let didUseMainSerialExecutor = uncheckedUseMainSerialExecutor
            defer { uncheckedUseMainSerialExecutor = didUseMainSerialExecutor }
            uncheckedUseMainSerialExecutor = true
            try operation()
        }

        /// Calls `await Task.yield()` `count` times. Combined with
        /// `serialized()`, it's possible to easily write reliable
        /// asynchronous tests.
        func yield(_ count: Int = 1) async {
            precondition(count > 0)
            for _ in 0 ..< count {
                await Task.yield()
            }
        }

        /// Overrides Swift's global executor with the main serial executor in an unchecked
        /// fashion.
        ///
        /// > Warning: When set to `true`, all tasks will be enqueued on the main serial
        /// executor till set
        /// > back to `false`. Consider using ``withMainSerialExecutor(operation:)-79jpc``,
        /// instead, which
        /// > scopes this work to the duration of a given operation.
        private var uncheckedUseMainSerialExecutor: Bool {
            get { swift_task_enqueueGlobal_hook != nil }
            set {
                swift_task_enqueueGlobal_hook =
                    newValue
                        ? { job, _ in MainActor.shared.enqueue(job) }
                        : nil
            }
        }
    }

    private typealias Original = @convention(thin) (UnownedJob) -> Void
    private typealias Hook = @convention(thin) (UnownedJob, Original) -> Void

    private var swift_task_enqueueGlobal_hook: Hook? {
        get { _swift_task_enqueueGlobal_hook.pointee }
        set { _swift_task_enqueueGlobal_hook.pointee = newValue }
    }

    private let _swift_task_enqueueGlobal_hook: UnsafeMutablePointer<Hook?> =
        dlsym(dlopen(nil, 0), "swift_task_enqueueGlobal_hook")
            .assumingMemoryBound(to: Hook?.self)

#endif
