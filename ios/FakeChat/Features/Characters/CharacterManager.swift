import SwiftUI

struct CharacterManager: View {
    @EnvironmentObject private var store: ChatStore
    @Environment(\.dismiss) private var dismiss
    @State private var showCreate = false
    @State private var pendingDeletion: Character?
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
                        .swipeActions {
                            Button(L.text("删除", "Delete")) { pendingDeletion = character }
                                .tint(.red)
                        }
                        .contextMenu {
                            Button(L.text("删除角色", "Delete character"), role: .destructive) { pendingDeletion = character }
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
            .alert(L.text("删除角色？", "Delete character?"), isPresented: Binding(
                get: { pendingDeletion != nil },
                set: { if !$0 { pendingDeletion = nil } }
            ), presenting: pendingDeletion) { character in
                Button(L.text("删除", "Delete"), role: .destructive) {
                    store.deleteCharacter(character.id)
                    pendingDeletion = nil
                }
                Button(L.text("取消", "Cancel"), role: .cancel) { pendingDeletion = nil }
            } message: { character in
                Text(L.text("将删除“\(character.name)”及其参与的所有聊天记录，无法撤销。", "This will permanently delete \(character.name) and all conversations involving this character."))
            }
        }
    }
}
