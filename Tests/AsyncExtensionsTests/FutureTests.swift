import AsyncExtensions
import XCTest

final class FutureTests: XCTestCase {
    func testResolveBeforeAwaiting() async throws {
        let future = Future<Int>()
        future.resolve(1)
        let value = try await future.value
        XCTAssertEqual(1, value)
    }

    func testFailBeforeAwaiting() async throws {
        let future = Future<Int>()
        future.fail(TestError())
        do {
            let value = try await future.value
            XCTFail("Should not have received \(value)")
        } catch {
            XCTAssertTrue(error is TestError)
        }
    }

    func testResolveAfterAwaiting() async throws {
        let future = Future<Int>()
        later { future.resolve(1) }
        let value = try await future.value
        XCTAssertEqual(1, value)
    }

    func testFailAfterAwaiting() async throws {
        let future = Future<Int>()
        later { future.fail(TestError()) }
        do {
            let value = try await future.value
            XCTFail("Should not have received \(value)")
        } catch {
            XCTAssertTrue(error is TestError)
        }
    }

    func testResolvingMultipleTimesIsNoop() async throws {
        let future = Future<Int>()
        future.resolve(1)
        future.resolve(2)
        let value = try await future.value
        XCTAssertEqual(1, value)
    }

    func testFailingMultipleTimesIsNoop() async throws {
        let future = Future<Int>()
        future.fail(TestError())
        future.fail(CancellationError())
        do {
            let value = try await future.value
            XCTFail("Should not have received \(value)")
        } catch {
            XCTAssertTrue(error is TestError)
        }
    }

    func testFailingAfterResolvingIsNoop() async throws {
        let future = Future<Int>()
        future.resolve(1)
        future.fail(TestError())
        let value = try await future.value
        XCTAssertEqual(1, value)
    }

    func testResolvingAfterFailingIsNoop() async throws {
        let future = Future<Int>()
        future.fail(TestError())
        future.resolve(1)
        do {
            let value = try await future.value
            XCTFail("Should not have received \(value)")
        } catch {
            XCTAssertTrue(error is TestError)
        }
    }

    func testResolvingWithMultipleAwaits() async throws {
        let future = Future<Int>()

        async let await1 = future.value
        async let await2 = future.value

        later { future.resolve(1) }

        let (value1, value2) = try await (await1, await2)
        XCTAssertEqual(1, value1)
        XCTAssertEqual(1, value2)
    }

    func testFailingWithMultipleAwaits() async throws {
        let future = Future<Int>()

        async let await1 = future.value
        async let await2 = future.value

        later { future.fail(TestError()) }

        do {
            let (value1, value2) = try await (await1, await2)
            XCTFail("Should not have received \(value1) or \(value2)")
        } catch {
            XCTAssertTrue(error is TestError)
        }
    }

    func testInitWithAsyncBlock() async throws {
        let future = Future<Int> { () async throws -> Int in
            try await Task.sleep(nanoseconds: 20 * NSEC_PER_MSEC)
            return 1
        }
        let value = try await future.value
        XCTAssertEqual(1, value)
    }

    func testInitWithFailingAsyncBlock() async throws {
        let future = Future<Int> { () async throws -> Int in
            try await Task.sleep(nanoseconds: 20 * NSEC_PER_MSEC)
            throw TestError()
        }
        do {
            let value = try await future.value
            XCTFail("Should not have received \(value)")
        } catch {
            XCTAssertTrue(error is TestError)
        }
    }

    func testInitWithBlock() async throws {
        let future = Future<Int> { completion in
            later { completion(.success(1)) }
        }
        let value = try await future.value
        XCTAssertEqual(1, value)
    }

    func testInitWithFailingBlock() async throws {
        let future = Future<Int> { completion in
            later { completion(.failure(TestError())) }
        }
        do {
            let value = try await future.value
            XCTFail("Should not have received \(value)")
        } catch {
            XCTAssertTrue(error is TestError)
        }
    }

    func testResolvingWithManyAwaits() async throws {
        let future = Future<Int> { completion in
            later(milliseconds: 1) { completion(.success(1)) }
        }

        let count = 1000
        let results = await withThrowingTaskGroup(of: Int.self) { group in
            (0 ..< count).forEach { _ in group.addTask { try await future.value } }

            var results: [Result<Int, Error>] = []
            while let result = await group.nextResult() {
                results.append(result)
            }
            return results
        }

        XCTAssertEqual(count, results.count)
        XCTAssertTrue(results.allSatisfy { result in
            guard case .success(1) = result else { return false }
            return true
        })
    }

    func testFailingWithManyAwaits() async throws {
        let future = Future<Int> { completion in
            later(milliseconds: 1) { completion(.failure(TestError())) }
        }

        let count = 1000
        let results = await withThrowingTaskGroup(of: Int.self) { group in
            (0 ..< count).forEach { _ in group.addTask { try await future.value } }

            var results: [Result<Int, Error>] = []
            while let result = await group.nextResult() {
                results.append(result)
            }
            return results
        }

        XCTAssertEqual(count, results.count)
        XCTAssertTrue(results.allSatisfy { result in
            if case let .failure(error) = result {
                return error is TestError
            } else {
                return false
            }
        })
    }
}

private func later(milliseconds: Int = 20, _ block: @escaping () -> Void) {
    DispatchQueue.global().asyncAfter(
        deadline: .now() + .milliseconds(milliseconds),
        execute: block
    )
}

private struct TestError: Error {}
