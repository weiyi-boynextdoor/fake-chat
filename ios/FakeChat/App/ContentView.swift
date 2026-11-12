import SwiftUI

struct ContentView: View {
    var body: some View {
        PlatformConversationList(platform: .weChat)
    }
}

struct PlatformConversationList: View {
    let platform: ChatPlatform

    var body: some View {
        switch platform {
        case .weChat:
            WeChatConversationListView()
        }
    }
}

struct ConversationDestination: View {
    @EnvironmentObject private var store: ChatStore
    let conversationID: UUID

    var body: some View {
        if let conversation = store.conversations.first(where: { $0.id == conversationID }) {
            switch conversation.platform {
            case .weChat:
                WeChatChatView(conversationID: conversationID)
            }
        } else {
            ContentUnavailableView(L.text("聊天不存在", "Conversation unavailable"), systemImage: "bubble.left")
        }
    }
}
