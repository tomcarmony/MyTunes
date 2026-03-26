import AVFoundation
import Combine
import Foundation

@MainActor
final class PlaybackController: ObservableObject {
    private let player = AVPlayer()

    @Published private(set) var currentTrack: Track?
    @Published private(set) var isPlaying = false
    @Published private(set) var currentTime: Double = 0
    @Published private(set) var duration: Double = 0

    private var albumQueue: [Track] = []
    private var queueIndex: Int = 0
    private var timeObserverToken: Any?
    private var endObserver: NSObjectProtocol?
    private var statusCancellable: AnyCancellable?
    private var rateCancellable: AnyCancellable?

    init() {
        timeObserverToken = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.3, preferredTimescale: 600),
            queue: .main
        ) { [weak self] time in
            guard let self else { return }
            Task { @MainActor in
                self.tick(time: time)
            }
        }

        rateCancellable = player.publisher(for: \.rate)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] rate in
                self?.isPlaying = rate > 0.01
            }
    }

    deinit {
        if let token = timeObserverToken {
            player.removeTimeObserver(token)
        }
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
        }
    }

    func play(track: Track, queue: [Track]) {
        guard let idx = queue.firstIndex(where: { $0.id == track.id }) else { return }
        albumQueue = queue
        queueIndex = idx
        loadCurrentItem(shouldPlay: true)
    }

    func togglePlayPause() {
        if isPlaying {
            player.pause()
        } else {
            if player.currentItem == nil, currentTrack != nil {
                loadCurrentItem(shouldPlay: true)
            } else {
                player.play()
            }
        }
    }

    func seek(to seconds: Double) {
        let t = CMTime(seconds: seconds, preferredTimescale: 600)
        player.seek(to: t, toleranceBefore: .zero, toleranceAfter: .zero)
    }

    func nextTrack() {
        guard queueIndex + 1 < albumQueue.count else { return }
        queueIndex += 1
        loadCurrentItem(shouldPlay: true)
    }

    func previousTrack() {
        guard queueIndex > 0 else { return }
        queueIndex -= 1
        loadCurrentItem(shouldPlay: true)
    }

    private func tick(time: CMTime) {
        guard time.isNumeric, !time.seconds.isNaN else { return }
        currentTime = time.seconds
        if let item = player.currentItem {
            let d = item.duration
            if d.isNumeric, !d.seconds.isNaN, d.seconds > 0 {
                duration = d.seconds
            }
        }
    }

    private func loadCurrentItem(shouldPlay: Bool) {
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
            self.endObserver = nil
        }
        statusCancellable?.cancel()
        statusCancellable = nil

        guard queueIndex >= 0, queueIndex < albumQueue.count else { return }
        let track = albumQueue[queueIndex]
        currentTrack = track

        let item = AVPlayerItem(url: track.url)
        player.replaceCurrentItem(with: item)

        endObserver = NotificationCenter.default.addObserver(
            forName: AVPlayerItem.didPlayToEndTimeNotification,
            object: item,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handlePlayToEnd()
            }
        }

        statusCancellable = item.publisher(for: \.status)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                guard let self else { return }
                if status == .readyToPlay {
                    let d = item.duration
                    if d.isNumeric, !d.seconds.isNaN, d.seconds > 0 {
                        duration = d.seconds
                    }
                }
            }

        if shouldPlay {
            player.play()
        }
    }

    private func handlePlayToEnd() {
        if queueIndex + 1 < albumQueue.count {
            queueIndex += 1
            loadCurrentItem(shouldPlay: true)
        } else {
            player.pause()
        }
    }
}
