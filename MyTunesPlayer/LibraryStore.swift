import AppKit
import Foundation

@MainActor
final class LibraryStore: ObservableObject {
    @Published private(set) var artists: [Artist] = []
    @Published private(set) var isScanning = false
    @Published var errorMessage: String?
    @Published private(set) var hasMusicRoot = false
    @Published private(set) var missingAlbumsFolder = false

    private var rootURL: URL?

    func bootstrap() {
        Task { await loadSavedRootAndScan() }
    }

    func chooseMusicFolder() {
        guard let url = MusicRootBookmark.pickMusicRootDirectory() else { return }
        stopAccessingRoot()
        _ = url.startAccessingSecurityScopedResource()
        do {
            try MusicRootBookmark.saveBookmark(for: url)
        } catch {
            errorMessage = error.localizedDescription
            url.stopAccessingSecurityScopedResource()
            return
        }
        rootURL = url
        hasMusicRoot = true
        missingAlbumsFolder = false
        Task { await scan() }
    }

    func changeMusicFolder() {
        stopAccessingRoot()
        MusicRootBookmark.clearBookmark()
        hasMusicRoot = false
        artists = []
        missingAlbumsFolder = false
        errorMessage = nil
        chooseMusicFolder()
    }

    func rescan() {
        Task { await scan() }
    }

    private func loadSavedRootAndScan() async {
        do {
            guard let url = try MusicRootBookmark.resolveBookmark() else {
                hasMusicRoot = false
                return
            }
            guard url.startAccessingSecurityScopedResource() else {
                errorMessage = "Could not access the saved music folder. Choose it again from Settings."
                hasMusicRoot = false
                return
            }
            rootURL = url
            hasMusicRoot = true
            await scan()
        } catch {
            errorMessage = error.localizedDescription
            hasMusicRoot = false
        }
    }

    private func scan() async {
        guard let rootURL else { return }
        isScanning = true
        errorMessage = nil
        defer { isScanning = false }

        let root = rootURL
        let albumsPath = root.appendingPathComponent("albums", isDirectory: true)
        var isDir: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: albumsPath.path, isDirectory: &isDir)
        missingAlbumsFolder = !(exists && isDir.boolValue)

        do {
            let result = try await Task.detached(priority: .userInitiated) {
                try MusicLibraryScanner.scanLibrary(root: root)
            }.value
            artists = result
        } catch {
            errorMessage = error.localizedDescription
            artists = []
        }
    }

    private func stopAccessingRoot() {
        rootURL?.stopAccessingSecurityScopedResource()
        rootURL = nil
    }
}
