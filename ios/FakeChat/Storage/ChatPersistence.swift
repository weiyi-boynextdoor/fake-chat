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
    var mediaDirectory: URL = URL.applicationSupportDirectory.appendingPathComponent("ChatMedia", isDirectory: true)

    func videoURL(_ filename: String) -> URL {
        mediaDirectory.appendingPathComponent(filename)
    }

    func importVideo(_ source: URL) throws -> String {
        try FileManager.default.createDirectory(at: mediaDirectory, withIntermediateDirectories: true)
        let filename = UUID().uuidString + "." + (source.pathExtension.isEmpty ? "mov" : source.pathExtension)
        try FileManager.default.copyItem(at: source, to: videoURL(filename))
        return filename
    }

    func removeVideo(_ filename: String) {
        try? FileManager.default.removeItem(at: videoURL(filename))
    }

}
