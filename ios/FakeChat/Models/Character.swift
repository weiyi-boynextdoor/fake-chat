import Foundation

struct Character: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    var avatarData: Data?
    var signature: String

    init(id: UUID = UUID(), name: String, avatarData: Data? = nil, signature: String = "") {
        self.id = id
        self.name = name
        self.avatarData = avatarData
        self.signature = signature
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, avatarData, signature
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        avatarData = try container.decodeIfPresent(Data.self, forKey: .avatarData)
        signature = try container.decodeIfPresent(String.self, forKey: .signature) ?? ""
    }
}
