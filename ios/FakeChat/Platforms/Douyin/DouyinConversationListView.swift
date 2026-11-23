import SwiftUI

struct DouyinConversationListView: View {
    @Environment(\.dismiss) private var dismissMode
    @EnvironmentObject private var store: ChatStore
    @State private var path: [UUID] = []
    @State private var tab: Tab = .messages
    @State private var showNewChat = false
    @State private var showCharacters = false
    @State private var showCreate = false

    private enum Tab {
        case messages, profile

        var title: String {
            switch self {
            case .messages: L.text("消息", "Messages")
            case .profile: L.text("我", "Me")
            }
        }
    }

    var body: some View {
        NavigationStack(path: $path) {
            VStack(spacing: 0) {
                Group {
                    switch tab {
                    case .messages: inbox
                    case .profile: profile
                    }
                }
                .frame(maxHeight: .infinity)
                bottomBar
            }
            .background(Color.white)
            .navigationTitle(tab.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.white, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismissMode() } label: {
                        Label(L.text("切换模式", "Switch mode"), systemImage: "rectangle.grid.1x2")
                    }
                }
                if tab == .messages {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { showNewChat = true } label: {
                            Label(L.text("发起私聊", "New chat"), systemImage: "square.and.pencil")
                        }
                    }
                }
            }
            .navigationDestination(for: UUID.self) { ConversationDestination(conversationID: $0) }
            .sheet(isPresented: $showNewChat) {
                NewConversationView(platform: .douyin) { id in
                    showNewChat = false
                    path.append(id)
                }
            }
            .sheet(isPresented: $showCharacters) { CharacterManager() }
            .sheet(isPresented: $showCreate) { CreateCharacterView() }
            .alert(L.text("提示", "Notice"), isPresented: Binding(get: { store.error != nil }, set: { if !$0 { store.error = nil } })) {
                Button(L.text("好", "OK")) { store.error = nil }
            } message: { Text(store.error ?? "") }
        }
        .tint(.indigo)
    }

    private var inbox: some View {
        let conversations = store.conversations(for: .douyin)
        return Group {
            if conversations.isEmpty {
                ContentUnavailableView {
                    Label(L.text("暂无私聊", "No private chats"), systemImage: "bubble.left.and.bubble.right")
                } actions: {
                    Button(L.text("发起私聊", "New chat")) { showNewChat = true }
                        .buttonStyle(.borderedProminent)
                }
            } else {
                let entries = conversations.map { (chat: $0, latest: store.messages(in: $0).last) }
                List {
                    ForEach(entries.sorted { ($0.latest?.date ?? .distantPast) > ($1.latest?.date ?? .distantPast) }, id: \.chat.id) { entry in
                        if let partnerID = entry.chat.participantIDs.first(where: { $0 != store.currentID }),
                           let partner = store.character(partnerID) {
                            Button { path.append(entry.chat.id) } label: {
                                HStack(spacing: 12) {
                                    Avatar(character: partner, size: 50).clipShape(Circle())
                                    VStack(alignment: .leading, spacing: 5) {
                                        Text(partner.name).font(.headline).lineLimit(1)
                                        Text(entry.latest?.preview ?? L.text("暂无消息", "No messages yet"))
                                            .font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .padding(.vertical, 5)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .swipeActions(allowsFullSwipe: false) {
                                Button(L.text("删除", "Delete"), role: .destructive) {
                                    store.deleteConversation(entry.chat.id)
                                }
                            }
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
    }

    private var profile: some View {
        List {
            if let character = store.current {
                NavigationLink {
                    CreateCharacterView(character: character, embeddedInNavigation: true)
                } label: {
                    HStack(spacing: 14) {
                        Avatar(character: character, size: 60).clipShape(Circle())
                        VStack(alignment: .leading, spacing: 5) {
                            Text(character.name).font(.headline)
                            if !character.signature.isEmpty {
                                Text(character.signature).font(.subheadline).foregroundStyle(.secondary)
                            }
                            Text(L.text("编辑个人资料", "Edit profile"))
                                .font(.subheadline).foregroundStyle(.indigo)
                        }
                    }
                    .padding(.vertical, 6)
                }
            } else {
                Button { showCreate = true } label: {
                    Label(L.text("创建我的资料", "Create my profile"), systemImage: "person.crop.circle.badge.plus")
                }
            }

            Button { showCharacters = true } label: {
                Label(L.text("管理角色", "Manage characters"), systemImage: "person.2")
            }
        }
        .listStyle(.insetGrouped)
    }

    private var bottomBar: some View {
        HStack(spacing: 0) {
            Text(L.text("首页", "Home")).frame(maxWidth: .infinity).accessibilityHidden(true)
            Text(L.text("朋友", "Friends")).frame(maxWidth: .infinity).accessibilityHidden(true)
            Image(systemName: "plus.app").font(.system(size: 28)).frame(maxWidth: .infinity)
                .accessibilityHidden(true)
            tabButton(.messages)
            tabButton(.profile)
        }
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(.secondary)
        .padding(.top, 4)
        .background(Color(white: 0.98).ignoresSafeArea(edges: .bottom))
        .overlay(alignment: .top) { Divider() }
    }

    private func tabButton(_ destination: Tab) -> some View {
        Button { tab = destination } label: {
            Text(destination.title)
                .foregroundStyle(tab == destination ? Color.indigo : Color.secondary)
                .frame(maxWidth: .infinity, minHeight: 46)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(tab == destination ? .isSelected : [])
    }
}
