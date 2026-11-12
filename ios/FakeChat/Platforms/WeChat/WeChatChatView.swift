import SwiftUI

struct WeChatChatView: View {
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
                                WeChatMessageRow(message: message, sender: sender, outgoing: sender.id == store.currentID).id(message.id)
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
        .background(WeChatStyle.background)
        .navigationTitle(partner?.name ?? "").navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(WeChatStyle.background, for: .navigationBar).toolbarBackground(.visible, for: .navigationBar)
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

}
