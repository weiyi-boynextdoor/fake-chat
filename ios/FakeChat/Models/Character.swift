import Foundation

struct Character: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var symbol: String
    var tint: Int
}
