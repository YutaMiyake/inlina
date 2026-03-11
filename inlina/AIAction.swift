import Foundation

enum AIAction: Hashable, Identifiable {
    case fixGrammar
    case improve
    case expand
    case summarize
    case translate
    case simplify
    case custom(String)

    var id: String {
        switch self {
        case .fixGrammar: return "fixGrammar"
        case .improve: return "improve"
        case .expand: return "expand"
        case .summarize: return "summarize"
        case .translate: return "translate"
        case .simplify: return "simplify"
        case .custom(let prompt): return "custom_\(prompt.hashValue)"
        }
    }

    var displayName: String {
        switch self {
        case .fixGrammar: return "Fix Grammar"
        case .improve: return "Improve Writing"
        case .expand: return "Expand"
        case .summarize: return "Summarize"
        case .translate: return "Translate"
        case .simplify: return "Simplify"
        case .custom: return "Custom"
        }
    }

    var systemPrompt: String {
        switch self {
        case .fixGrammar:
            return "You are a grammar correction assistant. Fix any grammar, spelling, and punctuation errors in the provided text. Preserve the original meaning and tone. Return only the corrected text without explanations."
        case .improve:
            return "You are a writing improvement assistant. Enhance the clarity, flow, and overall quality of the provided text while preserving its meaning and intent. Return only the improved text without explanations."
        case .expand:
            return "You are a writing expansion assistant. Elaborate on the provided text by adding relevant details, examples, and depth while maintaining the original tone and intent. Return only the expanded text without explanations."
        case .summarize:
            return "You are a summarization assistant. Provide a concise summary of the provided text, capturing the key points and main ideas. Return only the summary without explanations."
        case .translate:
            return "You are a translation assistant. Translate the provided text into English. If the text is already in English, translate it into Japanese. Return only the translated text without explanations."
        case .simplify:
            return "You are a simplification assistant. Rewrite the provided text using simpler language and shorter sentences while preserving the core meaning. Return only the simplified text without explanations."
        case .custom(let prompt):
            return prompt
        }
    }

    var icon: String {
        switch self {
        case .fixGrammar: return "text.badge.checkmark"
        case .improve: return "wand.and.stars"
        case .expand: return "arrow.up.left.and.arrow.down.right"
        case .summarize: return "doc.plaintext"
        case .translate: return "globe"
        case .simplify: return "text.redaction"
        case .custom: return "sparkles"
        }
    }

    /// The built-in actions (excludes custom).
    static var builtIn: [AIAction] {
        [.fixGrammar, .improve, .expand, .summarize, .translate, .simplify]
    }
}
