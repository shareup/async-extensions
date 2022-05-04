import XCTest
@testable import AsyncExtensions

final class AsyncInputStreamTests: XCTestCase {
    func testReadMaxLengthWithData() async throws {
        let stream = AsyncInputStream(data: Data("Hello!".utf8))

        let first = try await stream.read(maxLength: 3)
        XCTAssertEqual([72, 101, 108], first)

        let second = try await stream.read(maxLength: 2)
        XCTAssertEqual([108, 111], second)

        let third = try await stream.read(maxLength: 99999)
        XCTAssertEqual([33], third)

        let fourth = try await stream.read(maxLength: 99999)
        XCTAssertNil(fourth)

        do {
            let _ = try await stream.read(maxLength: 99999)
            XCTFail("Should have thrown an error after closing")
        } catch {
            XCTAssertEqual(.closed, (error as? AsyncInputStreamError))
        }
    }

    func testReadMaxLengthWithURL() async throws {
        let tempDir = FileManager.default
            .temporaryDirectory
            .appendingPathComponent("testInputStreamPublisherWithValidURL-\(arc4random())")

        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        let url = tempDir.appendingPathComponent("text.txt")
        try Data("Hello!".utf8).write(to: url, options: .atomic)

        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }

        let stream = try AsyncInputStream(url: url)

        let first = try await stream.read(maxLength: 3)
        XCTAssertEqual([72, 101, 108], first)

        let second = try await stream.read(maxLength: 2)
        XCTAssertEqual([108, 111], second)

        let third = try await stream.read(maxLength: 99999)
        XCTAssertEqual([33], third)

        let fourth = try await stream.read(maxLength: 99999)
        XCTAssertNil(fourth)

        do {
            let _ = try await stream.read(maxLength: 99999)
            XCTFail("Should have thrown an error after closing")
        } catch {
            XCTAssertEqual(.closed, (error as? AsyncInputStreamError))
        }
    }

    func testReadLongData() async throws {
        let size = 768 * 1024
        let data = Data([UInt8](repeating: 127, count: size))

        let stream = AsyncInputStream(data: data)

        let firstSize = 256 * 1024 + 1
        let first = try await stream.read(maxLength: firstSize)
        XCTAssertEqual(Array(data[0 ..< firstSize]), first)

        let secondSize = size - firstSize
        let second = try await stream.read(maxLength: secondSize)
        XCTAssertEqual(Array(data[firstSize...]), second)
    }

    func testReadReallyReallyLongData() async throws {
        let size = 8 * 1024 * 1024
        let data = Data([UInt8](repeating: 127, count: size))

        let stream = AsyncInputStream(data: data)

        let first = try await stream.read(maxLength: 4 * 1024 * 1024)
        let second = try await stream.read(maxLength: 4 * 1024 * 1024)

        XCTAssertEqual(first, second)
    }

    func testReadUInt8() async throws {
        // 0b0111
        let value: UInt8 = 7

        let input: [UInt8] = [7]
        let stream = AsyncInputStream(data: Data(input))

        let output: UInt8 = try await stream.read()
        XCTAssertEqual(value, output)

        do {
            let _ = try await stream.read() as UInt8
            XCTFail("Should have thrown an error after closing")
        } catch {
            XCTAssertEqual(.couldNotReadFixedWidthInteger(1), (error as? AsyncInputStreamError))
        }
    }

    func testReadUInt32() async throws {
        // 0b0111 0101 1011 1100 1101 0001 0101
        let value: UInt32 = 123_456_789

        let input: [UInt8] = [21, 205, 91, 7]
        let stream = AsyncInputStream(data: Data(input))

        let output: UInt32 = try await stream.read()
        XCTAssertEqual(value, output)

        do {
            let _ = try await stream.read() as UInt32
            XCTFail("Should have thrown an error after closing")
        } catch {
            XCTAssertEqual(.couldNotReadFixedWidthInteger(4), (error as? AsyncInputStreamError))
        }
    }

    func testReadUInt64() async throws {
        // 0b0111 0000 0100 1000 1000 0110 0001 1011 0000 1111 0011 1111
        let value: UInt64 = 123_456_789_876_543

        let input: [UInt8] = [63, 15, 27, 134, 72, 112, 0, 0]
        let stream = AsyncInputStream(data: Data(input))

        let output: UInt64 = try await stream.read()
        XCTAssertEqual(value, output)

        do {
            let _ = try await stream.read() as UInt64
            XCTFail("Should have thrown an error after closing")
        } catch {
            XCTAssertEqual(.couldNotReadFixedWidthInteger(8), (error as? AsyncInputStreamError))
        }
    }
}
