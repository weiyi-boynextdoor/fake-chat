import SwiftUI

struct WeChatMessageRow: View {
    let message: Message
    let sender: Character
    let outgoing: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if outgoing { Spacer(minLength: 55) } else { Avatar(character: sender, size: 40) }
            Text(message.text).font(.system(size: 17)).foregroundStyle(.black)
                .padding(.horizontal, 12).padding(.vertical, 10)
                .background(outgoing ? WeChatStyle.outgoingBubble : .white, in: RoundedRectangle(cornerRadius: 5))
                .overlay(alignment: outgoing ? .trailing : .leading) {
                    Triangle().fill(outgoing ? WeChatStyle.outgoingBubble : .white)
                        .frame(width: 7, height: 12).rotationEffect(.degrees(outgoing ? 90 : -90))
                        .offset(x: outgoing ? 5 : -5, y: -2)
                }
            if outgoing { Avatar(character: sender, size: 40) } else { Spacer(minLength: 55) }
        }
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
