import ImageIO
import SwiftUI
import UIKit

struct AvatarCropRequest: Identifiable {
    let id = UUID()
    let image: UIImage

    init?(data: Data) {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: 2048
              ] as CFDictionary) else { return nil }
        image = UIImage(cgImage: thumbnail)
    }
}

struct AvatarCropView: View {
    let request: AvatarCropRequest
    let onConfirm: (Data) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var canvas = AvatarCropCanvas()
    @State private var exportFailed = false

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                let side = max(1, min(geometry.size.width - 32, geometry.size.height - 100, 420))
                VStack(spacing: 24) {
                    Spacer(minLength: 0)
                    AvatarCropSurface(canvas: canvas, image: request.image)
                        .frame(width: side, height: side)
                        .clipped()
                        .overlay {
                            CropGrid().stroke(.white.opacity(0.5), lineWidth: 0.5)
                                .allowsHitTesting(false)
                        }
                        .overlay { Rectangle().strokeBorder(.white, lineWidth: 1).allowsHitTesting(false) }
                        .accessibilityLabel(L.text("拖动或双指缩放照片来裁剪头像", "Drag or pinch the photo to crop your avatar"))
                    Text(L.text("双指缩放，拖动调整位置", "Pinch to zoom, drag to reposition"))
                        .font(.subheadline).foregroundStyle(.white.opacity(0.75))
                    Spacer(minLength: 0)
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .background(.black)
            .navigationTitle(L.text("裁剪头像", "Crop avatar"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.black, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L.text("取消", "Cancel")) { dismiss() }.tint(.white)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L.text("确定", "Confirm")) {
                        if let data = canvas.exportJPEG() {
                            onConfirm(data)
                        } else {
                            exportFailed = true
                        }
                    }.tint(.green)
                }
            }
            .alert(L.text("无法裁剪图片，请重试", "Could not crop the photo. Please try again"), isPresented: $exportFailed) {
                Button(L.text("好", "OK"), role: .cancel) {}
            }
        }
        .interactiveDismissDisabled()
    }
}

private struct CropGrid: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            for fraction in [CGFloat(1) / 3, CGFloat(2) / 3] {
                path.move(to: CGPoint(x: rect.width * fraction, y: 0))
                path.addLine(to: CGPoint(x: rect.width * fraction, y: rect.height))
                path.move(to: CGPoint(x: 0, y: rect.height * fraction))
                path.addLine(to: CGPoint(x: rect.width, y: rect.height * fraction))
            }
        }
    }
}

private struct AvatarCropSurface: UIViewRepresentable {
    let canvas: AvatarCropCanvas
    let image: UIImage

    func makeUIView(context: Context) -> AvatarCropCanvas {
        canvas.setImage(image)
        return canvas
    }

    func updateUIView(_ uiView: AvatarCropCanvas, context: Context) {}
}

final class AvatarCropCanvas: UIScrollView, UIScrollViewDelegate {
    private let imageView = UIImageView()
    private var viewport = CGSize.zero

    init() {
        super.init(frame: .zero)
        delegate = self
        contentInsetAdjustmentBehavior = .never
        showsHorizontalScrollIndicator = false
        showsVerticalScrollIndicator = false
        bounces = false
        bouncesZoom = false
        clipsToBounds = true
        addSubview(imageView)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func setImage(_ image: UIImage) {
        imageView.image = image
        imageView.frame = CGRect(origin: .zero, size: image.size)
        contentSize = image.size
        viewport = .zero
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard bounds.width > 0, bounds.height > 0, bounds.size != viewport,
              let image = imageView.image else { return }
        viewport = bounds.size
        let minimum = AvatarCropGeometry.minimumZoom(image: image.size, viewport: viewport)
        minimumZoomScale = minimum
        maximumZoomScale = minimum * 6
        zoomScale = minimum
        contentOffset = AvatarCropGeometry.centeredOffset(image: image.size, viewport: viewport, zoom: minimum)
    }

    func viewForZooming(in scrollView: UIScrollView) -> UIView? { imageView }

    func exportJPEG() -> Data? {
        guard let image = imageView.image, bounds.width > 0 else { return nil }
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 512, height: 512), format: format)
        return renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 512, height: 512))
            image.draw(in: AvatarCropGeometry.drawingRect(image: image.size, viewport: bounds.size,
                zoom: zoomScale, offset: contentOffset, outputSide: 512))
        }.jpegData(compressionQuality: 0.85)
    }
}
