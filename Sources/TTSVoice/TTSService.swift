import Foundation

/// 对应 Electron `tts/service.js`：分段合成、可取消任务。
actor TTSService {
    private var activeJobId = 0

    func speak(
        text: String,
        config: TTSConfig,
        onState: @escaping (AppState) -> Void,
        onChunk: @escaping (_ jobId: Int, _ index: Int, _ part: String, _ audio: Data) -> Void
    ) async throws {
        activeJobId += 1
        let jobId = activeJobId

        let normalized = text.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return }

        onState(.synthesizing)
        let parts = TTSClient.splitText(normalized, maxChars: 80, maxBytes: 300)

        for (index, part) in parts.enumerated() {
            if jobId != activeJobId {
                onState(.idle)
                return
            }

            let audio = try await TTSClient.synthesize(config: config, text: part)
            onChunk(jobId, index + 1, part, audio)
        }

        onState(.idle)
    }

    func stop() {
        activeJobId += 1
    }
}
