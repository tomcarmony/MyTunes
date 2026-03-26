import AppKit
import Foundation

enum MusicRootBookmark {
    private static let defaultsKey = "musicRootSecurityScopedBookmark"

    static func saveBookmark(for url: URL) throws {
        let data = try url.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        UserDefaults.standard.set(data, forKey: defaultsKey)
    }

    /// Resolves the saved bookmark. Caller must `startAccessingSecurityScopedResource()` on the returned URL when reading files.
    static func resolveBookmark() throws -> URL? {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey) else { return nil }
        var isStale = false
        let url = try URL(
            resolvingBookmarkData: data,
            options: [.withSecurityScope, .withoutUI],
            bookmarkDataIsStale: &isStale
        )
        if isStale {
            return nil
        }
        return url
    }

    static func clearBookmark() {
        UserDefaults.standard.removeObject(forKey: defaultsKey)
    }

    /// Presents an open panel and returns the chosen directory URL (already security-scoped for the run loop turn).
    @MainActor
    static func pickMusicRootDirectory() -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Choose the folder that contains your `albums` directory (e.g. MyTunes)."
        guard panel.runModal() == .OK, let url = panel.url else { return nil }
        return url
    }
}
