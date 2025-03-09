import Foundation

public struct AnyAsyncSequence<Element>: AsyncSequence, Sendable {
    private let _makeAsyncIterator: @Sendable () -> AsyncIterator

    public init<Base: AsyncSequence>(
        _ base: Base
    ) where Base.Element == Element, Base: Sendable {
        _makeAsyncIterator = { AnyAsyncIterator(base: base.makeAsyncIterator()) }
    }

    public func makeAsyncIterator() -> AnyAsyncIterator<Element> {
        _makeAsyncIterator()
    }
}

public struct AnyAsyncIterator<Element>: AsyncIteratorProtocol {
    private let _next: () async throws -> Element?

    public init<Base: AsyncIteratorProtocol>(
        base: Base
    ) where Base.Element == Element {
        var base = base
        _next = { try await base.next() }
    }

    public mutating func next() async throws -> Element? {
        try await _next()
    }
}

public extension AsyncSequence {
    func eraseToAnyAsyncSequence() -> AnyAsyncSequence<Element> where Self: Sendable {
        AnyAsyncSequence(self)
    }
}
