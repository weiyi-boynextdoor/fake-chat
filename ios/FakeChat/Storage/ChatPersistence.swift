import Foundation

struct ChatPersistence {
    var defaults: UserDefaults = .standard
    private let key = "fake-chat.state.v1"

    func load() throws -> SavedState? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try JSONDecoder().decode(SavedState.self, from: data)
    }

    func save(_ state: SavedState) throws {
        defaults.set(try JSONEncoder().encode(state), forKey: key)
    }
}
