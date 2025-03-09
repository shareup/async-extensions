import AsyncExtensions
import AsyncTestExtensions
import Foundation
import Synchronized
import XCTest

final class AnyAsyncSequenceTests: XCTestCase {
    func testErasingAsyncStream() async throws {
        let stream = makeStream()
        let any = stream.eraseToAnyAsyncSequence()

        try await serialized {
            var expectedFromStream = [0, 2]
            var expectedFromAny = [1, 3]

            let streamTask = task {
                for await number in stream {
                    XCTAssertEqual(number, expectedFromStream.removeFirst())
                }
            }

            let anyTask = task {
                for try await number in any {
                    XCTAssertEqual(number, expectedFromAny.removeFirst())
                }
            }

            try await streamTask.value
            try await anyTask.value

            XCTAssertTrue(expectedFromStream.isEmpty)
            XCTAssertTrue(expectedFromAny.isEmpty)
        }
    }
}

private extension AnyAsyncSequenceTests {
    func makeStream() -> AsyncStream<Int> {
        let numbers = Locked([0, 1, 2, 3])
        return AsyncStream(
            unfolding: {
                numbers.access { numbers in
                    guard !numbers.isEmpty else { return nil }
                    return numbers.removeFirst()
                }
            },
            onCancel: { numbers.access { $0.removeAll() } }
        )
    }
}
