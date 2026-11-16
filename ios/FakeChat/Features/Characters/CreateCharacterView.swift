import PhotosUI
import SwiftUI
import UIKit

struct CreateCharacterView: View {
    @EnvironmentObject private var store: ChatStore
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var avatarData: Data?
    @State private var signature: String
    @State private var selection: PhotosPickerItem?
    @State private var isLoading = false
    @State private var photoError: String?
    @State private var cropRequest: AvatarCropRequest?
    private let characterID: UUID?
    private let embeddedInNavigation: Bool

    init(character: Character? = nil, embeddedInNavigation: Bool = false) {
        self.embeddedInNavigation = embeddedInNavigation
        characterID = character?.id
        _name = State(initialValue: character?.name ?? "")
        _avatarData = State(initialValue: character?.avatarData)
        _signature = State(initialValue: character?.signature ?? "")
    }

    var body: some View {
        if embeddedInNavigation {
            editor
        } else {
            NavigationStack { editor }
        }
    }

    private var editor: some View {
        ScrollView {
            VStack(spacing: 0) {
                PhotosPicker(selection: $selection, matching: .images) {
                    profileRow(L.text("头像", "Profile photo"), height: 76) {
                        if isLoading {
                            ProgressView().frame(width: 44, height: 44)
                        } else {
                            Avatar(character: Character(name: name, avatarData: avatarData, signature: signature), size: 44)
                        }
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(L.text("从相册选择头像", "Choose avatar from photos"))
                separator
                NavigationLink {
                    ProfileTextEditor(title: L.text("名字", "Name"), text: $name, allowsEmpty: false)
                } label: {
                    profileRow(L.text("名字", "Name")) { valueLabel(name) }
                }.buttonStyle(.plain)
                separator
                NavigationLink {
                    ProfileTextEditor(title: L.text("个性签名", "Signature"), text: $signature, allowsEmpty: true)
                } label: {
                    profileRow(L.text("个性签名", "Signature")) {
                        valueLabel(signature.isEmpty ? L.text("未设置", "Not set") : signature)
                    }
                }.buttonStyle(.plain)
            }
            .background(.white)
        }
            .background(Color(white: 0.93))
            .navigationTitle(characterID == nil ? L.text("创建角色", "Create character") : L.text("个人资料", "Personal info"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !embeddedInNavigation {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(L.text("取消", "Cancel")) { dismiss() }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L.text("保存", "Save")) {
                        if let characterID {
                            store.updateCharacter(characterID, name: name, avatarData: avatarData, signature: signature)
                        } else {
                            store.addCharacter(name: name, avatarData: avatarData, signature: signature)
                        }
                        dismiss()
                    }.disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)
                }
            }
            .task(id: selection) {
                guard let selection else { return }
                isLoading = true
                defer { if !Task.isCancelled { isLoading = false } }
                do {
                    guard let data = try await selection.loadTransferable(type: Data.self) else {
                        throw AvatarImportError.invalidImage
                    }
                    try Task.checkCancellation()
                    guard let request = AvatarCropRequest(data: data) else {
                        throw AvatarImportError.invalidImage
                    }
                    try Task.checkCancellation()
                    cropRequest = request
                } catch {
                    if !Task.isCancelled {
                        photoError = L.text("无法读取这张照片，请重新选择", "Could not load this photo. Please choose another")
                    }
                }
            }
            .fullScreenCover(item: $cropRequest, onDismiss: {
                selection = nil
                isLoading = false
            }) { request in
                AvatarCropView(request: request) { data in
                    avatarData = data
                    cropRequest = nil
                }
            }
            .alert(L.text("头像导入失败", "Photo import failed"), isPresented: Binding(
                get: { photoError != nil }, set: { if !$0 { photoError = nil } }
            )) {
                Button(L.text("好", "OK")) { photoError = nil }
            } message: { Text(photoError ?? "") }
    }

    private var separator: some View {
        Color.black.opacity(0.08).frame(height: 0.5).padding(.leading, 16)
    }

    private func valueLabel(_ value: String) -> some View {
        Text(value).foregroundStyle(.secondary).lineLimit(1).truncationMode(.tail)
    }

    private func profileRow<Value: View>(_ title: String, height: CGFloat = 56, @ViewBuilder value: () -> Value) -> some View {
        HStack(spacing: 12) {
            Text(title).foregroundStyle(.primary).layoutPriority(1)
            Spacer(minLength: 24)
            value()
            Image(systemName: "chevron.right").font(.system(size: 16, weight: .regular)).foregroundStyle(Color(white: 0.72))
        }
        .font(.system(size: 17))
        .padding(.horizontal, 16)
        .frame(minHeight: height)
        .contentShape(Rectangle())
    }


}

private enum AvatarImportError: Error {
    case invalidImage
}


private struct ProfileTextEditor: View {
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focused: Bool
    @Binding private var text: String
    @State private var draft: String
    let title: String
    let allowsEmpty: Bool

    init(title: String, text: Binding<String>, allowsEmpty: Bool) {
        self.title = title
        self.allowsEmpty = allowsEmpty
        _text = text
        _draft = State(initialValue: text.wrappedValue)
    }

    var body: some View {
        VStack {
            TextField(title, text: $draft, axis: .vertical)
                .lineLimit(1...(allowsEmpty ? 6 : 1))
                .focused($focused)
                .padding(16)
                .background(.white)
            Spacer()
        }
        .padding(.top, 16)
        .background(Color(white: 0.93))
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(L.text("完成", "Done")) {
                    text = allowsEmpty ? draft : draft.trimmingCharacters(in: .whitespacesAndNewlines)
                    dismiss()
                }.disabled(!allowsEmpty && draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .onAppear { focused = true }
    }
}
