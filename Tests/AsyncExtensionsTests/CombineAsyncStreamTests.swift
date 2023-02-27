import AsyncExtensions
import AsyncTestExtensions
@preconcurrency import Combine
import XCTest

final class CombineAsyncStreamTests: XCTestCase {
    func testWithNonThrowingPublisher() async throws {
        let publisher = [0, 1, 2, 3, 4, 5].publisher
        var expected = [0, 1, 2, 3, 4, 5]

        for await value in publisher.asyncValues {
            XCTAssertEqual(expected.removeFirst(), value)
        }
    }

    func testWithThrowingPublisher() async throws {
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
            for try await value in subject.asyncValues {
                received.append(value)
            }

            XCTFail()
        } catch {
            XCTAssertTrue(error is E)
            XCTAssertEqual([1, 2], received)
        }
    }
}
