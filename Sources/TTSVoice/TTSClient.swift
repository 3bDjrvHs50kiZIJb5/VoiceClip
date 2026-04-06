import Foundation

/// 对应 Electron `tts/core.js`：长文本拆分与字节火山 OpenSpeech HTTP 调用。
struct TTSConfig {
    var appId: String
    var bearerToken: String
    var cluster: String
    var voiceType: String
    var endpoint: String
    var uid: String
    var encoding: String
    var speedRatio: Double
    var volumeRatio: Double
    var pitchRatio: Double
}

enum TTSClient {
    private static let defaultMaxBytes = 300

    private static func toPositiveNumber(_ value: Double, fallback: Double) -> Double {
        value.isFinite && value > 0 ? value : fallback
    }

    /// 与 `splitText(text, 80, 300)` 对齐：按句合并后再按字节/字符硬切。
    static func splitText(_ text: String, maxChars: Int, maxBytes: Int = defaultMaxBytes) -> [String] {
        let source = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !source.isEmpty else { return [] }

        let normalized = source.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // Swift Regex 不支持 `(?<=…)` 环视；此处与 Node `split(/(?<=[。！？!?；;\.])\s*/)` 语义对齐。
        let sentences = splitOnSentenceEndings(normalized)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        if sentences.isEmpty {
            return splitLongText(normalized, maxChars: maxChars, maxBytes: maxBytes)
        }

        var parts: [String] = []
        var current = ""

        for sentence in sentences {
            if !fits(sentence, maxChars: maxChars, maxBytes: maxBytes) {
                if !current.isEmpty {
                    parts.append(current)
                    current = ""
                }
                parts.append(contentsOf: splitLongText(sentence, maxChars: maxChars, maxBytes: maxBytes))
                continue
            }

            let candidate = current.isEmpty ? sentence : current + sentence
            if fits(candidate, maxChars: maxChars, maxBytes: maxBytes) {
                current = candidate
            } else {
                if !current.isEmpty {
                    parts.append(current)
                }
                current = sentence
            }
        }

        if !current.isEmpty {
            parts.append(current)
        }

        return parts
    }

    /// 在句末标点后切分（`\s*` 含零宽），等价于 JS 的 `split(/(?<=[。！？!?；;\.])\s*/)`。
    private static func splitOnSentenceEndings(_ normalized: String) -> [String] {
        let terminators: Set<Character> = ["。", "！", "？", "!", "?", "；", ";", "."]
        var sentences: [String] = []
        var current = ""
        var skipWhitespaceAfterBreak = false

        for ch in normalized {
            if skipWhitespaceAfterBreak, ch.isWhitespace {
                continue
            }
            skipWhitespaceAfterBreak = false
            current.append(ch)
            if terminators.contains(ch) {
                let trimmed = current.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    sentences.append(trimmed)
                }
                current = ""
                skipWhitespaceAfterBreak = true
            }
        }

        let tail = current.trimmingCharacters(in: .whitespacesAndNewlines)
        if !tail.isEmpty {
            sentences.append(tail)
        }

        return sentences
    }

    private static func fits(_ text: String, maxChars: Int, maxBytes: Int) -> Bool {
        text.count <= maxChars && text.utf8.count <= maxBytes
    }

    private static func splitLongText(_ text: String, maxChars: Int, maxBytes: Int) -> [String] {
        var chunks: [String] = []
        var current = ""

        for char in text {
            let candidate = current + String(char)
            if !current.isEmpty && !fits(candidate, maxChars: maxChars, maxBytes: maxBytes) {
                chunks.append(current.trimmingCharacters(in: .whitespacesAndNewlines))
                current = String(char)
            } else {
                current = candidate
            }
        }

        let tail = current.trimmingCharacters(in: .whitespacesAndNewlines)
        if !tail.isEmpty {
            chunks.append(tail)
        }

        return chunks.filter { !$0.isEmpty }
    }

    static func synthesize(config: TTSConfig, text: String) async throws -> Data {
        let body: [String: Any] = [
            "app": [
                "appid": config.appId,
                "token": "access_token",
                "cluster": config.cluster,
            ],
            "user": [
                "uid": config.uid,
            ],
            "audio": [
                "voice_type": config.voiceType,
                "encoding": config.encoding,
                "speed_ratio": toPositiveNumber(config.speedRatio, fallback: 1.5),
                "volume_ratio": toPositiveNumber(config.volumeRatio, fallback: 1),
                "pitch_ratio": toPositiveNumber(config.pitchRatio, fallback: 1),
            ],
            "request": [
                "reqid": UUID().uuidString,
                "text": text,
                "text_type": "plain",
                "operation": "query",
            ],
        ]

        let jsonData = try JSONSerialization.data(withJSONObject: body)

        guard let url = URL(string: config.endpoint) else {
            throw NSError(domain: "TTSVoice", code: 1, userInfo: [NSLocalizedDescriptionKey: "无效的 endpoint"])
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        // 与 Node 版一致：`Bearer;${token}`（分号）
        request.setValue("Bearer;\(config.bearerToken)", forHTTPHeaderField: "Authorization")
        request.httpBody = jsonData

        let (data, response) = try await URLSession.shared.data(for: request)
        let rawText = String(data: data, encoding: .utf8) ?? ""

        guard let http = response as? HTTPURLResponse else {
            throw NSError(domain: "TTSVoice", code: 2, userInfo: [NSLocalizedDescriptionKey: "无 HTTP 响应"])
        }

        guard let payload = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            let snippet = String(rawText.prefix(200))
            throw NSError(
                domain: "TTSVoice",
                code: 3,
                userInfo: [NSLocalizedDescriptionKey: "接口返回了非 JSON 内容，HTTP \(http.statusCode): \(snippet)"]
            )
        }

        guard http.statusCode == 200 else {
            let msg = (payload["message"] as? String) ?? (payload["Message"] as? String) ?? rawText
            throw NSError(domain: "TTSVoice", code: 4, userInfo: [NSLocalizedDescriptionKey: "HTTP \(http.statusCode): \(msg)"])
        }

        let code = payload["code"] as? Int
        if code != 3000 {
            let msg = (payload["message"] as? String) ?? (payload["Message"] as? String) ?? "unknown"
            throw NSError(
                domain: "TTSVoice",
                code: 5,
                userInfo: [NSLocalizedDescriptionKey: "TTS 返回失败 code=\(code.map(String.init) ?? "nil") message=\(msg)"]
            )
        }

        guard let dataField = payload["data"] as? String else {
            throw NSError(domain: "TTSVoice", code: 6, userInfo: [NSLocalizedDescriptionKey: "TTS 返回中缺少 data 字段"])
        }

        guard let audioData = Data(base64Encoded: dataField) else {
            throw NSError(domain: "TTSVoice", code: 7, userInfo: [NSLocalizedDescriptionKey: "无法解析 Base64 音频数据"])
        }

        return audioData
    }
}
