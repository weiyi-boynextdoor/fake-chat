import SwiftUI
import UIKit

struct ChatMessageRow: View {
    @EnvironmentObject private var store: ChatStore
    let message: Message
    let sender: Character
    let outgoing: Bool
    var platform: ChatPlatform = .weChat
    private var bubbleColor: Color {
        guard outgoing else { return .white }
        return platform == .weChat ? WeChatStyle.outgoingBubble : Color(red: 0.23, green: 0.32, blue: 0.75)
    }

    var photoMessages: [Message] = []
    @State private var showPhoto = false

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if outgoing { Spacer(minLength: 55) } else { Avatar(character: sender, size: 40).clipShape(RoundedRectangle(cornerRadius: platform == .douyin ? 20 : 5.2)) }
            if let data = message.photoData, let image = UIImage(data: data) {
                Button { showPhoto = true } label: {
                    Image(uiImage: image).resizable().aspectRatio(contentMode: .fit)
                        .frame(width: min(180, 220 * image.size.width / max(image.size.height, 1)))
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                        .overlay {
                            if message.videoFilename != nil {
                                Image(systemName: "play.circle.fill").font(.system(size: 38))
                                    .foregroundStyle(.white).shadow(radius: 3)
                            }
                        }
                        .overlay(alignment: .bottomTrailing) {
                            if let duration = message.videoDuration {
                                Text(videoTime(duration)).font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(.white).padding(5).background(.black.opacity(0.4))
                            }
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(message.videoFilename == nil ? L.text("查看照片", "View photo") : L.text("播放视频", "Play video"))
                .fullScreenCover(isPresented: $showPhoto) {
                    if let url = store.videoURL(for: message) {
                        ChatVideoPlayer(url: url)
                    } else {
                        ChatPhotoViewer(messages: photoMessages.isEmpty ? [message] : photoMessages, selectedID: message.id)
                    }
                }
            } else {
                Text(message.text).font(.system(size: 17))
                    .foregroundStyle(platform == .douyin && outgoing ? Color.white : Color.black)
                    .padding(.horizontal, 12).padding(.vertical, 10)
                    .background(bubbleColor, in: RoundedRectangle(cornerRadius: platform == .weChat ? 5 : 14))
                    .overlay(alignment: outgoing ? .trailing : .leading) {
                        if platform == .weChat {
                            Triangle().fill(bubbleColor)
                            .frame(width: 7, height: 12).rotationEffect(.degrees(outgoing ? 90 : -90))
                            .offset(x: outgoing ? 5 : -5, y: -2)
                        }
                    }
            }
            if outgoing { Avatar(character: sender, size: 40).clipShape(RoundedRectangle(cornerRadius: platform == .douyin ? 20 : 5.2)) } else { Spacer(minLength: 55) }
        }
    }
    private func videoTime(_ duration: Double) -> String {
        let seconds = Int(max(0, duration.isFinite ? duration : 0))
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }

}

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.midX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.closeSubpath()
        }
    }
}
