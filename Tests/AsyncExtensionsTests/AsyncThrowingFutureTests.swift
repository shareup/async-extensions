import AsyncExtensions
import Synchronized
import XCTest

final class AsyncThrowingFutureTests: XCTestCase {
    func testResolveBeforeAwaiting() async throws {
        let future = AsyncThrowingFuture<Int>()
        future.resolve(1)
        let value = try await future.value
        XCTAssertEqual(1, value)
    }

    func testFailBeforeAwaiting() async throws {
        let future = AsyncThrowingFuture<Int>()
        future.fail(TestError())
        do {
            let value = try await future.value
            XCTFail("Should not have received \(value)")
        } catch {
            XCTAssertTrue(error is TestError)
        }
    }

    func testResolveAfterAwaiting() async throws {
        let future = AsyncThrowingFuture<Int>()
        later { future.resolve(1) }
        let value = try await future.value
        XCTAssertEqual(1, value)
    }

    func testFailAfterAwaiting() async throws {
        let future = AsyncThrowingFuture<Int>()
        later { future.fail(TestError()) }
        do {
            let value = try await future.value
            XCTFail("Should not have received \(value)")
        } catch {
            XCTAssertTrue(error is TestError)
        }
    }

    func testResolvingMultipleTimesIsNoop() async throws {
        let future = AsyncThrowingFuture<Int>()
        future.resolve(1)
        future.resolve(2)
        let value = try await future.value
        XCTAssertEqual(1, value)
    }

    func testFailingMultipleTimesIsNoop() async throws {
        let future = AsyncThrowingFuture<Int>()
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
        let future = AsyncThrowingFuture<Int>()
        future.resolve(1)
        future.fail(TestError())
        let value = try await future.value
        XCTAssertEqual(1, value)
    }

    func testResolvingAfterFailingIsNoop() async throws {
        let future = AsyncThrowingFuture<Int>()
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
        let future = AsyncThrowingFuture<Int>()

        async let await1 = future.value
        async let await2 = future.value

        later { future.resolve(1) }

        let (value1, value2) = try await (await1, await2)
        XCTAssertEqual(1, value1)
        XCTAssertEqual(1, value2)
    }

    func testFailingWithMultipleAwaits() async throws {
        let future = AsyncThrowingFuture<Int>()

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

    func testResolvingWithManyAwaits() async throws {
        let future = AsyncThrowingFuture<Int>()
        later(milliseconds: (1 ... 10).randomElement()!) {
            future.resolve(1)
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
        let future = AsyncThrowingFuture<Int>()
        later(milliseconds: (1 ... 10).randomElement()!) {
            future.fail(TestError())
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

    func testCancel() async throws {
        let future = AsyncThrowingFuture<Int>()
        let didCancel = AsyncThrowingFuture<Void>()

        let task = Task {
            do {
                let value = try await future.value
                XCTFail("Should not have resolved to \(value)")
            } catch {
                XCTAssertTrue(error is CancellationError)
                didCancel.resolve()
            }
        }

        task.cancel()

        try await didCancel.value
    }

    func testCancelOneAwaitAmongMany() async throws {
        let future = AsyncThrowingFuture<Int>()
        let values = Locked<[Int]>([])

        let taskToCancel = Task {
            do {
                let value = try await future.value
                XCTFail("Should not have resolved to \(value)")
            } catch {
                XCTAssertTrue(error is CancellationError)
                future.resolve(1)
            }
        }

        let taskToAwait1 = Task {
            let value = try await future.value
            values.access { $0.append(value) }
        }

        let taskToAwait2 = Task {
            let value = try await future.value
            values.access { $0.append(value) }
        }

        let taskToAwait3 = Task {
            let value = try await future.value
            values.access { $0.append(value) }
        }

        // Give the tasks an opportunity to await the future
        try await Task.sleep(nanoseconds: NSEC_PER_MSEC * 20)

        taskToCancel.cancel()

        try await taskToAwait1.value
        try await taskToAwait2.value
        try await taskToAwait3.value

        XCTAssertEqual([1, 1, 1], values.access { $0 })

        let value = try await future.value
        XCTAssertEqual(1, value)
    }

    func testRandomCancellations() async throws {
        let count = 1000
        let timeoutMs = 20

        let shouldSucceed = Locked(0)
        let didSucceed = Locked(0)
        let didFail = Locked(0)

        let future = AsyncThrowingFuture<Int>()

        later(milliseconds: timeoutMs) { future.resolve(1) }

        try await withThrowingTaskGroup(of: Void.self) { group in
            (0 ..< count).forEach { _ in
                if Bool.random() {
                    // This task will probably be cancelled
                    group.addTask {
                        let task = Task {
                            do {
                                let value = try await future.value
                                XCTAssertEqual(1, value)
                                didSucceed.access { $0 += 1 }
                            } catch {
                                XCTAssertTrue(error is CancellationError)
                                didFail.access { $0 += 1 }
                            }
                        }

                        let timeout = UInt64(Double(timeoutMs) * 0.8) * NSEC_PER_MSEC
                        try await Task.sleep(nanoseconds: timeout)
                        task.cancel()
                    }

                } else {
                    // This task should definitely succeed
                    shouldSucceed.access { $0 += 1 }
                    group.addTask {
                        let value = try await future.value
                        XCTAssertEqual(1, value)
                        didSucceed.access { $0 += 1 }
                    }
                }
            }

            try await group.waitForAll()
        }

        // `didSucceed` >= `shouldSucceed`
        XCTAssertGreaterThanOrEqual(
            didSucceed.access { $0 },
            shouldSucceed.access { $0 }
        )

        XCTAssertEqual(
            count,
            didSucceed.access { $0 } + didFail.access { $0 }
        )
    }

    func testReturnValueBeforeTimeoutExpires() async throws {
        let future = AsyncThrowingFuture<Int>(timeout: 100)
        later { future.resolve(1) }
        let value = try await future.value
        XCTAssertEqual(1, value)
    }

    func testTimeoutExpiresBeforeResolution() async throws {
        let future = AsyncThrowingFuture<Int>(timeout: 0.020)
        guard case let .failure(error) = await future.result
        else { return XCTFail("Future should have failed") }
        XCTAssertTrue(error is TimeoutError)
    }

    func testTimeoutFailsAllAwaits() async throws {
        let future = AsyncThrowingFuture<Int>(timeout: 0.020)
        let task1 = Task { try await future.value }
        let task2 = Task { try await future.value }
        let task3 = Task { try await future.value }

        let results = await [task1.result, task2.result, task3.result]

        func isTimeout(_ result: Result<Int, Error>) -> Bool {
            guard case let .failure(error) = result
            else { return false }
            return error is TimeoutError
        }

        XCTAssertTrue(results.allSatisfy(isTimeout))
    }

    func testResultWithValue() async throws {
        let future = AsyncThrowingFuture<Int>()
        later { future.resolve(1) }

        let result = await future.result

        switch result {
        case let .success(value):
            XCTAssertEqual(1, value)

        case let .failure(error):
            XCTFail("Should not have received failure: \(error)")
        }
    }

    func testResultWithFailure() async throws {
        let future = AsyncThrowingFuture<Int>()
        later { future.fail(TestError()) }

        let result = await future.result

        switch result {
        case let .success(value):
            XCTFail("Should not have received success: \(value)")

        case let .failure(error):
            XCTAssertTrue(error is TestError)
        }
    }
}

private func later(milliseconds: Int = 20, _ block: @escaping () -> Void) {
    DispatchQueue.global().asyncAfter(
        deadline: .now() + .milliseconds(milliseconds),
        execute: block
    )
}

private struct TestError: Error {}
