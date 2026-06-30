import SwiftUI

/// The saved-prompt library. Each entry is a prompt (+ settings) the user chose
/// to keep — usually from a finished video they liked. "Use" seeds a fresh job
/// and jumps to Generate.
struct LibraryView: View {
    @Environment(AppModel.self) private var model
    let onUse: (SavedPrompt) -> Void

    var body: some View {
        Group {
            if model.savedPrompts.isEmpty {
                ContentUnavailableView {
                    Label("No saved prompts", systemImage: "books")
                } description: {
                    Text("Save a prompt you love from a finished video, then reuse it to start a new job.")
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: Spacing.s3) {
                        ForEach(model.savedPrompts) { item in
                            LibraryRow(
                                item: item,
                                onUse: { onUse(item) },
                                onRemove: { model.removeSavedPrompt(item) })
                        }
                    }
                    .padding(Spacing.s6)
                    .frame(maxWidth: 820)
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .background(SmokeBackground())
        .navigationTitle("Library")
    }
}

private struct LibraryRow: View {
    let item: SavedPrompt
    let onUse: () -> Void
    let onRemove: () -> Void

    var body: some View {
        Surface(radius: Radius.medium, padding: Spacing.s4) {
            VStack(alignment: .leading, spacing: Spacing.s2) {
                HStack(spacing: Spacing.s2) {
                    Image(systemName: "bookmark.fill")
                        .foregroundStyle(.tint)
                        .font(.caption)
                    Text(item.displayTitle)
                        .font(.app(AppType.body)).fontWeight(.medium)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Spacer()
                    Text(item.createdAt, style: .date)
                        .font(.app(AppType.caption)).foregroundStyle(.tertiary)
                }

                if !item.prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(item.prompt)
                        .font(.app(AppType.body)).foregroundStyle(.secondary)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack(spacing: Spacing.s2) {
                    Chip(text: item.model)
                    Chip(text: aspectLabel)
                    Chip(text: "\(item.duration)s")
                    Spacer()
                    Button { onUse() } label: {
                        Label("Use", systemImage: "arrow.up.right.square")
                            .font(.app(AppType.caption))
                    }
                    .buttonStyle(.glass)
                    Button(role: .destructive) { onRemove() } label: {
                        Image(systemName: "trash")
                            .font(.app(AppType.caption))
                    }
                    .buttonStyle(.glass)
                    .help("Remove from library")
                }
            }
        }
    }

    private var aspectLabel: String {
        item.aspect.isEmpty ? "Default" : item.aspect
    }
}
