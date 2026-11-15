import SwiftUI
import UIKit

struct Avatar: View {
    let character: Character
    var size: CGFloat = 44

    var body: some View {
        Group {
            if let data = character.avatarData, let image = UIImage(data: data) {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                Text(String(character.name.prefix(1)))
                    .font(.system(size: size * 0.42, weight: .medium))
                    .foregroundStyle(Color(white: 0.45))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(white: 0.9))
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.13))
        .accessibilityHidden(true)
    }
}
