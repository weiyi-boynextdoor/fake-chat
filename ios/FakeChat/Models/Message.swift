import Foundation

struct Message: Identifiable, Codable {
    var id = UUID()
    var senderID: UUID
    var text: String
    var date = Date()
    var photoData: Data?

    var preview: String { photoData == nil ? text : L.text("[照片]", "[Photo]") }
}
