import Foundation

struct Conversation: Identifiable, Codable {
    var id = UUID()
    var platform: ChatPlatform = .weChat
    var participantIDs: [UUID]
    var messages: [Message] = []

    private enum CodingKeys: String, CodingKey {
        case id, platform, participantIDs, messages
    }

    init(platform: ChatPlatform = .weChat, participantIDs: [UUID], messages: [Message] = []) {
        self.platform = platform
        self.participantIDs = participantIDs
        self.messages = messages
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        platform = try container.decodeIfPresent(ChatPlatform.self, forKey: .platform) ?? .weChat
        participantIDs = try container.decode([UUID].self, forKey: .participantIDs)
        messages = try container.decode([Message].self, forKey: .messages)
    }
}
