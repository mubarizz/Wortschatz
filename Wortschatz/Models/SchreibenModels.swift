import Foundation

// MARK: - Exam Level (B1 / B2)
public enum SchreibenExamLevel: String, Codable, CaseIterable, Identifiable {
    case b1 = "B1"
    case b2 = "B2"
    
    public var id: String { rawValue }
    
    public var title: String {
        switch self {
        case .b1: return "Goethe-Zertifikat B1"
        case .b2: return "Goethe-Zertifikat B2"
        }
    }
    
    public var subtitle: String {
        switch self {
        case .b1: return "3 Teile • E-Mail, Forumsbeitrag & Kurzmitteilung"
        case .b2: return "2 Teile • Gesellschaftlicher Forumsbeitrag & Formelle Nachricht"
        }
    }
}

// MARK: - Exam Teil (Goethe B1 Teil 1-3 & B2 Teil 1-2)
public enum SchreibenExamTeil: String, Codable, CaseIterable, Identifiable {
    case b1Teil1 = "B1_TEIL_1"
    case b1Teil2 = "B1_TEIL_2"
    case b1Teil3 = "B1_TEIL_3"
    case b2Teil1 = "B2_TEIL_1"
    case b2Teil2 = "B2_TEIL_2"
    
    public var id: String { rawValue }
    
    public var level: SchreibenExamLevel {
        switch self {
        case .b1Teil1, .b1Teil2, .b1Teil3:
            return .b1
        case .b2Teil1, .b2Teil2:
            return .b2
        }
    }
    
    public var shortTitle: String {
        switch self {
        case .b1Teil1: return "Teil 1"
        case .b1Teil2: return "Teil 2"
        case .b1Teil3: return "Teil 3"
        case .b2Teil1: return "Teil 1"
        case .b2Teil2: return "Teil 2"
        }
    }
    
    public var fullTitle: String {
        switch self {
        case .b1Teil1: return "B1 • Teil 1: Persönliche E-Mail"
        case .b1Teil2: return "B1 • Teil 2: Diskussionsbeitrag (Forum)"
        case .b1Teil3: return "B1 • Teil 3: Formelle Kurzmitteilung"
        case .b2Teil1: return "B2 • Teil 1: Forumsbeitrag (Meinung & Argumentation)"
        case .b2Teil2: return "B2 • Teil 2: Formelle Nachricht (Beruf & Alltag)"
        }
    }
    
    public var categoryDescription: String {
        switch self {
        case .b1Teil1:
            return "Informelle Nachricht an Freunde/Bekannte: Ereignis beschreiben, begründen und Vorschlag machen."
        case .b1Teil2:
            return "Meinungsäußerung in einem Online-Forum zu einem Alltagsthema mit eigener Erfahrung."
        case .b1Teil3:
            return "Kurze formelle E-Mail (Sie-Form): Absage, Entschuldigung oder höfliche Bitte."
        case .b2Teil1:
            return "Strukturierte Stellungnahme zu einem gesellschaftlichen Thema mit Gründen, Vor-/Nachteilen und Alternativen."
        case .b2Teil2:
            return "Formelle Korrespondenz im Berufs- oder Studienkontext mit Konjunktiv II und gehobenen Konnektoren."
        }
    }
    
    public var defaultTargetWords: Int {
        switch self {
        case .b1Teil1: return 80
        case .b1Teil2: return 80
        case .b1Teil3: return 40
        case .b2Teil1: return 150
        case .b2Teil2: return 100
        }
    }
    
    public var defaultTimeMinutes: Int {
        switch self {
        case .b1Teil1: return 20
        case .b1Teil2: return 25
        case .b1Teil3: return 15
        case .b2Teil1: return 50
        case .b2Teil2: return 25
        }
    }
    
    public var defaultRegisterHint: String {
        switch self {
        case .b1Teil1: return "Informell (Du-Form) • Persönliche Anrede & Grußformel"
        case .b1Teil2: return "Semi-formell (Forum) • Eigene Meinung & Begründung"
        case .b1Teil3: return "Formell (Sie-Form) • Höfliche Anrede, Entschuldigung & Gruß"
        case .b2Teil1: return "Sachlich-argumentativ • Konnektoren & Nomen-Verb-Verbindungen"
        case .b2Teil2: return "Formell (Sie-Form) • Höflicher Konjunktiv II & präziser Stil"
        }
    }
    
    public var leitpunkteCount: Int {
        switch self {
        case .b1Teil1, .b1Teil2, .b1Teil3: return 3
        case .b2Teil1, .b2Teil2: return 4
        }
    }
    
    public var iconName: String {
        switch self {
        case .b1Teil1: return "envelope.open.fill"
        case .b1Teil2: return "bubble.left.and.bubble.right.fill"
        case .b1Teil3: return "doc.text.fill"
        case .b2Teil1: return "newspaper.fill"
        case .b2Teil2: return "briefcase.fill"
        }
    }
    
    public static func teile(for level: SchreibenExamLevel) -> [SchreibenExamTeil] {
        allCases.filter { $0.level == level }
    }
}

// MARK: - Exam Prompt / Task
public struct SchreibenTask: Identifiable, Codable, Equatable, Hashable {
    public var id: String
    public var level: SchreibenExamLevel
    public var teil: SchreibenExamTeil
    public var title: String
    public var situation: String
    public var leitpunkte: [String]
    public var targetWords: Int
    public var registerHint: String
    public var recommendedTimeMinutes: Int
    public var isAIGenerated: Bool
    public var createdAt: Date
    
    public init(
        id: String = UUID().uuidString,
        level: SchreibenExamLevel,
        teil: SchreibenExamTeil,
        title: String,
        situation: String,
        leitpunkte: [String],
        targetWords: Int? = nil,
        registerHint: String? = nil,
        recommendedTimeMinutes: Int? = nil,
        isAIGenerated: Bool = false,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.level = level
        self.teil = teil
        self.title = title
        self.situation = situation
        self.leitpunkte = leitpunkte
        self.targetWords = targetWords ?? teil.defaultTargetWords
        self.registerHint = registerHint ?? teil.defaultRegisterHint
        self.recommendedTimeMinutes = recommendedTimeMinutes ?? teil.defaultTimeMinutes
        self.isAIGenerated = isAIGenerated
        self.createdAt = createdAt
    }
}

// MARK: - Goethe Examiner Evaluation Models
public struct SchreibenLeitpunktEvaluation: Identifiable, Codable, Equatable {
    public var id: UUID
    public var leitpunkt: String
    /// "erfuellt", "teilweise", or "fehlt"
    public var status: String
    public var comment: String
    
    enum CodingKeys: String, CodingKey {
        case leitpunkt
        case status
        case comment
    }
    
    public init(
        id: UUID = UUID(),
        leitpunkt: String,
        status: String,
        comment: String
    ) {
        self.id = id
        self.leitpunkt = leitpunkt
        self.status = status
        self.comment = comment
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = UUID()
        self.leitpunkt = (try? container.decode(String.self, forKey: .leitpunkt)) ?? ""
        self.status = (try? container.decode(String.self, forKey: .status)) ?? "teilweise"
        self.comment = (try? container.decode(String.self, forKey: .comment)) ?? ""
    }
}

public struct SchreibenSentenceCorrection: Identifiable, Codable, Equatable {
    public var id: UUID
    public var originalSentence: String
    public var correctedSentence: String
    public var category: String
    public var explanation: String
    
    enum CodingKeys: String, CodingKey {
        case originalSentence
        case correctedSentence
        case category
        case explanation
    }
    
    public init(
        id: UUID = UUID(),
        originalSentence: String,
        correctedSentence: String,
        category: String,
        explanation: String
    ) {
        self.id = id
        self.originalSentence = originalSentence
        self.correctedSentence = correctedSentence
        self.category = category
        self.explanation = explanation
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = UUID()
        self.originalSentence = (try? container.decode(String.self, forKey: .originalSentence)) ?? ""
        self.correctedSentence = (try? container.decode(String.self, forKey: .correctedSentence)) ?? ""
        self.category = (try? container.decode(String.self, forKey: .category)) ?? "Grammatik"
        self.explanation = (try? container.decode(String.self, forKey: .explanation)) ?? ""
    }
}

public struct SchreibenEvaluationResult: Codable, Equatable {
    /// 0 - 25: Erfüllung der Aufgabenstellung (Inhalt, Leitpunkte, Textlänge, Register)
    public var erfuellungScore: Int
    /// 0 - 25: Kohärenz & Textaufbau (Gliederung, Konnektoren, roter Faden)
    public var kohaerenzScore: Int
    /// 0 - 25: Wortschatz & Ausdruck (Spektrum, Präzision, Kollokationen)
    public var wortschatzScore: Int
    /// 0 - 25: Strukturen, Grammatik & Orthografie (Satzbau, Kasus, Rechtschreibung)
    public var strukturenScore: Int
    
    public var estimatedLevel: String
    public var examinerSummary: String
    public var leitpunkteCheck: [SchreibenLeitpunktEvaluation]
    public var corrections: [SchreibenSentenceCorrection]
    public var improvedModelText: String
    public var recommendedRedemittel: [String]
    
    public var totalScore: Int {
        min(100, max(0, erfuellungScore + kohaerenzScore + wortschatzScore + strukturenScore))
    }
    
    /// Goethe-Institut passing threshold is 60 / 100 points (60%)
    public var passed: Bool {
        totalScore >= 60
    }
    
    public var gradeLabel: String {
        switch totalScore {
        case 90...100: return "Sehr gut"
        case 80..<90:  return "Gut"
        case 70..<80:  return "Befriedigend"
        case 60..<70:  return "Ausreichend (Bestanden)"
        default:       return "Nicht bestanden (< 60 Pkt.)"
        }
    }
    
    public init(
        erfuellungScore: Int,
        kohaerenzScore: Int,
        wortschatzScore: Int,
        strukturenScore: Int,
        estimatedLevel: String,
        examinerSummary: String,
        leitpunkteCheck: [SchreibenLeitpunktEvaluation],
        corrections: [SchreibenSentenceCorrection],
        improvedModelText: String,
        recommendedRedemittel: [String]
    ) {
        self.erfuellungScore = min(25, max(0, erfuellungScore))
        self.kohaerenzScore = min(25, max(0, kohaerenzScore))
        self.wortschatzScore = min(25, max(0, wortschatzScore))
        self.strukturenScore = min(25, max(0, strukturenScore))
        self.estimatedLevel = estimatedLevel
        self.examinerSummary = examinerSummary
        self.leitpunkteCheck = leitpunkteCheck
        self.corrections = corrections
        self.improvedModelText = improvedModelText
        self.recommendedRedemittel = recommendedRedemittel
    }
}

// MARK: - Submission & Offline Queue Models
public enum SchreibenSubmissionStatus: String, Codable {
    case pendingOfflineEvaluation = "PENDING_OFFLINE"
    case evaluated = "EVALUATED"
}

public struct SchreibenSubmission: Identifiable, Codable, Equatable {
    public var id: UUID
    public var task: SchreibenTask
    public var userText: String
    public var wordCount: Int
    public var submittedAt: Date
    public var durationSeconds: Int
    public var status: SchreibenSubmissionStatus
    public var evaluation: SchreibenEvaluationResult?
    public var evaluatedModel: String?
    public var eloDelta: Double?
    public var newUserElo: Double?
    public var timeBonusAwarded: Bool?
    
    public init(
        id: UUID = UUID(),
        task: SchreibenTask,
        userText: String,
        wordCount: Int,
        submittedAt: Date = Date(),
        durationSeconds: Int = 0,
        status: SchreibenSubmissionStatus,
        evaluation: SchreibenEvaluationResult? = nil,
        evaluatedModel: String? = nil,
        eloDelta: Double? = nil,
        newUserElo: Double? = nil,
        timeBonusAwarded: Bool? = nil
    ) {
        self.id = id
        self.task = task
        self.userText = userText
        self.wordCount = wordCount
        self.submittedAt = submittedAt
        self.durationSeconds = durationSeconds
        self.status = status
        self.evaluation = evaluation
        self.evaluatedModel = evaluatedModel
        self.eloDelta = eloDelta
        self.newUserElo = newUserElo
        self.timeBonusAwarded = timeBonusAwarded
    }
    
    public var formattedDuration: String {
        let mins = durationSeconds / 60
        let secs = durationSeconds % 60
        return String(format: "%02d:%02d", mins, secs)
    }
    
    public var finishedWithinTimeLimit: Bool {
        durationSeconds <= task.recommendedTimeMinutes * 60
    }
}

// MARK: - Schreiben Elo Rating Algorithm
public enum SchreibenEloCalculator {
    /// Calculates the Elo rating change for completing a Goethe B1 or B2 Schreiben exam.
    /// - Passing (>= 60/100): +15 to +48 Elo for B1, +22 to +62 Elo for B2, scaled by score and Teil length.
    /// - Time Limit Bonus: +4 Elo if passed and completed within the official recommended Goethe time.
    /// - Below 60/100: -4 to -10 Elo depending on score.
    public static func calculateEloDelta(
        task: SchreibenTask,
        evaluation: SchreibenEvaluationResult,
        durationSeconds: Int
    ) -> (delta: Double, timeBonus: Bool) {
        let score = evaluation.totalScore
        let isB2 = (task.level == .b2)
        let withinTime = durationSeconds > 0 && durationSeconds <= (task.recommendedTimeMinutes * 60)
        
        if score >= 60 {
            // Base Elo for passing at 60 points
            let basePass: Double = isB2 ? 22.0 : 15.0
            // Extra Elo per point above 60 (0 to 40 extra points)
            let perPointFactor: Double = isB2 ? 0.90 : 0.72
            let scoreBonus = Double(score - 60) * perPointFactor
            let timeBonus: Double = withinTime ? 4.0 : 0.0
            let totalDelta = (basePass + scoreBonus + timeBonus).rounded()
            return (totalDelta, withinTime)
        } else if score >= 45 {
            // Close to passing (45-59 Pkt.)
            return (-4.0, false)
        } else {
            // Significantly below passing (< 45 Pkt.)
            return (-8.0, false)
        }
    }
}

// MARK: - Analytics & Weak-Point Models
public struct SchreibenTeilStatistics: Identifiable, Equatable {
    public let teil: SchreibenExamTeil
    public let attemptCount: Int
    public let averageScore: Int
    public let bestScore: Int
    public let passCount: Int
    public let avgErfuellung: Double
    public let avgKohaerenz: Double
    public let avgWortschatz: Double
    public let avgStrukturen: Double
    
    public var id: String { teil.id }
    
    public var passRatePercentage: Int {
        guard attemptCount > 0 else { return 0 }
        return Int((Double(passCount) / Double(attemptCount) * 100.0).rounded())
    }
}

public struct SchreibenCriterionWeakness: Identifiable, Equatable {
    public let id: String
    public let title: String
    public let averageOutOf25: Double
    public let advice: String
}

// MARK: - Verbatim Official Goethe-Institut & telc/ALTE Leistungsbeispiele (100% Offline, Non-AI)
public struct OfficialGoetheSample: Identifiable, Codable, Equatable {
    public let id: String
    public let level: SchreibenExamLevel
    public let teil: SchreibenExamTeil
    public let officialSourcePDF: String
    public let officialPages: String
    public let title: String
    public let workingTimeMinutes: Int
    public let targetWords: Int
    public let maxOfficialPoints: Int
    public let officialPromptText: String
    public let impulseQuote: String?
    public let officialLeitpunkte: [String]
    public let candidateLabel: String
    public let authenticCandidateText: String
    public var linguistCorrectedText: String? = nil
    public let officialScoringBreakdown: String
    public let uneditedErrorsNote: [String]
    
    public var candidateWordCount: Int {
        authenticCandidateText
            .split { $0.isWhitespace || $0.isNewline }
            .count
    }
}

public enum OfficialGoetheSamplesBank {
    /// Combined 70 real, 100% non-AI exam writing samples:
    /// - 14 verbatim official Goethe-Institut B1 & B2 Modellsatz / Übungssatz / Prüfertraining candidate examples
    /// - 56 verbatim official telc / ALTE MERLIN Corpus B1 & B2 candidate exam scripts with linguist corrections
    public static let allSamples: [OfficialGoetheSample] = {
        goethePDFSamples + loadBundledMerlinSamples()
    }()
    
    private static func loadBundledMerlinSamples() -> [OfficialGoetheSample] {
        if let url = Bundle.main.url(forResource: "official_schreiben_samples", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let decoded = try? JSONDecoder().decode([OfficialGoetheSample].self, from: data) {
            return decoded
        }
        return []
    }
    
    public static let goethePDFSamples: [OfficialGoetheSample] = [
        // =========================================================================
        // 1. b1_modellsatz_erwachsene.pdf — AUFGABE 1 (Geburtstag)
        // =========================================================================
        OfficialGoetheSample(
            id: "official_b1_ms_erw_t1",
            level: .b1,
            teil: .b1Teil1,
            officialSourcePDF: "Goethe-Zertifikat B1 • Modellsatz Erwachsene (Vs_11_070115)",
            officialPages: "Kandidatenblätter S. 24 • Prüferblätter S. 42 & S. 44",
            title: "Aufgabe 1: Geburtstag",
            workingTimeMinutes: 20,
            targetWords: 80,
            maxOfficialPoints: 40,
            officialPromptText: "Sie haben vor einer Woche Ihren Geburtstag gefeiert. Ein Freund/Eine Freundin von Ihnen konnte nicht zu Ihrer Feier kommen, weil er/sie krank war.\nSchreiben Sie eine E-Mail (circa 80 Wörter). Schreiben Sie etwas zu allen drei Punkten. Achten Sie auf den Textaufbau (Anrede, Einleitung, Reihenfolge der Inhaltspunkte, Schluss).",
            impulseQuote: nil,
            officialLeitpunkte: [
                "Beschreiben Sie: Wie war die Feier?",
                "Begründen Sie: Welches Geschenk finden Sie besonders toll und warum?",
                "Machen Sie einen Vorschlag für ein Treffen."
            ],
            candidateLabel: "Kandidatin: Polina Müller (Original-Leistungsbeispiel B1)",
            authenticCandidateText: """
            Liebe Anna,

            wie geht es dir? Bist du wieder gesund?
            Ohne dich war meine Feier nicht so lustig! Ich lud nicht viele Freunde ein. Wir feierten meinen Geburtstag an Bord des Schiffes. Es war sehr spannend, in hohe See zu stechen und dort zu schwimmen. Mit dem Schiff konnten wir durch das sogenannten „Goldes Tor“ aus Felsen durchgehen. Ich habe auch viele Geschenke bekommen, aber ein Geschenk war besonders toll. Das ist ein Lied von meinem Freund Nikolay. Er hat es selbst geschrieben! Die Musik ist auch wunderbar. Ich finde es original.
            Sei nicht traurig, dass du nicht gekommen bist. Möchtest du vielleicht am Wochenende mit mir ins Kino gehen? Ich würde dich gern sehen.

            Bis bald!
            Mit freundlichen Grüßen
            Polina Müller
            """,
            officialScoringBreakdown: "Offizielles Goethe-Leistungsbeispiel für solides B1-Niveau (Max. 40 Punkte in Teil 1: Erfüllung 10 Pkt., Kohärenz 10 Pkt., Wortschatz 10 Pkt., Strukturen 10 Pkt.). Alle 3 Sprachfunktionen (Feier beschreiben, Geschenk begründen, Treffen vorschlagen) sind inhaltlich und umfänglich angemessen erfüllt. Kleiner Register-Hinweis am Schluss: „Mit freundlichen Grüßen“ + Nachname ist in einer E-Mail an eine enge Freundin zu formell (besser: „Liebe Grüße, Polina“).",
            uneditedErrorsNote: [
                "„durch das sogenannten ‚Goldes Tor‘ … durchgehen“ ➔ durch das sogenannte „Goldene Tor“ fahren",
                "„Ich finde es original.“ ➔ Ich finde es sehr originell.",
                "„Mit freundlichen Grüßen Polina Müller“ ➔ Registerbruch bei informeller E-Mail (Du-Form)"
            ]
        ),
        
        // =========================================================================
        // 2. b1_modellsatz_erwachsene.pdf — AUFGABE 2 (Persönliche Kontakte und Internet)
        // =========================================================================
        OfficialGoetheSample(
            id: "official_b1_ms_erw_t2",
            level: .b1,
            teil: .b1Teil2,
            officialSourcePDF: "Goethe-Zertifikat B1 • Modellsatz Erwachsene (Vs_11_070115)",
            officialPages: "Kandidatenblätter S. 24 • Prüferblätter S. 42 & S. 44",
            title: "Aufgabe 2: Persönliche Kontakte und Internet",
            workingTimeMinutes: 25,
            targetWords: 80,
            maxOfficialPoints: 40,
            officialPromptText: "Sie haben im Fernsehen eine Diskussionssendung zum Thema „Persönliche Kontakte und Internet“ gesehen. Im Online-Gästebuch der Sendung finden Sie folgende Meinung. Schreiben Sie nun Ihre Meinung zum Thema (circa 80 Wörter).",
            impulseQuote: "www.diskussion-aktuell.de • Gästebuch • 15.01. 16:55 Uhr • Tanja:\n„Ich finde es schlimm, dass persönliche Treffen immer seltener werden. Freunde wohnen oft sehr weit auseinander. Und da ist man dann schon froh über das Internet. Aber Kontakte im Internet können doch persönliche Treffen nicht ersetzen!“",
            officialLeitpunkte: [
                "Beziehen Sie sich auf die Meinung im Gästebuch (Tanja).",
                "Äußern und begründen Sie Ihre eigene Meinung zu Kontakten im Internet.",
                "Gehen Sie auf die Bedeutung persönlicher Treffen ein."
            ],
            candidateLabel: "Original-Leistungsbeispiel B1 (Modellsatz Erwachsene, S. 44)",
            authenticCandidateText: """
            Wie Tania finde ich es schade, dass persönliche Treffen immer seltener werden. In eine Welt, wo die Leute immer sich beeilen, haben wir immer weniger Zeit für unsere Freunde. Wir laufen die ganze Tag von ein Teil von die Stadt zu ein ander, und wir sehen nich, dass wir, auf diese Art, persönliche Kontakten verlieren. Naturlich glaube ich nicht, dass Internet nur schlimm ist; zum Beispiel, ist es sehr wichtig wann Menschen sehr weit weg wohnen, in ein Paar Sekunden kommt ein E-Mail von Rome nach Melbourne, von Los Angeles nach Wien an.
            Was wir nich vergessen sollen ist dass persönliche Treffen konnen nich ersetzt werden.
            """,
            officialScoringBreakdown: "Offizielles Goethe-Leistungsbeispiel für B1 Teil 2 (Max. 40 Punkte). Inhaltlich und argumentativ gut aufgebaut (Stufe A/B bei Erfüllung & Kohärenz: direkter Bezug auf Tanja, klares Beispiel mit Rom/Melbourne/Wien und Fazit). Im Kriterium Strukturen & Orthografie (Stufe B/C) zeigen sich typische B1-Fehler bei Kasus nach Präpositionen, Umlauten und Nebensatz-Verbstellung, die das Verständnis jedoch nicht beeinträchtigen.",
            uneditedErrorsNote: [
                "„In eine Welt, wo die Leute immer sich beeilen“ ➔ In einer Welt, in der sich die Leute immer beeilen",
                "„die ganze Tag von ein Teil von die Stadt zu ein ander“ ➔ den ganzen Tag von einem Teil der Stadt zum anderen",
                "„wann Menschen sehr weit weg wohnen“ ➔ wenn Menschen sehr weit weg wohnen",
                "„dass persönliche Treffen konnen nich ersetzt werden“ ➔ dass persönliche Treffen nicht ersetzt werden können (Verb am Ende im Nebensatz)"
            ]
        ),
        
        // =========================================================================
        // 3. b1_modellsatz_erwachsene.pdf — AUFGABE 3 (Entschuldigung)
        // =========================================================================
        OfficialGoetheSample(
            id: "official_b1_ms_erw_t3",
            level: .b1,
            teil: .b1Teil3,
            officialSourcePDF: "Goethe-Zertifikat B1 • Modellsatz Erwachsene (Vs_11_070115)",
            officialPages: "Kandidatenblätter S. 24 • Prüferblätter S. 42 & S. 44",
            title: "Aufgabe 3: Entschuldigung bei Frau Müller",
            workingTimeMinutes: 15,
            targetWords: 40,
            maxOfficialPoints: 20,
            officialPromptText: "Ihre Kursleiterin, Frau Müller, hat Sie zu einem Gespräch über Ihre persönlichen Lernziele eingeladen. Zu dem Termin können Sie aber nicht kommen.\nSchreiben Sie an Frau Müller. Entschuldigen Sie sich höflich und berichten Sie, warum Sie nicht kommen können. Schreiben Sie eine E-Mail (circa 40 Wörter). Vergessen Sie nicht die Anrede und den Gruß am Schluss.",
            impulseQuote: nil,
            officialLeitpunkte: [
                "Passende formelle Anrede wählen.",
                "Sich höflich für die Absage entschuldigen.",
                "Den Grund berichten, warum Sie nicht zum Gespräch kommen können, sowie Gruß am Schluss."
            ],
            candidateLabel: "Kandidatin: Jennifer M. (Original-Leistungsbeispiel B1)",
            authenticCandidateText: """
            Liebe Frau Müller,

            Es tut mir leid, dass ich zu Ihrem Gespräch über Ihre persönlichen Lernziele nicht kommen kann. Ich muss an diesem Tag in Deutschland meine Mutter besuchen. Sie ist im Krankenhaus Krank und muss operiert werden.

            Mit Freundlichen Grüßen,
            Jennifer M.
            """,
            officialScoringBreakdown: "Offizielles Goethe-Leistungsbeispiel für B1 Teil 3 (Max. 20 Punkte: Erfüllung 4 Pkt., Kohärenz 4 Pkt., Wortschatz 6 Pkt., Strukturen 6 Pkt.). Mitteilung ist inhaltlich klar und verständlich; kleiner logischer Fehler bei der Übernahme aus der Aufgabenstellung („über Ihre persönlichen Lernziele“ statt „über meine persönlichen Lernziele“) sowie Großschreibung nach Anrede.",
            uneditedErrorsNote: [
                "„über Ihre persönlichen Lernziele“ ➔ über meine persönlichen Lernziele (Pronomen nicht aus Aufgabenstellung kopieren!)",
                "„Sie ist im Krankenhaus Krank“ ➔ Sie liegt krank im Krankenhaus",
                "„Mit Freundlichen Grüßen,“ ➔ Mit freundlichen Grüßen (kleines ‚f‘ und ohne Komma)"
            ]
        ),
        
        // =========================================================================
        // 4. B1_Uebungssatz_Erwachsene.pdf — AUFGABE 1 (Online Deutsch lernen)
        // =========================================================================
        OfficialGoetheSample(
            id: "official_b1_us_erw_t1",
            level: .b1,
            teil: .b1Teil1,
            officialSourcePDF: "Goethe-Zertifikat B1 • Übungssatz Erwachsene (VS0.1)",
            officialPages: "Kandidatenblätter S. 24 • Prüferblätter S. 43–45",
            title: "Aufgabe 1: Online Deutsch lernen",
            workingTimeMinutes: 20,
            targetWords: 80,
            maxOfficialPoints: 40,
            officialPromptText: "Sie haben online Deutsch gelernt und berichten Ihrer Freundin/Ihrem Freund darüber.\nSchreiben Sie eine E-Mail (circa 80 Wörter). Schreiben Sie etwas zu allen drei Punkten. Achten Sie auf den Textaufbau (Anrede, Einleitung, Reihenfolge der Inhaltspunkte, Schluss).",
            impulseQuote: nil,
            officialLeitpunkte: [
                "Beschreiben Sie: Wie haben Sie gelernt?",
                "Begründen Sie: Welche Vorteile hat das Lernen mit dem Computer?",
                "Machen Sie einen Vorschlag für ein Treffen."
            ],
            candidateLabel: "Kandidatin: Elena (Original-Leistungsbeispiel B1, VS0.1)",
            authenticCandidateText: """
            Liebe Julia,

            wie geht’s dir? Wie ist dein Deutschkurs?
            Ich kann kein Deutschkurs besuchen, weil ich arbeite. So habe ich mit dem Computer Deutsch gelernt! Es war cool! Ich habe eine Online-Kurs besucht, ich habe Online-Übungen gemacht und ich habe mit anderen Studenten oder Studentinnen über Skype telefoniert. Das Lernen am Computer hat viele Vorteil! Du kannst den Kurs besuchen, wenn du Zeit hast oder du kannst mit den Tutoren über deine Problemen mit der Grammatik sprechen. Sie sind sehr nett!
            Dieses Wochenende können wir uns treffen! Hast du Zeit? Ich kann den Online-Kurs dir zeigen!

            Bis bald,
            Elena
            """,
            officialScoringBreakdown: "Offizielles Goethe-Leistungsbeispiel für B1 Teil 1 (Max. 40 Punkte). Sehr natürliche, partneradäquate E-Mail: Anrede, Einleitung, alle drei Inhaltspunkte (Online-Übungen & Skype, zeitliche Flexibilität & Tutoren, Wochenendtreffen) sowie Grußformel sind durchgängig umgesetzt.",
            uneditedErrorsNote: [
                "„Ich kann kein Deutschkurs besuchen“ / „eine Online-Kurs“ ➔ keinen Deutschkurs / einen Online-Kurs (Akkusativ maskulin)",
                "„hat viele Vorteil!“ ➔ hat viele Vorteile! (Plural)",
                "„über deine Problemen“ ➔ über deine Probleme (Akkusativ Plural nach ‚über‘)",
                "„Ich kann den Online-Kurs dir zeigen!“ ➔ Ich kann dir den Online-Kurs zeigen!"
            ]
        ),
        
        // =========================================================================
        // 5. B1_Uebungssatz_Erwachsene.pdf — AUFGABE 2 (Feste Arbeitszeiten)
        // =========================================================================
        OfficialGoetheSample(
            id: "official_b1_us_erw_t2",
            level: .b1,
            teil: .b1Teil2,
            officialSourcePDF: "Goethe-Zertifikat B1 • Übungssatz Erwachsene (VS0.1)",
            officialPages: "Kandidatenblätter S. 24 • Prüferblätter S. 43–45",
            title: "Aufgabe 2: Feste Arbeitszeiten",
            workingTimeMinutes: 25,
            targetWords: 80,
            maxOfficialPoints: 40,
            officialPromptText: "Sie haben im Fernsehen eine Diskussionssendung zum Thema „Feste Arbeitszeiten“ gesehen. Im Online-Gästebuch der Sendung finden Sie folgende Meinung. Schreiben Sie nun Ihre Meinung zum Thema (circa 80 Wörter).",
            impulseQuote: "www.diskussion-aktuell.de • Gästebuch • 05.01. 17:23 Uhr • Jessica:\n„Ich arbeite von 9.00 bis 17.30 Uhr. Die festen Arbeitszeiten sind schon praktisch: Ich habe einen geregelten Tagesablauf, kann pünktlich das Büro verlassen und bin für Kunden immer zu erreichen. Seitdem ich zwei kleine Kinder habe, wäre ich jedoch gerne flexibler.“",
            officialLeitpunkte: [
                "Äußern Sie Ihre Meinung zu festen bzw. flexiblen Arbeitszeiten.",
                "Berichten Sie von eigenen Erfahrungen im Berufsalltag.",
                "Wägen Sie Vor- und Nachteile (z. B. Familie, Staus, geregelter Ablauf) ab."
            ],
            candidateLabel: "Original-Leistungsbeispiel B1 (Übungssatz Erwachsene, S. 45)",
            authenticCandidateText: """
            Ich bin der Meinung, dass feste Arbeitszeiten sehr streng sind. Im Rahmen meiner letzten Arbeitserfahrung hatte ich freie Arbeitszeiten und konnte meine 39 Arbeitsstunden wie ich wollte organisieren.
            Deshalb konnte ich einfacher einen Privattermin vereinbaren. Das ist auch sehr praktisch, wenn unsere Kinder krank sind, weil wir keinen freien Tag brauchen (wir arbeiten mehr der Rest des Woches). Außerdem kann man Staus vermeiden und Zeit gewinnen. Aber ich kann auch Leute verstehen, die einen geregelten Tagesablauf brauchen. Ich denke, dass es kommt auf die Persönlichkeit als auch auf die Verantwortung an und die Unternehmen sind nicht immer einverstanden freien Arbeitszeit anzubieten.
            """,
            officialScoringBreakdown: "Offizielles Goethe-Leistungsbeispiel für B1 Teil 2 (Max. 40 Punkte). Sehr starker Wortschatz und gute Konnektoren („Im Rahmen meiner letzten Arbeitserfahrung“, „Deshalb“, „Außerdem“, „einen Privattermin vereinbaren“, „Staus vermeiden“). Vereinzelte Grammatikfehler am Schluss stören das Verständnis nicht.",
            uneditedErrorsNote: [
                "„der Rest des Woches“ ➔ den Rest der Woche (die Woche = feminin)",
                "„Ich denke, dass es kommt auf die Persönlichkeit … an“ ➔ Ich denke, dass es sowohl auf die Persönlichkeit als auch auf die Verantwortung ankommt (Verb am Ende nach ‚dass‘)",
                "„freien Arbeitszeit anzubieten“ ➔ freie Arbeitszeiten anzubieten"
            ]
        ),
        
        // =========================================================================
        // 6. B1_Uebungssatz_Erwachsene.pdf — AUFGABE 3 (Kurs „Erfolgreich präsentieren“)
        // =========================================================================
        OfficialGoetheSample(
            id: "official_b1_us_erw_t3",
            level: .b1,
            teil: .b1Teil3,
            officialSourcePDF: "Goethe-Zertifikat B1 • Übungssatz Erwachsene (VS0.1)",
            officialPages: "Kandidatenblätter S. 24 • Prüferblätter S. 43–45",
            title: "Aufgabe 3: Entschuldigung bei Herrn Weber",
            workingTimeMinutes: 15,
            targetWords: 40,
            maxOfficialPoints: 20,
            officialPromptText: "Sie haben sich für den Kurs „Erfolgreich präsentieren“ angemeldet. Zu dem ersten Termin können Sie aber nicht kommen.\nSchreiben Sie an Ihren Kursleiter, Herrn Weber. Entschuldigen Sie sich höflich und berichten Sie, warum Sie nicht kommen können. Schreiben Sie eine E-Mail (circa 40 Wörter). Vergessen Sie nicht die Anrede und den Gruß am Schluss.",
            impulseQuote: nil,
            officialLeitpunkte: [
                "Formelle Anrede an Herrn Weber.",
                "Sich höflich für das Fehlen beim ersten Termin entschuldigen.",
                "Den Grund für die Abwesenheit nennen und mit formellem Gruß schließen."
            ],
            candidateLabel: "Kandidat: Sascha P. (Original-Leistungsbeispiel B1, VS0.1)",
            authenticCandidateText: """
            Sehr geehrter Herr Weber!

            Ich habe mich zu den Kurs „Erfolgreich präsentieren“ angemeldet. Ich habe auch schon bezahlt. Es tut mir Leid aber ich kann zu dem ersten Termin nicht kommen, weil ich in Krankenhaus bin. Ich habe mein Bein zum Skifahren gebrochen. Entschuldigen Sie mich bitte. Ich komme nächstes Mal.

            Mit freundlichen Grüßen
            Sascha P.
            """,
            officialScoringBreakdown: "Offizielles Goethe-Leistungsbeispiel für B1 Teil 3 (Max. 20 Punkte). Alle Inhaltspunkte und das formelle Register (Sie-Form, Anrede, Gruß) sind voll erfüllt; typische Präpositionsfehler („zu den Kurs“, „zum Skifahren“) auf B1-Niveau.",
            uneditedErrorsNote: [
                "„zu den Kurs … angemeldet“ ➔ für den Kurs angemeldet",
                "„weil ich in Krankenhaus bin“ ➔ weil ich im Krankenhaus bin",
                "„Ich habe mein Bein zum Skifahren gebrochen.“ ➔ Ich habe mir beim Skifahren das Bein gebrochen."
            ]
        ),
        
        // =========================================================================
        // 7. B1_Uebungssatz_Jugendliche.pdf — AUFGABE 1 (Praktikum in einer Buchhandlung)
        // =========================================================================
        OfficialGoetheSample(
            id: "official_b1_us_jug_t1",
            level: .b1,
            teil: .b1Teil1,
            officialSourcePDF: "Goethe-Zertifikat B1 • Übungssatz Jugendliche",
            officialPages: "Kandidatenblätter S. 24 • Prüferblätter S. 43–45",
            title: "Aufgabe 1: Praktikum in einer Buchhandlung",
            workingTimeMinutes: 20,
            targetWords: 80,
            maxOfficialPoints: 40,
            officialPromptText: "Du hast im Sommer ein Praktikum in einer Buchhandlung gemacht und möchtest einem Freund/einer Freundin davon erzählen.\nSchreibe eine E-Mail (circa 80 Wörter). Schreibe etwas zu allen drei Punkten. Achte auf den Textaufbau (Anrede, Einleitung, Reihenfolge der Inhaltspunkte, Schluss).",
            impulseQuote: nil,
            officialLeitpunkte: [
                "Beschreibe: Wie war das Praktikum in der Buchhandlung?",
                "Begründe: Was hat dir besonders gut gefallen?",
                "Mache einen Vorschlag für ein Treffen."
            ],
            candidateLabel: "Kandidatin: Anna (Original-Leistungsbeispiel B1 Jugendliche)",
            authenticCandidateText: """
            Liebe Miriam,

            wie geht es dir? Mir geht es super.
            Im Sommer habe ich ein Praktikum in einer Buchhandlung gemacht und jetzt möchte ich dir davon erzählen. Diese Praktikum war sehr lustig und interessant. Ich habe viel Leute kennengelernt und viel neue Bücher zu lesen gefunden. Besonders gut hat mir mit Kindern und ihren Eltern arbeiten gefallen, weil sie so nett waren!
            Aber ich kann nicht alles beschreiben. Besser sage ich dir alles, wenn wir uns treffen. Wie findest du am Samstag um 16 Uhr im Clasische Cafe? Ruf mir bitte an.

            Liebe Grüße
            Anna
            """,
            officialScoringBreakdown: "Offizielles Goethe-Leistungsbeispiel für B1 Teil 1 (Max. 40 Punkte). Sehr gelungener Textaufbau mit flüssiger Überleitung zum Treffensvorschlag („Aber ich kann nicht alles beschreiben. Besser sage ich dir alles, wenn wir uns treffen.“).",
            uneditedErrorsNote: [
                "„Diese Praktikum“ ➔ Dieses Praktikum (das Praktikum = Neutrum)",
                "„viel Leute … viel neue Bücher“ ➔ viele Leute … viele neue Bücher",
                "„Ruf mir bitte an.“ ➔ Ruf mich bitte an. (anrufen + Akkusativ)"
            ]
        ),
        
        // =========================================================================
        // 8. B1_Uebungssatz_Jugendliche.pdf — AUFGABE 2 (Private Fotos in sozialen Netzwerken)
        // =========================================================================
        OfficialGoetheSample(
            id: "official_b1_us_jug_t2",
            level: .b1,
            teil: .b1Teil2,
            officialSourcePDF: "Goethe-Zertifikat B1 • Übungssatz Jugendliche",
            officialPages: "Kandidatenblätter S. 24 • Prüferblätter S. 43–45",
            title: "Aufgabe 2: Private Fotos in sozialen Netzwerken",
            workingTimeMinutes: 25,
            targetWords: 80,
            maxOfficialPoints: 40,
            officialPromptText: "Du hast in einer Zeitschrift einen Artikel zum Thema „Private Fotos in sozialen Netzwerken“ gelesen. Im Online-Forum der Zeitung findest du folgende Meinung. Schreibe nun deine Meinung zum Thema (circa 80 Wörter).",
            impulseQuote: "www.diskussion-aktuell.de • Gästebuch • 16.06. 11:32 Uhr • Susan:\n„Mich nervt es so, wenn ständig fotografiert wird. Auf jeder Party, im Café, immer und überall. Ich mag das nicht! Und am meisten stört mich, dass die Leute diese Fotos dann oft auch noch ins Internet stellen, wo sie jeder sehen kann. Das ist doch privat!“",
            officialLeitpunkte: [
                "Beziehe dich auf Susans Beitrag im Online-Forum.",
                "Äußere deine Meinung zum Fotografieren und Hochladen privater Fotos.",
                "Begründe, welche Regeln (z. B. um Erlaubnis fragen) gelten sollten."
            ],
            candidateLabel: "Original-Leistungsbeispiel B1 (Übungssatz Jugendliche, S. 45)",
            authenticCandidateText: """
            Meine Meinung zu dieses Thema ist, dass man sollte keine Fotos von anderen machen. Das ist, wie Susan sagt, privat. Wenn jemand ein Foto von mir machte und dann es in Internet stellte, dann würde ich sehr böse mit dieser Person sein, weil viele Leute diese Foto sehen können. Und vielleicht will ich nicht, dass andere Leute das Foto sehen.
            Wenn man eine Foto von einem anderen Person ins Internet stellen will, dann muss der „fotografierte Person“ seinen Erlaubnis geben und wenn er das nicht macht, dann darf den anderen Person das Foto nicht ins Internet hochladen.
            """,
            officialScoringBreakdown: "Offizielles Goethe-Leistungsbeispiel für B1 Teil 2 (Max. 40 Punkte). Gute Verwendung von Konditionalsätzen (Wenn… dann) und Konjunktiv II („würde ich… sein“). Wiederholte Genus-Unsicherheiten bei „das Foto“, „die Person“ und „die Erlaubnis“.",
            uneditedErrorsNote: [
                "„zu dieses Thema ist, dass man sollte keine Fotos … machen“ ➔ zu diesem Thema ist, dass man keine Fotos … machen sollte",
                "„böse mit dieser Person“ ➔ böse auf diese Person",
                "„eine Foto von einem anderen Person“ ➔ ein Foto von einer anderen Person (das Foto, die Person)",
                "„seinen Erlaubnis geben“ ➔ seine/ihre Erlaubnis geben (die Erlaubnis = feminin)"
            ]
        ),
        
        // =========================================================================
        // 9. B1_Uebungssatz_Jugendliche.pdf — AUFGABE 3 (Einkaufen für Frau Selden)
        // =========================================================================
        OfficialGoetheSample(
            id: "official_b1_us_jug_t3",
            level: .b1,
            teil: .b1Teil3,
            officialSourcePDF: "Goethe-Zertifikat B1 • Übungssatz Jugendliche",
            officialPages: "Kandidatenblätter S. 24 • Prüferblätter S. 43–45",
            title: "Aufgabe 3: Einkaufen für Frau Selden",
            workingTimeMinutes: 15,
            targetWords: 40,
            maxOfficialPoints: 20,
            officialPromptText: "Eine Arbeitskollegin deiner Mutter, Frau Selden, sucht jemanden, der einmal in der Woche für sie einkaufen geht. Deine Mutter hat dir ihre E-Mail-Adresse gegeben.\nSchreib an Frau Selden. Erkläre, warum du diesen Job machen möchtest und schlag ein Treffen vor. Schreibe eine E-Mail (circa 40 Wörter). Vergiss nicht die Anrede und den Gruß am Schluss.",
            impulseQuote: nil,
            officialLeitpunkte: [
                "Formelle Anrede an Frau Selden.",
                "Erkläre, warum du den Job machen möchtest.",
                "Schlage ein Treffen vor und schließe mit einem höflichen Gruß."
            ],
            candidateLabel: "Kandidat: Petros Papadopoulos (Original-Leistungsbeispiel B1)",
            authenticCandidateText: """
            Sehr geehrte Frau Selden,

            ich möchte einmal pro Woche für Sie einkaufen gehen, weil ich mehr Taschengeld verdienen möchte. Ist es vielleicht möglich, wenn wir uns am Samstag bei uns treffen, um über meinen Job zu diskutieren?
            Ich danke Sie im Voraus.

            Mit freundlichen Grüßen
            Petros Papadopoulos
            """,
            officialScoringBreakdown: "Offizielles Goethe-Leistungsbeispiel für B1 Teil 3 (Max. 20 Punkte). Sehr gute Satzverknüpfung mit Nebensatz („weil…“) und Finalsatz („um … zu“). Typischer Kasusfehler bei „danken“ („Ich danke Sie“ statt „Ich danke Ihnen“).",
            uneditedErrorsNote: [
                "„Ich danke Sie im Voraus.“ ➔ Ich danke Ihnen im Voraus. (danken + Dativ!)"
            ]
        ),
        
        // =========================================================================
        // 10. b2_modellsatz_erwachsene.pdf — TEIL 1 (Plastikverpackungen im Alltag)
        // =========================================================================
        OfficialGoetheSample(
            id: "official_b2_ms_erw_t1",
            level: .b2,
            teil: .b2Teil1,
            officialSourcePDF: "Goethe-Zertifikat B2 • Modellsatz Erwachsene (Vs1.5_160426)",
            officialPages: "Kandidatenblätter S. 24 • Prüferblätter S. 46–48",
            title: "Teil 1: Forumsbeitrag zur Verschmutzung der Umwelt",
            workingTimeMinutes: 50,
            targetWords: 150,
            maxOfficialPoints: 60,
            officialPromptText: "Sie schreiben einen Forumsbeitrag zur Verschmutzung der Umwelt. Denken Sie an eine Einleitung und einen Schluss. Bei der Bewertung wird darauf geachtet, wie genau die Inhaltspunkte bearbeitet sind, wie korrekt der Text ist und wie gut die Sätze und Abschnitte sprachlich miteinander verknüpft sind. Schreiben Sie circa 150 Wörter.",
            impulseQuote: nil,
            officialLeitpunkte: [
                "Äußern Sie Ihre Meinung zu Plastikverpackungen im Alltag.",
                "Nennen Sie Gründe, warum Plastikverpackungen so verbreitet sind.",
                "Nennen Sie andere Möglichkeiten, Dinge im Alltag zu verpacken.",
                "Nennen Sie Vorteile der anderen Verpackungen."
            ],
            candidateLabel: "Original-Leistungsbeispiel B2 (Modellsatz Erwachsene, S. 48)",
            authenticCandidateText: """
            Plastikverpackungen werden heutzutage weltweit verwendet, nicht nur im Supermarkt, sondern auch in der Restaurants. Man kann mit Plastiktüte viele Sachen zusammen tragen, die unseres Leben viel einfacher und leichter machen.
            Meiner Meinung nach gibt es nicht nur einzige Grund der Verbreitung der Plastikverpackungen. Eine der Gründe ist die niedrige Koste der Produktion der Plastikverpackungen. Die Lebensmittelfirmen packen sowohl Fleisch, Chips, Keks, Brot, Gemüse, die Flüssigkeiten, zum Beispiel Milch, Jogurt, Seife, Reinigungsmittel ein. Ich bin der Ansicht, dass die Plastikverpackungen sehr lang halten kann, entweder unter sehr warme oder kalte Temperatur. Aus meiner persönlichen Erfahrung benutze ich meinstens meine Einkaufstüte, mit der ich viel Waren einfüllen kann, wie Plastiktüte. Wenn ich die Einkaufstüte zu Haus vergesse, nehme ich einfach ein Papierverpackung, die man immer beim Supermarkt finden kann.
            Heutzutage verwenden viele Bäckerei Papiertüte stattdessen Plastiktüte, um das Brot zu verpacke. meiner Auffassung nach sind die viel umweltfreundlicher als Plastiktüte. Viele Menschen betönen, dass wir mehr an unsere zukunftige Umwelt denken sollten. Die andere Verpackungen, die aus Papier oder Cotton produziert werden, sind nicht nur viel umweltfreundlicher, sondern auch werden viel schöner und eleganter ausgesehen. Sie sind leicht trägbar und die Einkauftüte sind sehr lang hältbar.
            Ich hoffe, dass mehr Menschen die Plastikverpackungen aufhören zu verwenden. Wir kümmern um unsere Welt.
            """,
            officialScoringBreakdown: "Offizielles Goethe-Leistungsbeispiel für B2 Teil 1 (Max. 60 Punkte im offiziellen B2-Bewertungsbogen: Aufgabenerfüllung 14 Pkt., Kohärenz 14 Pkt., Wortschatz 16 Pkt., Strukturen 16 Pkt.). Alle 4 Inhaltspunkte sind ausführlich behandelt (209 Wörter) und der Text nutzt zweiteilige Konnektoren („nicht nur … sondern auch“) sowie Relativ- und Finalsätze („um … zu“). In Wortschatz & Strukturen liegen mehrere Morphologie- und Endungsfehler vor, die das Verständnis jedoch nicht verhindern (solides B2-Bestehensniveau, Stufe B/C).",
            uneditedErrorsNote: [
                "„in der Restaurants“ ➔ in den Restaurants (Dativ Plural)",
                "„Eine der Gründe ist die niedrige Koste“ ➔ Einer der Gründe sind die niedrigen Kosten",
                "„Papiertüte stattdessen Plastiktüte“ ➔ Papiertüten statt Plastiktüten",
                "„leicht trägbar … sehr lang hältbar“ ➔ leicht tragbar … sehr lange haltbar",
                "„Wir kümmern um unsere Welt.“ ➔ Wir sollten uns um unsere Welt kümmern."
            ]
        ),
        
        // =========================================================================
        // 11. b2_modellsatz_erwachsene.pdf — TEIL 2 (Nachricht an Herrn Ebert - Überlastung)
        // =========================================================================
        OfficialGoetheSample(
            id: "official_b2_ms_erw_t2",
            level: .b2,
            teil: .b2Teil2,
            officialSourcePDF: "Goethe-Zertifikat B2 • Modellsatz Erwachsene (Vs1.5_160426)",
            officialPages: "Kandidatenblätter S. 24 • Prüferblätter S. 46–48",
            title: "Teil 2: Arbeitsbelastung im Praktikum (Herr Ebert)",
            workingTimeMinutes: 25,
            targetWords: 100,
            maxOfficialPoints: 40,
            officialPromptText: "Sie machen gerade ein Praktikum bei einer deutschen Firma. Sie haben derzeit so viel zu tun, dass Sie Ihre Arbeit nicht mehr schaffen. Schreiben Sie eine Nachricht an Ihren Vorgesetzten, Herrn Ebert.\nÜberlegen Sie sich eine passende Reihenfolge für die Inhaltspunkte. Vergessen Sie nicht Anrede und Gruß. Schreiben Sie circa 100 Wörter.",
            impulseQuote: nil,
            officialLeitpunkte: [
                "Beschreiben Sie, womit Sie beschäftigt sind.",
                "Bitten Sie um Verständnis für Ihre Situation.",
                "Zeigen Sie Verständnis für die Arbeitssituation in der Firma.",
                "Machen Sie einen Vorschlag für die kommenden Tage."
            ],
            candidateLabel: "Kandidatin: Mergime xx (Original-Leistungsbeispiel B2, S. 48)",
            authenticCandidateText: """
            Sehr geehrter Herr Ebert,

            ich schreibe Ihnen, weil ich ein Problem mit meinen Kollegin habe. Er ist sehr nett aber gibt mir zu viel Aufgaben, die ich nicht allen schaffen kann.
            Wie Sie auch wissen ich habe 2 Kinder und meine kleine Tochter ist krank. Sie wird diese Woche operiert lassen, deswegen bitte ich Ihnen, dass Sie auch meine Situation verstehen können. Ich muss mich um meine Tochter kümmern aber, wenn ich zu viel für die Firma zu Tun habe schaffe ich es nicht.
            Ich kann schön die Arbeitssituation in der Firma verstehen. Wir haben viel zu Tun und wenig Zeit. Um diese Problem zu lösen, schlage ich vor, dass mein Kollegen und ich die Aufgaben zusammen machen (oder Teilen) können.
            Ich danke Ihnen für Ihre Verständnis.

            Mit freundlichen Grüße
            Mergime xx
            """,
            officialScoringBreakdown: "Offizielles Goethe-Leistungsbeispiel für B2 Teil 2 (Max. 40 Punkte im B2-Bewertungsbogen: Aufgabenerfüllung 10 Pkt., Kohärenz 10 Pkt., Wortschatz 10 Pkt., Strukturen 10 Pkt.). Alle 4 Leitpunkte sind klar strukturiert und in sinnvoller Reihenfolge bearbeitet. Abzüge gibt es bei Strukturen (Verbstellung nach „Wie Sie auch wissen“, Kasus bei „ich bitte Sie“, „mit meinem Kollegen“).",
            uneditedErrorsNote: [
                "„mit meinen Kollegin … Er ist“ ➔ mit meinem Kollegen",
                "„Wie Sie auch wissen ich habe 2 Kinder“ ➔ Wie Sie auch wissen, habe ich zwei Kinder (Inversion nach vorangestelltem Nebensatz)",
                "„deswegen bitte ich Ihnen“ ➔ deswegen bitte ich Sie (bitten + Akkusativ)",
                "„für Ihre Verständnis. Mit freundlichen Grüße“ ➔ für Ihr Verständnis. Mit freundlichen Grüßen"
            ]
        ),
        
        // =========================================================================
        // 12. b2_modellsatz_jugendliche.pdf — TEIL 1 (Körperschmuck: Tattoos & Piercings)
        // =========================================================================
        OfficialGoetheSample(
            id: "official_b2_ms_jug_t1",
            level: .b2,
            teil: .b2Teil1,
            officialSourcePDF: "Goethe-Zertifikat B2 • Modellsatz Jugendliche (Vs1.5_170426)",
            officialPages: "Kandidatenblätter S. 24 • Prüferblätter S. 46–48",
            title: "Teil 1: Forumsbeitrag zu Körperschmuck (Tattoos & Piercings)",
            workingTimeMinutes: 50,
            targetWords: 150,
            maxOfficialPoints: 60,
            officialPromptText: "Du schreibst einen Forumsbeitrag zu Körperschmuck wie Tattoos oder Piercings. Denke an eine Einleitung und einen Schluss. Bei der Bewertung wird darauf geachtet, wie genau die Inhaltspunkte bearbeitet sind, wie korrekt der Text ist und wie gut die Sätze und Abschnitte sprachlich miteinander verknüpft sind. Schreibe circa 150 Wörter.",
            impulseQuote: nil,
            officialLeitpunkte: [
                "Äußere deine Meinung zu Tattoos und anderen Formen des Körperschmucks.",
                "Begründe, warum du für oder gegen solchen Schmuck bist.",
                "Schlage andere Möglichkeiten vor, wie man seinen Körper schmücken kann.",
                "Nenne die Vorteile der anderen Möglichkeiten."
            ],
            candidateLabel: "Original-Leistungsbeispiel B2 (Modellsatz Jugendliche, S. 48)",
            authenticCandidateText: """
            Manche tragen Schmuck seit über 10 000 Jahren, wie z.B. in der Neolitischenepoke. Ich werde meine Meinung äußeren und somit meine Darstellung erleuchtern.
            Meiner Meinung nach sind Tattoos eine Körper-Verletzung, wie es schön im Gesetzt geschrieben ist, deswegen finde ich Tattoos gefährlich für den menschlichen Körper, obwohl es manche Leute schön finden. Im Gegenteil des Tattoos finde ich Schmuck wie z.B. Ohrringe, Ketten, Perlen usw … hüpsch, da es den Menschlichenkörper verschönert, indem es den Menschen brillianz und Symbolik schenkt. Ein andere Möglichkeit wär, auf seinen Körpe Zeichnungen zu malen mit einer Farbe die wasserlöslich ist. Mit dieser Möglichkeit, könnten wir die gleichen Effecte produzieren, als mit den Tat-toos ohne dass unsere Körper Schaden erlittet.
            Um meine Gedanke zu gliedern, würde ich herausstellen dass Körperschmuck den Menschlichenkörper verschönert, wenn es ihm nicht körperlich schadet.
            """,
            officialScoringBreakdown: "Offizielles Goethe-Leistungsbeispiel für B2 Teil 1 (Max. 60 Punkte). Zeigt den typischen B2-Anspruch: historische Einleitung, komplexe Nebensätze mit „obwohl“, „da“, „indem“, „ohne dass“ sowie Konjunktiv II („wäre“, „könnten“). Einzelne Fehlgriffe im Ausdruck („Darstellung erleuchtern“ statt „erläutern“, „Im Gegenteil des Tattoos“ statt „Im Gegensatz zu Tattoos“) beeinträchtigen das Verständnis nicht.",
            uneditedErrorsNote: [
                "„meine Darstellung erleuchtern“ ➔ meine Darstellung erläutern",
                "„wie es schön im Gesetzt geschrieben ist“ ➔ wie es schon im Gesetz geschrieben steht",
                "„Im Gegenteil des Tattoos“ ➔ Im Gegensatz zu Tattoos",
                "„ohne dass unsere Körper Schaden erlittet“ ➔ ohne dass unser Körper Schaden erleidet"
            ]
        ),
        
        // =========================================================================
        // 13. b2_modellsatz_jugendliche.pdf — TEIL 2 (Verpasste Sitzung im Praktikum)
        // =========================================================================
        OfficialGoetheSample(
            id: "official_b2_ms_jug_t2",
            level: .b2,
            teil: .b2Teil2,
            officialSourcePDF: "Goethe-Zertifikat B2 • Modellsatz Jugendliche (Vs1.5_170426)",
            officialPages: "Kandidatenblätter S. 24 • Prüferblätter S. 46–48",
            title: "Teil 2: Verpasste Sitzung im Praktikum (Herr Ebert)",
            workingTimeMinutes: 25,
            targetWords: 100,
            maxOfficialPoints: 40,
            officialPromptText: "Du machst gerade ein Praktikum bei einer deutschen Firma. Aufgrund eines Missverständnisses hast du eine wichtige Sitzung verpasst. Du benötigst die Unterlagen, die in der Sitzung verteilt wurden. Schreibe eine Nachricht an den Ausbildungsleiter, Herrn Ebert.\nÜberlege dir eine passende Reihenfolge für die Inhaltspunkte. Vergiss nicht Anrede und Gruß. Schreibe circa 100 Wörter.",
            impulseQuote: nil,
            officialLeitpunkte: [
                "Entschuldige dich.",
                "Erkläre die Ursache für deine Abwesenheit.",
                "Sage, warum du deine Abwesenheit bedauerst.",
                "Bitte um die Unterlagen."
            ],
            candidateLabel: "Kandidat: Vincent xx (Original-Leistungsbeispiel B2, S. 48)",
            authenticCandidateText: """
            Sehr geehrter Herr Ebert,

            Ich möchte mich gerne bei Ihnen entschuldigen, weil ich Gestern die Sitzung verpasst habe. Ich versichere ihnen nebenbei, dass es niemals mehr vorkommen wird! Ich habe diese Sitzung nicht Freiwillig verpasst sondern wegen eines Missverständnisses: Als ich die e-mail mit der Uhrzeit der Sitzung bekommen hab, dacht ich, dass sie um 7 Uhr am Abend stattfindet, und nicht um 7 Uhr am Morgen.
            Ich bedauere und schäme mich, diese Sitzung verpasst zu haben, weil diese Firma und gerade das Praktikum mir sehr am Herzen liegen, und es für mich sehr interessant gewesen wäre, bei der Sitzung dabei zu sein. Es ist ja nicht jeden Tag, dass man die mögligkeit bekommt, bei der Sitzung einer so großen Firma da zu sein.
            Auch noch: der Mitarbeiter Christian Wolf hatte Unterlagen für mich, die er mir bei der Sitzung geben wollte. Ich war ja, wie schon gesagt, nicht da und konnte sie nicht bekommen. Er hat mir gesagt, dass er sie Ihnen gegeben hat, deshalb würde ich sie höflich bitten, sie mir Morgen geben zu können, wann auch immer sie Zeit haben. Ich entschuldige mich nochmals und wünsche ihnen einen angenehmen Tag.

            Vincent xx
            """,
            officialScoringBreakdown: "Offizielles Goethe-Leistungsbeispiel für B2 Teil 2 (Max. 40 Punkte). Sehr starke grammatische B2-Strukturen: Genitiv („wegen eines Missverständnisses“), Infinitiv Perfekt („verpasst zu haben“), Idiomatik („mir sehr am Herzen liegen“) und Irrealis der Vergangenheit („interessant gewesen wäre“). Kleinere Orthografiefehler bei Groß-/Kleinschreibung der Höflichkeitsform „Ihnen/Sie“.",
            uneditedErrorsNote: [
                "„weil ich Gestern … nicht Freiwillig … Morgen“ ➔ gestern, freiwillig, morgen werden kleingeschrieben",
                "„Ich versichere ihnen … würde ich sie höflich bitten“ ➔ Ihnen / Sie in der Höflichkeitsanrede immer großschreiben",
                "„Auch noch:“ ➔ Außerdem: / Hinzu kommt, dass … (formellerer Konnektor)"
            ]
        ),
        
        // =========================================================================
        // 14. Pruefungsziele_Testbeschreibung_B2.pdf — Prüfertraining 1.2 (Maria)
        // =========================================================================
        OfficialGoetheSample(
            id: "official_b2_handbuch_maria",
            level: .b2,
            teil: .b2Teil1,
            officialSourcePDF: "Goethe-Zertifikat B2 • Prüfungsziele, Testbeschreibung & Prüfertraining (ISBN 978-3-939670-06-3)",
            officialPages: "Modellsatz S. 40 • Prüfertraining 1.2 S. 43–44",
            title: "Prüfertraining 1.2: Strengere Kindererziehung (Leserbrief)",
            workingTimeMinutes: 65,
            targetWords: 180,
            maxOfficialPoints: 15,
            officialPromptText: "Im Internet lesen Sie folgende Meldung. Schreiben Sie als Reaktion auf diese Meldung an die Online-Redaktion. Vergessen Sie bitte nicht Anrede und Gruß.",
            impulseQuote: "Große Mehrheit der Deutschen für strengere Kindererziehung:\n„Für Kinder brechen schlechte Zeiten an: 62 Prozent der Deutschen finden, dass die lieben Kleinen wieder strenger erzogen werden sollten. Nur 31 Prozent sind einer Umfrage unter mehr als 1.000 Befragten zufolge mit den derzeitigen Erziehungsmethoden zufrieden, wie der Fernsehsender RTL am Samstag mitteilte. Mit 95 Prozent sprachen sich die meisten Befragten dafür aus, dass Kinder Pflichten wie Aufräumen und Einkaufen erfüllen sollten. 87 Prozent finden, dass Kinder regelmäßig über ihre Schularbeiten berichten sollten und 56 Prozent waren dafür, Kindern das Kaugummikauen in der Schule zu untersagen. Dagegen fanden nur 14 Prozent den Vorschlag gut, Kinder in eine Schuluniform zu stecken.“",
            officialLeitpunkte: [
                "Sagen Sie, mit welchen der erwähnten Erziehungsmaßnahmen Sie persönlich (nicht) einverstanden sind.",
                "Sagen Sie, ob Kinder früher strenger erzogen wurden.",
                "Sagen Sie, wer für die Erziehung der Kinder zuständig ist.",
                "Sagen Sie, welche Vorschläge für die Kindererziehung Sie machen möchten."
            ],
            candidateLabel: "Kandidatin: Maria — Offizielle Goethe-Prüferbewertung: 12,5 / 15 Punkte (83%)",
            authenticCandidateText: """
            Sehr geehrte Damen und Herren,

            Mit dem großen Interesse habe ich die Meldung über die Erziehung der Kinder gelesen. Ich freue mich sehr, daß dieses Thema heute so aktuell ist. Meiner Meinung nach, ist es nicht nur interessant, sondern auch ein großes Problem für die Eltern heute. Deswegen möchte ich auch etwas dazu schreiben.
            Die wichtigste Rolle bei der Erziehung der Kinder spielen die Eltern. Manche Probleme in der Zukunft, zum Beispiel die schlechte Benehmung in der Schule oder ein schlechter Umgang mit den anderen Kindern kommen aus der Kindheit.
            Die Atmosphäre in der Familie spielt eine große Rolle. Ich finde, daß es gut ist, daß die Kinder früher strenger erzogen wurden. Sie bekamen von der Familie viel mehr, als heute und waren auch in der Zukunft selbstständiger.
            Ich bin einverstanden, daß die Kinder beim Einkaufen den Eltern helfen sollten. Und die Eltern sollten unbedingt auf das Studium der Kinder achten. Ich glaube auch, daß sehr gute Idee ist, Kinder in eine Schuluniform zu stecken und selbstverständlich das Kaugummikauen in der Schule untersagen. Die Eltern heute beschäftigen sich sehr mit ihrer Arbeit, aber sie sollten mehr Zeit für die Kinder haben.
            """,
            officialScoringBreakdown: """
            WÖRTLICHER KOMMENTAR DER GOETHE-PRÜFERKOMMISSION (S. 43):
            „12,5 Punkte (von 15) – Ein Beispiel für eine gute Leistung. Die Teilnehmende schreibt einen klar gegliederten Brief. Sie beherrscht Lexik und Grammatik gut, auch wenn sie sich beim Aufbau noch an den Vorgaben der Aufgabe ‚entlanghangelt‘.“
            • Inhaltliche Vollständigkeit (3,5 / 4 Pkt.): „Die Textlänge ist ausreichend. Alle vier Inhaltspunkte sind behandelt, jedoch zwei nur sehr knapp, deswegen gibt es einen halben Punkt Abzug.“
            • Textaufbau und Kohärenz (3 / 4 Pkt.): „Der Text besitzt eine gute Einleitung und ist durchgängig flüssig lesbar. Kaum verknüpfte, einzelne Absätze, deshalb Entscheidung für drei Punkte.“
            • Ausdrucksfähigkeit (3 / 3,5 Pkt.): „Es bestehen noch Unsicherheiten im Sprachgefühl. Sie übernimmt Formulierungen aus der Vorlage.“
            • Korrektheit (3 / 3,5 Pkt.): „Wenige Fehler (z. B. ‚die schlechte Benehmung‘ statt ‚das schlechte Benehmen‘), die das Verständnis nicht beeinträchtigen.“
            """,
            uneditedErrorsNote: [
                "„Mit dem großen Interesse“ ➔ Mit großem Interesse (ohne Artikel)",
                "„die schlechte Benehmung“ ➔ das schlechte Benehmen",
                "„auf das Studium der Kinder achten“ ➔ auf die schulischen Leistungen der Kinder achten (Studium = Universität)",
                "„daß sehr gute Idee ist“ ➔ dass es eine sehr gute Idee ist"
            ]
        )
    ]
}
