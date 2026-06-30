import SwiftUI
import AVKit
import AVFoundation

/// AppKit-backed video surface used by `VideoPlayerView`.
///
/// This wraps `AVPlayerView` directly instead of using SwiftUI's `VideoPlayer`.
/// SwiftUI's `VideoPlayer` (in the private `_AVKit_SwiftUI` module) was aborting
/// in the Swift runtime — `getSuperclassMetadata` failing inside
/// `_swift_initClassMetadataImpl` — the first time a finished video's preview was
/// inserted. The trigger was `VideoPlayer(player: nil)` (a lazily-initialized
/// player) combined with `.aspectRatio` and the implicit transition when the
/// preview appeared. Owning a single `AVPlayer` here keeps the type metadata in
/// this module, never produces a nil-player view, and reuses one player via
/// `replaceCurrentItem`.
struct AVPlayerRepresentable: NSViewRepresentable {
    let url: URL

    func makeNSView(context: Context) -> AVPlayerView {
        let view = AVPlayerView()
        view.controlsStyle = .inline
        let player = AVPlayer(url: url)
        context.coordinator.player = player
        context.coordinator.url = url
        view.player = player
        player.play()
        return view
    }

    func updateNSView(_ nsView: AVPlayerView, context: Context) {
        // The same view is reused across renders; only swap the media when the
        // URL genuinely changes (e.g. a different result is opened).
        guard context.coordinator.url != url else { return }
        context.coordinator.url = url
        context.coordinator.player?.replaceCurrentItem(with: AVPlayerItem(url: url))
        context.coordinator.player?.play()
    }

    static func dismantleNSView(_ nsView: AVPlayerView, coordinator: Coordinator) {
        coordinator.player?.pause()
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        var player: AVPlayer?
        var url: URL?
    }
}

/// Plays a single result URL inline with Open / Save actions. Presented in a
/// sheet from a job card.
struct VideoPlayerView: View {
    let url: URL
    @State private var saving = false
    @State private var savedMessage: String?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme

    private static let promptLimit = AppLimits.prompt

    var body: some View {
        let set = AppTheme.resolve(scheme)
        return VStack(spacing: Spacing.s4) {
            AVPlayerRepresentable(url: url)
                .aspectRatio(16.0 / 9.0, contentMode: .fit)
                .clipShape(.rect(cornerRadius: Radius.medium))

            HStack(spacing: Spacing.s4) {
                if let savedMessage {
                    Label(savedMessage, systemImage: "checkmark.circle.fill")
                        .font(.app(AppType.caption))
                        .foregroundStyle(set.success)
                }
                Spacer()
                Button { dismiss() } label: {
                    Text("Close").font(.app(AppType.body))
                }
                Button { ZVUtil.openExternal(url) } label: {
                    Label("Open", systemImage: "safari").font(.app(AppType.body))
                }
                Button { saveToDownloads() } label: {
                    Label("Save to Downloads", systemImage: "square.and.arrow.down").font(.app(AppType.body))
                }
                .buttonStyle(.glassProminent)
                .disabled(saving)
            }
        }
        .padding(Spacing.s6)
        .frame(maxWidth: 720)
    }

    private func saveToDownloads() {
        saving = true
        savedMessage = nil
        Task {
            let result = await ZVUtil.saveVideo(from: url)
            await MainActor.run {
                saving = false
                if let result { savedMessage = result ? "Saved" : "Save failed" }
            }
        }
    }
}
