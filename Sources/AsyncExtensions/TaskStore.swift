import Foundation
import Synchronized

public extension Task {
    /// Inserts the task into the specified `TaskStore`.
    /// - returns: The key under which the task was stored.
    @discardableResult
    func store(in store: TaskStore) -> String {
        store.add(self)
    }

    /// Inserts the task into the specified `TaskStore` under the
    /// supplied `key`.
    func store(forKey key: String, in store: TaskStore) {
        store.insert(self, forKey: key)
    }

    /// Inserts the task into the specified `TaskStore` if there is
    /// not already a task stored under the same `key`. If there is
    /// already a task stored under the `key`, the receiver is cancelled.
    /// - returns: `true` if the task was inserted, otherwise `false`.
    func storeNew(forKey key: String, in store: TaskStore) -> Bool {
        store.insertNew(self, forKey: key)
    }
}

public final class TaskStore: Hashable, @unchecked
Sendable {
    private let state = Locked(State())

    public init() {}

    deinit {
        state.access { $0.cancelAll() }
    }

    /// Inserts the task into the receiver.
    /// - returns: The key under which the task was stored.
    @discardableResult
    public func add(_ task: Task<some Any, some Any>) -> String {
        let key = UUID().uuidString
        state.access { $0.insert(task, forKey: key) }
        return key
    }

    /// Inserts the task into the receiver under the supplied `key`.
    public func insert(_ task: Task<some Any, some Any>, forKey key: String) {
        state.access { $0.insert(task, forKey: key) }
    }

    /// Inserts the task into the receiver if there is not already a
    /// task stored under the same `key`. If there is already a task
    /// stored under the `key`, the `task` argument is cancelled.
    /// - returns: `true` if the task was inserted, otherwise `false`.
    @discardableResult
    public func insertNew(
        _ task: Task<some Any, some Any>,
        forKey key: String
    ) -> Bool {
        let didInsert = state.access { $0.insertNew(task, forKey: key) }
        if !didInsert { task.cancel() }
        return didInsert
    }

    /// Cancels the task stored under the specified key.
    public func cancel(forKey key: String) {
        state.access { $0.cancel(forKey: key) }
    }

    /// Cancels all of the tasks that satisfy the given predicate.
    public func cancelAll(where shouldBeRemoved: (String) -> Bool) {
        state.access { $0.cancelAll(where: shouldBeRemoved) }
    }

    /// Cancels all of the tasks stored in the receiver.
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
    func storedNewTask<S: Sendable>(
        key: String,
        priority: TaskPriority? = nil,
        operation: @escaping @Sendable () async -> S
    ) -> Bool {
        Task<S, Never>(priority: priority, operation: operation)
            .storeNew(forKey: key, in: self)
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

    @discardableResult
    func storedNewTask(
        key: String,
        priority: TaskPriority? = nil,
        operation: @escaping @Sendable () async throws -> some Sendable
    ) -> Bool {
        Task(priority: priority, operation: operation)
            .storeNew(forKey: key, in: self)
    }
}

private struct State {
    var tasks: [String: () -> Void] = [:]

    mutating func insert(_ task: Task<some Any, some Any>, forKey key: String) {
        cancel(forKey: key)
        tasks[key] = { task.cancel() }
    }

    mutating func insertNew(
        _ task: Task<some Any, some Any>,
        forKey key: String
    ) -> Bool {
        guard tasks[key] == nil else { return false }
        tasks[key] = { task.cancel() }
        return true
    }

    mutating func cancel(forKey key: String) {
        if let cancel = tasks.removeValue(forKey: key) { cancel() }
    }

    mutating func cancelAll(where shouldBeRemoved: (String) -> Bool) {
        let keys = Array(tasks.keys)
        keys.forEach { key in
            if shouldBeRemoved(key) {
                tasks.removeValue(forKey: key)?()
            }
        }
    }

    mutating func cancelAll() {
        tasks.values.forEach { $0() }
        tasks.removeAll()
    }
}
