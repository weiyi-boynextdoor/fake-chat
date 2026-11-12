import Foundation

struct Message: Identifiable, Codable {
    var id = UUID()
    var senderID: UUID
    var text: String
    var date = Date()
}
