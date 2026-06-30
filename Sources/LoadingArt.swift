import SwiftUI
import AppKit
import AVFoundation

/// Ambient looping `fire.mp4` art shown behind a job while it renders. The clip
/// (red fire) is hue-rotated through the full spectrum on a slow loop and held at
/// a low opacity, so each rendering card glows with shifting colour. Muted,
/// control-free, and looped so the seam is masked by an opacity envelope (see
/// `FireVideo`). If the clip is missing the view is transparent (no crash).
struct LoadingArt: View {
    @State private var hue: Angle = .zero
    /// Seconds for one full rainbow pass. Kept slow so the colour drift is calm.
    private let cycleSeconds: Double = 11

    var body: some View {
        FireVideo()
            .hueRotation(hue)
            .onAppear {
                withAnimation(.linear(duration: cycleSeconds).repeatForever(autoreverses: false)) {
                    hue = .degrees(360)
                }
            }
    }
}

/// A looping, muted, control-free AVPlayer surface for `fire.mp4`.
///
/// The raw loop was jarring at the seam, so playback is slowed and an opacity
/// envelope dims the layer to a low trough exactly at the loop point and holds a
/// soft peak in the middle, with eased ramps over the first/last ~15% of the
/// clip. The cut therefore happens while the fire is barely visible, so the loop
/// reads as a slow breathing fade rather than a hard jump. Opacity is derived
/// from the player's *actual* playback time each tick (not an independent
/// animation), so it can't drift out of sync with the seam.
private struct FireVideo: NSViewRepresentable {
    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> PlayerView {
        let view = PlayerView()
        context.coordinator.attach(to: view, url: Self.videoURL)
        return view
    }

    func updateNSView(_ nsView: PlayerView, context: Context) {
        // Restart if the system paused the player (e.g. after re-render).
        context.coordinator.ensurePlaying()
    }

    static func dismantleNSView(_ nsView: PlayerView, coordinator: Coordinator) {
        coordinator.teardown()
    }

    /// Resolve the bundled art clip, searching a few likely resource locations.
    static var videoURL: URL? {
        Bundle.main.url(forResource: "fire", withExtension: "mp4")
            ?? Bundle.main.url(forResource: "fire", withExtension: "mp4", subdirectory: "Art")
            ?? Bundle.main.url(forResource: "fire", withExtension: "mp4", subdirectory: "Resources/Art")
            ?? Bundle.main.url(forResource: "fire", withExtension: "mp4", subdirectory: "Resources")
    }

    final class Coordinator {
        private var player: AVQueuePlayer?
        private var looper: AVPlayerLooper?
        private var timeObserver: Any?
        private weak var hostView: PlayerView?

        /// <1.0 slows the fire; kept gentle so it drifts rather than flickers.
        private let playbackRate: Float = 0.55
        /// Peak brightness mid-clip and trough right at the seam.
        private let peakOpacity: CGFloat = 0.62
        private let troughOpacity: CGFloat = 0.05
        /// Fraction of the clip (at each end) over which opacity ramps.
        private let fadeFrac: Double = 0.15

        func attach(to view: PlayerView, url: URL?) {
            hostView = view
            view.setFireOpacity(peakOpacity)
            guard let url else { return }

            let player = AVQueuePlayer()
            player.isMuted = true
            player.actionAtItemEnd = .none
            let item = AVPlayerItem(url: url)
            let looper = AVPlayerLooper(player: player, templateItem: item)
            self.player = player
            self.looper = looper
            view.player = player
            player.play()
            player.rate = playbackRate
            installEnvelope()
        }

        func ensurePlaying() {
            guard let player, player.rate == 0 else { return }
            player.play()
            player.rate = playbackRate
        }

        func teardown() {
            if let token = timeObserver { player?.removeTimeObserver(token); timeObserver = nil }
            player?.pause()
            player?.removeAllItems()
            looper = nil
            player = nil
            hostView = nil
        }

        /// Drive layer opacity from the player's real position so the dim always
        /// lands on the seam. Fires ~24×/s.
        private func installEnvelope() {
            let interval = CMTime(seconds: 1.0 / 24.0, preferredTimescale: 600)
            timeObserver = player?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
                guard let self else { return }
                let duration = self.resolveDuration()
                let progress: Double
                if duration > 0 {
                    var secs = time.seconds
                    if secs.isNaN || secs < 0 { secs = 0 }
                    secs = secs.truncatingRemainder(dividingBy: duration)
                    progress = min(max(secs / duration, 0), 1)
                } else {
                    progress = 0.5
                }
                let dim = Self.seamDimming(progress: progress, fadeFrac: self.fadeFrac)
                self.hostView?.setFireOpacity(self.peakOpacity + (self.troughOpacity - self.peakOpacity) * dim)
            }
        }

        private func resolveDuration() -> Double {
            let d = player?.currentItem?.duration ?? .invalid
            let s = d.seconds
            return (s.isFinite && s > 0) ? s : 0
        }

        /// 0 in the middle of the clip (full brightness), 1 at the seam (dim),
        /// eased with a smoothstep over `fadeFrac` at each end.
        static func seamDimming(progress p: Double, fadeFrac: Double) -> CGFloat {
            let distanceToSeam = min(p, 1 - p)          // 0 at seam, 0.5 at mid
            let x = min(max(distanceToSeam / fadeFrac, 0), 1)
            let bright = x * x * (3 - 2 * x)            // smoothstep: ~0 near seam, 1 beyond
            return CGFloat(1 - bright)                  // invert → dimming factor
        }
    }

    /// Hosts an `AVPlayerLayer` filling its bounds.
    final class PlayerView: NSView {
        private let playerLayer = AVPlayerLayer()

        var player: AVPlayer? {
            didSet { playerLayer.player = player }
        }

        override init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            wantsLayer = true
            playerLayer.videoGravity = .resizeAspectFill
            playerLayer.backgroundColor = NSColor.clear.cgColor
            // No implicit opacity animation — we set it directly each tick.
            playerLayer.actions = ["opacity": NSNull()]
            layer?.addSublayer(playerLayer)
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override func layout() {
            super.layout()
            playerLayer.frame = bounds
        }

        func setFireOpacity(_ value: CGFloat) {
            playerLayer.opacity = Float(value)
        }
    }
}
