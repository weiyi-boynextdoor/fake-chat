import AVFoundation
import CoreTransferable
import UniformTypeIdentifiers
import PhotosUI
import SwiftUI
import UIKit

struct WeChatChatView: View {
    @EnvironmentObject private var store: ChatStore
    let conversationID: UUID
    @State private var draft = ""
    @State private var showSender = false
    @State private var showAttachments = false
    @State private var selection: [PhotosPickerItem] = []
    @State private var isLoadingMedia = false
    @FocusState private var inputFocused: Bool
    private var conversation: Conversation? { store.conversations.first { $0.id == conversationID } }
    private var partner: Character? { conversation?.participantIDs.first { $0 != store.currentID }.flatMap(store.character) }

    private var messages: [Message] { conversation.map(store.messages(in:)) ?? [] }

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 18) {
                        if let first = messages.first {
                            Text(first.date, format: .dateTime.month().day().hour().minute())
                                .font(.system(size: 12)).foregroundStyle(.secondary).padding(.top, 18)
                        }
                        ForEach(messages) { message in
                            if let sender = store.character(message.senderID) {
                                WeChatMessageRow(message: message, sender: sender, outgoing: sender.id == store.currentID, photoMessages: messages.filter { $0.photoData != nil && $0.videoFilename == nil }).id(message.id)
                            }
                        }
                    }.padding(.horizontal, 12).padding(.bottom, 20)
                }
                .scrollDismissesKeyboard(.interactively)
                .onAppear { if let id = messages.last?.id { proxy.scrollTo(id, anchor: .bottom) } }
                .onChange(of: messages.map(\.id)) { _, _ in
                    if let id = messages.last?.id { withAnimation { proxy.scrollTo(id, anchor: .bottom) } }
                }
            }
            Divider()
            HStack(alignment: .bottom, spacing: 10) {
                Image(systemName: "waveform.circle").font(.system(size: 27)).padding(.bottom, 5).accessibilityHidden(true)
                TextField(L.text("输入消息", "Message"), text: $draft, axis: .vertical)
                    .focused($inputFocused)
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
                Button {
                    inputFocused = false
                    withAnimation(.easeOut(duration: 0.2)) { showAttachments.toggle() }
                } label: {
                    Image(systemName: "plus.circle").font(.system(size: 27)).padding(.bottom, 5)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(L.text("更多功能", "More options"))
                .accessibilityValue(showAttachments ? L.text("已展开", "Expanded") : L.text("已收起", "Collapsed"))
            }.padding(.horizontal, 10).padding(.vertical, 8).background(Color(white: 0.96))
            if showAttachments {
                attachmentPanel
            }
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
        .onChange(of: inputFocused) { _, focused in
            if focused { withAnimation { showAttachments = false } }
        }
        .task(id: selection) {
            guard !selection.isEmpty, let senderID = store.currentID else { return }
            let selectedMedia = selection
            isLoadingMedia = true
            defer { isLoadingMedia = false; selection = [] }
            do {
                var attachments: [MediaAttachment] = []
                var temporaryVideos: [URL] = []
                defer { temporaryVideos.forEach { try? FileManager.default.removeItem(at: $0) } }
                for item in selectedMedia {
                    if item.supportedContentTypes.contains(where: { $0.conforms(to: .movie) }) {
                        guard let video = try await item.loadTransferable(type: ImportedVideo.self) else {
                            throw PhotoImportError.invalidImage
                        }
                        temporaryVideos.append(video.url)
                        try Task.checkCancellation()
                        let asset = AVURLAsset(url: video.url)
                        let duration = try await asset.load(.duration).seconds
                        let generator = AVAssetImageGenerator(asset: asset)
                        generator.appliesPreferredTrackTransform = true
                        generator.maximumSize = CGSize(width: 480, height: 480)
                        let frame = try await generator.image(at: .zero).image
                        guard let thumbnail = UIImage(cgImage: frame).jpegData(compressionQuality: 0.8) else {
                            throw PhotoImportError.invalidImage
                        }
                        attachments.append(MediaAttachment(photoData: thumbnail, videoURL: video.url,
                                                           duration: duration.isFinite ? duration : 0))
                        continue
                    }
                    guard let data = try await item.loadTransferable(type: Data.self),
                          let image = UIImage(data: data) else { throw PhotoImportError.invalidImage }
                    try Task.checkCancellation()
                    let scale = min(1, 1600 / max(image.size.width, image.size.height))
                    let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
                    let format = UIGraphicsImageRendererFormat()
                    format.scale = 1
                    let resized = UIGraphicsImageRenderer(size: size, format: format).image { _ in
                        image.draw(in: CGRect(origin: .zero, size: size))
                    }
                    guard let photo = resized.jpegData(compressionQuality: 0.85) else { throw PhotoImportError.invalidImage }
                    attachments.append(MediaAttachment(photoData: photo))
                }
                try Task.checkCancellation()
                store.sendMedia(attachments, to: conversationID, senderID: senderID)
                withAnimation { showAttachments = false }
            } catch {
                if !Task.isCancelled {
                    store.error = L.text("无法读取所选照片或视频，请重新选择", "Could not load the selected photos or videos. Please choose again")
                }
            }
        }
        .confirmationDialog(L.text("切换发送角色", "Switch sender"), isPresented: $showSender, titleVisibility: .visible) {
            ForEach(store.characters.filter { conversation?.participantIDs.contains($0.id) == true }) { character in
                Button(character.name + (character.id == store.currentID ? " ✓" : "")) { store.select(character) }
            }
        }
    }

    private var attachmentPanel: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 20) {
            PhotosPicker(selection: $selection, selectionBehavior: .ordered, matching: .any(of: [.images, .videos])) {
                optionLabel(L.text("照片", "Photos"), symbol: "photo.fill")
                    .overlay { if isLoadingMedia { ProgressView() } }
            }.buttonStyle(.plain).disabled(isLoadingMedia)
            optionLabel(L.text("拍摄", "Camera"), symbol: "camera.fill").accessibilityValue(L.text("暂不可用", "Unavailable"))
            optionLabel(L.text("视频通话", "Video call"), symbol: "video.fill").accessibilityValue(L.text("暂不可用", "Unavailable"))
            optionLabel(L.text("位置", "Location"), symbol: "mappin.circle.fill").accessibilityValue(L.text("暂不可用", "Unavailable"))
            optionLabel(L.text("红包", "Red packet"), symbol: "gift.fill").accessibilityValue(L.text("暂不可用", "Unavailable"))
            optionLabel(L.text("转账", "Transfer"), symbol: "arrow.left.arrow.right").accessibilityValue(L.text("暂不可用", "Unavailable"))
            optionLabel(L.text("语音输入", "Voice input"), symbol: "mic.fill").accessibilityValue(L.text("暂不可用", "Unavailable"))
            optionLabel(L.text("收藏", "Favorites"), symbol: "cube.fill").accessibilityValue(L.text("暂不可用", "Unavailable"))
        }
        .padding(.horizontal, 20).padding(.top, 16).padding(.bottom, 22)
        .background(Color(white: 0.96).ignoresSafeArea(edges: .bottom))
        .overlay(alignment: .top) { Divider() }
    }

    private func optionLabel(_ title: String, symbol: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: symbol).font(.system(size: 27)).foregroundStyle(Color(white: 0.3))
                .frame(width: 62, height: 62).background(.white, in: RoundedRectangle(cornerRadius: 16))
            Text(title).font(.system(size: 13)).foregroundStyle(.secondary).lineLimit(1).minimumScaleFactor(0.7)
        }.frame(maxWidth: .infinity)
    }

}


private enum PhotoImportError: Error { case invalidImage }

private struct ImportedVideo: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(importedContentType: .movie) { received in
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension(received.file.pathExtension.isEmpty ? "mov" : received.file.pathExtension)
            try FileManager.default.copyItem(at: received.file, to: url)
            return ImportedVideo(url: url)
        }
    }
}
