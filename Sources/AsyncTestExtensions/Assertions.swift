import Foundation
import XCTest

public func AssertEqual<T: Equatable>(
    _ expression1: @autoclosure () async throws -> T,
    _ expression2: @autoclosure () async throws -> T,
    _ message: @autoclosure () -> String = "",
    file: StaticString = #filePath,
    line: UInt = #line
) async {
    do {
        let expr1 = try await expression1()
        let expr2 = try await expression2()
        XCTAssertEqual(expr1, expr2, message(), file: file, line: line)
    } catch {
        XCTFail("\(message()): \(String(describing: error))", file: file, line: line)
    }
}

public func AssertTrue(
    _ expression: @autoclosure () async throws -> Bool,
    _ message: @autoclosure () -> String = "",
    file: StaticString = #filePath,
    line: UInt = #line
) async {
    do {
        let expr = try await expression()
        XCTAssertTrue(expr, message(), file: file, line: line)
    } catch {
        XCTFail("\(message()): \(String(describing: error))", file: file, line: line)
    }
}

public func AssertFalse(
    _ expression: @autoclosure () async throws -> Bool,
    _ message: @autoclosure () -> String = "",
    file: StaticString = #filePath,
    line: UInt = #line
) async {
    do {
        let expr = try await expression()
        XCTAssertFalse(expr, message(), file: file, line: line)
    } catch {
        XCTFail("\(message()): \(String(describing: error))", file: file, line: line)
    }
}

public func AssertNil(
    _ expression: @autoclosure () async throws -> Any?,
    _ message: @autoclosure () -> String = "",
    file: StaticString = #filePath,
    line: UInt = #line
) async {
    do {
        let expr = try await expression()
        XCTAssertNil(expr, message(), file: file, line: line)
    } catch {
        XCTFail("\(message()): \(String(describing: error))", file: file, line: line)
    }
}

public func AssertNotNil(
    _ expression: @autoclosure () async throws -> Any?,
    _ message: @autoclosure () -> String = "",
    file: StaticString = #filePath,
    line: UInt = #line
) async {
    do {
        let expr = try await expression()
        XCTAssertNotNil(expr, message(), file: file, line: line)
    } catch {
        XCTFail("\(message()): \(String(describing: error))", file: file, line: line)
    }
}

public func AssertThrowsError<T>(
    _ expression: @autoclosure () async throws -> T,
    _ message: @autoclosure () -> String = "",
    file: StaticString = #filePath,
    line: UInt = #line,
    _ errorHandler: (_ error: Error) -> Void = { _ in }
) async {
    do {
        _ = try await expression()
        XCTFail(message(), file: file, line: line)
    } catch {
        errorHandler(error)
    }
}

public func AssertNoThrow<T>(
    _ expression: @autoclosure () async throws -> T,
    _ message: @autoclosure () -> String = "",
    file: StaticString = #filePath,
    line: UInt = #line
) async {
    do {
        _ = try await expression()
    } catch {
        XCTFail("\(message()): \(String(describing: error))", file: file, line: line)
    }
}

public func AssertEqualEventually<T: Equatable>(
    _ expression1: @escaping @autoclosure () async throws -> T,
    _ expression2: @escaping @autoclosure () async throws -> T,
    _ timeout: TimeInterval = 5,
    _ message: @escaping @autoclosure () -> String = "",
    file: StaticString = #filePath,
    line: UInt = #line
) async {
    do {
        try await withThrowingTaskGroup(
            of: Void.self
        ) { (group: inout ThrowingTaskGroup<Void, Error>) in
            _ = group.addTaskUnlessCancelled {
                try await Task.sleep(nanoseconds: UInt64(timeout * Double(NSEC_PER_SEC)))
                throw CancellationError()
            }

            _ = group.addTaskUnlessCancelled {
                var expr1 = try await expression1()
                var expr2 = try await expression2()

                while expr1 != expr2 {
                    try await Task.sleep(nanoseconds: 10 * NSEC_PER_MSEC)

                    expr1 = try await expression1()
                    expr2 = try await expression2()
                }

                XCTAssertEqual(expr1, expr2, message(), file: file, line: line)
            }

            _ = try await group.next()
            group.cancelAll()
        }
    } catch is CancellationError {
        do {
            let expr1 = try await expression1()
            let expr2 = try await expression2()
            XCTAssertEqual(expr1, expr2, message(), file: file, line: line)
        } catch {
            XCTFail("\(message()): \(String(describing: error))", file: file, line: line)
        }
    } catch {
        XCTFail("\(message()): \(String(describing: error))", file: file, line: line)
    }
}

public func AssertTrueEventually(
    _ expression1: @escaping @autoclosure () async throws -> Bool,
    _ timeout: TimeInterval = 5,
    _ message: @escaping @autoclosure () -> String = "",
    file: StaticString = #filePath,
    line: UInt = #line
) async {
    do {
        try await withThrowingTaskGroup(
            of: Void.self
        ) { (group: inout ThrowingTaskGroup<Void, Error>) in
            _ = group.addTaskUnlessCancelled {
                try await Task.sleep(nanoseconds: UInt64(timeout * Double(NSEC_PER_SEC)))
                throw CancellationError()
            }

            _ = group.addTaskUnlessCancelled {
                var expr1 = try await expression1()

                while !expr1 {
                    try await Task.sleep(nanoseconds: 10 * NSEC_PER_MSEC)
                    expr1 = try await expression1()
                }

                XCTAssertTrue(expr1, message(), file: file, line: line)
            }

            _ = try await group.next()
            group.cancelAll()
        }
    } catch is CancellationError {
        do {
            let expr1 = try await expression1()
            XCTAssertTrue(expr1, message(), file: file, line: line)
        } catch {
            XCTFail("\(message()): \(String(describing: error))", file: file, line: line)
        }
    } catch {
        XCTFail("\(message()): \(String(describing: error))", file: file, line: line)
    }
}
