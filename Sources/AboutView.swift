import SwiftUI
import AppKit

/// The About window (app menu → About Z Video Generator). Mirrors Muxy's rich
/// About panel, adapted to Z's design system: bundled app icon, IBM Plex type,
/// SF-Symbol feature rows, txw credits, and a pure-tip "Support Z" button backed
/// by StoreKit 2 (`Store`). The version is read from the Info.plist keys driven
/// by `MARKETING_VERSION` / `CURRENT_PROJECT_VERSION`.
struct AboutView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme
    @ObservedObject private var store = Store.shared

    /// Supporter gold — the cosmetic mark + thank-you tint. Matches Muxy's
    /// supporter gold (#b27d0c).
    private let gold = Color(hex: "b27d0c")

    private var versionText: String {
        let info = Bundle.main.infoDictionary ?? [:]
        let short = info["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info["CFBundleVersion"] as? String ?? "1"
        return "Version \(short) (\(build))"
    }

    /// (SF Symbol, label) — Z uses SF Symbols app-wide (no Carbon assets), so the
    /// feature rows use system symbols rather than Muxy's Carbon icons.
    private let featureRows: [(String, String)] = [
        ("wand.and.stars", "Text-to-video, with audio"),
        ("books.vertical", "Prompt library & presets"),
        ("ruler", "Up to 4K · 30 or 60 fps"),
        ("arrow.down.to.line", "Play & save to Downloads"),
    ]

    var body: some View {
        let set = AppTheme.resolve(scheme)
        VStack(spacing: Spacing.s5) {
            Image(nsImage: NSApplication.shared.applicationIconImage)
                .resizable()
                .interpolation(.high)
                .frame(width: 96, height: 96)

            VStack(spacing: 2) {
                Text("Z Video Generator").font(.app(AppType.heading01)).foregroundStyle(.primary)
                Text(versionText).font(.app(AppType.caption)).foregroundStyle(.secondary)
            }

            Text("Turn a prompt into a short video with Z.AI — manage a queue, reuse prompts, and save your renders.")
                .font(.app(AppType.body))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, Spacing.s2)

            VStack(spacing: Spacing.s2) {
                ForEach(featureRows, id: \.0) { icon, label in
                    HStack(spacing: Spacing.s3) {
                        Image(systemName: icon)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(set.interactive)
                            .frame(width: 18)
                        Text(label).font(.app(AppType.caption)).foregroundStyle(.secondary)
                        Spacer()
                    }
                }
            }
            .padding(.horizontal, Spacing.s2)

            Divider()

            VStack(spacing: Spacing.s1) {
                if let url = URL(string: "https://z.ai") {
                    Link("Powered by Z.AI →", destination: url)
                        .font(.app(AppType.caption))
                        .foregroundStyle(set.interactive)
                }
                Text("Built by Alexander Ruppel")
                    .font(.app(AppType.tag)).foregroundStyle(.secondary)
                Link("txw.ca", destination: URL(string: "https://txw.ca")!)
                    .font(.app(AppType.tag))
                Text("© 2026 txw")
                    .font(.app(AppType.tag)).foregroundStyle(.tertiary)
            }

            // Pure-tip supporter IAP: a cosmetic thank-you, never credits or a
            // feature gate. Until the ASC product is live the button explains why
            // it can't purchase instead of looking dead.
            if store.supporter {
                Label("Thank you for your support!", systemImage: "heart.fill")
                    .font(.app(AppType.body)).fontWeight(.semibold)
                    .foregroundStyle(gold)
            } else {
                Button {
                    store.clearPurchaseNote()
                    Task { await store.purchase() }
                } label: {
                    Label("Support Z Video Generator", systemImage: "heart")
                        .font(.app(AppType.body)).fontWeight(.semibold)
                }
                .buttonStyle(.borderedProminent)
                .tint(set.interactive)
                .controlSize(.large)
            }

            if let note = store.purchaseNote {
                Text(note)
                    .font(.app(AppType.tag)).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(Spacing.s6)
        .frame(width: 340)
        .background(SmokeBackground())
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Done") { dismiss() }
            }
        }
    }
}
