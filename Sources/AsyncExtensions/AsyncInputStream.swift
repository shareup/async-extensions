import Foundation

public actor AsyncInputStream {
    private let stream: InputStream

    public init(url: URL) throws {
        guard let stream = InputStream(url: url)
        else { throw AsyncInputStreamError.couldNotOpenURL(url) }

        self.stream = stream
        self.stream.open()
    }

    public init(data: Data) {
        stream = InputStream(data: data)
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

    public func read<I: FixedWidthInteger>() throws -> I {
        let size = MemoryLayout<I>.size
        let bytes = try read(maxLength: size)
        guard let bytes = bytes, bytes.count == size else {
            throw AsyncInputStreamError.couldNotReadFixedWidthInteger(size)
        }
        var output = I()
        for i in 0..<size {
            output.uncheckedSetByte(at: i, to: bytes[i])
        }
        return output
    }

    public func read(maxLength len: Int) throws -> [UInt8]? {
        if case .closed = stream.streamStatus {
            throw AsyncInputStreamError.closed
        }

        var buffer = [UInt8](repeating: 0, count: len)
        let bytesRead = stream.read(&buffer, maxLength: len)
        switch bytesRead {
        case -1:
            stream.close()
            throw stream.streamError ?? AsyncInputStreamError.unknown

        case 0:
            stream.close()
            return nil

        default:
            buffer.removeLast(len - bytesRead)
            return buffer
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
