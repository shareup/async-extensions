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

public func AssertThrowsError(
    _ expression: @autoclosure () async throws -> some Any,
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

public func AssertNoThrow(
    _ expression: @autoclosure () async throws -> some Any,
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
    let result = await withTaskGroup(of: Result<(T, T), Error>.self) { group in
        group.addTask { () async -> Result<(T, T), Error> in
            do {
                var expr1: T
                var expr2: T

                repeat {
                    await Task.yield()
                    
                    async let _expr1 = expression1()
                    async let _expr2 = expression2()

                    (expr1, expr2) = try await (_expr1, _expr2)
                } while !Task.isCancelled && expr1 != expr2

                return .success((expr1, expr2))
            } catch {
                return .failure(error)
            }
        }

        group.addTask {
            // TODO: Replace with `Clock` once minimum supported version >= iOS 16
            try? await Task.sleep(nanoseconds: UInt64(timeout * Double(NSEC_PER_SEC)))
            return .failure(AssertionTimeoutError())
        }

        let result = await group.next()!
        group.cancelAll()
        return result
    }

    switch result {
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
    let result = await withTaskGroup(of: Result<Bool, Error>.self) { group in
        group.addTask { () async -> Result<Bool, Error> in
            do {
                var expr = try await expression()
                while !Task.isCancelled, !expr {
                    await Task.yield()
                    expr = try await expression()
                }
                return .success(expr)
            } catch {
                return .failure(error)
            }
        }

        group.addTask {
            // TODO: Replace with `Clock` once minimum supported version >= iOS 16
            try? await Task.sleep(nanoseconds: UInt64(timeout * Double(NSEC_PER_SEC)))
            return .failure(AssertionTimeoutError())
        }

        let result = await group.next()!
        group.cancelAll()
        return result
    }

    switch result {
    case let .success(isTrue):
        XCTAssertTrue(isTrue, message(), file: file, line: line)

    case let .failure(error):
        XCTFail("\(message()): \(String(describing: error))", file: file, line: line)
    }
}

private struct AssertionTimeoutError: Error, Sendable { init() {} }
