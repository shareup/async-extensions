import AsyncExtensions
import XCTest

final class TaskStoreTests: XCTestCase {
    func testHashable() {
        let store1 = TaskStore()
        let store2 = TaskStore()

        XCTAssertEqual(store1, store1)
        XCTAssertNotEqual(store1, store2)
        XCTAssertEqual(store2.hashValue, store2.hashValue)
        XCTAssertNotEqual(store1.hashValue, store2.hashValue)
    }

    func testAddingMultipleDifferentTypesOfTasks() throws {
        let store = TaskStore()

        let ex1 = expectation(description: "Task 1 should have been cancelled")
        let key1 = store.storedTask {
            do {
                try await Task.sleep(nanoseconds: NSEC_PER_SEC * 10)
                XCTFail("Should not have completed")
                return 1
            } catch {
                ex1.fulfill()
                return 0
            }
        }
        XCTAssertNotNil(UUID(uuidString: key1))

        let ex2 = expectation(description: "Task 2 should have been cancelled")
        let key2 = "second one"
        store.storedTask(key: key2) {
            do {
                try await Task.sleep(nanoseconds: NSEC_PER_SEC * 10)
                XCTFail("Should not have completed")
                return "Nope"
            } catch {
                ex2.fulfill()
                throw error
            }
        }

        store.cancel(forKey: key2)
        wait(for: [ex2], timeout: 2)

        store.cancelAll()
        wait(for: [ex1], timeout: 2)
    }

    func testInsertNew() throws {
        let store = TaskStore()

        let key = "key"

        let ex1 = expectation(description: "Task 1 should complete")
        let didInsert1 = store.insertNew(
            Task {
                do {
                    try await Task.sleep(nanoseconds: NSEC_PER_MSEC * 100)
                    ex1.fulfill()
                } catch {
                    XCTFail("Should have completed")
                }
            },
            forKey: key
        )

        let ex2 = expectation(description: "Task 2 should have been cancelled")
        let didInsert2 = store.insertNew(
            Task {
                do {
                    try await Task.sleep(nanoseconds: NSEC_PER_SEC * 10)
                    XCTFail("Should have been cancelled")
                } catch is CancellationError {
                    ex2.fulfill()
                } catch {
                    XCTFail("Should have received CancellationError, not \(error)")
                }
            },
            forKey: key
        )

        wait(for: [ex1, ex2], timeout: 2)
        XCTAssertTrue(didInsert1)
        XCTAssertFalse(didInsert2)
    }

    func testAllTasksAreCancelledOnDeinitialization() throws {
        let ex1 = expectation(description: "Task 1 should have been cancelled")
        let ex2 = expectation(description: "Task 2 should have been cancelled")
        let ex3 = expectation(description: "Task 3 should have been cancelled")

        autoreleasepool {
            let store = TaskStore()

            store.storedTask {
                do {
                    try await Task.sleep(nanoseconds: NSEC_PER_SEC * 10)
                    XCTFail("Should not have completed")
                    return 1
                } catch {
                    ex1.fulfill()
                    return 0
                }
            }

            store.storedTask(key: "task2") {
                do {
                    try await Task.sleep(nanoseconds: NSEC_PER_SEC * 10)
                    XCTFail("Should not have completed")
                    return "Nope"
                } catch {
                    ex2.fulfill()
                    return "Yep"
                }
            }

            store.storedTask {
                do {
                    try await Task.sleep(nanoseconds: NSEC_PER_SEC * 10)
                    XCTFail("Should not have completed")
                    return Double(999.99)
                } catch {
                    ex3.fulfill()
                    throw error
                }
            }
        }

        wait(for: [ex1, ex2, ex3], timeout: 2)
    }
}
