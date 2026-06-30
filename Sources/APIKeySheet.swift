import SwiftUI

/// Change or remove the stored Z.AI API key. Reached from the sidebar footer.
/// Removing the key drops back to `OnboardingView`.
struct APIKeySheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var keyInput = ""

    private var trimmed: String { keyInput.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s5) {
            VStack(alignment: .leading, spacing: Spacing.s2) {
                Eyebrow(text: "API key")
                Text("Z.AI API key").font(.app(AppType.heading01)).foregroundStyle(.primary)
                Text("Stored in your Mac's Keychain. Only ever sent to z.ai to generate videos.")
                    .font(.app(AppType.body)).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            SecureField("id.secret", text: $keyInput)
                .textFieldStyle(.plain)
                .font(.app(AppType.bodyLong))
                .padding(Spacing.s3)
                .fieldBackground()

            if let url = URL(string: "https://z.ai") {
                Link("Get a key at z.ai →", destination: url)
                    .font(.app(AppType.caption)).foregroundStyle(.secondary)
            }

            HStack(spacing: Spacing.s4) {
                Button(role: .destructive) {
                    keyInput = ""
                    model.apiKey = ""
                    KeychainStore.delete()
                    dismiss()
                } label: {
                    Text("Remove").font(.app(AppType.body))
                }
                .buttonStyle(.glass)
                .disabled(model.apiKey.isEmpty && keyInput.isEmpty)
                Spacer()
                Button("Cancel") { dismiss() }.font(.app(AppType.body))
                Button {
                    model.apiKey = trimmed
                    dismiss()
                } label: {
                    Text("Save").font(.app(AppType.body)).fontWeight(.semibold)
                }
                .buttonStyle(.glassProminent)
                .controlSize(.large)
                .disabled(trimmed.isEmpty)
            }
        }
        .padding(Spacing.s6)
        .frame(width: 460)
        .background(SmokeBackground())
        .onAppear { keyInput = model.apiKey }
    }
}
