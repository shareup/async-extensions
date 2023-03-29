import AsyncExtensions
import AsyncTestExtensions
@preconcurrency import Combine
import Synchronized
import XCTest

final class PublisherAsyncExtensionsTests: XCTestCase {
    func testAllValuesWithNonThrowingPublisher() async throws {
        let publisher = [0, 1, 2, 3, 4, 5].publisher
        var expected = [0, 1, 2, 3, 4, 5]

        for await value in publisher.allValues {
            XCTAssertEqual(expected.removeFirst(), value)
        }
    }

    func testCanCancelAllValuesIterationWithNonThrowingPublisher() async throws {
        let count = 1_000_000_000_000
        let subject = PassthroughSubject<Int, Never>()

        let streamTask = Task {
            var received = [Int]()
            for await value in subject.allValues {
                received.append(value)
            }
            XCTAssertLessThan(received.count, 1_000_000_000_000)
        }

        let sendTask = Task {
            for i in 1 ... count {
                subject.send(i)
                await Task.yield()
                if Task.isCancelled { break }
            }
        }

        try await Task.sleep(nanoseconds: NSEC_PER_MSEC * 10)
        streamTask.cancel()

        await streamTask.value

        sendTask.cancel()
    }

    func testAllValuesWithThrowingPublisher() async throws {
        struct E: Error {}
        let subject = PassthroughSubject<Int, Error>()
        var received = [Int]()

        Task {
            try await Task.sleep(nanoseconds: NSEC_PER_MSEC * 10)
            subject.send(1)
            try await Task.sleep(nanoseconds: NSEC_PER_MSEC * 10)
            subject.send(2)
            try await Task.sleep(nanoseconds: NSEC_PER_MSEC * 10)
            subject.send(completion: .failure(E()))
        }

        do {
            for try await value in subject.allValues {
                received.append(value)
            }

            XCTFail()
        } catch {
            XCTAssertTrue(error is E)
            XCTAssertEqual([1, 2], received)
        }
    }

    func testCanCancelAllValuesIterationWithThrowingPublisher() async throws {
        let count = 1_000_000_000_000
        let subject = PassthroughSubject<Int, Error>()

        let streamTask = Task {
            var received = [Int]()

            do {
                for try await value in subject.allValues {
                    received.append(value)
                }
                XCTAssertLessThan(received.count, 1_000_000_000_000)
            } catch {
                XCTFail("Should not have thrown \(String(describing: error))")
            }
        }

        let sendTask = Task {
            for i in 1 ... count {
                subject.send(i)
                await Task.yield()
                if Task.isCancelled { break }
            }
        }

        try await Task.sleep(nanoseconds: NSEC_PER_MSEC * 10)
        streamTask.cancel()

        await streamTask.value

        sendTask.cancel()
    }
}
