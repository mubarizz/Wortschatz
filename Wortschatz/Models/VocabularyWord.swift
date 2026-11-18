import Foundation
import SwiftUI

// MARK: - Word Category & Gender Helper
public enum WordCategory: String, Codable, CaseIterable {
    case masculineNoun = "der"
    case feminineNoun = "die"
    case neuterNoun = "das"
    case verb = "Verb"
    case adjective = "Adjektiv"
    case adverb = "Adverb"
    case phrase = "Ausdruck"
    case other = "Sonstiges"
    
    public var badgeColor: Color {
        switch self {
        case .masculineNoun: return Color.blue
        case .feminineNoun: return Color.red
        case .neuterNoun: return Color.green
        case .verb: return Color.purple
        case .adjective: return Color.orange
        case .adverb: return Color.teal
        case .phrase, .other: return Color.gray
        }
    }
    
    public static func from(rawType: String) -> WordCategory {
        let trimmed = rawType.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if trimmed == "der" { return .masculineNoun }
        if trimmed == "die" { return .feminineNoun }
        if trimmed == "das" { return .neuterNoun }
        if trimmed.contains("verb") { return .verb }
        if trimmed.contains("adj") { return .adjective }
        if trimmed.contains("adv") { return .adverb }
        return .other
    }
}

// MARK: - Core Vocabulary Word Model
public struct VocabularyWord: Identifiable, Codable, Equatable, Hashable {
    public let id: UUID
    public let articleOrType: String
    public let word: String
    public let englishDefinition: String
    public let germanDefinition: String
    public let b1Example: String
    public let b2Example: String
    
    // MARK: - Gamification & Spaced Repetition (Elo) State
    /// Baseline word rating (default 1200.0).
    /// As user answers correctly, word Elo decreases (the word is "defeated" / mastered).
    /// If user fails, word Elo increases (the word is proven harder).
    public var elo: Double
    public var reviewsCount: Int
    public var correctCount: Int
    public var incorrectCount: Int
    public var consecutiveCorrect: Int
    public var lastReviewedAt: Date?
    
    public init(
        id: UUID = UUID(),
        articleOrType: String,
        word: String,
        englishDefinition: String,
        germanDefinition: String,
        b1Example: String,
        b2Example: String,
        elo: Double = 1200.0,
        reviewsCount: Int = 0,
        correctCount: Int = 0,
        incorrectCount: Int = 0,
        consecutiveCorrect: Int = 0,
        lastReviewedAt: Date? = nil
    ) {
        self.id = id
        self.articleOrType = articleOrType
        self.word = word
        self.englishDefinition = englishDefinition
        self.germanDefinition = germanDefinition
        self.b1Example = b1Example
        self.b2Example = b2Example
        self.elo = elo
        self.reviewsCount = reviewsCount
        self.correctCount = correctCount
        self.incorrectCount = incorrectCount
        self.consecutiveCorrect = consecutiveCorrect
        self.lastReviewedAt = lastReviewedAt
    }
    
    // MARK: - Cleaned Word Representation
    /// Strips redundant leading articles (e.g. converts "der Kasten" -> "Kasten" if article is already "der")
    public var cleanTargetWord: String {
        let trimmed = word.trimmingCharacters(in: .whitespacesAndNewlines)
        let prefixes = ["der ", "die ", "das ", "der/die ", "die/der "]
        for prefix in prefixes {
            if trimmed.lowercased().hasPrefix(prefix) {
                return String(trimmed.dropFirst(prefix.count))
            }
        }
        // Also strip optional preposition notes like "(aus + D)" for cloze target matching if needed
        return trimmed
    }
    
    /// Display title for cards, e.g. "der Kasten" or "versäumen"
    public var displayTitle: String {
        let clean = cleanTargetWord
        let cat = category
        if cat == .masculineNoun || cat == .feminineNoun || cat == .neuterNoun {
            return "\(articleOrType) \(clean)"
        }
        return word
    }
    
    public var category: WordCategory {
        WordCategory.from(rawType: articleOrType)
    }
    
    // MARK: - Progressive Cloze Deletion Mechanics
    /// A word unlocks B2 testing mode once the user has answered it correctly at least twice in a row
    /// or when its difficulty elo has dropped to <= 1150 (demonstrated mastery).
    public var isB2MasteryReached: Bool {
        return consecutiveCorrect >= 2 || (reviewsCount >= 3 && correctRate >= 0.75) || elo <= 1120.0
    }
    
    public var activeExample: String {
        return isB2MasteryReached ? b2Example : b1Example
    }
    
    public var activeExampleLevelTag: String {
        return isB2MasteryReached ? "B2" : "B1"
    }
    
    public var correctRate: Double {
        guard reviewsCount > 0 else { return 0.0 }
        return Double(correctCount) / Double(reviewsCount)
    }
    
    public var masteryLabel: String {
        if reviewsCount == 0 { return "Neu" }
        if isB2MasteryReached { return "B2 Gemeistert" }
        if consecutiveCorrect >= 1 { return "B1 Festigung" }
        return "Im Training"
    }
}
