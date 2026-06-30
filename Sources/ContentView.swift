import SwiftUI

enum SidebarItem: Hashable, CaseIterable {
    case generate
    case library
    case history

    var title: String {
        switch self {
        case .generate: "Generate"
        case .library: "Library"
        case .history: "History"
        }
    }

    /// Genuine IBM Carbon icon asset (from @carbon/icons), bundled as a template SVG.
    var carbonIcon: String {
        switch self {
        case .generate: "carbon-generate"   // ai-generate
        case .library: "carbon-library"     // catalog (Carbon has no literal "library")
        case .history: "carbon-history"     // time
        }
    }
}

struct ContentView: View {
    @Environment(AppModel.self) private var model
    @State private var selection: SidebarItem? = .generate
    @State private var showAPIKeySheet = false

    var body: some View {
        ZStack {
            SmokeBackground()
            // Keep the full app as long as the user has a key OR any saved
            // content — so a missing key never throws a returning user into the
            // first-run screen. The Generate view shows a "re-add your key"
            // banner when there's no key; only a genuinely new user (no key,
            // no jobs/library/history) sees OnboardingView.
            if model.canUse || model.hasExistingContent {
                NavigationSplitView {
                    sidebar
                } detail: {
                    detailView
                }
                .sheet(isPresented: $showAPIKeySheet) { APIKeySheet() }
            } else {
                OnboardingView()
            }
        }
    }

    @ViewBuilder
    private var detailView: some View {
        switch selection {
        case .history: HistoryView()
        case .library:
            LibraryView(onUse: { saved in
                model.addJob(from: saved)
                selection = .generate
            })
        default:
            GenerationView(onAddKey: { showAPIKeySheet = true })
        }
    }

    private var sidebar: some View {
        VStack(spacing: 0) {
            List(selection: $selection) {
                Section {
                    ForEach(SidebarItem.allCases, id: \.self) { item in
                        Label {
                            Text(item.title)
                        } icon: {
                            CarbonIcon(name: item.carbonIcon, size: 16)
                        }
                        .tag(item)
                    }
                }
            }
            .listStyle(.sidebar)

            SidebarFooter(status: model.connectionStatus) {
                showAPIKeySheet = true
            }
            .padding(.bottom, Spacing.s4)
        }
        .navigationTitle("Z Video")
        // Locked, non-draggable width (min == ideal == max) so the panel stays
        // narrow and consistent — never drifts.
        .navigationSplitViewColumnWidth(min: 130, ideal: 130, max: 130)
    }

}

/// Carbon footer row that doubles as the live connection-status light: a colored
/// dot (green = key works, yellow = checking / can't connect, red = no key) next
/// to a short label, plus a discreet key glyph. The whole row opens the
/// `APIKeySheet` to change or remove the key.
private struct SidebarFooter: View {
    let status: ConnectionStatus
    let action: () -> Void
    @Environment(\.colorScheme) private var scheme
    @State private var hovered = false

    private var dotColor: Color {
        let set = AppTheme.resolve(scheme)
        switch status {
        case .connected: return set.success
        case .checking:  return set.warning
        case .error:     return set.warning   // can't connect / key rejected
        case .noKey:     return set.danger
        case .demo:      return set.interactive   // demo mode, no key
        }
    }

    private var label: String {
        switch status {
        case .connected: return "Connected"
        case .checking:  return "Connecting"
        case .error:     return "Offline"
        case .noKey:     return "No key"
        case .demo:      return "Demo"
        }
    }

    var body: some View {
        let set = AppTheme.resolve(scheme)
        VStack(spacing: 0) {
            // Flush 1px Carbon divider separating the footer from the nav list.
            set.border
                .opacity(scheme == .dark ? 0.7 : 1)
                .frame(height: 1)
                .frame(maxWidth: .infinity)

            Button(action: action) {
                HStack(spacing: Spacing.s2) {
                    Circle()
                        .fill(dotColor)
                        .frame(width: 8, height: 8)
                    Text(label)
                        .font(.app(AppType.caption))
                        .foregroundStyle(set.textSecondary)
                        .lineLimit(1)
                    Spacer(minLength: Spacing.s2)
                    CarbonIcon(name: "carbon-key", size: 13)
                        .foregroundStyle(set.textSecondary)
                }
                .padding(.horizontal, Spacing.s3)
                .padding(.vertical, Spacing.s2)
                .frame(maxWidth: .infinity)
                .contentShape(.rect)
            }
            .buttonStyle(.carbonGhost(hovered: hovered))
            .onHover { hovered = $0 }
            .help("Change or remove your Z.AI API key")
        }
    }
}
