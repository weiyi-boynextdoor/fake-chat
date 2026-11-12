import SwiftUI

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
