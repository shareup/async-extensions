import AsyncExtensions
import AsyncTestExtensions
import XCTest

final class XCTestCaseAsyncTestExtensionsTests: XCTestCase {
    func testNonThrowingTask() async throws {
        let task = task {
            try await Task.sleep(nanoseconds: NSEC_PER_MSEC * 10)
            return 12_345
        }

        let value = try await task.value
        XCTAssertEqual(12_345, value)
    }

    func testNonThrowingTaskWithAssertEqual() async throws {
        let task = task {
            try await Task.sleep(nanoseconds: NSEC_PER_MSEC * 10)
            return 12_345
        }

        await AssertEqual(12_345, try await task.value)
    }

    func testThrowingTask() async throws {
        struct Err: Error {}

        let task = task { () async throws -> Int in
            try await Task.sleep(nanoseconds: NSEC_PER_MSEC * 10)
            throw Err()
        }

        do {
            let value = try await task.value
            XCTFail("Should not have received \(value)")
        } catch {
            XCTAssertTrue(error is Err)
        }
    }

    func testThrowingTaskWithAssertThrowsError() async throws {
        struct Err: Error {}

        let task = task { () async throws -> Int in
            try await Task.sleep(nanoseconds: NSEC_PER_MSEC * 10)
            throw Err()
        }

        await AssertThrowsError(try await task.value) { error in
            XCTAssertTrue(error is Err)
        }
    }

    func testNonThrowingTaskWithVoidReturnValue() async throws {
        let task = task { () in
            try! await Task.sleep(nanoseconds: NSEC_PER_MSEC * 10)
        }

        try await task.value
    }

    func testThrowingTaskWithVoidReturnValue() async throws {
        let task = task {
            try await Task.sleep(nanoseconds: NSEC_PER_MSEC * 10)
        }

        try await task.value
    }

    func testTaskTimesOut() async throws {
        let task = task(timeout: 0.01) {
            try await Task.sleep(nanoseconds: NSEC_PER_SEC)
            XCTFail("Should not have completed successfully")
        }

        await AssertThrowsError(try await task.value) { error in
            XCTAssertTrue(error is TimeoutError)
        }
    }
}
