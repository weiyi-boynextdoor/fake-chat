import Foundation

enum ChatPlatform: String, Codable, CaseIterable, Identifiable {
    case weChat
    case douyin

    var id: Self { self }

    var title: String {
        switch self {
        case .weChat: L.text("微信", "WeChat")
        case .douyin: L.text("抖音", "Douyin")
        }
    }
}
