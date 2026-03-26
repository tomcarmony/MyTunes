import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var library: LibraryStore
    @EnvironmentObject private var playback: PlaybackController

    @State private var selectedArtistID: Artist.ID?
    @State private var selectedAlbumID: Album.ID?
    @State private var searchText = ""

    var body: some View {
        VStack(spacing: 0) {
            Group {
                if !library.hasMusicRoot {
                    emptyNoRootView
                } else {
                    librarySplitView
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()
            PlayerBarView()
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Rescan library") {
                    library.rescan()
                }
                .disabled(!library.hasMusicRoot || library.isScanning)
            }
        }
        .searchable(text: $searchText, prompt: "Filter artists, albums, tracks")
        .onAppear {
            library.bootstrap()
        }
        .onChange(of: library.artists) { _, newArtists in
            if let id = selectedArtistID, !newArtists.contains(where: { $0.id == id }) {
                selectedArtistID = nil
                selectedAlbumID = nil
            }
            if let aid = selectedArtistID, let albumId = selectedAlbumID,
               let artist = newArtists.first(where: { $0.id == aid }),
               !artist.albums.contains(where: { $0.id == albumId }) {
                selectedAlbumID = nil
            }
        }
    }

    private var emptyNoRootView: some View {
        ContentUnavailableView {
            Label("Choose your music folder", systemImage: "folder.badge.questionmark")
        } description: {
            Text("Pick the folder that contains an `albums` directory, for example `…/MyTunes` with `MyTunes/albums/Artist/Album/songs`.")
        } actions: {
            Button("Choose folder…") {
                library.chooseMusicFolder()
            }
            .keyboardShortcut("o", modifiers: [.command])
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var librarySplitView: some View {
        NavigationSplitView {
            VStack(alignment: .leading, spacing: 0) {
                if library.isScanning {
                    ProgressView("Indexing…")
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                }
                if library.missingAlbumsFolder {
                    Text("No `albums` folder found under the selected directory. Add `albums/Artist/Album/` or pick another folder.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.bottom, 6)
                }
                List(selection: $selectedArtistID) {
                    ForEach(filteredArtists) { artist in
                        Text(artist.name)
                            .tag(artist.id as Artist.ID?)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .navigationTitle("Artists")
            .navigationSplitViewColumnWidth(min: 160, ideal: 200)
        } content: {
            Group {
                if let artist = selectedArtist {
                    List(selection: $selectedAlbumID) {
                        ForEach(filteredAlbums(for: artist)) { album in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(album.name)
                                Text("\(album.tracks.count) tracks")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .tag(album.id as Album.ID?)
                        }
                    }
                    .navigationTitle(artist.name)
                } else {
                    ContentUnavailableView("Select an artist", systemImage: "person.fill")
                }
            }
            .navigationSplitViewColumnWidth(min: 200, ideal: 260)
        } detail: {
            Group {
                if let album = selectedAlbum {
                    List(album.tracks) { track in
                        TrackRowView(track: track, album: album, playback: playback)
                    }
                    .navigationTitle(album.name)
                } else {
                    ContentUnavailableView("Select an album", systemImage: "opticaldisc")
                }
            }
        }
    }

    private var selectedArtist: Artist? {
        guard let id = selectedArtistID else { return nil }
        return library.artists.first { $0.id == id }
    }

    private var selectedAlbum: Album? {
        guard let artist = selectedArtist, let aid = selectedAlbumID else { return nil }
        return artist.albums.first { $0.id == aid }
    }

    private var filteredArtists: [Artist] {
        let base = library.artists
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return base }
        return base.filter { artist in
            artist.name.localizedCaseInsensitiveContains(q)
                || artist.albums.contains { album in
                    album.name.localizedCaseInsensitiveContains(q)
                        || album.tracks.contains { $0.title.localizedCaseInsensitiveContains(q) }
                }
        }
    }

    private func filteredAlbums(for artist: Artist) -> [Album] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return artist.albums }
        return artist.albums.filter { album in
            album.name.localizedCaseInsensitiveContains(q)
                || album.tracks.contains { $0.title.localizedCaseInsensitiveContains(q) }
                || artist.name.localizedCaseInsensitiveContains(q)
        }
    }
}

private struct TrackRowView: View {
    let track: Track
    let album: Album
    @ObservedObject var playback: PlaybackController

    var body: some View {
        Button {
            playback.play(track: track, queue: album.tracks)
        } label: {
            HStack {
                Image(systemName: playback.currentTrack?.id == track.id && playback.isPlaying ? "speaker.wave.2.fill" : "play.circle")
                    .foregroundStyle(.secondary)
                Text(track.title)
                Spacer()
            }
        }
        .buttonStyle(.plain)
    }
}

private struct PlayerBarView: View {
    @EnvironmentObject private var playback: PlaybackController

    @State private var isScrubbing = false
    @State private var scrubValue: Double = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Button(action: { playback.previousTrack() }) {
                    Image(systemName: "backward.fill")
                }
                .keyboardShortcut(.leftArrow, modifiers: [.command])

                Button(action: { playback.togglePlayPause() }) {
                    Image(systemName: playback.isPlaying ? "pause.fill" : "play.fill")
                        .font(.title2)
                }
                .keyboardShortcut(.space, modifiers: [])

                Button(action: { playback.nextTrack() }) {
                    Image(systemName: "forward.fill")
                }
                .keyboardShortcut(.rightArrow, modifiers: [.command])

                VStack(alignment: .leading, spacing: 2) {
                    Text(playback.currentTrack?.title ?? "Nothing playing")
                        .font(.headline)
                        .lineLimit(1)
                    Text(" ")
                        .font(.caption2)
                        .hidden()
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Text(formatTime(isScrubbing ? scrubValue : playback.currentTime))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                Text("/")
                    .foregroundStyle(.tertiary)
                Text(formatTime(playback.duration))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }

            Slider(
                value: Binding(
                    get: {
                        isScrubbing ? scrubValue : playback.currentTime
                    },
                    set: { scrubValue = $0 }
                ),
                in: 0 ... max(playback.duration, 0.01),
                onEditingChanged: { editing in
                    if editing {
                        isScrubbing = true
                        scrubValue = playback.currentTime
                    } else {
                        playback.seek(to: scrubValue)
                        isScrubbing = false
                    }
                }
            )
            .disabled(playback.currentTrack == nil || playback.duration <= 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.bar)
    }

    private func formatTime(_ seconds: Double) -> String {
        guard seconds.isFinite, !seconds.isNaN, seconds >= 0 else { return "0:00" }
        let total = Int(seconds.rounded(.down))
        let m = total / 60
        let s = total % 60
        return String(format: "%d:%02d", m, s)
    }
}

#Preview {
    ContentView()
        .environmentObject(LibraryStore())
        .environmentObject(PlaybackController())
}
