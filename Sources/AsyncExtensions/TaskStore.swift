import Foundation
import Synchronized

public extension Task {
    @discardableResult
    func store(in store: TaskStore) -> String {
        store.add(self)
    }

    func store(forKey key: String, in store: TaskStore) {
        store.insert(self, forKey: key)
    }
}

public final class TaskStore: Hashable, @unchecked
Sendable {
    private let state = Locked(State())

    public init() {}

    deinit {
        state.access { $0.cancelAll() }
    }

    @discardableResult
    public func add(_ task: Task<some Any, some Any>) -> String {
        let key = UUID().uuidString
        state.access { $0.insert(task, forKey: key) }
        return key
    }

    public func insert(_ task: Task<some Any, some Any>, forKey key: String) {
        state.access { $0.insert(task, forKey: key) }
    }

    public func cancel(forKey key: String) {
        state.access { $0.cancel(forKey: key) }
    }

    public func cancelAll() {
        state.access { $0.cancelAll() }
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self))
    }

    public static func == (lhs: TaskStore, rhs: TaskStore) -> Bool {
        ObjectIdentifier(lhs) == ObjectIdentifier(rhs)
    }
}

public extension TaskStore {
    @discardableResult
    func storedTask<S: Sendable>(
        priority: TaskPriority? = nil,
        operation: @escaping @Sendable () async -> S
    ) -> String {
        Task<S, Never>(priority: priority, operation: operation)
            .store(in: self)
    }

    func storedTask<S: Sendable>(
        key: String,
        priority: TaskPriority? = nil,
        operation: @escaping @Sendable () async -> S
    ) {
        Task<S, Never>(priority: priority, operation: operation)
            .store(forKey: key, in: self)
    }

    @discardableResult
    func storedTask(
        priority: TaskPriority? = nil,
        operation: @escaping @Sendable () async throws -> some Sendable
    ) -> String {
        Task(priority: priority, operation: operation)
            .store(in: self)
    }

    func storedTask(
        key: String,
        priority: TaskPriority? = nil,
        operation: @escaping @Sendable () async throws -> some Sendable
    ) {
        Task(priority: priority, operation: operation)
            .store(forKey: key, in: self)
    }
}

private struct State {
    var tasks: [String: () -> Void] = [:]

    mutating func insert(_ task: Task<some Any, some Any>, forKey key: String) {
        cancel(forKey: key)
        tasks[key] = { task.cancel() }
    }

    mutating func cancel(forKey key: String) {
        if let cancel = tasks.removeValue(forKey: key) { cancel() }
    }

    mutating func cancelAll() {
        tasks.values.forEach { $0() }
        tasks.removeAll()
    }
}
