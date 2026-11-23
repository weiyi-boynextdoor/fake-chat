import AVKit
import SwiftUI
import UIKit

struct ChatPhotoViewer: View {
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
            let shouldClose = state == .ended && MediaDismissal.shouldClose(
                distance: offset.y, velocity: velocity.y, peak: peakDownward, height: size.height
            )
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


struct ChatVideoPlayer: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var playback: LoopingVideoPlayback
    @State private var translation = CGSize.zero
    @State private var peakDownward: CGFloat = 0
    @State private var closing = false

    init(url: URL) {
        _playback = StateObject(wrappedValue: LoopingVideoPlayback(url: url))
    }

    private var player: AVPlayer { playback.player }

    var body: some View {
        GeometryReader { geometry in
            let progress = min(1, max(0, translation.height) / geometry.size.height)
            ZStack {
                Color.black.opacity(1 - Double(progress) * 0.85)
                VideoPlaybackSurface(player: player) { state, offset, velocity in
                    handlePan(state, offset: offset, velocity: velocity, height: geometry.size.height)
                }
                .scaleEffect(1 - progress * 0.3)
                .offset(translation)
                .allowsHitTesting(!closing)
            }.clipped()
        }
        .ignoresSafeArea()
        .presentationBackground(.clear)
        .statusBarHidden()
        .onAppear {
            try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
            try? AVAudioSession.sharedInstance().setActive(true)
            player.play()
        }
        .onDisappear {
            player.pause()
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
        .accessibilityAction(.escape) { dismiss() }
    }
    private func handlePan(_ state: UIGestureRecognizer.State, offset: CGPoint, velocity: CGPoint, height: CGFloat) {
        guard !closing else { return }
        if state == .began { peakDownward = 0 }
        if state == .began || state == .changed {
            peakDownward = max(peakDownward, offset.y)
            translation = CGSize(width: offset.x * 0.25, height: max(0, offset.y))
            return
        }
        guard state == .ended || state == .cancelled || state == .failed else { return }
        if state == .ended && MediaDismissal.shouldClose(distance: offset.y, velocity: velocity.y,
                                                       peak: peakDownward, height: height) {
            closing = true
            player.pause()
            withAnimation(.easeOut(duration: 0.2)) { translation.height = height }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { dismiss() }
        } else {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) { translation = .zero }
        }
    }

}


private final class LoopingVideoPlayback: ObservableObject {
    let player: AVQueuePlayer
    private let looper: AVPlayerLooper

    init(url: URL) {
        let queue = AVQueuePlayer()
        player = queue
        looper = AVPlayerLooper(player: queue, templateItem: AVPlayerItem(url: url))
    }
}

private enum MediaDismissal {
    static func shouldClose(distance: CGFloat, velocity: CGFloat, peak: CGFloat, height: CGFloat) -> Bool {
        let reversed = peak - distance > 16 || velocity < -120
        return !reversed && (distance > height * 0.2 || (distance > 24 && velocity > 650))
    }
}

private struct VideoPlaybackSurface: UIViewControllerRepresentable {
    let player: AVPlayer
    let onPan: (UIGestureRecognizer.State, CGPoint, CGPoint) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onPan: onPan) }

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        controller.allowsPictureInPicturePlayback = false
        let pan = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePan(_:)))
        pan.maximumNumberOfTouches = 1
        pan.delegate = context.coordinator
        controller.view.addGestureRecognizer(pan)
        return controller
    }

    func updateUIViewController(_ controller: AVPlayerViewController, context: Context) {
        context.coordinator.onPan = onPan
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var onPan: (UIGestureRecognizer.State, CGPoint, CGPoint) -> Void

        init(onPan: @escaping (UIGestureRecognizer.State, CGPoint, CGPoint) -> Void) {
            self.onPan = onPan
        }

        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard let pan = gestureRecognizer as? UIPanGestureRecognizer else { return false }
            let velocity = pan.velocity(in: pan.view)
            return velocity.y > abs(velocity.x)
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
            var view = touch.view
            while let current = view {
                if current is UIControl { return false }
                view = current.superview
            }
            // Leave the transport controls available for scrubbing and playback.
            guard let surface = gestureRecognizer.view else { return false }
            return touch.location(in: surface).y < surface.bounds.height - 100
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                               shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            true
        }

        @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
            onPan(gesture.state, gesture.translation(in: gesture.view?.window), gesture.velocity(in: gesture.view?.window))
        }
    }
}
