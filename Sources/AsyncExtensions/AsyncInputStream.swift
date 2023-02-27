import Foundation

public final class AsyncInputStream {
    // 16 KiB
    // Modeled after https://github.com/apple/swift-async-algorithms/blob/a973b06d06f2be355c562ec3ce031373514b03f5/Sources/AsyncAlgorithms/AsyncBufferedByteIterator.swift#L34
    private static let defaultMaxChunkSize: Int = 16 * 1024

    private static let defaultBufferSize: Int = 512 * 1024

    private let maxChunkSize: Int

    private var state: State

    public convenience init(url: URL) throws {
        try self.init(url: url, maxChunkSize: Self.defaultMaxChunkSize)
    }

    public convenience init(data: Data) {
        self.init(data: data, maxChunkSize: Self.defaultMaxChunkSize)
    }

    internal init(url: URL, maxChunkSize: Int) throws {
        self.maxChunkSize = maxChunkSize

        guard let stream = InputStream(url: url)
        else { throw AsyncInputStreamError.couldNotOpenURL(url) }

        let bufferSize = Self.defaultBufferSize
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        buffer.initialize(repeating: 0, count: bufferSize)

        state = .open(stream, buffer, bufferSize: bufferSize)

        stream.open()
    }

    internal init(data: Data, maxChunkSize: Int) {
        self.maxChunkSize = maxChunkSize

        let stream = InputStream(data: data)
        let bufferSize = Self.defaultBufferSize
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        buffer.initialize(repeating: 0, count: bufferSize)

        state = .open(stream, buffer, bufferSize: bufferSize)

        stream.open()
    }

    deinit {
        state.close()
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

        do {
            return try await doRead(maxLength: len)
        } catch {
            state.fail(error)
            throw error
        }
    }

    private func doRead(maxLength len: Int) async throws -> [UInt8]? {
        try Task.checkCancellation()
        try state.checkOpen()

        state.resizeBuffer(to: len)

        var totalBytesRead = 0
        var shouldStop = false

        repeat {
            try Task.checkCancellation()

            let chunkSize = min(len - totalBytesRead, maxChunkSize)

            let bytesRead = try state.read(chunkSize, offset: totalBytesRead)
            precondition(bytesRead >= 0)

            shouldStop = bytesRead == 0 || bytesRead < chunkSize

            totalBytesRead += bytesRead

            await Task.yield()
        } while !shouldStop && len > totalBytesRead

        if totalBytesRead > 0 {
            return try state.copyBytesAndReset(totalBytesRead)
        } else {
            state.close()
            return nil
        }
    }
}

private enum State {
    case closed
    case failed(Error)
    case open(InputStream, UnsafeMutablePointer<UInt8>, bufferSize: Int)

    func checkOpen() throws {
        switch self {
        case .closed:
            throw AsyncInputStreamError.closed

        case let .failed(error):
            throw error

        case .open:
            break
        }
    }

    mutating func close() {
        switch self {
        case .closed, .failed:
            break

        case let .open(stream, buffer, bufferSize):
            stream.close()
            buffer.deinitialize(count: bufferSize)
            buffer.deallocate()
            self = .closed
        }
    }

    mutating func fail(_ error: Error) {
        switch self {
        case .closed, .failed:
            break

        case let .open(stream, buffer, bufferSize):
            stream.close()
            buffer.deinitialize(count: bufferSize)
            buffer.deallocate()
            self = .failed(error)
        }
    }

    func read(_ length: Int, offset: Int) throws -> Int {
        switch self {
        case .closed:
            throw AsyncInputStreamError.closed

        case let .failed(error):
            throw error

        case let .open(stream, buffer, bufferSize):
            precondition(offset + length <= bufferSize)
            let bytesRead = stream.read(buffer.advanced(by: offset), maxLength: length)
            guard bytesRead >= 0
            else { throw stream.streamError ?? POSIXError(.EIO) }
            return bytesRead
        }
    }

    func copyBytesAndReset(_ size: Int) throws -> [UInt8] {
        switch self {
        case .closed:
            throw AsyncInputStreamError.closed

        case let .failed(error):
            throw error

        case let .open(_, buffer, bufferSize):
            // This does not copy the bytes.
            let validBuffer = UnsafeMutableBufferPointer(
                start: buffer,
                count: size
            )

            // This copies the bytes into the array.
            let bytes = Array(validBuffer)

            #if compiler(>=5.8)
                buffer.update(repeating: 0, count: bufferSize)
            #else
                buffer.assign(repeating: 0, count: bufferSize)
            #endif

            return bytes
        }
    }

    mutating func resizeBuffer(to newBufferSize: Int) {
        switch self {
        case .closed, .failed:
            break

        case let .open(stream, buffer, bufferSize):
            guard newBufferSize > bufferSize else { return }

            buffer.deinitialize(count: bufferSize)
            buffer.deallocate()

            let newBuffer = UnsafeMutablePointer<UInt8>
                .allocate(capacity: newBufferSize)
            newBuffer.initialize(repeating: 0, count: newBufferSize)

            self = .open(stream, newBuffer, bufferSize: newBufferSize)
        }
    }
}

public enum AsyncInputStreamError: Error, Equatable {
    case closed
    case couldNotOpenURL(URL)
    case couldNotReadFixedWidthInteger(Int)
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
