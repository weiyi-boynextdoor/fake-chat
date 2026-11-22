import Foundation

struct ChatPersistence {
    var defaults: UserDefaults
    let platform: ChatPlatform
    let mediaDirectory: URL
    private var key: String {
        platform == .weChat ? "fake-chat.state.v1" : "fake-chat.\(platform.rawValue).state.v1"
    }

    init(defaults: UserDefaults = .standard, platform: ChatPlatform = .weChat, mediaDirectory: URL? = nil) {
        self.defaults = defaults
        self.platform = platform
        let directoryName = platform == .weChat ? "ChatMedia" : "ChatMedia-\(platform.rawValue)"
        self.mediaDirectory = mediaDirectory ?? URL.applicationSupportDirectory
            .appendingPathComponent(directoryName, isDirectory: true)
    }

    func load() throws -> SavedState? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try JSONDecoder().decode(SavedState.self, from: data)
    }

    func save(_ state: SavedState) throws {
        defaults.set(try JSONEncoder().encode(state), forKey: key)
    }

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
