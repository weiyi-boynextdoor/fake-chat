import Combine
import Foundation

final class ChatStore: ObservableObject {
    @Published private(set) var characters: [Character] = []
    @Published private(set) var conversations: [Conversation] = []
    @Published private(set) var currentID: UUID?
    @Published var error: String?
    private let persistence: ChatPersistence
    private var canSave = true

    init(persistence: ChatPersistence = ChatPersistence()) {
        self.persistence = persistence
        do {
            if let state = try persistence.load() {
                characters = state.characters
                conversations = state.conversations
                currentID = characters.first { $0.id == state.currentID }?.id ?? characters.first?.id
            }
        } catch {
            canSave = false
            self.error = L.text("无法读取本地记录，请重启 App 后重试。原始数据已保留。", "Could not load saved conversations. Restart the app to retry. Your saved data is preserved.")
        }
    }

    var current: Character? { characters.first { $0.id == currentID } }

    func character(_ id: UUID) -> Character? {
        characters.first { $0.id == id }
    }

    func conversations(for platform: ChatPlatform) -> [Conversation] {
        guard let currentID else { return [] }
        return conversations.filter {
            $0.platform == platform && $0.participantIDs.contains(currentID)
                && !$0.deletedForCharacterIDs.contains(currentID)
        }
    }

    func messages(in conversation: Conversation) -> [Message] {
        guard let currentID else { return [] }
        return conversation.visibleMessages(for: currentID)
    }

    func deleteConversation(_ id: UUID) {
        guard canSave, let currentID,
              let index = conversations.firstIndex(where: { $0.id == id }),
              conversations[index].participantIDs.contains(currentID) else { return }
        conversations[index].deletedForCharacterIDs.insert(currentID)
        conversations[index].clearedMessageCounts[currentID] = conversations[index].messages.count
        save()
    }

    func addCharacter(name: String, avatarData: Data? = nil, signature: String = "") {
        guard canSave else { return }
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        let character = Character(name: name, avatarData: avatarData, signature: signature)
        characters.append(character)
        if current == nil { currentID = character.id }
        save()
    }

    func updateCharacter(_ id: UUID, name: String, avatarData: Data?, signature: String? = nil) {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard canSave, !name.isEmpty,
              let index = characters.firstIndex(where: { $0.id == id }) else { return }
        characters[index].name = name
        characters[index].avatarData = avatarData
        if let signature { characters[index].signature = signature }
        save()
    }

    func deleteCharacter(_ id: UUID) {
        guard canSave, characters.contains(where: { $0.id == id }) else { return }
        conversations.removeAll { $0.participantIDs.contains(id) }
        characters.removeAll { $0.id == id }
        if currentID == id { currentID = characters.first?.id }
        save()
    }

    func select(_ character: Character) {
        guard canSave, characters.contains(where: { $0.id == character.id }) else { return }
        currentID = character.id
        save()
    }

    func start(with character: Character, platform: ChatPlatform) -> UUID? {
        guard canSave, let currentID, character.id != currentID,
              characters.contains(where: { $0.id == character.id }) else { return nil }
        if let index = conversations.firstIndex(where: {
            $0.platform == platform && Set($0.participantIDs) == Set([currentID, character.id])
        }) {
            conversations[index].deletedForCharacterIDs.remove(currentID)
            save()
            return conversations[index].id
        }
        let conversation = Conversation(platform: platform, participantIDs: [currentID, character.id])
        conversations.insert(conversation, at: 0)
        save()
        return conversation.id
    }

    func send(_ text: String, to id: UUID) {
        guard canSave, let currentID, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let index = conversations.firstIndex(where: { $0.id == id }),
              conversations[index].participantIDs.contains(currentID) else { return }
        conversations[index].messages.append(Message(senderID: currentID, text: text))
        conversations[index].deletedForCharacterIDs.removeAll()
        save()
    }

    func sendPhoto(_ data: Data, to id: UUID, senderID: UUID) {
        sendPhotos([data], to: id, senderID: senderID)
    }

    func sendPhotos(_ photos: [Data], to id: UUID, senderID: UUID) {
        guard canSave, !photos.isEmpty, photos.allSatisfy({ !$0.isEmpty }),
              characters.contains(where: { $0.id == senderID }),
              let index = conversations.firstIndex(where: { $0.id == id }),
              conversations[index].participantIDs.contains(senderID) else { return }
        conversations[index].messages.append(contentsOf: photos.map { Message(senderID: senderID, text: "", photoData: $0) })
        conversations[index].deletedForCharacterIDs.removeAll()
        save()
    }

    func videoURL(for message: Message) -> URL? {
        message.videoFilename.map(persistence.videoURL)
    }

    func sendMedia(_ attachments: [MediaAttachment], to id: UUID, senderID: UUID) {
        guard canSave, !attachments.isEmpty, attachments.allSatisfy({ !$0.photoData.isEmpty }),
              characters.contains(where: { $0.id == senderID }),
              let index = conversations.firstIndex(where: { $0.id == id }),
              conversations[index].participantIDs.contains(senderID) else { return }
        var filenames: [String] = []
        do {
            let messages = try attachments.map { attachment in
                var filename: String?
                if let url = attachment.videoURL {
                    let imported = try persistence.importVideo(url)
                    filename = imported
                    filenames.append(imported)
                }
                return Message(senderID: senderID, text: "", photoData: attachment.photoData,
                               videoFilename: filename, videoDuration: attachment.duration)
            }
            var updated = conversations
            updated[index].messages.append(contentsOf: messages)
            updated[index].deletedForCharacterIDs.removeAll()
            try persistence.save(SavedState(characters: characters, conversations: updated, currentID: currentID))
            conversations = updated
        } catch {
            filenames.forEach(persistence.removeVideo)
            self.error = L.text("媒体保存失败，请重试", "Could not save media. Please try again")
        }
    }

    private func save() {
        do {
            try persistence.save(SavedState(characters: characters, conversations: conversations, currentID: currentID))
        } catch {
            self.error = L.text("保存失败，请重试", "Could not save. Please try again")
        }
    }
}
