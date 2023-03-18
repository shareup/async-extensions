@testable import AsyncExtensions
import AsyncTestExtensions
import XCTest

final class AsyncOutputStreamTests: XCTestCase {
    func testWriteDataToBuffer() async throws {
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: 6)
        buffer.initialize(to: 0)

        let stream = AsyncOutputStream(buffer: buffer, length: 6)

        try await AssertEqual(3, await stream.write(Data("Hel".utf8)))
        XCTAssertTrue(buffer.hasPrefix(Data("Hel".utf8)))

        try await AssertEqual(0, await stream.write(Data()))
        XCTAssertTrue(buffer.hasPrefix(Data("Hel".utf8) + [0, 0, 0]))

        try await AssertEqual(3, await stream.write(Data("lo!".utf8)))
        XCTAssertTrue(buffer.hasPrefix(Data("Hello!".utf8)))

        try await AssertThrowsError(await stream.write(Data("NO!!!".utf8)))
        XCTAssertTrue(buffer.hasPrefix(Data("Hello!".utf8)))
    }

    func testWriteIntegersToBuffer() async throws {
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: 7)
        buffer.initialize(to: 0)

        let stream = AsyncOutputStream(buffer: buffer, length: 7)

        try await AssertEqual(4, await stream.write(987_654_321 as Int32))
        XCTAssertTrue(buffer.hasPrefix(Data([177, 104, 222, 58, 0, 0, 0])))

        try await AssertEqual(2, await stream.write(65123 as UInt16))
        XCTAssertTrue(buffer.hasPrefix(Data([177, 104, 222, 58, 99, 254, 0])))

        try await AssertEqual(1, await stream.write(15 as Int8))
        XCTAssertTrue(buffer.hasPrefix(Data([177, 104, 222, 58, 99, 254, 15])))
    }

    func testWriteToFile() async throws {
        try await inSandbox { tempDir in
            let fileURL = append("test.txt", to: tempDir)
            let stream = try AsyncOutputStream(url: fileURL)
            try await AssertEqual(6, await stream.write(Data("Hello!".utf8)))
            XCTAssertEqual("Hello!", try String(contentsOf: fileURL))
        }
    }

    func testWriteToInvalidURL() async throws {
        try await inSandbox { tempDir in
            let fileURL = append("not/an/actual/file", to: tempDir)
            let stream = try AsyncOutputStream(url: fileURL)
            try await AssertThrowsError(await stream.write(Data("Hello!".utf8)))
        }
    }
}

private extension AsyncOutputStreamTests {
    func inSandbox(_ block: (URL) async throws -> Void) async throws {
        let tempDir = FileManager.default
            .temporaryDirectory
            .appendingPathComponent("TestAsyncOutputStream-\(arc4random())")

        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        defer { try? FileManager.default.removeItem(at: tempDir) }

        try await block(tempDir)
    }

    func append(_ pathComponent: String, to url: URL) -> URL {
        if #available(macOS 13.0, *) {
            return url.appending(
                path: pathComponent,
                directoryHint: .inferFromPath
            )
        } else {
            return url.appendingPathComponent(
                pathComponent,
                isDirectory: pathComponent.hasSuffix("/")
            )
        }
    }
}

private extension UnsafeMutablePointer where Pointee == UInt8 {
    func hasPrefix(_ bytes: Data) -> Bool {
        for (i, byte) in bytes.enumerated() {
            if advanced(by: i).pointee != byte {
                return false
            }
        }
        return true
    }
}
