import SwiftUI

@main
struct MyTunesPlayerApp: App {
    @StateObject private var libraryStore = LibraryStore()
    @StateObject private var playbackController = PlaybackController()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(libraryStore)
                .environmentObject(playbackController)
                .frame(minWidth: 880, minHeight: 520)
        }
        .commands {
            CommandGroup(replacing: .newItem) {}

            CommandMenu("Library") {
                Button("Choose music folder…") {
                    libraryStore.chooseMusicFolder()
                }
                .keyboardShortcut("o", modifiers: [.command, .shift])

                Button("Change music folder…") {
                    libraryStore.changeMusicFolder()
                }

                Divider()

                Button("Rescan library") {
                    libraryStore.rescan()
                }
                .keyboardShortcut("r", modifiers: [.command])
                .disabled(!libraryStore.hasMusicRoot || libraryStore.isScanning)
            }
        }

        Settings {
            SettingsView()
                .environmentObject(libraryStore)
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject private var library: LibraryStore

    var body: some View {
        Form {
            Section {
                Text("Music lives under a folder you choose (for example in iCloud Drive). Expected layout:")
                    .foregroundStyle(.secondary)
                Text("YourFolder/albums/Artist Name/Album Name/tracks.mp3")
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
            }

            Section {
                Button("Choose music folder…") {
                    library.chooseMusicFolder()
                }
                Button("Change music folder…") {
                    library.changeMusicFolder()
                }
                Button("Rescan library") {
                    library.rescan()
                }
                .disabled(!library.hasMusicRoot || library.isScanning)
            }

            if let err = library.errorMessage, !err.isEmpty {
                Section("Status") {
                    Text(err)
                        .foregroundStyle(.red)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 420, height: 320)
    }
}
