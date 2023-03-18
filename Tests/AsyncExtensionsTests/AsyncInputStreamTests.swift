@testable import AsyncExtensions
import AsyncTestExtensions
import XCTest

final class AsyncInputStreamTests: XCTestCase {
    func testReadMaxLengthOfZero() async throws {
        let stream = AsyncInputStream(data: Data("Hello!".utf8))
        try await AssertNil(await stream.read(maxLength: 0))
        try await AssertNil(await stream.read(maxLength: 0))
    }

    func testReadMaxLengthWithData() async throws {
        let stream = AsyncInputStream(data: Data("Hello!".utf8))
        try await AssertEqual([72, 101, 108], await stream.read(maxLength: 3))
        try await AssertEqual([108, 111], await stream.read(maxLength: 2))
        try await AssertEqual([33], await stream.read(maxLength: 99999))
        try await AssertNil(await stream.read(maxLength: 99999))
        try await AssertThrowsError(
            await stream.read(maxLength: 99999),
            "Should have thrown an error after closing",
            { XCTAssertEqual(.closed, $0 as? AsyncInputStreamError) }
        )
    }

    func testReadMaxLengthWithURL() async throws {
        let tempDir = FileManager.default
            .temporaryDirectory
            .appendingPathComponent("TestAsyncInputStream-\(arc4random())")

        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        let url = tempDir.appendingPathComponent("text.txt")
        try Data("Hello!".utf8).write(to: url, options: .atomic)

        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }

        let stream = try AsyncInputStream(url: url)

        try await AssertEqual([72, 101, 108], await stream.read(maxLength: 3))
        try await AssertEqual([108, 111], await stream.read(maxLength: 2))
        try await AssertEqual([33], await stream.read(maxLength: 99999))
        try await AssertNil(await stream.read(maxLength: 99999))
        try await AssertThrowsError(
            await stream.read(maxLength: 99999),
            "Should have thrown an error after closing",
            { XCTAssertEqual(.closed, $0 as? AsyncInputStreamError) }
        )
    }

    func testReadLongData() async throws {
        let size = 768 * 1024
        let data = Data([UInt8](repeating: 127, count: size))

        let stream = AsyncInputStream(data: data)

        let firstSize = 256 * 1024 + 1
        try await AssertEqual(
            Array(data[0 ..< firstSize]),
            await stream.read(maxLength: firstSize)
        )

        let secondSize = size - firstSize
        try await AssertEqual(
            Array(data[firstSize...]),
            await stream.read(maxLength: secondSize)
        )
    }

    func testReadReallyReallyLongData() async throws {
        let size = 8 * 1024 * 1024
        let data = Data([UInt8](repeating: 127, count: size))

        let stream = AsyncInputStream(data: data)

        try await AssertEqual(
            await stream.read(maxLength: 4 * 1024 * 1024),
            await stream.read(maxLength: 4 * 1024 * 1024)
        )
    }

    func testMaxChunkSize() async throws {
        let data = Data([0, 1, 2, 3, 4])
        XCTAssertEqual(5, data.count)

        let fiveBytes = AsyncInputStream(data: data, maxChunkSize: 5)
        try await AssertEqual(Array(data), await fiveBytes.read(maxLength: 5))
        try await AssertNil(await fiveBytes.read(maxLength: 5))

        let fourBytes = AsyncInputStream(data: data, maxChunkSize: 4)
        try await AssertEqual(Array(data), await fourBytes.read(maxLength: 5))
        try await AssertNil(await fourBytes.read(maxLength: 5))

        let sixBytes = AsyncInputStream(data: data, maxChunkSize: 6)
        try await AssertEqual(Array(data), await sixBytes.read(maxLength: 5))
        try await AssertNil(await sixBytes.read(maxLength: 5))
    }

    func testReadUInt8() async throws {
        // 0b0111
        let value: UInt8 = 7

        let input: [UInt8] = [7]
        let stream = AsyncInputStream(data: Data(input))

        try await AssertEqual(value, await stream.read())
        try await AssertThrowsError(
            await stream.read() as UInt8,
            "Should have thrown an error after closing",
            { XCTAssertEqual(.couldNotReadFixedWidthInteger(1), $0 as? AsyncInputStreamError) }
        )
    }

    func testReadUInt32() async throws {
        // 0b0111 0101 1011 1100 1101 0001 0101
        let value: UInt32 = 123_456_789

        let input: [UInt8] = [21, 205, 91, 7]
        let stream = AsyncInputStream(data: Data(input))

        try await AssertEqual(value, await stream.read())
        try await AssertThrowsError(
            await stream.read() as UInt32,
            "Should have thrown an error after closing",
            { XCTAssertEqual(.couldNotReadFixedWidthInteger(4), $0 as? AsyncInputStreamError) }
        )
    }

    func testReadUInt64() async throws {
        // 0b0111 0000 0100 1000 1000 0110 0001 1011 0000 1111 0011 1111
        let value: UInt64 = 123_456_789_876_543

        let input: [UInt8] = [63, 15, 27, 134, 72, 112, 0, 0]
        let stream = AsyncInputStream(data: Data(input))

        try await AssertEqual(value, await stream.read())
        try await AssertThrowsError(
            await stream.read() as UInt64,
            "Should have thrown an error after closing",
            { XCTAssertEqual(.couldNotReadFixedWidthInteger(8), $0 as? AsyncInputStreamError) }
        )
    }
}
