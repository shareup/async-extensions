import Foundation

public final class AsyncOutputStream {
    private var state: State

    public init(url: URL, append: Bool) throws {
        guard let stream = OutputStream(url: url, append: append)
        else { throw AsyncOutputStreamError.couldNotOpenURL(url) }

        state = .open(stream)
        stream.open()
    }

    public init(buffer: UnsafeMutablePointer<UInt8>, length: Int) {
        let stream = OutputStream(toBuffer: buffer, capacity: length)
        state = .open(stream)
        stream.open()
    }

    deinit {
        state.close()
    }

    @discardableResult
    public func write<I: FixedWidthInteger>(_ value: I) async throws -> Int {
        let size = MemoryLayout<I>.size

        try Task.checkCancellation()

        return try await withUnsafeThrowingContinuation { cont in
            queue.async {
                do {
                    var value = value
                    let bytesWritten = try withUnsafeBytes(of: &value) { ptr in
                        try self.state.write(
                            ptr.baseAddress!.assumingMemoryBound(to: UInt8.self),
                            length: size
                        )
                    }

                    if bytesWritten == 0 { self.state.close() }

                    cont.resume(returning: bytesWritten)
                } catch {
                    self.state.fail(error)
                    cont.resume(throwing: error)
                }
            }
        } as Int
    }

    @discardableResult
    public func write(_ data: Data) async throws -> Int {
        guard data.count > 0 else { return 0 }

        try Task.checkCancellation()

        return try await withUnsafeThrowingContinuation { cont in
            queue.async {
                do {
                    let bytesWritten = try data
                        .withUnsafeBytes { (ptr: UnsafeRawBufferPointer) in
                            try self.state.write(
                                ptr.baseAddress!.assumingMemoryBound(to: UInt8.self),
                                length: data.count
                            )
                        }

                    if bytesWritten == 0 { self.state.close() }

                    cont.resume(returning: bytesWritten)
                } catch {
                    self.state.fail(error)
                    cont.resume(throwing: error)
                }
            }
        } as Int
    }
}

private enum State {
    case closed
    case failed(Error)
    case open(OutputStream)

    func checkOpen() throws {
        switch self {
        case .closed:
            throw AsyncOutputStreamError.closed

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

        case let .open(stream):
            stream.close()
            self = .closed
        }
    }

    mutating func fail(_ error: Error) {
        switch self {
        case .closed, .failed:
            break

        case let .open(stream):
            stream.close()
            self = .failed(error)
        }
    }

    func write(_ buffer: UnsafePointer<UInt8>, length: Int) throws -> Int {
        switch self {
        case .closed:
            throw AsyncOutputStreamError.closed

        case let .failed(error):
            throw error

        case let .open(stream):
            let bytesRead = stream.write(buffer, maxLength: length)
            guard bytesRead >= 0 else {
                throw stream.streamError ?? POSIXError(.EIO)
            }
            return bytesRead
        }
    }
}

public enum AsyncOutputStreamError: Error, Equatable {
    case closed
    case couldNotOpenURL(URL)
}

private let queue: DispatchQueue = {
    DispatchQueue(
        label: "app.shareup.async-output-stream",
        qos: .default,
        attributes: [],
        autoreleaseFrequency: .workItem,
        target: .global()
    )
}()
