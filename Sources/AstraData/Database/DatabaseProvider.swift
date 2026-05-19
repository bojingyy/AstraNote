import Foundation

public actor DatabaseProvider {
    private var state: DatabaseState

    public init(initialState: DatabaseState = DatabaseState()) {
        self.state = initialState
    }

    public func schemaVersion() -> Int {
        state.schemaVersion
    }

    public func read<T: Sendable>(_ operation: (DatabaseState) throws -> T) rethrows -> T {
        try operation(state)
    }

    @discardableResult
    public func transaction<T: Sendable>(_ operation: (inout DatabaseState) throws -> T) throws -> T {
        var working = state
        do {
            let result = try operation(&working)
            state = working
            return result
        } catch {
            throw error
        }
    }
}
