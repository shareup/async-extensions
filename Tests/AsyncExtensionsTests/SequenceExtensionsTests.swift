@testable import AsyncExtensions
import AsyncTestExtensions
import Synchronized
import XCTest

final class MapFunctionsTests: XCTestCase {
    func testAsyncMapOnArray() async throws {
        let square: (Int) async throws -> Int = {
            try await Task.sleep(nanoseconds: 1_000_000)
            return $0 * $0
        }

        let squares = try await [1, 2, 3].asyncMap(square)
        XCTAssertEqual([1, 4, 9], squares)
    }

    func testConcurrentMapOnArray() async throws {
        let square: (Int) async throws -> Int = {
            try await Task.sleep(nanoseconds: 1_000_000)
            return $0 * $0
        }

        let squares = try await [1, 2, 3].concurrentMap(square)
        XCTAssertEqual([1, 4, 9], squares)
    }

    func testAsyncMapRunsTasksSerially() async throws {
        struct TestState {
            var concurrentTestCount = 0 {
                didSet {
                    if concurrentTestCount > 1 {
                        didRunTestsConcurrently = true
                    }
                }
            }

            var didRunTestsConcurrently = false
        }

        let state = Locked(TestState())

        let square: (Int) async throws -> Int = {
            state.access { $0.concurrentTestCount += 1 }
            defer { state.access { $0.concurrentTestCount -= 1 } }
            try await Task.sleep(nanoseconds: 10_000_000)
            return $0 * $0
        }

        let squares = try await [1, 2, 3, 4, 5, 6, 7, 8, 9, 10].asyncMap(square)
        XCTAssertEqual([1, 4, 9, 16, 25, 36, 49, 64, 81, 100], squares)
        XCTAssertFalse(state.access { $0.didRunTestsConcurrently })
    }

    func testConcurrentMapRunsTasksConcurrently() async throws {
        struct TestState {
            var concurrentTestCount = 0 {
                didSet {
                    if concurrentTestCount > 1 {
                        didRunTestsConcurrently = true
                    }
                }
            }

            var didRunTestsConcurrently = false
        }

        let state = Locked(TestState())

        let square: (Int) async throws -> Int = {
            state.access { $0.concurrentTestCount += 1 }
            defer { state.access { $0.concurrentTestCount -= 1 } }
            try await Task.sleep(nanoseconds: 10_000_000)
            return $0 * $0
        }

        let squares = try await [1, 2, 3, 4, 5, 6, 7, 8, 9, 10].concurrentMap(square)
        XCTAssertEqual([1, 4, 9, 16, 25, 36, 49, 64, 81, 100], squares)
        XCTAssertTrue(state.access { $0.didRunTestsConcurrently })
    }
}
