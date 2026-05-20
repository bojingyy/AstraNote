import Foundation

public actor DatabaseProvider {
    private var state: DatabaseState
    private let persistenceURL: URL?

    public init(initialState: DatabaseState = DatabaseState(), persistenceURL: URL? = nil) {
        self.persistenceURL = persistenceURL

        if
            let persistenceURL,
            let data = try? Data(contentsOf: persistenceURL),
            let decoded = try? JSONDecoder().decode(DatabaseState.self, from: data)
        {
            self.state = decoded
        } else {
            self.state = initialState
        }
    }

    public static func defaultPersistenceURL() -> URL? {
        let fileManager = FileManager.default
        guard let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        let directory = appSupport.appendingPathComponent("AstraNotes", isDirectory: true)
        do {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        } catch {
            return nil
        }
        return directory.appendingPathComponent("database-state.json")
    }

    public func schemaVersion() -> Int {
        state.schemaVersion
    }

    public func exportState() -> DatabaseState {
        state
    }

    public func replaceState(_ newState: DatabaseState) {
        state = newState
        persistIfNeeded()
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
            persistIfNeeded()
            return result
        } catch {
            throw error
        }
    }

    private func persistIfNeeded() {
        guard let persistenceURL else {
            return
        }
        guard let data = try? JSONEncoder().encode(state) else {
            return
        }
        try? data.write(to: persistenceURL, options: .atomic)
    }
}
