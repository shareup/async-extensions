import AsyncExtensions
import AsyncTestExtensions
import Combine
import Synchronized
import XCTest

final class PublisherAsyncExtensionsTests: XCTestCase {
    func testAllValuesWithNonThrowingPublisher() async throws {
        let publisher = [0, 1, 2, 3, 4, 5].publisher
        var expected = [0, 1, 2, 3, 4, 5]

        for await value in publisher.allAsyncValues {
            XCTAssertEqual(expected.removeFirst(), value)
        }
    }

    func testCancelAllAsyncValuesIterationWithNonThrowingPublisher() async throws {
        try await serialized {
            let count = 1_000_000_000_000
            let subject = PassthroughSubject<Int, Never>()

            let streamTask = task {
                var received = [Int]()
                for await value in subject.allAsyncValues {
                    received.append(value)
                }
                XCTAssertGreaterThan(received.count, 0)
                XCTAssertLessThan(received.count, 1_000_000_000_000)
            }

            let sendTask = task {
                for i in 1 ... count {
                    subject.send(i)
                    await Task.yield()
                    if Task.isCancelled { break }
                }
            }

            await yield(10)
            streamTask.cancel()

            await AssertThrowsError(try await streamTask.value)

            sendTask.cancel()
        }
    }

    func testAsyncValuesWithNonThrowingPublisher() async throws {
        try await serialized {
            let subject = PassthroughSubject<Int, Never>()
            let received = Locked([Int]())

            let task = task {
                var iterations = 0
                for await value in subject.asyncValues {
                    defer { iterations += 1 }

                    received.access { $0.append(value) }

                    subject.send(value + 1)
                    subject.send(value + 2)
                    subject.send(value + 3)

                    if iterations == 3 { return }
                }
            }

            await yield(2)
            subject.send(1)

            try await task.value

            XCTAssertEqual([1, 4, 7, 10], received.access { $0 })
        }
    }

    func testAllAsyncValuesWithThrowingPublisher() async throws {
        struct E: Error {}

        await serialized {
            let subject = PassthroughSubject<Int, Error>()
            var received = [Int]()

            Task {
                subject.send(1)
                subject.send(2)
                subject.send(completion: .failure(E()))
            }

            do {
                for try await value in subject.allAsyncValues {
                    received.append(value)
                }

                XCTFail()
            } catch {
                XCTAssertTrue(error is E)
                XCTAssertEqual([1, 2], received)
            }
        }
    }

    func testAsyncValuesWithThrowingPublisher() async throws {
        struct E: Error {}

        try await serialized {
            let subject = PassthroughSubject<Int, Error>()
            let received = Locked([Int]())

            let task = task {
                var iterations = 0
                for try await value in subject.asyncValues {
                    defer { iterations += 1 }

                    received.access { $0.append(value) }

                    subject.send(value + 1)
                    subject.send(value + 2)
                    subject.send(value + 3)

                    if iterations == 3 {
                        subject.send(completion: .failure(E()))
                    }
                }
            }

            await yield(2)
            subject.send(1)

            await AssertThrowsError(try await task.value)

            XCTAssertEqual([1, 4, 7, 10, 13], received.access { $0 })
        }
    }

    func testCancelAllAsyncValuesIterationWithThrowingPublisher() async throws {
        try await serialized {
            let count = 1_000_000_000_000
            let subject = PassthroughSubject<Int, Error>()

            let streamTask = task {
                var received = [Int]()

                do {
                    for try await value in subject.allAsyncValues {
                        received.append(value)
                    }
                    XCTAssertGreaterThan(received.count, 0)
                    XCTAssertLessThan(received.count, 1_000_000_000_000)
                } catch {
                    XCTFail("Should not have thrown \(String(describing: error))")
                }
            }

            let sendTask = task {
                for i in 1 ... count {
                    subject.send(i)
                    await Task.yield()
                    if Task.isCancelled { break }
                }
            }

            await yield(10)
            streamTask.cancel()

            await AssertThrowsError(try await streamTask.value)

            sendTask.cancel()
        }
    }
}
