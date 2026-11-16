import SwiftUI
import UIKit

struct WeChatMessageRow: View {
    let message: Message
    let sender: Character
    let outgoing: Bool
    var photoMessages: [Message] = []
    @State private var showPhoto = false

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if outgoing { Spacer(minLength: 55) } else { Avatar(character: sender, size: 40) }
            if let data = message.photoData, let image = UIImage(data: data) {
                Button { showPhoto = true } label: {
                    Image(uiImage: image).resizable().aspectRatio(contentMode: .fit)
                        .frame(width: min(180, 220 * image.size.width / max(image.size.height, 1)))
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(L.text("查看照片", "View photo"))
                .fullScreenCover(isPresented: $showPhoto) {
                    PhotoViewer(messages: photoMessages.isEmpty ? [message] : photoMessages, selectedID: message.id)
                }
            } else {
                Text(message.text).font(.system(size: 17)).foregroundStyle(.black)
                    .padding(.horizontal, 12).padding(.vertical, 10)
                    .background(outgoing ? WeChatStyle.outgoingBubble : .white, in: RoundedRectangle(cornerRadius: 5))
                    .overlay(alignment: outgoing ? .trailing : .leading) {
                        Triangle().fill(outgoing ? WeChatStyle.outgoingBubble : .white)
                            .frame(width: 7, height: 12).rotationEffect(.degrees(outgoing ? 90 : -90))
                            .offset(x: outgoing ? 5 : -5, y: -2)
                    }
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


private struct PhotoViewer: View {
    @Environment(\.dismiss) private var dismiss
    let messages: [Message]
    private let images: [UIImage?]
    @State private var index: Int
    @State private var translation = CGSize.zero
    @State private var horizontal: Bool?
    @State private var peakDownward: CGFloat = 0
    @State private var closing = false

    init(messages: [Message], selectedID: UUID) {
        self.messages = messages
        images = messages.map { $0.photoData.flatMap { UIImage(data: $0) } }
        _index = State(initialValue: messages.firstIndex { $0.id == selectedID } ?? 0)
    }

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            let progress = min(1, max(0, translation.height) / size.height)
            ZStack {
                Color.black.opacity(1 - Double(progress) * 0.85)
                ForEach(messages.indices.filter { abs($0 - index) <= 1 }, id: \.self) { page in
                    if let image = images[page] {
                        ZoomablePhoto(image: image, onDismiss: { dismiss() }, onPan: { state, offset, velocity in
                            handlePan(state, offset: offset, velocity: velocity, size: size)
                        })
                        .frame(width: size.width, height: size.height)
                        .scaleEffect(horizontal == false ? 1 - progress * 0.3 : 1)
                        .offset(x: CGFloat(page - index) * (size.width + 16) + translation.width,
                                y: translation.height)
                        .allowsHitTesting(page == index && !closing)
                    }
                }
            }.clipped()
        }
        .ignoresSafeArea()
        .presentationBackground(.clear)
        .accessibilityAction(.escape) { dismiss() }
        .statusBarHidden()
    }

    private func handlePan(_ state: UIGestureRecognizer.State, offset: CGPoint, velocity: CGPoint, size: CGSize) {
        guard !closing else { return }
        if state == .began {
            horizontal = abs(velocity.x) > abs(velocity.y)
            peakDownward = 0
        }
        if state == .began || state == .changed {
            if horizontal == true {
                let atEdge = (index == 0 && offset.x > 0) || (index == messages.count - 1 && offset.x < 0)
                translation = CGSize(width: offset.x * (atEdge ? 0.25 : 1), height: 0)
            } else {
                peakDownward = max(peakDownward, offset.y)
                translation = CGSize(width: offset.x * 0.25, height: max(0, offset.y))
            }
            return
        }
        guard state == .ended || state == .cancelled || state == .failed else { return }
        if horizontal == true {
            let projected = offset.x + velocity.x * 0.18
            let step = state == .ended && abs(projected) > size.width * 0.25 ? (projected < 0 ? 1 : -1) : 0
            withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) {
                index = min(max(0, index + step), messages.count - 1)
                translation = .zero
                horizontal = nil
            }
        } else {
            let reversed = peakDownward - offset.y > 16 || velocity.y < -120
            let shouldClose = state == .ended && !reversed &&
                (offset.y > size.height * 0.2 || (offset.y > 24 && velocity.y > 650))
            if shouldClose {
                closing = true
                withAnimation(.easeOut(duration: 0.2)) { translation.height = size.height }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { dismiss() }
            } else {
                withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) {
                    translation = .zero
                    horizontal = nil
                }
            }
        }
    }
}

private struct ZoomablePhoto: UIViewRepresentable {
    let image: UIImage
    let onDismiss: () -> Void
    let onPan: (UIGestureRecognizer.State, CGPoint, CGPoint) -> Void

    func makeUIView(context: Context) -> PhotoScrollView {
        let view = PhotoScrollView()
        view.imageView.image = image
        view.onDismiss = onDismiss
        view.onPan = onPan
        return view
    }

    func updateUIView(_ uiView: PhotoScrollView, context: Context) {
        uiView.onDismiss = onDismiss
        uiView.onPan = onPan
    }
}

private final class PhotoScrollView: UIScrollView, UIScrollViewDelegate, UIGestureRecognizerDelegate {
    let imageView = UIImageView()
    var onDismiss: (() -> Void)?
    var onPan: ((UIGestureRecognizer.State, CGPoint, CGPoint) -> Void)?
    private weak var dismissPan: UIPanGestureRecognizer?
    private var previousSize = CGSize.zero

    override init(frame: CGRect) {
        super.init(frame: frame)
        delegate = self
        minimumZoomScale = 1
        maximumZoomScale = 5
        showsHorizontalScrollIndicator = false
        showsVerticalScrollIndicator = false
        contentInsetAdjustmentBehavior = .never
        imageView.contentMode = .scaleAspectFit
        addSubview(imageView)
        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(toggleZoom(_:)))
        doubleTap.numberOfTapsRequired = 2
        addGestureRecognizer(doubleTap)
        let singleTap = UITapGestureRecognizer(target: self, action: #selector(closePhoto))
        singleTap.require(toFail: doubleTap)
        addGestureRecognizer(singleTap)
        let swipeDown = UIPanGestureRecognizer(target: self, action: #selector(dismissWithSwipe(_:)))
        dismissPan = swipeDown
        swipeDown.delegate = self
        swipeDown.maximumNumberOfTouches = 1
        panGestureRecognizer.require(toFail: swipeDown)
        addGestureRecognizer(swipeDown)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard bounds.size != previousSize, bounds.width > 0, bounds.height > 0,
              let image = imageView.image else { return }
        previousSize = bounds.size
        setZoomScale(1, animated: false)
        let scale = min(bounds.width / image.size.width, bounds.height / image.size.height)
        imageView.frame = CGRect(origin: .zero, size: CGSize(width: image.size.width * scale, height: image.size.height * scale))
        contentSize = imageView.bounds.size
        centerImage()
    }

    func viewForZooming(in scrollView: UIScrollView) -> UIView? { imageView }

    func scrollViewDidZoom(_ scrollView: UIScrollView) { centerImage() }

    private func centerImage() {
        contentInset = UIEdgeInsets(
            top: max(0, (bounds.height - imageView.frame.height) / 2), left: max(0, (bounds.width - imageView.frame.width) / 2),
            bottom: 0, right: 0
        )
    }

    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard gestureRecognizer === dismissPan, let pan = dismissPan else {
            return super.gestureRecognizerShouldBegin(gestureRecognizer)
        }
        let velocity = pan.velocity(in: self)
        return zoomScale <= minimumZoomScale + 0.01 && (abs(velocity.x) > abs(velocity.y) || velocity.y > 0)
    }

    @objc private func closePhoto() {
        onDismiss?()
    }

    @objc private func dismissWithSwipe(_ gesture: UIPanGestureRecognizer) {
        onPan?(gesture.state, gesture.translation(in: window), gesture.velocity(in: window))
    }

    @objc private func toggleZoom(_ gesture: UITapGestureRecognizer) {
        if zoomScale > 1 {
            setZoomScale(1, animated: true)
        } else {
            let point = gesture.location(in: imageView)
            let size = CGSize(width: bounds.width / 3, height: bounds.height / 3)
            zoom(to: CGRect(x: point.x - size.width / 2, y: point.y - size.height / 2, width: size.width, height: size.height), animated: true)
        }
    }
}
