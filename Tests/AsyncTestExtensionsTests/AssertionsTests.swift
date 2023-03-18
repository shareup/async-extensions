@testable import AsyncTestExtensions
import Synchronized
import XCTest

final class AssertionsTests: XCTestCase {
    func testAssertEqual() async throws {
        try await AssertEqual(
            await delayed(2),
            await delayed(2)
        )
    }

    func testAssertTrue() async throws {
        try await AssertTrue(await delayed(true))
    }

    func testAssertFalse() async throws {
        try await AssertFalse(await delayed(false))
    }

    func testAssertNil() async throws {
        try await AssertNil(await delayed(nil as String?))
    }

    func testAssertNotNil() async throws {
        try await AssertNotNil(await delayed("some" as String?))
    }

    func testAssertThrowsError() async throws {
        struct Err: Error, Equatable {}
        try await AssertThrowsError(await delayedThrow(Err())) { err in
            XCTAssertEqual(Err(), err as? Err)
        }
    }

    func testAssertNoThrow() async throws {
        try await AssertNoThrow(await delayed("nope"))
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
