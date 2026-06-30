import SwiftUI

struct HistoryView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Group {
            if model.history.isEmpty {
                ContentUnavailableView {
                    Label("No history yet", systemImage: "clock.arrow.circlepath")
                } description: {
                    Text("Generated videos will appear here.")
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: Spacing.s3) {
                        ForEach(model.history) { item in
                            HistoryRow(item: item)
                        }
                    }
                    .padding(Spacing.s6)
                    .frame(maxWidth: 820)
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .background(SmokeBackground())
        .navigationTitle("History")
        .toolbar {
            if !model.history.isEmpty {
                ToolbarItem(placement: .primaryAction) {
                    Button(role: .destructive) {
                        model.clearHistory()
                    } label: {
                        Label("Clear", systemImage: "trash")
                    }
                }
            }
        }
    }
}

private struct HistoryRow: View {
    let item: HistoryItem

    var body: some View {
        Surface(radius: Radius.medium, padding: Spacing.s4) {
            HStack(spacing: Spacing.s4) {
                poster
                VStack(alignment: .leading, spacing: Spacing.s2) {
                    Text(item.prompt)
                        .font(.app(AppType.body)).foregroundStyle(.primary)
                        .lineLimit(2)
                    HStack(spacing: Spacing.s2) {
                        Chip(text: item.model)
                        Text("·").foregroundStyle(.tertiary)
                        Text(item.date, style: .date)
                    }
                    .font(.app(AppType.caption))
                    .foregroundStyle(.secondary)
                }
                Spacer()
                if let url = URL(string: item.videoURL) {
                    Button { ZVUtil.openExternal(url) } label: {
                        Label("Open", systemImage: "arrow.up.right.square")
                            .font(.app(AppType.caption))
                    }
                    .buttonStyle(.glass)
                }
            }
        }
    }

    @ViewBuilder
    private var poster: some View {
        let cover = item.coverURL.flatMap(URL.init(string:))
        ZStack {
            RoundedRectangle(cornerRadius: Radius.small, style: .continuous).fill(Color.black)
            if let cover {
                AsyncImage(url: cover) { phase in
                    switch phase {
                    case .success(let image): image.resizable().scaledToFill()
                    default: Color.black
                    }
                }
            } else {
                Image(systemName: "film")
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
        .frame(width: 96, height: 60)
        .clipShape(RoundedRectangle(cornerRadius: Radius.small, style: .continuous))
    }
}
