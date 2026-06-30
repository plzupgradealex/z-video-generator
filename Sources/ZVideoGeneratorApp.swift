import SwiftUI

@main
struct ZVideoGeneratorApp: App {
    @State private var appModel = AppModel()
    @Environment(\.scenePhase) private var scenePhase

    init() {
        // Register bundled IBM Plex faces before any view renders.
        AppFont.registerBundledFonts()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appModel)
                .tint(Color(hex: "4f8dff"))
                .frame(minWidth: 1040, minHeight: 680)
                // Flush the persisted gallery when the app steps to the background
                // or quits — pairs with the per-transition + 3s autosave so a
                // clean shutdown never loses in-flight or edited state.
                .onChange(of: scenePhase) { _, phase in
                    if phase == .background { appModel.saveJobs() }
                    // Re-probe Z.AI when the user comes back to the app, so the
                    // status light recovers (e.g. after fixing their network).
                    if phase == .active { appModel.verifyKey() }
                }
        }
        .windowStyle(.automatic)
        .windowToolbarStyle(.unified(showsTitle: true))
        .commands { ZVAppCommands() }

        // Settings window (⌘,) — default model/aspect/resolution/etc. for new jobs.
        Settings {
            SettingsView()
                .environment(appModel)
        }

        // Standalone windows opened from the app/Help menus.
        WindowGroup("About Z Video Generator", id: "about") {
            AboutView()
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 320, height: 280)

        WindowGroup("Z Video Generator Help", id: "help") {
            HelpView()
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 720, height: 620)
    }
}

/// Customizes the app-menu About item (→ About window) and the Help item
/// (→ in-app Help window, ⌘?).
struct ZVAppCommands: Commands {
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(replacing: .appInfo) {
            Button("About Z Video Generator") { openWindow(id: "about") }
        }
        CommandGroup(replacing: .help) {
            Button("Z Video Generator Help") { openWindow(id: "help") }
                .keyboardShortcut("?", modifiers: .command)
        }
    }
}
