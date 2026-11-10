import SwiftUI

@main
struct FakeChatApp: App {
    @StateObject private var store = ChatStore()

    var body: some Scene {
        WindowGroup {
            ContentView().environmentObject(store).preferredColorScheme(.light)
        }
    }
}

struct Character: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var symbol: String
    var tint: Int
}

struct Message: Identifiable, Codable {
    var id = UUID()
    var senderID: UUID
    var text: String
    var date = Date()
}

struct Conversation: Identifiable, Codable {
    var id = UUID()
    var participantIDs: [UUID]
    var messages: [Message] = []
}

struct SavedState: Codable {
    var characters: [Character]
    var conversations: [Conversation]
    var currentID: UUID
}

final class ChatStore: ObservableObject {
    @Published var characters: [Character] = []
    @Published var conversations: [Conversation] = []
    @Published var currentID = UUID()
    @Published var error: String?
    private let key = "fake-chat.state.v1"

    init() {
        if let data = UserDefaults.standard.data(forKey: key) {
            do {
                let state = try JSONDecoder().decode(SavedState.self, from: data)
                characters = state.characters
                conversations = state.conversations
                currentID = state.currentID
                return
            } catch {
                self.error = L.text("无法读取本地记录", "Could not load saved conversations")
            }
        }
        let me = Character(name: L.text("我", "Me"), symbol: "person.fill", tint: 0)
        let friend = Character(name: L.text("小林", "Alex"), symbol: "leaf.fill", tint: 1)
        let colleague = Character(name: L.text("陈晨", "Charlie"), symbol: "sun.max.fill", tint: 2)
        characters = [me, friend, colleague]
        currentID = me.id
        conversations = [Conversation(participantIDs: [me.id, friend.id], messages: [
            Message(senderID: friend.id, text: L.text("周末一起去散步吧 🌿", "Shall we go for a walk this weekend? 🌿")),
            Message(senderID: me.id, text: L.text("好呀！想去哪里？", "Sure! Where would you like to go?")),
            Message(senderID: friend.id, text: L.text("去江边吧，听说那里的日落很好看。", "The riverside. I hear the sunset is beautiful there."))
        ]), Conversation(participantIDs: [me.id, colleague.id], messages: [Message(senderID: colleague.id, text: L.text("照片发给你啦，记得看看～", "Sent you the photos. Take a look!"))])]
    }

    var current: Character { characters.first { $0.id == currentID } ?? characters[0] }
    func character(_ id: UUID) -> Character? { characters.first { $0.id == id } }
    func save() {
        do {
            UserDefaults.standard.set(try JSONEncoder().encode(SavedState(characters: characters, conversations: conversations, currentID: currentID)), forKey: key)
        } catch {
            self.error = L.text("保存失败，请重试", "Could not save. Please try again")
        }
    }
    func select(_ character: Character) { currentID = character.id; save() }
    func start(with character: Character) -> UUID {
        if let existing = conversations.first(where: { Set($0.participantIDs) == Set([currentID, character.id]) }) { return existing.id }
        let conversation = Conversation(participantIDs: [currentID, character.id])
        conversations.insert(conversation, at: 0)
        save()
        return conversation.id
    }
    func send(_ text: String, to id: UUID) {
        guard let index = conversations.firstIndex(where: { $0.id == id }), conversations[index].participantIDs.contains(currentID) else { return }
        conversations[index].messages.append(Message(senderID: currentID, text: text))
        save()
    }
}

enum L {
    static func text(_ chinese: String, _ english: String) -> String {
        Locale.preferredLanguages.first?.hasPrefix("zh") == true ? chinese : english
    }
}

extension Color {
    static let chatBackground = Color(white: 0.93)
    static let wechatGreen = Color(red: 0.58, green: 0.92, blue: 0.39)
}

struct Avatar: View {
    let character: Character
    var size: CGFloat = 44
    private var color: Color { [.teal, .green, .orange, .blue, .purple][abs(character.tint % 5)] }
    var body: some View {
        Image(systemName: character.symbol)
            .font(.system(size: size * 0.46, weight: .medium))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(color.gradient, in: RoundedRectangle(cornerRadius: size * 0.13))
    }
}

struct ContentView: View {
    @EnvironmentObject private var store: ChatStore
    @State private var showCharacters = false
    @State private var showNewChat = false
    @State private var path: [UUID] = []
    @State private var search = ""

    private var visible: [Conversation] {
        store.conversations.filter { $0.participantIDs.contains(store.currentID) }
            .filter { search.isEmpty || partner($0)?.name.localizedCaseInsensitiveContains(search) == true }
            .sorted { ($0.messages.last?.date ?? .distantPast) > ($1.messages.last?.date ?? .distantPast) }
    }
    private func partner(_ conversation: Conversation) -> Character? {
        conversation.participantIDs.first { $0 != store.currentID }.flatMap(store.character)
    }
    var body: some View {
        NavigationStack(path: $path) {
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
                            ContentUnavailableView(L.text("暂无聊天", "No conversations"), systemImage: "bubble.left.and.bubble.right", description: Text(L.text("点击右上角 + 发起聊天", "Tap + to start a conversation"))).padding(.top, 60)
                        }
                    }
                }.background(.white)
                HStack {
                    VStack(spacing: 4) {
                        Image(systemName: "bubble.left.and.bubble.right.fill").font(.system(size: 23))
                        Text(L.text("微信", "Chats")).font(.system(size: 11))
                    }.foregroundStyle(.green).frame(maxWidth: .infinity)
                    Button { showCharacters = true } label: {
                        VStack(spacing: 4) {
                            Image(systemName: "person.crop.circle").font(.system(size: 23))
                            Text(L.text("角色", "Characters")).font(.system(size: 11))
                        }.frame(maxWidth: .infinity)
                    }.tint(.secondary)
                }.padding(.top, 10).padding(.bottom, 6).background(Color(white: 0.97))
            }
            .background(Color.chatBackground)
            .navigationTitle(L.text("微信", "WeChat")).navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.chatBackground, for: .navigationBar).toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showCharacters = true } label: { Avatar(character: store.current, size: 29) }
                        .accessibilityLabel(L.text("切换当前角色", "Switch current character"))
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showNewChat = true } label: { Image(systemName: "plus.circle").foregroundStyle(.primary) }
                        .accessibilityLabel(L.text("发起聊天", "New conversation"))
                }
            }
            .navigationDestination(for: UUID.self) { ChatView(conversationID: $0) }
            .sheet(isPresented: $showCharacters) { CharacterManager() }
            .sheet(isPresented: $showNewChat) {
                NavigationStack {
                    List(store.characters.filter { $0.id != store.currentID }) { character in
                        Button {
                            let id = store.start(with: character)
                            showNewChat = false
                            path.append(id)
                        } label: { HStack { Avatar(character: character); Text(character.name).foregroundStyle(.primary) } }
                    }
                    .navigationTitle(L.text("发起聊天", "New conversation"))
                    .toolbar { ToolbarItem(placement: .cancellationAction) { Button(L.text("取消", "Cancel")) { showNewChat = false } } }
                }
            }
            .alert(L.text("提示", "Notice"), isPresented: Binding(get: { store.error != nil }, set: { if !$0 { store.error = nil } })) {
                Button(L.text("好", "OK")) { store.error = nil }
            } message: { Text(store.error ?? "") }
        }.tint(.primary)
    }
}

struct ChatView: View {
    @EnvironmentObject private var store: ChatStore
    let conversationID: UUID
    @State private var draft = ""
    @State private var showSender = false
    private var conversation: Conversation? { store.conversations.first { $0.id == conversationID } }
    private var partner: Character? { conversation?.participantIDs.first { $0 != store.currentID }.flatMap(store.character) }

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 18) {
                        if let first = conversation?.messages.first {
                            Text(first.date, format: .dateTime.month().day().hour().minute())
                                .font(.system(size: 12)).foregroundStyle(.secondary).padding(.top, 18)
                        }
                        ForEach(conversation?.messages ?? []) { message in
                            if let sender = store.character(message.senderID) {
                                messageRow(message, sender: sender).id(message.id)
                            }
                        }
                    }.padding(.horizontal, 12).padding(.bottom, 20)
                }
                .scrollDismissesKeyboard(.interactively)
                .onAppear { if let id = conversation?.messages.last?.id { proxy.scrollTo(id, anchor: .bottom) } }
                .onChange(of: conversation?.messages.count) { _, _ in
                    if let id = conversation?.messages.last?.id { withAnimation { proxy.scrollTo(id, anchor: .bottom) } }
                }
            }
            Divider()
            HStack(alignment: .bottom, spacing: 10) {
                Image(systemName: "waveform.circle").font(.system(size: 27)).padding(.bottom, 5).accessibilityHidden(true)
                TextField(L.text("输入消息", "Message"), text: $draft, axis: .vertical)
                    .lineLimit(1...5).padding(10).background(.white, in: RoundedRectangle(cornerRadius: 5))
                if draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Image(systemName: "face.smiling").font(.system(size: 25)).padding(.bottom, 6).accessibilityHidden(true)
                } else {
                    Button(L.text("发送", "Send")) {
                        store.send(draft, to: conversationID)
                        draft = ""
                    }.font(.system(size: 15, weight: .medium)).padding(.horizontal, 12).padding(.vertical, 10)
                        .background(Color.green, in: RoundedRectangle(cornerRadius: 5)).foregroundStyle(.white)
                }
            }.padding(.horizontal, 10).padding(.vertical, 8).background(Color(white: 0.96))
        }
        .background(Color.chatBackground)
        .navigationTitle(partner?.name ?? "").navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.chatBackground, for: .navigationBar).toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showSender = true } label: { Image(systemName: "ellipsis").foregroundStyle(.primary) }
                    .accessibilityLabel(L.text("切换发送角色", "Switch sender"))
            }
        }
        .confirmationDialog(L.text("切换发送角色", "Switch sender"), isPresented: $showSender, titleVisibility: .visible) {
            ForEach(store.characters.filter { conversation?.participantIDs.contains($0.id) == true }) { character in
                Button(character.name + (character.id == store.currentID ? " ✓" : "")) { store.select(character) }
            }
        }
    }

    private func messageRow(_ message: Message, sender: Character) -> some View {
        let outgoing = sender.id == store.currentID
        return HStack(alignment: .top, spacing: 8) {
            if outgoing { Spacer(minLength: 55) } else { Avatar(character: sender, size: 40) }
            Text(message.text).font(.system(size: 17)).foregroundStyle(.black)
                .padding(.horizontal, 12).padding(.vertical, 10)
                .background(outgoing ? Color.wechatGreen : .white, in: RoundedRectangle(cornerRadius: 5))
                .overlay(alignment: outgoing ? .trailing : .leading) {
                    Triangle().fill(outgoing ? Color.wechatGreen : .white)
                        .frame(width: 7, height: 12).rotationEffect(.degrees(outgoing ? 90 : -90))
                        .offset(x: outgoing ? 5 : -5, y: -2)
                }
            if outgoing { Avatar(character: sender, size: 40) } else { Spacer(minLength: 55) }
        }
    }
}

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.midX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.closeSubpath()
        }
    }
}

struct CharacterManager: View {
    @EnvironmentObject private var store: ChatStore
    @Environment(\.dismiss) private var dismiss
    @State private var showCreate = false
    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(store.characters) { character in
                        Button { store.select(character) } label: {
                            HStack(spacing: 12) {
                                Avatar(character: character)
                                Text(character.name).foregroundStyle(.primary)
                                Spacer()
                                if store.currentID == character.id { Image(systemName: "checkmark.circle.fill").foregroundStyle(.green) }
                            }.padding(.vertical, 4)
                        }
                    }
                } header: { Text(L.text("当前角色", "Current character")) } footer: {
                    Text(L.text("切换角色后，以该角色的身份查看和发送消息。聊天页右上角也可以切换双方角色。", "View and send messages as the selected character. You can also switch between participants from the chat menu."))
                }
                Button { showCreate = true } label: { Label(L.text("创建角色", "Create character"), systemImage: "person.badge.plus") }.tint(.green)
            }
            .navigationTitle(L.text("角色管理", "Characters"))
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button(L.text("完成", "Done")) { dismiss() } } }
            .sheet(isPresented: $showCreate) { CreateCharacterView() }
        }
    }
}

struct CreateCharacterView: View {
    @EnvironmentObject private var store: ChatStore
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var symbol = "person.fill"
    @State private var tint = 0
    private let symbols = ["person.fill", "leaf.fill", "sun.max.fill", "cat.fill", "star.fill", "moon.fill"]
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack { Spacer(); Avatar(character: Character(name: name, symbol: symbol, tint: tint), size: 80); Spacer() }.listRowBackground(Color.clear)
                }
                Section(L.text("昵称", "Name")) { TextField(L.text("输入角色昵称", "Enter character name"), text: $name) }
                Section(L.text("头像", "Avatar")) {
                    HStack {
                        ForEach(symbols, id: \.self) { item in
                            Button { symbol = item } label: {
                                Image(systemName: item).frame(maxWidth: .infinity).padding(.vertical, 10)
                                    .foregroundStyle(symbol == item ? .green : .secondary)
                            }.buttonStyle(.plain)
                        }
                    }
                    Picker(L.text("颜色", "Color"), selection: $tint) {
                        Text(L.text("青色", "Teal")).tag(0)
                        Text(L.text("绿色", "Green")).tag(1)
                        Text(L.text("橙色", "Orange")).tag(2)
                        Text(L.text("蓝色", "Blue")).tag(3)
                        Text(L.text("紫色", "Purple")).tag(4)
                    }
                }
            }
            .navigationTitle(L.text("创建角色", "Create character")).navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(L.text("取消", "Cancel")) { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L.text("保存", "Save")) {
                        store.characters.append(Character(name: name.trimmingCharacters(in: .whitespacesAndNewlines), symbol: symbol, tint: tint))
                        store.save()
                        dismiss()
                    }.disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}
