import Foundation

struct Message: Identifiable, Codable {
    var id = UUID()
    var senderID: UUID
    var text: String
    var date = Date()
    var photoData: Data?

    var videoFilename: String?
    var videoDuration: Double?

    var preview: String { videoFilename != nil ? L.text("[视频]", "[Video]") : (photoData == nil ? text : L.text("[照片]", "[Photo]")) }
}

struct MediaAttachment {
    var photoData: Data
    var videoURL: URL? = nil
    var duration: Double? = nil
}
