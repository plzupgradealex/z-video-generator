import SwiftUI

/// First-run API-key entry. Shown in place of the app until a key is stored.
/// The key is written to `AppModel.apiKey` (→ Keychain) on Continue; the app is
/// then surfaced. This replaces the old in-preview "add your key" CTA.
struct OnboardingView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.colorScheme) private var scheme
    @State private var key = ""
    @State private var didSubmit = false
    @FocusState private var focused: Bool

    private var trimmed: String { key.trimmingCharacters(in: .whitespacesAndNewlines) }
    /// Z.AI keys look like `id.secret`.
    private var isValid: Bool { trimmed.split(separator: ".").count >= 2 }

    var body: some View {
        VStack(spacing: Spacing.s7) {
            Spacer(minLength: 0)
            brand
            card
            Spacer(minLength: 0)
            footnote
        }
        .padding(.horizontal, Spacing.s7)
        .padding(.vertical, Spacing.s9)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { focused = true }
    }

    private var brand: some View {
        VStack(spacing: Spacing.s4) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(LinearGradient(colors: [Color(hex: "4f8dff"), Color(hex: "0f62fe")],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                Image(systemName: "play.fill")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white)
            }
            .frame(width: 48, height: 48)
            .shadow(color: Color(hex: "4f8dff").opacity(0.4), radius: 12, y: 4)

            VStack(spacing: 2) {
                Text("Z Video").font(.app(AppType.heading02)).foregroundStyle(.primary)
                Text("Z.AI video generation").font(.app(AppType.caption)).foregroundStyle(.secondary)
            }
        }
    }

    private var card: some View {
        let set = AppTheme.resolve(scheme)
        return VStack(alignment: .leading, spacing: Spacing.s5) {
            VStack(alignment: .leading, spacing: Spacing.s2) {
                Text("Enter your Z.AI API key").font(.app(AppType.heading01)).foregroundStyle(.primary)
                Text("Paste your key to generate videos. It's stored securely in your Mac's Keychain — only ever sent to z.ai.")
                    .font(.app(AppType.body)).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            SecureField("id.secret", text: $key)
                .textFieldStyle(.plain)
                .font(.app(AppType.bodyLong))
                .padding(Spacing.s3)
                .fieldBackground()
                .focused($focused)
                .onSubmit(continueAction)

            if didSubmit && !isValid {
                Text("That doesn't look like a Z.AI key — it should be in the form id.secret.")
                    .font(.app(AppType.caption)).foregroundStyle(set.danger)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack(spacing: Spacing.s4) {
                if let url = URL(string: "https://z.ai") {
                    Link("Get a key at z.ai →", destination: url)
                        .font(.app(AppType.caption))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button(action: continueAction) {
                    Text("Continue").font(.app(AppType.body)).fontWeight(.semibold)
                        .padding(.horizontal, Spacing.s4)
                }
                .buttonStyle(.glassProminent)
                .controlSize(.large)
                .disabled(trimmed.isEmpty)
            }

            Button {
                model.isDemoMode = true
            } label: {
                Text("Try the demo without a key →")
                    .font(.app(AppType.caption))
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.secondary)
        }
        .padding(Spacing.s7)
        .frame(maxWidth: 460)
        .glassSurface(in: RoundedRectangle(cornerRadius: Radius.large, style: .continuous))
    }

    private var footnote: some View {
        Text("Your key never leaves your Mac except to call the Z.AI API directly.")
            .font(.app(AppType.caption)).foregroundStyle(.tertiary)
    }

    private func continueAction() {
        didSubmit = true
        guard isValid else { return }
        model.apiKey = trimmed
        key = ""
    }
}
