import Foundation

struct SavedState: Codable {
    var characters: [Character]
    var conversations: [Conversation]
    var currentID: UUID?
}
