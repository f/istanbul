import Foundation
import AVFoundation

struct BBCSound: Identifiable {
    let id: String
    let description: String
    let duration: Double

    var mp3URL: URL {
        URL(string: "https://sound-effects-media.bbcrewind.co.uk/mp3/\(id).mp3")!
    }

    var shortTitle: String {
        var text = description
        if text.hasPrefix("Istanbul, ") {
            text = String(text.dropFirst("Istanbul, ".count))
        }
        if let dotIndex = text.firstIndex(of: ",") {
            text = String(text[text.startIndex..<dotIndex])
        }
        return text.prefix(1).uppercased() + text.dropFirst()
    }

    var formattedDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

@Observable
final class SoundManager: NSObject, AVAudioPlayerDelegate {
    var sounds: [BBCSound] = []
    var isLoading = false
    var currentSound: BBCSound?
    var downloading: String?
    var volume: Float = 0.7
    var errorMessage: String?
    var isLooping = false
    var isAutoAdvance = false

    private var player: AVAudioPlayer?

    var isPlaying: Bool {
        currentSound != nil
    }

    func fetchSounds() async {
        isLoading = true
        defer { isLoading = false }

        guard let url = URL(string: "https://sound-effects-api.bbcrewind.co.uk/api/sfx/search") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = ["criteria": ["query": "istanbul", "size": 20]]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            let results = json?["results"] as? [[String: Any]] ?? []

            sounds = results.compactMap { result in
                guard let id = result["id"] as? String,
                      let description = result["description"] as? String,
                      let techMeta = result["technicalMetadata"] as? [String: Any],
                      let durationStr = techMeta["duration"] as? String,
                      let duration = Double(durationStr)
                else { return nil }
                return BBCSound(id: id, description: description, duration: duration)
            }
        } catch {
            errorMessage = "Failed to load sounds. Check your connection."
        }
    }

    func toggleSound(_ sound: BBCSound) async {
        if currentSound?.id == sound.id {
            stop()
        } else {
            await play(sound)
        }
    }

    func play(_ sound: BBCSound) async {
        stop()

        let localURL = localFileURL(for: sound)

        if !FileManager.default.fileExists(atPath: localURL.path) {
            downloading = sound.id
            defer { downloading = nil }
            do {
                let (tempURL, _) = try await URLSession.shared.download(from: sound.mp3URL)
                try FileManager.default.moveItem(at: tempURL, to: localURL)
            } catch {
                errorMessage = "Failed to download \(sound.shortTitle)"
                return
            }
        }

        do {
            let p = try AVAudioPlayer(contentsOf: localURL)
            p.delegate = self
            p.numberOfLoops = isLooping ? -1 : 0
            p.volume = volume
            p.play()
            player = p
            currentSound = sound
        } catch {
            errorMessage = "Failed to play \(sound.shortTitle)"
        }
    }

    func stop() {
        player?.stop()
        player = nil
        currentSound = nil
    }

    func setVolume(_ newVolume: Float) {
        volume = newVolume
        player?.volume = newVolume
    }

    private func localFileURL(for sound: BBCSound) -> URL {
        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let soundsDir = cacheDir.appendingPathComponent("IstanbulSounds")
        try? FileManager.default.createDirectory(at: soundsDir, withIntermediateDirectories: true)
        return soundsDir.appendingPathComponent("\(sound.id).mp3")
    }

    // MARK: - AVAudioPlayerDelegate

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        // If looping is enabled, AVAudioPlayer won't call this because it loops internally.
        // Handle automatic advance when a sound finishes.
        guard isAutoAdvance,
              let current = currentSound,
              let index = sounds.firstIndex(where: { $0.id == current.id }) else {
            if !isLooping {
                self.player = nil
                currentSound = nil
            }
            return
        }

        let nextIndex = sounds.index(after: index)
        guard nextIndex < sounds.count else {
            self.player = nil
            currentSound = nil
            return
        }

        let nextSound = sounds[nextIndex]
        Task { [weak self] in
            await self?.play(nextSound)
        }
    }
}
