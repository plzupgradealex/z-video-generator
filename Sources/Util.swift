import AppKit
import Foundation

/// Small, shared helpers that don't belong to any one type.

enum ZVUtil {
    /// Open a URL in the user's default browser, but only for `http`/`https`.
    /// Result URLs originate from the Z.AI API (always https), but validating the
    /// scheme here means a malformed or unexpected value can never hand the
    /// system a `file://`/custom-scheme URL to dispatch.
    static func openExternal(_ url: URL) {
        guard let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" else { return }
        NSWorkspace.shared.open(url)
    }

    /// Trim a server error body to a length that stays useful in the UI without
    /// dumping a multi-kilobyte HTML error page into an alert.
    static func summarize(_ string: String, limit: Int = 240) -> String {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.count <= limit ? trimmed : String(trimmed.prefix(limit)) + "…"
    }

    /// Save a video (bundled `file://` demo result or a remote `https` result) to
    /// a location the user picks via `NSSavePanel`, defaulting to ~/Downloads.
    ///
    /// This runs under the narrow `files.user-selected.read-write` entitlement:
    /// `NSSavePanel` is the App Sandbox powerbox, so the user's selection grants
    /// write access without the broad `files.downloads.read-write` entitlement
    /// (which App Review asked us to remove as not strictly necessary).
    ///
    /// Returns `nil` if the user cancelled, `true` on success, `false` on error.
    static func saveVideo(from url: URL) async -> Bool? {
        // Fetch the bytes first — instant for a bundled file, a network fetch
        // for a remote result — so a failure never wastes the user's pick.
        let data: Data
        do {
            if url.isFileURL {
                data = try Data(contentsOf: url)
            } else {
                let (fetched, _) = try await URLSession.shared.data(from: url)
                data = fetched
            }
        } catch {
            return false
        }

        // runModal() blocks, so present the panel on the main actor.
        let destination: URL? = await MainActor.run {
            let panel = NSSavePanel()
            panel.title = "Save Video"
            panel.prompt = "Save"
            panel.nameFieldStringValue = "ZVideo-\(Int(Date().timeIntervalSince1970)).mp4"
            panel.canCreateDirectories = true
            if let downloads = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first {
                panel.directoryURL = downloads
            }
            return panel.runModal() == .OK ? panel.url : nil
        }
        guard let destination else { return nil } // user cancelled

        do {
            try data.write(to: destination, options: .atomic)
            return true
        } catch {
            return false
        }
    }
}
