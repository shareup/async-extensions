import DispatchTimer
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
    let task = Task { () async throws -> (T, T) in
        var expr1 = try await expression1()
        var expr2 = try await expression2()

        while !Task.isCancelled, expr1 != expr2 {
            try await Task.sleep(nanoseconds: NSEC_PER_MSEC * 10)

            expr1 = try await expression1()
            expr2 = try await expression2()
        }
        return (expr1, expr2)
    }

    let timer = DispatchTimer(
        fireAt: .now() + .nanoseconds(Int(timeout * Double(NSEC_PER_SEC)))
    ) { task.cancel() }
    defer { timer.invalidate() }

    switch await task.result {
    case let .success((expr1, expr2)):
        XCTAssertEqual(expr1, expr2, message(), file: file, line: line)

    case let .failure(error):
        XCTFail("\(message()): \(String(describing: error))", file: file, line: line)
    }
}

public func AssertTrueEventually(
    _ expression: @escaping @autoclosure () async throws -> Bool,
    _ timeout: TimeInterval = 5,
    _ message: @escaping @autoclosure () -> String = "",
    file: StaticString = #filePath,
    line: UInt = #line
) async {
    let task = Task { () async throws -> Bool in
        var expr = try await expression()
        while !Task.isCancelled, !expr {
            try await Task.sleep(nanoseconds: NSEC_PER_MSEC * 10)
            expr = try await expression()
        }
        return expr
    }

    let timer = DispatchTimer(
        fireAt: .now() + .nanoseconds(Int(timeout * Double(NSEC_PER_SEC)))
    ) { task.cancel() }
    defer { timer.invalidate() }

    switch await task.result {
    case let .success(isTrue):
        XCTAssertTrue(isTrue, message(), file: file, line: line)

    case let .failure(error):
        XCTFail("\(message()): \(String(describing: error))", file: file, line: line)
    }
}
