import SwiftUI

struct WeChatConversationListView: View {
    @EnvironmentObject private var store: ChatStore
    @State private var showCharacters = false
    @State private var showNewChat = false
    @State private var path: [UUID] = []
    @State private var search = ""
    @State private var selectedTab: WeChatTab = .chats

    private var visible: [Conversation] {
        store.conversations(for: .weChat)
            .filter { search.isEmpty || partner($0)?.name.localizedCaseInsensitiveContains(search) == true }
            .sorted { ($0.messages.last?.date ?? .distantPast) > ($1.messages.last?.date ?? .distantPast) }
    }
    private func partner(_ conversation: Conversation) -> Character? {
        conversation.participantIDs.first { $0 != store.currentID }.flatMap(store.character)
    }
    var body: some View {
        NavigationStack(path: $path) {
            VStack(spacing: 0) {
                Group {
                    switch selectedTab {
                    case .chats:
                        chatList
                    case .contacts:
                        contacts
                    case .discover:
                        ContentUnavailableView(L.text("发现", "Discover"), systemImage: "safari", description: Text(L.text("暂未添加发现内容", "No discover content yet")))
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    case .me:
                        profile
                    }
                }
                WeChatBottomBar(selection: $selectedTab)

            }
            .background(WeChatStyle.background)
            .navigationTitle(selectedTab.title).navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(WeChatStyle.background, for: .navigationBar).toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showCharacters = true } label: {
                        if let current = store.current {
                            Avatar(character: current, size: 29)
                        } else {
                            Image(systemName: "person.crop.circle").font(.system(size: 25))
                        }
                    }
                        .accessibilityLabel(L.text("切换当前角色", "Switch current character"))
                }
                if selectedTab == .chats || selectedTab == .contacts {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { showNewChat = true } label: { Image(systemName: "plus.circle").foregroundStyle(.primary) }
                            .accessibilityLabel(L.text("发起聊天", "New conversation"))
                    }
                }
            }
            .navigationDestination(for: UUID.self) { ConversationDestination(conversationID: $0) }
            .sheet(isPresented: $showCharacters) { CharacterManager() }
            .sheet(isPresented: $showNewChat) {
                NewConversationView(platform: .weChat) { id in
                    showNewChat = false
                    path.append(id)
                }
            }
            .alert(L.text("提示", "Notice"), isPresented: Binding(get: { store.error != nil }, set: { if !$0 { store.error = nil } })) {
                Button(L.text("好", "OK")) { store.error = nil }
            } message: { Text(store.error ?? "") }
        }.tint(.primary)
    }

    private var chatList: some View {
        VStack(spacing: 0) {
                HStack {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    TextField(L.text("搜索", "Search"), text: $search)
                }.padding(9).background(.white, in: RoundedRectangle(cornerRadius: 8)).padding(.horizontal, 12).padding(.vertical, 8)
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(visible) { conversation in
                            if let character = partner(conversation) {
                                Button { path.append(conversation.id) } label: {
                                    HStack(spacing: 12) {
                                        Avatar(character: character, size: 49)
                                        VStack(alignment: .leading, spacing: 7) {
                                            HStack {
                                                Text(character.name).font(.system(size: 17)).foregroundStyle(.primary)
                                                Spacer()
                                                if let date = conversation.messages.last?.date {
                                                    Text(date, style: .time).font(.system(size: 11)).foregroundStyle(.tertiary)
                                                }
                                            }
                                            Text(conversation.messages.last?.text ?? L.text("暂无消息", "No messages yet"))
                                                .font(.system(size: 14)).foregroundStyle(.secondary).lineLimit(1)
                                        }
                                    }.padding(.horizontal, 16).padding(.vertical, 13).background(.white)
                                }.buttonStyle(.plain)
                                Divider().padding(.leading, 77)
                            }
                        }
                        if visible.isEmpty {
                            if store.current == nil {
                                ContentUnavailableView {
                                    Label(L.text("创建你的第一个角色", "Create your first character"), systemImage: "person.crop.circle.badge.plus")
                                } description: {
                                    Text(L.text("先创建角色，再开始编写聊天记录", "Create characters to start composing conversations"))
                                } actions: {
                                    Button(L.text("创建角色", "Create character")) { showCharacters = true }
                                }.padding(.top, 60)
                            } else if !search.isEmpty {
                                ContentUnavailableView.search(text: search).padding(.top, 60)
                            } else {
                                ContentUnavailableView {
                                    Label(L.text("暂无聊天", "No conversations"), systemImage: "bubble.left.and.bubble.right")
                                } description: {
                                    Text(L.text("选择另一个角色开始聊天", "Choose another character to start a conversation"))
                                } actions: {
                                    Button(L.text("发起聊天", "New conversation")) { showNewChat = true }
                                }.padding(.top, 60)
                            }
                        }
                    }
                }.background(.white)
        }
    }

    private var contacts: some View {
        List {
            ForEach(store.characters.filter { $0.id != store.currentID }) { character in
                Button {
                    if let id = store.start(with: character, platform: .weChat) { path.append(id) }
                } label: {
                    HStack(spacing: 12) {
                        Avatar(character: character)
                        Text(character.name).foregroundStyle(.primary)
                    }.padding(.vertical, 4)
                }
            }
            Button { showCharacters = true } label: {
                Label(L.text("管理角色", "Manage characters"), systemImage: "person.badge.plus")
            }
        }.listStyle(.plain)
    }

    private var profile: some View {
        List {
            if let current = store.current {
                HStack(spacing: 16) {
                    Avatar(character: current, size: 60)
                    Text(current.name).font(.title3.weight(.semibold))
                }.padding(.vertical, 20)
            }
            Button { showCharacters = true } label: {
                Label(L.text("角色管理", "Characters"), systemImage: "person.2")
                    .foregroundStyle(.primary)
            }
        }.listStyle(.insetGrouped)
    }

}


private enum WeChatTab: CaseIterable {
    case chats, contacts, discover, me

    var title: String {
        switch self {
        case .chats: L.text("微信", "WeChat")
        case .contacts: L.text("通讯录", "Contacts")
        case .discover: L.text("发现", "Discover")
        case .me: L.text("我", "Me")
        }
    }


}

private struct WeChatBottomBar: View {
    @Binding var selection: WeChatTab
    private let background = Color(white: 0.97)
    private let green = Color(red: 0.04, green: 0.75, blue: 0.36)

    var body: some View {
        HStack(spacing: 0) {
            ForEach(WeChatTab.allCases, id: \.self) { tab in
                Button { selection = tab } label: {
                    VStack(spacing: 5) {
                        Group {
                            if tab == .chats {
                                WeChatTabGlyph(tab: tab).fill()
                            } else {
                                WeChatTabGlyph(tab: tab).stroke(style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round))
                            }
                        }.frame(width: 32, height: 29)
                        Text(tab.title).font(.system(size: 11))
                    }
                    .foregroundStyle(selection == tab ? green : Color(white: 0.1))
                    .frame(maxWidth: .infinity)
                    .frame(height: 53)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selection == tab ? .isSelected : [])
            }
        }
        .padding(.top, 5)
        .background(background.ignoresSafeArea(edges: .bottom))
        .overlay(alignment: .top) { Color.black.opacity(0.08).frame(height: 0.5) }
    }
}


private struct WeChatTabGlyph: Shape {
    let tab: WeChatTab

    func path(in rect: CGRect) -> Path {
        var path = Path()
        switch tab {
        case .chats:
            path.move(to: CGPoint(x: 7, y: 24))
            path.addCurve(to: CGPoint(x: 1, y: 14), control1: CGPoint(x: 3, y: 22), control2: CGPoint(x: 1, y: 18))
            path.addCurve(to: CGPoint(x: 16, y: 1), control1: CGPoint(x: 1, y: 6), control2: CGPoint(x: 8, y: 1))
            path.addCurve(to: CGPoint(x: 31, y: 14), control1: CGPoint(x: 24, y: 1), control2: CGPoint(x: 31, y: 6))
            path.addCurve(to: CGPoint(x: 13, y: 26), control1: CGPoint(x: 31, y: 23), control2: CGPoint(x: 23, y: 28))
            path.addLine(to: CGPoint(x: 4, y: 29))
            path.closeSubpath()
        case .discover:
            path.addEllipse(in: CGRect(x: 2, y: 1, width: 28, height: 28))
            path.move(to: CGPoint(x: 22, y: 8))
            path.addLine(to: CGPoint(x: 18, y: 18))
            path.addLine(to: CGPoint(x: 9, y: 22))
            path.addLine(to: CGPoint(x: 13, y: 12))
            path.closeSubpath()
        case .contacts, .me:
            path.move(to: CGPoint(x: 2, y: 28))
            path.addLine(to: CGPoint(x: 2, y: 25))
            path.addQuadCurve(to: CGPoint(x: 10, y: 20), control: CGPoint(x: 3, y: 23))
            path.addLine(to: CGPoint(x: 11, y: 17))
            path.addCurve(to: CGPoint(x: 8, y: 8), control1: CGPoint(x: 8, y: 14), control2: CGPoint(x: 8, y: 11))
            path.addCurve(to: CGPoint(x: 13, y: 2), control1: CGPoint(x: 8, y: 4), control2: CGPoint(x: 10, y: 2))
            path.addCurve(to: CGPoint(x: 18, y: 8), control1: CGPoint(x: 16, y: 2), control2: CGPoint(x: 18, y: 4))
            path.addCurve(to: CGPoint(x: 15, y: 17), control1: CGPoint(x: 18, y: 11), control2: CGPoint(x: 18, y: 14))
            path.addLine(to: CGPoint(x: 16, y: 20))
            path.addQuadCurve(to: CGPoint(x: 24, y: 25), control: CGPoint(x: 23, y: 23))
            path.addLine(to: CGPoint(x: 24, y: 28))
            path.closeSubpath()
            if tab == .contacts {
                for (y, width) in [(11.0, 9.0), (16.0, 9.0), (21.0, 6.0)] {
                    path.move(to: CGPoint(x: 23, y: y))
                    path.addLine(to: CGPoint(x: 23 + width, y: y))
                }
            } else {
                path = path.offsetBy(dx: 3, dy: 0)
            }
        }
        return path.applying(CGAffineTransform(scaleX: rect.width / 34, y: rect.height / 30))
    }
}
