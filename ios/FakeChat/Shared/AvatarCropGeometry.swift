import CoreGraphics
import Foundation

enum AvatarCropGeometry {
    static func minimumZoom(image: CGSize, viewport: CGSize) -> CGFloat {
        max(viewport.width / image.width, viewport.height / image.height)
    }

    static func centeredOffset(image: CGSize, viewport: CGSize, zoom: CGFloat) -> CGPoint {
        CGPoint(x: max(0, (image.width * zoom - viewport.width) / 2),
                y: max(0, (image.height * zoom - viewport.height) / 2))
    }

    static func drawingRect(image: CGSize, viewport: CGSize, zoom: CGFloat, offset: CGPoint, outputSide: CGFloat) -> CGRect {
        let ratio = outputSide / viewport.width
        return CGRect(x: -offset.x * ratio, y: -offset.y * ratio,
                      width: image.width * zoom * ratio, height: image.height * zoom * ratio)
    }
}
