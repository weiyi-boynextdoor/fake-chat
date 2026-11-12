import SwiftUI

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
                        store.addCharacter(name: name, symbol: symbol, tint: tint)
                        dismiss()
                    }.disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}
