import SwiftUI

/// In-app Help, opened from the Help menu (⌘?). A single scrollable, themed
/// page covering setup, usage, persistence, and security — no external help
/// book or network dependency.
struct HelpView: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            SmokeBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.s6) {
                    header

                    HelpSection(title: "Getting started", symbol: "key.fill") {
                        HelpPara("Z Video Generator calls the Z.AI video API directly from your Mac. To start, paste your Z.AI API key — it has the form <b>id.secret</b> and you can get one at z.ai.")
                        HelpPara("Your key is stored in macOS <b>Keychain</b>, never in a plain file. It is only ever sent to z.ai to generate videos — it is not logged, not bundled with the app, and never included in the project. Change or remove it anytime from the key button at the bottom of the sidebar.")
                    }

                    HelpSection(title: "Creating a video", symbol: "wand.and.stars") {
                        HelpPara("Click <b>Generate Video</b> to add a new job, then write a prompt and pick your settings. Each job is independent, so you can queue several different prompts at once.")
                        HelpPara("Open any job's full editor by <b>double-clicking</b> its card (or its chevron). The detail view shows the live status, all parameters, and the finished video.")
                        HelpBullets([
                            "Generate Video — adds a job and opens its detail.",
                            "Generate all — starts every ready job at once.",
                            "Stop all / Cancel — stops the active render(s).",
                            "Clear done — removes finished jobs from the gallery."
                        ])
                    }

                    HelpSection(title: "Running several at once", symbol: "square.stack.3d.up") {
                        HelpPara("Up to <b>8</b> videos render concurrently — the Z.AI API is the limit, not your Mac. Jobs beyond that are queued and start automatically as slots free up. Each job is titled by its position (Video 1, Video 2, …) so you can tell them apart while several run.")
                    }

                    HelpSection(title: "Parameters", symbol: "slider.horizontal.3") {
                        HelpBullets([
                            "Model — which Z.AI video model to use (cogvideox-3, vidu, …).",
                            "Aspect — Landscape, Portrait, Square, or Default.",
                            "Resolution — output size in pixels.",
                            "Duration — clip length in seconds.",
                            "FPS — frames per second (30 or 60).",
                            "Quality — Quality (better) or Speed (faster). Only cogvideox-3.",
                            "Motion — how much camera/object movement to allow.",
                            "Include audio — generate a matching audio track when supported."
                        ])
                    }

                    HelpSection(title: "Pick up where you left off", symbol: "arrow.triangle.2.circlepath") {
                        HelpPara("Your gallery is saved to disk, and an in-progress render keeps going on Z.AI's servers even if you quit the app. When you reopen Z Video Generator, any job that was still rendering <b>automatically resumes</b> — and if it finished while the app was closed, it shows as ready.")
                        HelpPara("Finished jobs stick around too, so you can always reopen one to grab its prompt.")
                    }

                    HelpSection(title: "Reusing a prompt", symbol: "doc.on.doc") {
                        HelpPara("From a job's detail, use <b>⋯ → Copy prompt</b> to copy its text, or <b>Duplicate</b> to clone the job with all its settings. <b>Regenerate</b> re-runs a finished job; <b>Retry</b> re-runs a failed one.")
                    }

                    HelpSection(title: "Saving your videos", symbol: "square.and.arrow.down") {
                        HelpPara("Finished videos play inline. Use <b>Save to Downloads</b> to keep the .mp4, or <b>Open</b> to play it in your default player. For anything you want to keep permanently, save it — the playback link Z.AI provides can eventually expire.")
                    }

                    HelpSection(title: "Security & privacy", symbol: "lock.shield") {
                        HelpBullets([
                            "Sandboxed, with App Transport Security locked to HTTPS.",
                            "Your API key lives in Keychain and requires your Mac to be unlocked.",
                            "The only thing that leaves your Mac is what you ask Z.AI to render.",
                            "No analytics, no tracking, no third-party SDKs."
                        ])
                    }

                    HelpSection(title: "Troubleshooting", symbol: "lifepreserver") {
                        HelpBullets([
                            "“That doesn't look like a Z.AI key” — the key must contain a dot, like id.secret.",
                            "A render fails — open its detail to read the server message, then Retry.",
                            "Video won't play after a long time — the result link may have expired; regenerate or re-open sooner and save it.",
                            "Want to start over — remove the key from the sidebar footer to return to setup."
                        ])
                    }

                    if let url = URL(string: "https://z.ai") {
                        Link(destination: url) {
                            Label("Get a key or manage your account at z.ai →", systemImage: "safari")
                                .font(.app(AppType.body))
                                .foregroundStyle(AppTheme.resolve(scheme).interactive)
                        }
                        .padding(.top, Spacing.s2)
                    }
                }
                .padding(Spacing.s7)
                .frame(maxWidth: 640)
                .frame(maxWidth: .infinity)
            }
        }
        .frame(minWidth: 560, minHeight: 460)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Done") { dismiss() }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Spacing.s3) {
            HStack(spacing: Spacing.s4) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(LinearGradient(colors: [Color(hex: "4f8dff"), Color(hex: "0f62fe")],
                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                    Image(systemName: "play.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                }
                .frame(width: 40, height: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Z Video Generator").font(.app(AppType.heading01)).foregroundStyle(.primary)
                    Text("Generate videos in parallel, beautifully.").font(.app(AppType.body)).foregroundStyle(.secondary)
                }
            }
            Divider().padding(.top, Spacing.s2)
        }
    }
}

// MARK: - Help building blocks

private struct HelpSection<Content: View>: View {
    let title: String
    let symbol: String
    @ViewBuilder var content: Content

    var body: some View {
        Surface {
            VStack(alignment: .leading, spacing: Spacing.s3) {
                HStack(spacing: Spacing.s3) {
                    Image(systemName: symbol)
                        .font(.app(AppType.body))
                        .foregroundStyle(.tint)
                        .frame(width: 22)
                    Text(title).font(.app(AppType.heading01)).foregroundStyle(.primary)
                }
                VStack(alignment: .leading, spacing: Spacing.s2) { content }
            }
        }
    }
}

/// A paragraph that supports <b>…</b> for bold runs (used for inline emphasis
/// without a full AttributedString builder per call).
private struct HelpPara: View {
    let text: String

    init(_ text: String) { self.text = text }

    var body: some View {
        Text(parts)
            .font(.app(AppType.bodyLong))
            .foregroundStyle(.primary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var parts: AttributedString {
        var result = AttributedString()
        let segments = text.components(separatedBy: "<b>")
        for (i, segment) in segments.enumerated() {
            if i == 0 {
                result += AttributedString(segment)
            } else {
                let split = segment.components(separatedBy: "</b>")
                var bold = AttributedString(split.first ?? "")
                bold.inlinePresentationIntent = .stronglyEmphasized
                result += bold
                if split.count > 1 { result += AttributedString(split[1]) }
            }
        }
        return result
    }
}

private struct HelpBullets: View {
    let items: [String]
    init(_ items: [String]) { self.items = items }
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s2) {
            ForEach(items, id: \.self) { HelpPara("•  \($0)") }
        }
    }
}
