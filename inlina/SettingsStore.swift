import Foundation
import SwiftUI

// MARK: - AIProvider

enum AIProvider: String, CaseIterable, Codable, Identifiable {
    case openai
    case anthropic
    case gemini

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .openai: return "OpenAI"
        case .anthropic: return "Anthropic"
        case .gemini: return "Google Gemini"
        }
    }

    var defaultBaseURL: String {
        switch self {
        case .openai: return "https://api.openai.com/v1"
        case .anthropic: return "https://api.anthropic.com/v1"
        case .gemini: return "https://generativelanguage.googleapis.com/v1beta"
        }
    }

    var defaultModel: String {
        switch self {
        case .openai: return "gpt-4o"
        case .anthropic: return "claude-sonnet-4-20250514"
        case .gemini: return "gemini-pro"
        }
    }
}

// MARK: - CustomPrompt

struct CustomPrompt: Codable, Identifiable, Hashable {
    var id: UUID
    var name: String
    var prompt: String

    init(id: UUID = UUID(), name: String, prompt: String) {
        self.id = id
        self.name = name
        self.prompt = prompt
    }
}

// MARK: - SettingsStore

final class SettingsStore: ObservableObject {
    static let shared = SettingsStore()

    private let defaults = UserDefaults.standard

    private enum Keys {
        static let apiKey = "inlina_apiKey"
        static let provider = "inlina_provider"
        static let baseURL = "inlina_baseURL"
        static let model = "inlina_model"
        static let customPrompts = "inlina_customPrompts"
    }

    // MARK: - Published Properties

    @Published var apiKey: String {
        didSet { defaults.set(apiKey, forKey: Keys.apiKey) }
    }

    @Published var provider: AIProvider {
        didSet {
            defaults.set(provider.rawValue, forKey: Keys.provider)
            // Reset model to provider default when switching providers
            if model.isEmpty || oldValue != provider {
                model = provider.defaultModel
            }
        }
    }

    @Published var baseURL: String {
        didSet { defaults.set(baseURL, forKey: Keys.baseURL) }
    }

    @Published var model: String {
        didSet { defaults.set(model, forKey: Keys.model) }
    }

    @Published var customPrompts: [CustomPrompt] {
        didSet {
            if let data = try? JSONEncoder().encode(customPrompts) {
                defaults.set(data, forKey: Keys.customPrompts)
            }
        }
    }

    // MARK: - Computed Properties

    /// Returns the user-configured base URL if non-empty, otherwise the provider's default.
    var effectiveBaseURL: String {
        let trimmed = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? provider.defaultBaseURL : trimmed
    }

    // MARK: - Init

    private init() {
        self.apiKey = defaults.string(forKey: Keys.apiKey) ?? ""

        if let rawProvider = defaults.string(forKey: Keys.provider),
           let stored = AIProvider(rawValue: rawProvider) {
            self.provider = stored
        } else {
            self.provider = .openai
        }

        self.baseURL = defaults.string(forKey: Keys.baseURL) ?? ""

        if let data = defaults.data(forKey: Keys.customPrompts),
           let decoded = try? JSONDecoder().decode([CustomPrompt].self, from: data) {
            self.customPrompts = decoded
        } else {
            self.customPrompts = []
        }

        let storedModel = defaults.string(forKey: Keys.model) ?? ""
        if storedModel.isEmpty {
            let currentProvider: AIProvider
            if let rawProvider = defaults.string(forKey: Keys.provider),
               let stored = AIProvider(rawValue: rawProvider) {
                currentProvider = stored
            } else {
                currentProvider = .openai
            }
            self.model = currentProvider.defaultModel
        } else {
            self.model = storedModel
        }
    }
}
