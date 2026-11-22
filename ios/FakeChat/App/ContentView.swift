import SwiftUI

struct ContentView: View {
    @State private var selection: ChatPlatform?

    var body: some View {
        NavigationStack {
            List(ChatPlatform.allCases, id: \.self) { platform in
                Button { selection = platform } label: {
                    HStack(spacing: 14) {
                        Image(systemName: platform == .weChat ? "bubble.left.and.bubble.right.fill" : "music.note")
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(platform == .weChat ? Color.green : Color.indigo, in: RoundedRectangle(cornerRadius: 12))
                        Text(platform.title).foregroundStyle(.primary)
                        Spacer()
                        Image(systemName: "chevron.right").font(.footnote).foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 6)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .navigationTitle(L.text("选择聊天模式", "Choose chat mode"))
        }
        .fullScreenCover(item: $selection) { platform in
            PlatformConversationList(platform: platform).id(platform)
        }
    }
}

struct PlatformConversationList: View {
    @StateObject private var store: ChatStore
    let platform: ChatPlatform

    init(platform: ChatPlatform) {
        self.platform = platform
        _store = StateObject(wrappedValue: ChatStore(persistence: ChatPersistence(platform: platform)))
    }

    var body: some View {
        Group {
            switch platform {
            case .weChat: WeChatConversationListView()
            case .douyin: DouyinConversationListView()
            }
        }
        .environmentObject(store)
    }
}

struct ConversationDestination: View {
    @EnvironmentObject private var store: ChatStore
    let conversationID: UUID

    var body: some View {
        if let conversation = store.conversations.first(where: { $0.id == conversationID }) {
            WeChatChatView(conversationID: conversationID, platform: conversation.platform)
        } else {
            ContentUnavailableView(L.text("聊天不存在", "Conversation unavailable"), systemImage: "bubble.left")
        }
    }
}
