import Foundation

// MARK: - Cloze Masking & Answer Validation Engine
public struct ClozeMaskedSentence {
    public let originalSentence: String
    public let prefix: String
    public let maskedWord: String
    public let suffix: String
    public let isMasked: Bool
    
    public var displayMasked: String {
        return "\(prefix) [ ______ ] \(suffix)"
    }
}

public enum ClozeSentenceEngine {
    
    /// Finds and masks the target word (or its inflected forms) in the example sentence
    public static func mask(sentence: String, targetWord: VocabularyWord) -> ClozeMaskedSentence {
        let cleanWord = targetWord.cleanTargetWord
        
        // Clean out extra parentheses notes like "(aus + D)" or "(verb)"
        let baseKeyword = cleanWord
            .replacingOccurrences(of: #"\s*\(.*?\)"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Build regex to match the base word, plural, adjective endings, or common past participles
        // e.g. "Entscheidung" matches "Entscheidung", "Entscheidungen"
        // "fällig" matches "fällige", "fälliger", "fälligen"
        // "Beleg" matches "Beleg", "Belege", "Belegen"
        let escapedBase = NSRegularExpression.escapedPattern(for: baseKeyword)
        let pattern = #"\b"# + escapedBase + #"(?:en|e|es|er|em|s|te|ten|t)?\b"#
        
        if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
           let match = regex.firstMatch(in: sentence, options: [], range: NSRange(location: 0, length: sentence.utf16.count)) {
            
            if let sentenceRange = Range(match.range, in: sentence) {
                let prefix = String(sentence[..<sentenceRange.lowerBound]).trimmingCharacters(in: .whitespaces)
                let masked = String(sentence[sentenceRange])
                let suffix = String(sentence[sentenceRange.upperBound...]).trimmingCharacters(in: .whitespaces)
                
                return ClozeMaskedSentence(
                    originalSentence: sentence,
                    prefix: prefix,
                    maskedWord: masked,
                    suffix: suffix,
                    isMasked: true
                )
            }
        }
        
        // Fallback: If sentence uses an irregular verb form (e.g. betrogen instead of betrügen)
        // or separable prefix (anfallen -> fallen... an), try token-based matching or fallback blank
        let wordsInSentence = sentence.components(separatedBy: " ")
        if let lastWord = wordsInSentence.first(where: { $0.lowercased().contains(baseKeyword.lowercased().prefix(4)) }) {
            let parts = sentence.components(separatedBy: lastWord)
            if parts.count >= 2 {
                return ClozeMaskedSentence(
                    originalSentence: sentence,
                    prefix: parts[0].trimmingCharacters(in: .whitespaces),
                    maskedWord: lastWord,
                    suffix: parts.dropFirst().joined(separator: lastWord).trimmingCharacters(in: .whitespaces),
                    isMasked: true
                )
            }
        }
        
        // Default clean fallback
        return ClozeMaskedSentence(
            originalSentence: sentence,
            prefix: sentence,
            maskedWord: cleanWord,
            suffix: "",
            isMasked: false
        )
    }
    
    /// Validates learner answer against expected target word and masked token.
    /// Leniently accepts:
    /// - The exact inflected word found in the sentence (e.g. "Belege")
    /// - The dictionary lemma / root word (e.g. "Beleg" or "der Beleg")
    /// - Ignores leading articles if typed by user ("der", "die", "das")
    /// - Case-insensitive with whitespace trimming
    public static func validate(input: String, target: VocabularyWord, maskedToken: String) -> Bool {
        let cleanInput = sanitize(input)
        let cleanRoot = sanitize(target.cleanTargetWord)
        let cleanMasked = sanitize(maskedToken)
        
        // Exact root or masked token match
        if cleanInput == cleanRoot || cleanInput == cleanMasked {
            return true
        }
        
        // Match with article prefix stripped
        let strippedInput = stripArticles(cleanInput)
        let strippedRoot = stripArticles(cleanRoot)
        let strippedMasked = stripArticles(cleanMasked)
        
        if strippedInput == strippedRoot || strippedInput == strippedMasked {
            return true
        }
        
        // Stem match (>= 5 letters matching root)
        if strippedRoot.count >= 5 && strippedInput.hasPrefix(String(strippedRoot.prefix(strippedRoot.count - 1))) {
            return true
        }
        
        return false
    }
    
    private static func sanitize(_ text: String) -> String {
        return text
            .replacingOccurrences(of: #"[.,;:!?\"'„“]"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }
    
    private static func stripArticles(_ text: String) -> String {
        for prefix in ["der ", "die ", "das "] {
            if text.hasPrefix(prefix) {
                return String(text.dropFirst(prefix.count))
            }
        }
        return text
    }
}
