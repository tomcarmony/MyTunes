import Foundation

enum MusicLibraryScanner {
    private static let allowedExtensions: Set<String> = ["mp3", "m4a", "aac", "wav"]

    /// Scans `root/albums/{artist}/{album}/*` for audio files. `root` must be accessible (security-scoped if needed).
    static func scanLibrary(root: URL) throws -> [Artist] {
        let albumsRoot = root.appendingPathComponent("albums", isDirectory: true)
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: albumsRoot.path, isDirectory: &isDir), isDir.boolValue else {
            return []
        }

        let artistURLs = try FileManager.default.contentsOfDirectory(
            at: albumsRoot,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )
        .filter { url in
            (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
        }
        .sorted { $0.lastPathComponent.localizedCaseInsensitiveCompare($1.lastPathComponent) == .orderedAscending }

        var artists: [Artist] = []
        for artistURL in artistURLs {
            let artistName = artistURL.lastPathComponent
            let albumURLs = try FileManager.default.contentsOfDirectory(
                at: artistURL,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            )
            .filter { url in
                (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
            }
            .sorted { $0.lastPathComponent.localizedCaseInsensitiveCompare($1.lastPathComponent) == .orderedAscending }

            var albums: [Album] = []
            for albumURL in albumURLs {
                let albumName = albumURL.lastPathComponent
                let fileURLs = try FileManager.default.contentsOfDirectory(
                    at: albumURL,
                    includingPropertiesForKeys: [.isRegularFileKey],
                    options: [.skipsHiddenFiles]
                )
                let tracks: [Track] = fileURLs
                    .filter { url in
                        guard (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true else {
                            return false
                        }
                        let ext = url.pathExtension.lowercased()
                        return allowedExtensions.contains(ext)
                    }
                    .sorted { $0.lastPathComponent.localizedCaseInsensitiveCompare($1.lastPathComponent) == .orderedAscending }
                    .map { url in
                        let base = url.deletingPathExtension().lastPathComponent
                        return Track(id: url.path, url: url, title: base)
                    }

                guard !tracks.isEmpty else { continue }
                let albumId = albumURL.path
                albums.append(Album(id: albumId, name: albumName, artistName: artistName, tracks: tracks))
            }

            guard !albums.isEmpty else { continue }
            artists.append(Artist(id: artistName, name: artistName, albums: albums))
        }

        return artists
    }
}
