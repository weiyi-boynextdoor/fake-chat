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
        return conversations.filter { $0.platform == platform && $0.participantIDs.contains(currentID) }
    }

    func addCharacter(name: String, symbol: String, tint: Int) {
        guard canSave else { return }
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        let character = Character(name: name, symbol: symbol, tint: tint)
        characters.append(character)
        if current == nil { currentID = character.id }
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
        if let existing = conversations.first(where: {
            $0.platform == platform && Set($0.participantIDs) == Set([currentID, character.id])
        }) { return existing.id }
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
        save()
    }

    private func save() {
        do {
            try persistence.save(SavedState(characters: characters, conversations: conversations, currentID: currentID))
        } catch {
            self.error = L.text("保存失败，请重试", "Could not save. Please try again")
        }
    }
}
