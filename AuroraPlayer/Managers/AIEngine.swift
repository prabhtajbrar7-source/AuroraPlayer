//
//  AIEngine.swift
//  AuroraPlayer
//
//  "AI playlists" has two honest tiers:
//
//  1. On-device (default, works offline, no API key): a heuristic mix engine
//     that scores your own library against a mood/energy target derived from
//     the prompt's keywords, play history, and skip history. This always works.
//
//  2. Remote (opt-in, requires the user's own API key in Settings): sends your
//     library's *metadata only* (titles/artists/genres — never audio files) to
//     Anthropic or OpenAI and asks for a themed playlist selection + a short
//     description. You must supply your own key; AuroraPlayer never ships one.
//
//  Both paths return the same `AIPlaylistResult`, so the UI doesn't care which
//  one ran.
//

import Foundation

struct AIPlaylistResult {
    let title: String
    let description: String
    let songIDs: [UUID]
}

enum AIEngineError: LocalizedError {
    case emptyLibrary
    case missingAPIKey
    case networkError(String)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .emptyLibrary: return "Import some songs first — there's nothing to build a playlist from yet."
        case .missingAPIKey: return "Add an API key in Settings → AI, or switch to On-Device mode."
        case .networkError(let message): return "Network error: \(message)"
        case .invalidResponse: return "The AI response couldn't be parsed. Try again."
        }
    }
}

@MainActor
final class AIEngine {
    static let shared = AIEngine()
    private init() {}

    private let library = LibraryManager.shared

    func generatePlaylist(prompt: String, settings: AppSettings) async throws -> AIPlaylistResult {
        guard !library.songs.isEmpty else { throw AIEngineError.emptyLibrary }

        switch settings.aiProvider {
        case .onDeviceOnly:
            return generateOnDevice(prompt: prompt)
        case .anthropic:
            return try await generateRemote(prompt: prompt, provider: .anthropic, apiKey: settings.aiAPIKey)
        case .openAI:
            return try await generateRemote(prompt: prompt, provider: .openAI, apiKey: settings.aiAPIKey)
        }
    }

    /// Builds the "smart queue" — reorders the current library toward whatever
    /// energy level matches the time of day and the user's recent listening,
    /// the way Apple Music's autoplay / Spotify Radio try to.
    func generateSmartQueue(seed: Song?) -> [Song] {
        let all = library.songs
        guard !all.isEmpty else { return [] }

        let targetEnergy = seed?.estimatedEnergy ?? defaultEnergyForTimeOfDay()
        let scored = all.map { song -> (Song, Double) in
            var score = 1.0 - abs(song.estimatedEnergy - targetEnergy)
            score += Double(song.playCount) * 0.05
            score -= Double(song.skipCount) * 0.08
            if song.genre == seed?.genre { score += 0.15 }
            return (song, score)
        }
        return scored.sorted { $0.1 > $1.1 }.map(\.0)
    }

    // MARK: On-device heuristic

    private func generateOnDevice(prompt: String) -> AIPlaylistResult {
        let lowered = prompt.lowercased()
        let targetEnergy: Double
        if ["workout", "gym", "run", "hype", "party", "pump"].contains(where: lowered.contains) {
            targetEnergy = 0.85
        } else if ["chill", "study", "focus", "sleep", "calm", "relax", "rain"].contains(where: lowered.contains) {
            targetEnergy = 0.2
        } else {
            targetEnergy = 0.5
        }

        let genreHint = library.songs
            .map(\.genre)
            .first { lowered.contains($0.lowercased()) }

        let scored = library.songs.map { song -> (Song, Double) in
            var score = 1.0 - abs(song.estimatedEnergy - targetEnergy)
            if let genreHint, song.genre == genreHint { score += 0.3 }
            score += Double(song.playCount) * 0.03
            return (song, score)
        }

        let selected = scored.sorted { $0.1 > $1.1 }.prefix(25).map(\.0.id)

        return AIPlaylistResult(
            title: prompt.isEmpty ? "Smart Mix" : prompt.capitalized,
            description: "Built on-device from \(library.songs.count) songs in your library, matched to the mood of “\(prompt)”.",
            songIDs: Array(selected)
        )
    }

    private func defaultEnergyForTimeOfDay() -> Double {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 6..<10: return 0.45   // morning: moderate
        case 10..<17: return 0.6   // day: upbeat
        case 17..<21: return 0.7   // evening: energetic
        default: return 0.25       // night: wind down
        }
    }

    // MARK: Remote LLM (optional, user-supplied key)

    private enum Provider { case anthropic, openAI }

    private func generateRemote(prompt: String, provider: Provider, apiKey: String) async throws -> AIPlaylistResult {
        guard !apiKey.isEmpty else { throw AIEngineError.missingAPIKey }

        // Only metadata leaves the device — never audio, never file paths.
        let catalogSummary = library.songs.prefix(300).map {
            "\($0.id.uuidString)|\($0.title)|\($0.artist)|\($0.genre)"
        }.joined(separator: "\n")

        let instructions = """
        You are curating a playlist from the user's own music library.
        Library rows are formatted as id|title|artist|genre.
        User request: "\(prompt)"

        Reply with ONLY minified JSON, no prose, no markdown fences, matching:
        {"title": string, "description": string, "ids": [string, ...]}
        Choose at most 25 ids that exist in the library rows above.
        """

        let requestBody: Data
        let url: URL
        var request: URLRequest

        switch provider {
        case .anthropic:
            url = URL(string: "https://api.anthropic.com/v1/messages")!
            request = URLRequest(url: url)
            request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
            request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            let payload: [String: Any] = [
                "model": "claude-sonnet-5",
                "max_tokens": 1024,
                "messages": [["role": "user", "content": instructions + "\n\n" + catalogSummary]]
            ]
            requestBody = try JSONSerialization.data(withJSONObject: payload)
        case .openAI:
            url = URL(string: "https://api.openai.com/v1/chat/completions")!
            request = URLRequest(url: url)
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            let payload: [String: Any] = [
                "model": "gpt-4o-mini",
                "messages": [["role": "user", "content": instructions + "\n\n" + catalogSummary]]
            ]
            requestBody = try JSONSerialization.data(withJSONObject: payload)
        }

        request.httpMethod = "POST"
        request.httpBody = requestBody

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "unknown error"
            throw AIEngineError.networkError(message)
        }

        let text = try extractText(from: data, provider: provider)
        return try parseResult(from: text, fallbackTitle: prompt)
    }

    private func extractText(from data: Data, provider: Provider) throws -> String {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw AIEngineError.invalidResponse
        }
        switch provider {
        case .anthropic:
            guard let content = json["content"] as? [[String: Any]],
                  let first = content.first,
                  let text = first["text"] as? String else { throw AIEngineError.invalidResponse }
            return text
        case .openAI:
            guard let choices = json["choices"] as? [[String: Any]],
                  let message = choices.first?["message"] as? [String: Any],
                  let text = message["content"] as? String else { throw AIEngineError.invalidResponse }
            return text
        }
    }

    private func parseResult(from text: String, fallbackTitle: String) throws -> AIPlaylistResult {
        let cleaned = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")

        guard let data = cleaned.data(using: .utf8),
              let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let ids = json["ids"] as? [String] else {
            throw AIEngineError.invalidResponse
        }

        let title = (json["title"] as? String) ?? fallbackTitle.capitalized
        let description = (json["description"] as? String) ?? "AI-curated playlist."
        let uuids = ids.compactMap { UUID(uuidString: $0) }

        return AIPlaylistResult(title: title, description: description, songIDs: uuids)
    }
}
