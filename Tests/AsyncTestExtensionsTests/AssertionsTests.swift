import XCTest
@testable import AsyncTestExtensions
import Synchronized

final class AssertionsTests: XCTestCase {
    func testAssertEqual() async throws {
        await AssertEqual(
            try await delayed(2),
            try await delayed(2)
        )
    }

    func testAssertTrue() async throws {
        await AssertTrue(try await delayed(true))
    }

    func testAssertFalse() async throws {
        await AssertFalse(try await delayed(false))
    }

    func testAssertNil() async throws {
        await AssertNil(try await delayed(nil as String?))
    }

    func testAssertNotNil() async throws {
        await AssertNotNil(try await delayed("some" as String?))
    }

    func testAssertThrowsError() async throws {
        struct Err: Error, Equatable {}
        await AssertThrowsError(try await delayedThrow(Err())) { err in
            XCTAssertEqual(Err(), err as? Err)
        }
    }

    func testAssertNoThrow() async throws {
        await AssertNoThrow(try await delayed("nope"))
    }

    func testAssertEqualEventually() async throws {
        let values = Locked((0, 4))
        func one() async -> Int {
            values.access { v in
                let prev = v
                v = (prev.0 + 1, prev.1)
                return prev.0
            }
        }

        func two() async -> Int {
            values.access { v in
                let prev = v
                v = (prev.0, prev.1 - 1)
                return prev.1
            }
        }

        await AssertEqualEventually(await one(), await two())
    }

    func testAssertTrueEventually() async throws {
        let count = Locked(0)
        func bool() async -> Bool {
            let c = count.access { count -> Int in
                defer { count += 1}
                return count
            }
            return c == 5
        }
        await AssertTrueEventually(await bool())
    }
}

private extension AssertionsTests {
    func delayed<T: Equatable>(_ value: T) async throws -> T {
        try await Task.sleep(nanoseconds: 5 * NSEC_PER_MSEC)
        return value
    }

    func delayedThrow<T: Error>(_ error: T) async throws {
        try await Task.sleep(nanoseconds: 5 * NSEC_PER_MSEC)
        throw error
    }
}
