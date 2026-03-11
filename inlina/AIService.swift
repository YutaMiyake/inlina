import Foundation

// MARK: - AIServiceError

enum AIServiceError: LocalizedError {
    case missingAPIKey
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int, message: String)
    case decodingError(String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "API key is not configured. Please set your API key in Settings."
        case .invalidURL:
            return "The configured base URL is invalid."
        case .invalidResponse:
            return "Received an invalid response from the API."
        case .httpError(let statusCode, let message):
            return "API error (\(statusCode)): \(message)"
        case .decodingError(let detail):
            return "Failed to parse API response: \(detail)"
        }
    }
}

// MARK: - AIService

final class AIService {
    static let shared = AIService()

    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60
        config.timeoutIntervalForResource = 120
        self.session = URLSession(configuration: config)
    }

    // MARK: - Public API

    /// Process text with the given AI action using the currently configured provider.
    func process(text: String, action: AIAction) async throws -> String {
        let settings = SettingsStore.shared
        let apiKey = settings.apiKey.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !apiKey.isEmpty else {
            throw AIServiceError.missingAPIKey
        }

        let provider = settings.provider
        let baseURL = settings.effectiveBaseURL
        let model = settings.model

        switch provider {
        case .openai:
            return try await callOpenAI(
                text: text,
                systemPrompt: action.systemPrompt,
                apiKey: apiKey,
                baseURL: baseURL,
                model: model
            )
        case .anthropic:
            return try await callAnthropic(
                text: text,
                systemPrompt: action.systemPrompt,
                apiKey: apiKey,
                baseURL: baseURL,
                model: model
            )
        case .gemini:
            return try await callGemini(
                text: text,
                systemPrompt: action.systemPrompt,
                apiKey: apiKey,
                baseURL: baseURL,
                model: model
            )
        }
    }

    // MARK: - OpenAI

    private func callOpenAI(
        text: String,
        systemPrompt: String,
        apiKey: String,
        baseURL: String,
        model: String
    ) async throws -> String {
        let urlString = "\(baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/")))/chat/completions"
        guard let url = URL(string: urlString) else {
            throw AIServiceError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": text]
            ],
            "temperature": 0.3
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)
        try validateHTTPResponse(response, data: data)

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let first = choices.first,
              let message = first["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw AIServiceError.decodingError("Could not extract content from OpenAI response.")
        }

        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Anthropic

    private func callAnthropic(
        text: String,
        systemPrompt: String,
        apiKey: String,
        baseURL: String,
        model: String
    ) async throws -> String {
        let urlString = "\(baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/")))/messages"
        guard let url = URL(string: urlString) else {
            throw AIServiceError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        let body: [String: Any] = [
            "model": model,
            "max_tokens": 4096,
            "system": systemPrompt,
            "messages": [
                ["role": "user", "content": text]
            ]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)
        try validateHTTPResponse(response, data: data)

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = json["content"] as? [[String: Any]],
              let first = content.first,
              let resultText = first["text"] as? String else {
            throw AIServiceError.decodingError("Could not extract content from Anthropic response.")
        }

        return resultText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Gemini

    private func callGemini(
        text: String,
        systemPrompt: String,
        apiKey: String,
        baseURL: String,
        model: String
    ) async throws -> String {
        let base = baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let urlString = "\(base)/models/\(model):generateContent?key=\(apiKey)"
        guard let url = URL(string: urlString) else {
            throw AIServiceError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "system_instruction": [
                "parts": [
                    ["text": systemPrompt]
                ]
            ],
            "contents": [
                [
                    "parts": [
                        ["text": text]
                    ]
                ]
            ],
            "generationConfig": [
                "temperature": 0.3
            ]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)
        try validateHTTPResponse(response, data: data)

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let candidates = json["candidates"] as? [[String: Any]],
              let first = candidates.first,
              let contentObj = first["content"] as? [String: Any],
              let parts = contentObj["parts"] as? [[String: Any]],
              let firstPart = parts.first,
              let resultText = firstPart["text"] as? String else {
            throw AIServiceError.decodingError("Could not extract content from Gemini response.")
        }

        return resultText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Helpers

    private func validateHTTPResponse(_ response: URLResponse, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIServiceError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let message: String
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                if let error = json["error"] as? [String: Any],
                   let msg = error["message"] as? String {
                    message = msg
                } else if let errorMsg = json["error"] as? String {
                    message = errorMsg
                } else {
                    message = String(data: data, encoding: .utf8) ?? "Unknown error"
                }
            } else {
                message = String(data: data, encoding: .utf8) ?? "Unknown error"
            }
            throw AIServiceError.httpError(statusCode: httpResponse.statusCode, message: message)
        }
    }
}
