import SwiftUI

struct NewConversationView: View {
    @EnvironmentObject private var store: ChatStore
    @Environment(\.dismiss) private var dismiss
    @State private var showCreate = false
    let platform: ChatPlatform
    let onSelect: (UUID) -> Void

    private var candidates: [Character] {
        store.characters.filter { $0.id != store.currentID }
    }

    var body: some View {
        NavigationStack {
            List {
                if store.current == nil {
                    Text(L.text("先创建你的当前角色，再创建聊天对象", "Create your current character first, then add someone to chat with"))
                        .foregroundStyle(.secondary)
                } else if candidates.isEmpty {
                    Text(L.text("再创建一个角色，即可开始聊天", "Create one more character to start a conversation"))
                        .foregroundStyle(.secondary)
                }
                ForEach(candidates) { character in
                    Button {
                        if let id = store.start(with: character, platform: platform) { onSelect(id) }
                    } label: {
                        HStack {
                            Avatar(character: character)
                            Text(character.name).foregroundStyle(.primary)
                        }
                    }
                }
                Button { showCreate = true } label: {
                    Label(L.text("创建角色", "Create character"), systemImage: "person.badge.plus")
                }
            }
            .navigationTitle(L.text("发起聊天", "New conversation"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L.text("取消", "Cancel")) { dismiss() }
                }
            }
            .sheet(isPresented: $showCreate) { CreateCharacterView() }
        }
    }
}
