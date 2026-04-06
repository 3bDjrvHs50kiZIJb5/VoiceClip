import AVFoundation
import Foundation

/// 与 Electron 播放器一致：主线程入队，顺序播放多段 WAV。
final class QueuedAudioPlayer: NSObject, AVAudioPlayerDelegate {
    private var queue: [Data] = []
    private var current: AVAudioPlayer?
    private var isDraining = false

    func enqueue(_ data: Data) {
        queue.append(data)
        if !isDraining {
            playNext()
        }
    }

    func clear() {
        queue.removeAll()
        current?.stop()
        current = nil
        isDraining = false
    }

    private func playNext() {
        guard !queue.isEmpty else {
            isDraining = false
            return
        }

        isDraining = true
        let data = queue.removeFirst()

        do {
            let player = try AVAudioPlayer(data: data)
            player.delegate = self
            current = player
            player.play()
        } catch {
            current = nil
            playNext()
        }
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        current = nil
        playNext()
    }
}
