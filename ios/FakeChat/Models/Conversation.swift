import Foundation

struct Conversation: Identifiable, Codable {
    var id = UUID()
    var platform: ChatPlatform = .weChat
    var participantIDs: [UUID]
    var messages: [Message] = []
    var deletedForCharacterIDs: Set<UUID> = []
    var clearedMessageCounts: [UUID: Int] = [:]

    private enum CodingKeys: String, CodingKey {
        case id, platform, participantIDs, messages, deletedForCharacterIDs, clearedMessageCounts
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
        deletedForCharacterIDs = try container.decodeIfPresent(Set<UUID>.self, forKey: .deletedForCharacterIDs) ?? []
        clearedMessageCounts = try container.decodeIfPresent([UUID: Int].self, forKey: .clearedMessageCounts) ?? [:]
    }

    func visibleMessages(for characterID: UUID) -> [Message] {
        guard participantIDs.contains(characterID) else { return [] }
        return Array(messages.dropFirst(max(0, clearedMessageCounts[characterID] ?? 0)))
    }
}
