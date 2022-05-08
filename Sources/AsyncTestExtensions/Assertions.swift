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

public func AssertThrowsError<T>(
    _ expression: @autoclosure () async throws -> T,
    _ message: @autoclosure () -> String = "",
    file: StaticString = #filePath,
    line: UInt = #line,
    _ errorHandler: (_ error: Error) -> Void = { _ in }
) async {
    do {
        let _ = try await expression()
        XCTFail(message(), file: file, line: line)
    } catch {
        errorHandler(error)
    }
}
