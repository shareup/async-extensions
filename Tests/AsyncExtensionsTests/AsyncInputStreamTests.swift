@testable import AsyncExtensions
import AsyncTestExtensions
import XCTest

final class AsyncInputStreamTests: XCTestCase {
    func testReadMaxLengthOfZero() async throws {
        let stream = AsyncInputStream(data: Data("Hello!".utf8))
        await AssertNil(try await stream.read(maxLength: 0))
        await AssertNil(try await stream.read(maxLength: 0))
    }

    func testReadMaxLengthWithData() async throws {
        let stream = AsyncInputStream(data: Data("Hello!".utf8))
        await AssertEqual([72, 101, 108], try await stream.read(maxLength: 3))
        await AssertEqual([108, 111], try await stream.read(maxLength: 2))
        await AssertEqual([33], try await stream.read(maxLength: 99999))
        await AssertNil(try await stream.read(maxLength: 99999))
        await AssertThrowsError(
            try await stream.read(maxLength: 99999),
            "Should have thrown an error after closing",
            { XCTAssertEqual(.closed, $0 as? AsyncInputStreamError) }
        )
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

        await AssertEqual([72, 101, 108], try await stream.read(maxLength: 3))
        await AssertEqual([108, 111], try await stream.read(maxLength: 2))
        await AssertEqual([33], try await stream.read(maxLength: 99999))
        await AssertNil(try await stream.read(maxLength: 99999))
        await AssertThrowsError(
            try await stream.read(maxLength: 99999),
            "Should have thrown an error after closing",
            { XCTAssertEqual(.closed, $0 as? AsyncInputStreamError) }
        )
    }

    func testReadLongData() async throws {
        let size = 768 * 1024
        let data = Data([UInt8](repeating: 127, count: size))

        let stream = AsyncInputStream(data: data)

        let firstSize = 256 * 1024 + 1
        await AssertEqual(
            Array(data[0 ..< firstSize]),
            try await stream.read(maxLength: firstSize)
        )

        let secondSize = size - firstSize
        await AssertEqual(
            Array(data[firstSize...]),
            try await stream.read(maxLength: secondSize)
        )
    }

    func testReadReallyReallyLongData() async throws {
        let size = 8 * 1024 * 1024
        let data = Data([UInt8](repeating: 127, count: size))

        let stream = AsyncInputStream(data: data)

        await AssertEqual(
            try await stream.read(maxLength: 4 * 1024 * 1024),
            try await stream.read(maxLength: 4 * 1024 * 1024)
        )
    }

    func testReadBytesPastEndDoesNotThrow() async throws {
        let size = 128 * 1024
        let data = Data([UInt8](repeating: 127, count: size))

        let stream = AsyncInputStream(data: data)

        let chunk = try await stream.read(maxLength: size)
        XCTAssertEqual(data, Data(try XCTUnwrap(chunk)))

        let noChunk1 = try await stream.read(maxLength: size)
        XCTAssertNil(noChunk1)

        let noChunk2 = try await stream.read(maxLength: size)
        XCTAssertNil(noChunk2)
    }

    func testMaxChunkSize() async throws {
        let data = Data([0, 1, 2, 3, 4])
        XCTAssertEqual(5, data.count)

        let fiveBytes = AsyncInputStream(data: data, maxChunkSize: 5)
        await AssertEqual(Array(data), try await fiveBytes.read(maxLength: 5))
        await AssertNil(try await fiveBytes.read(maxLength: 5))

        let fourBytes = AsyncInputStream(data: data, maxChunkSize: 4)
        await AssertEqual(Array(data), try await fourBytes.read(maxLength: 5))
        await AssertNil(try await fourBytes.read(maxLength: 5))

        let sixBytes = AsyncInputStream(data: data, maxChunkSize: 6)
        await AssertEqual(Array(data), try await sixBytes.read(maxLength: 5))
        await AssertNil(try await sixBytes.read(maxLength: 5))
    }

    func testReadUInt8() async throws {
        // 0b0111
        let value: UInt8 = 7

        let input: [UInt8] = [7]
        let stream = AsyncInputStream(data: Data(input))

        await AssertEqual(value, try await stream.read())
        await AssertThrowsError(
            try await stream.read() as UInt8,
            "Should have thrown an error after closing",
            { XCTAssertEqual(.couldNotReadFixedWidthInteger(1), $0 as? AsyncInputStreamError) }
        )
    }

    func testReadUInt32() async throws {
        // 0b0111 0101 1011 1100 1101 0001 0101
        let value: UInt32 = 123_456_789

        let input: [UInt8] = [21, 205, 91, 7]
        let stream = AsyncInputStream(data: Data(input))

        await AssertEqual(value, try await stream.read())
        await AssertThrowsError(
            try await stream.read() as UInt32,
            "Should have thrown an error after closing",
            { XCTAssertEqual(.couldNotReadFixedWidthInteger(4), $0 as? AsyncInputStreamError) }
        )
    }

    func testReadUInt64() async throws {
        // 0b0111 0000 0100 1000 1000 0110 0001 1011 0000 1111 0011 1111
        let value: UInt64 = 123_456_789_876_543

        let input: [UInt8] = [63, 15, 27, 134, 72, 112, 0, 0]
        let stream = AsyncInputStream(data: Data(input))

        await AssertEqual(value, try await stream.read())
        await AssertThrowsError(
            try await stream.read() as UInt64,
            "Should have thrown an error after closing",
            { XCTAssertEqual(.couldNotReadFixedWidthInteger(8), $0 as? AsyncInputStreamError) }
        )
    }
}
