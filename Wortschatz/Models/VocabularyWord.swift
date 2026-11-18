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
        case .masculineNoun: return Color(red: 0.14, green: 0.45, blue: 0.96) // Crisp Cobalt Blue
        case .feminineNoun: return Color(red: 0.91, green: 0.24, blue: 0.36)  // Vibrant Rose Red
        case .neuterNoun: return Color(red: 0.10, green: 0.66, blue: 0.44)    // Emerald Green
        case .verb: return Color(red: 0.53, green: 0.28, blue: 0.92)          // Deep Violet
        case .adjective: return Color(red: 0.92, green: 0.50, blue: 0.10)     // Warm Amber
        case .adverb: return Color(red: 0.08, green: 0.62, blue: 0.68)        // Teal Cyan
        case .phrase, .other: return Color.secondary
        }
    }
    
    /// Compact single-line badge label so rows never wrap or misalign
    public func compactTag(for rawType: String) -> String {
        switch self {
        case .masculineNoun: return "der"
        case .feminineNoun: return "die"
        case .neuterNoun: return "das"
        case .verb: return "Verb"
        case .adjective:
            return rawType.lowercased().contains("adv") ? "Adj/Adv" : "Adj."
        case .adverb: return "Adv."
        case .phrase: return "Ausdr."
        case .other:
            let trimmed = rawType.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.count > 7 ? String(trimmed.prefix(6)) + "." : trimmed
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

// MARK: - Higher-Level Part of Speech (for Quiz Distractor Matching)
public enum PartOfSpeech: String, Codable, CaseIterable {
    case noun = "Nomen"
    case verb = "Verb"
    case adjective = "Adjektiv"
    case other = "Sonstiges"
    
    public static func from(rawType: String) -> PartOfSpeech {
        let t = rawType.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if t.contains("verb") { return .verb }
        if t.contains("adj") || t.contains("adv") { return .adjective }
        if t == "der" || t == "die" || t == "das" || t.starts(with: "der") || t.starts(with: "die") || t.starts(with: "das") {
            return .noun
        }
        return .other
    }
}


// MARK: - Core Vocabulary Word Model
public struct VocabularyWord: Identifiable, Codable, Equatable, Hashable {
    public let id: UUID
    public var articleOrType: String
    public var word: String
    public var englishDefinition: String
    public var germanDefinition: String
    public var b1Example: String
    public var b2Example: String
    public var cefrLevel: String?
    
    // MARK: - Gamification & Spaced Repetition (Elo & Learn Score) State
    /// Baseline word rating (default 1200.0).
    public var elo: Double
    /// 0–100% Learn Score: < 75% is "Zu lernen / Im Training", >= 75% is "Gelernt"
    public var learnScore: Int
    public var reviewsCount: Int
    public var correctCount: Int
    public var incorrectCount: Int
    public var consecutiveCorrect: Int
    public var lastReviewedAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id, articleOrType, word, englishDefinition, germanDefinition, b1Example, b2Example, cefrLevel
        case elo, learnScore, reviewsCount, correctCount, incorrectCount, consecutiveCorrect, lastReviewedAt
    }
    
    public init(
        id: UUID = UUID(),
        articleOrType: String,
        word: String,
        englishDefinition: String,
        germanDefinition: String,
        b1Example: String,
        b2Example: String,
        cefrLevel: String? = nil,
        elo: Double = 1200.0,
        learnScore: Int = 0,
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
        self.cefrLevel = cefrLevel
        self.elo = elo
        self.learnScore = min(100, max(0, learnScore))
        self.reviewsCount = reviewsCount
        self.correctCount = correctCount
        self.incorrectCount = incorrectCount
        self.consecutiveCorrect = consecutiveCorrect
        self.lastReviewedAt = lastReviewedAt
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.articleOrType = try container.decode(String.self, forKey: .articleOrType)
        self.word = try container.decode(String.self, forKey: .word)
        self.englishDefinition = try container.decode(String.self, forKey: .englishDefinition)
        self.germanDefinition = try container.decode(String.self, forKey: .germanDefinition)
        self.b1Example = try container.decode(String.self, forKey: .b1Example)
        self.b2Example = try container.decode(String.self, forKey: .b2Example)
        self.cefrLevel = try container.decodeIfPresent(String.self, forKey: .cefrLevel)
        self.elo = (try? container.decode(Double.self, forKey: .elo)) ?? 1200.0
        self.reviewsCount = (try? container.decode(Int.self, forKey: .reviewsCount)) ?? 0
        self.correctCount = (try? container.decode(Int.self, forKey: .correctCount)) ?? 0
        self.incorrectCount = (try? container.decode(Int.self, forKey: .incorrectCount)) ?? 0
        self.consecutiveCorrect = (try? container.decode(Int.self, forKey: .consecutiveCorrect)) ?? 0
        self.lastReviewedAt = try container.decodeIfPresent(Date.self, forKey: .lastReviewedAt)
        
        if let decodedScore = try container.decodeIfPresent(Int.self, forKey: .learnScore) {
            self.learnScore = min(100, max(0, decodedScore))
        } else {
            // Migrate existing words smoothly from previous review counts
            let migrated = (self.correctCount * 25) - (self.incorrectCount * 18) + (self.consecutiveCorrect >= 2 ? 10 : 0)
            self.learnScore = min(100, max(0, migrated))
        }
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
    
    /// Compact grammatical tag guaranteed to fit in a fixed-width column
    public var compactCategoryTag: String {
        category.compactTag(for: articleOrType)
    }
    
    public var partOfSpeech: PartOfSpeech {
        PartOfSpeech.from(rawType: articleOrType)
    }
    
    // MARK: - Progressive Cloze & Learn Score Mechanics
    /// A word is considered "Gelernt" once its Learn Score reaches >= 75%
    public var isLearned: Bool {
        return learnScore >= 75
    }
    
    /// A word unlocks B2 testing mode once its Learn Score reaches >= 50%, or >= 2 consecutive correct
    public var isB2MasteryReached: Bool {
        return learnScore >= 50 || consecutiveCorrect >= 2 || (reviewsCount >= 3 && correctRate >= 0.75) || elo <= 1120.0
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
        if reviewsCount == 0 && learnScore == 0 { return "Neu" }
        if isLearned { return "Gelernt ✓" }
        if learnScore >= 40 { return "Im Training" }
        return "Unsicher"
    }
    
    public var learnScoreColor: Color {
        if reviewsCount == 0 && learnScore == 0 { return .gray }
        if isLearned { return .green }
        if learnScore >= 40 { return .blue }
        return .orange
    }
}
