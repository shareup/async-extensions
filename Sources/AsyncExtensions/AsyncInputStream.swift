import Foundation

public final class AsyncInputStream {
    // 16 KiB
    // Modeled after https://github.com/apple/swift-async-algorithms/blob/a973b06d06f2be355c562ec3ce031373514b03f5/Sources/AsyncAlgorithms/AsyncBufferedByteIterator.swift#L34
    private static let defaultMaxChunkSize: Int = 16 * 1024

    private let stream: InputStream
    private let maxChunkSize: Int

    public convenience init(url: URL) throws {
        try self.init(url: url, maxChunkSize: Self.defaultMaxChunkSize)
    }

    public convenience init(data: Data) {
        self.init(data: data, maxChunkSize: Self.defaultMaxChunkSize)
    }

    internal init(url: URL, maxChunkSize: Int) throws {
        guard let stream = InputStream(url: url)
        else { throw AsyncInputStreamError.couldNotOpenURL(url) }

        self.stream = stream
        self.maxChunkSize = maxChunkSize

        self.stream.open()
    }

    internal init(data: Data, maxChunkSize: Int) {
        stream = InputStream(data: data)
        self.maxChunkSize = maxChunkSize

        stream.open()
    }

    deinit {
        switch stream.streamStatus {
        case .closed:
            break

        default:
            stream.close()
        }
    }

    public func read<I: FixedWidthInteger>() async throws -> I {
        let size = MemoryLayout<I>.size
        let bytes = try await read(maxLength: size)
        guard let bytes, bytes.count == size else {
            throw AsyncInputStreamError.couldNotReadFixedWidthInteger(size)
        }
        var output = I()
        for i in 0 ..< size {
            output.uncheckedSetByte(at: i, to: bytes[i])
        }
        return output
    }

    public func read(maxLength len: Int) async throws -> [UInt8]? {
        guard len > 0 else { return nil }

        if case .closed = stream.streamStatus {
            throw AsyncInputStreamError.closed
        }

        let task: Task<[UInt8]?, Error> = Task {
            var buffer = [UInt8](repeating: 0, count: len)
            var totalBytesRead = 0
            var shouldStop = false

            repeat {
                guard !Task.isCancelled else {
                    throw CancellationError()
                }

                let chunkSize = min(len - totalBytesRead, self.maxChunkSize)

                let bytesRead = await self._read(
                    chunkSize: chunkSize,
                    offset: totalBytesRead,
                    into: &buffer
                )

                switch bytesRead {
                case -1:
                    self.stream.close()
                    throw self.stream.streamError ?? AsyncInputStreamError.unknown

                case 0:
                    shouldStop = true

                default:
                    totalBytesRead += bytesRead

                    if bytesRead < chunkSize {
                        shouldStop = true
                    }
                }

            } while !shouldStop && len > totalBytesRead

            if totalBytesRead > 0 {
                buffer.removeLast(len - totalBytesRead)
                return buffer
            } else {
                stream.close()
                return nil
            }
        }

        return try await task.value
    }

    private func _read(
        chunkSize: Int,
        offset: Int,
        into buffer: UnsafeMutablePointer<UInt8>
    ) async -> Int {
        await withUnsafeContinuation { (cont: UnsafeContinuation<Int, Never>) in
            let bytesRead = stream.read(buffer.advanced(by: offset), maxLength: chunkSize)
            cont.resume(returning: bytesRead)
        }
    }
}

public enum AsyncInputStreamError: Error, Equatable {
    case closed
    case couldNotOpenURL(URL)
    case couldNotReadFixedWidthInteger(Int)
    case invalidBufferPointer
    case unknown
}

private extension FixedWidthInteger {
    // https://github.com/apple/swift/blob/be0ca0a58e0086cb73224f46edb37bf306a10a6b/stdlib/public/core/SmallString.swift#L353
    @inline(__always)
    mutating func uncheckedSetByte(at i: Int, to value: UInt8) {
        precondition(i >= 0 && i < MemoryLayout<Self>.stride)

        #if _endian(big)
            let shift = (7 - Self(truncatingIfNeeded: i)) &* 8
        #else
            let shift = Self(truncatingIfNeeded: i) &* 8
        #endif

        let valueMask: Self = 0xFF &<< shift
        self = (self & ~valueMask) | (Self(truncatingIfNeeded: value) &<< shift)
    }
}
