@testable import AsyncTestExtensions
import Synchronized
import XCTest

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
        let one = [7, 6, 5, 4].async
        func first() async -> Int { await one.min()! }

        let two = [1, 2, 3, 4].async
        func second() async -> Int { await two.max()! }

        await AssertEqualEventually(await first(), await second())
    }

    func testAssertTrueEventually() async throws {
        let results = [false, false, false, true].async
        func bool() async -> Bool {
            for await result in results {
                return result
            }
            XCTFail("Should have stopped with the true result")
            return false // should never be called
        }
        await AssertTrueEventually(await bool())
    }
}

private extension AssertionsTests {
    func delayed<T: Equatable>(_ value: T) async throws -> T {
        try await Task.sleep(nanoseconds: 5 * NSEC_PER_MSEC)
        return value
    }

    func delayedThrow(_ error: some Error) async throws {
        try await Task.sleep(nanoseconds: 5 * NSEC_PER_MSEC)
        throw error
    }
}

private extension Array where Element: Sendable {
    var async: AsyncStream<Element> {
        var copy = self
        return AsyncStream { cont in
            while !copy.isEmpty {
                cont.yield(copy.removeFirst())
            }
            cont.finish()
        }
    }
}
