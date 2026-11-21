import Foundation

// MARK: - Grammatical Case Enum
public enum PrepositionCase: String, Codable, CaseIterable, Equatable {
    case akkusativ = "Akk"
    case dativ = "Dat"
    case genitiv = "Gen"
    
    public var fullName: String {
        switch self {
        case .akkusativ: return "Akkusativ"
        case .dativ: return "Dativ"
        case .genitiv: return "Genitiv"
        }
    }
    
    public var questionWord: String {
        switch self {
        case .akkusativ: return "Wen / Was?"
        case .dativ: return "Wem?"
        case .genitiv: return "Wessen?"
        }
    }
}

// MARK: - Preposition Entry Model
public struct PrepositionEntry: Identifiable, Codable, Equatable {
    public let id: String
    public let verb: String
    public let preposition: String
    public let targetCase: PrepositionCase
    public let cefrLevel: String // "B1", "B2", "C1"
    public let englishTranslation: String
    public let sentencePrefix: String
    public let targetPhrase: String // e.g. "auf teure Urlaubsreisen"
    public let sentenceSuffix: String
    public let fullSentence: String
    public let ruleExplanation: String
    public let distractorOptions: [String]
    
    public var correctCombination: String {
        "\(preposition) + \(targetCase.rawValue)."
    }
    
    public init(
        id: String,
        verb: String,
        preposition: String,
        targetCase: PrepositionCase,
        cefrLevel: String,
        englishTranslation: String,
        sentencePrefix: String,
        targetPhrase: String,
        sentenceSuffix: String,
        ruleExplanation: String,
        distractorOptions: [String] = []
    ) {
        self.id = id
        self.verb = verb
        self.preposition = preposition
        self.targetCase = targetCase
        self.cefrLevel = cefrLevel
        self.englishTranslation = englishTranslation
        self.sentencePrefix = sentencePrefix
        self.targetPhrase = targetPhrase
        self.sentenceSuffix = sentenceSuffix
        self.fullSentence = "\(sentencePrefix) \(targetPhrase) \(sentenceSuffix)"
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespaces)
        self.ruleExplanation = ruleExplanation
        self.distractorOptions = distractorOptions
    }
}

// MARK: - Sprint Question Model
public struct PrepositionQuestion: Identifiable, Equatable {
    public let id = UUID()
    public let entry: PrepositionEntry
    public let options: [String]
    public let correctIndex: Int
    
    public var correctOption: String {
        options[correctIndex]
    }
}

// MARK: - Sprint Session Result
public struct PrepositionSessionResult: Identifiable, Equatable {
    public let id = UUID()
    public let totalQuestions: Int
    public let correctCount: Int
    public let streakMax: Int
    public let pointsEarned: Int
    public let missedEntries: [PrepositionEntry]
    public let durationSeconds: Int
    public let modeTitle: String
    
    public var accuracyPercentage: Int {
        guard totalQuestions > 0 else { return 0 }
        return Int(round(Double(correctCount) / Double(totalQuestions) * 100.0))
    }
}
