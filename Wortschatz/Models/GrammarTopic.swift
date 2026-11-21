import Foundation
import SwiftUI

// MARK: - Grammar Category
public enum GrammarCategory: String, Codable, CaseIterable {
    case satzbau = "Satzbau"
    case verben = "Verben & Modi"
    case kasus = "Kasus & Nomen"
    
    public var badgeColor: Color {
        switch self {
        case .satzbau: return Color(red: 0.14, green: 0.45, blue: 0.96)
        case .verben: return Color(red: 0.53, green: 0.28, blue: 0.92)
        case .kasus: return Color(red: 0.08, green: 0.62, blue: 0.68)
        }
    }
    
    public var iconName: String {
        switch self {
        case .satzbau: return "rectangle.3.group.fill"
        case .verben: return "bolt.horizontal.circle.fill"
        case .kasus: return "link.circle.fill"
        }
    }
}

// MARK: - Sentence Building Exercise (Satzbau-Architekt)
public struct GrammarExercise: Identifiable, Codable, Equatable, Hashable {
    public let id: UUID
    public let englishPrompt: String
    public let targetSentence: String
    public let ruleCallout: String
    
    public init(
        id: UUID = UUID(),
        englishPrompt: String,
        targetSentence: String,
        ruleCallout: String
    ) {
        self.id = id
        self.englishPrompt = englishPrompt
        self.targetSentence = targetSentence
        self.ruleCallout = ruleCallout
    }
    
    /// Splits the target sentence into clean word tokens (keeping commas attached to the preceding word for natural clause boundaries, and stripping final period/question mark)
    public var expectedTokens: [String] {
        let trimmed = targetSentence
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: #"[.!?]+$"#, with: "", options: .regularExpression)
        return trimmed
            .components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }
    }
}

// MARK: - Grammar Topic Model
public struct GrammarTopic: Identifiable, Codable, Equatable, Hashable {
    public let id: String
    public var title: String
    public var subtitle: String
    public var level: String // "B1" or "B2"
    public var category: GrammarCategory
    public var formula: String
    public var explanation: String
    public var signalWords: [String]
    public var examples: [String]
    public var exercises: [GrammarExercise]
    
    // MARK: - Learn Score & SRS State (0% – 100%)
    public var learnScore: Int
    public var reviewsCount: Int
    public var correctCount: Int
    public var incorrectCount: Int
    public var consecutiveCorrect: Int
    public var lastReviewedAt: Date?
    
    public init(
        id: String,
        title: String,
        subtitle: String,
        level: String,
        category: GrammarCategory,
        formula: String,
        explanation: String,
        signalWords: [String],
        examples: [String],
        exercises: [GrammarExercise],
        learnScore: Int = 0,
        reviewsCount: Int = 0,
        correctCount: Int = 0,
        incorrectCount: Int = 0,
        consecutiveCorrect: Int = 0,
        lastReviewedAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.level = level
        self.category = category
        self.formula = formula
        self.explanation = explanation
        self.signalWords = signalWords
        self.examples = examples
        self.exercises = exercises
        self.learnScore = min(100, max(0, learnScore))
        self.reviewsCount = reviewsCount
        self.correctCount = correctCount
        self.incorrectCount = incorrectCount
        self.consecutiveCorrect = consecutiveCorrect
        self.lastReviewedAt = lastReviewedAt
    }
    
    public var isLearned: Bool {
        learnScore >= 75 && correctCount >= 12
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

// MARK: - Complete B1 & B2 Seed Curriculum
private struct BundledExerciseDTO: Codable {
    let englishPrompt: String
    let targetSentence: String
    let ruleCallout: String
}

public enum GrammarCurriculum {
    /// Returns all grammar topics enriched with the 50 bundled exercises per topic (1,150 total) from `grammar_exercises.json`
    public static func loadAllTopicsWithExercises() -> [GrammarTopic] {
        var topics = allTopics
        guard let url = Bundle.main.url(forResource: "grammar_exercises", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let dict = try? JSONDecoder().decode([String: [BundledExerciseDTO]].self, from: data) else {
            return topics
        }
        
        for i in 0..<topics.count {
            let tid = topics[i].id
            if let dtoList = dict[tid], !dtoList.isEmpty {
                topics[i].exercises = dtoList.map {
                    GrammarExercise(
                        englishPrompt: $0.englishPrompt,
                        targetSentence: $0.targetSentence,
                        ruleCallout: $0.ruleCallout
                    )
                }
            }
        }
        return topics
    }
    
    public static let allTopics: [GrammarTopic] = [
        
        // ==========================================
        // 1. SATZBAU & WORTSTELLUNG (B1 & B2)
        // ==========================================
        GrammarTopic(
            id: "b1_nebensaetze_kausal_konzessiv",
            title: "Nebensätze (weil, obwohl, dass)",
            subtitle: "Verb-Endstellung im Nebensatz",
            level: "B1",
            category: .satzbau,
            formula: "Hauptsatz , [Konnektor + Subjekt + ... + konjugiertes Verb]",
            explanation: "Nach unterordnenden Konnektoren wie 'weil', 'da', 'obwohl', 'dass' und 'wenn' wandert das konjugierte Verb immer ans Ende des Nebensatzes.",
            signalWords: ["weil", "da", "obwohl", "dass", "wenn", "als"],
            examples: [
                "Ich lerne jeden Tag Deutsch, weil ich in Berlin arbeiten möchte.",
                "Er geht heute joggen, obwohl es draußen sehr kalt ist."
            ],
            exercises: [
                GrammarExercise(
                    englishPrompt: "I am learning German every day because I want to work in Berlin.",
                    targetSentence: "Ich lerne jeden Tag Deutsch, weil ich in Berlin arbeiten möchte.",
                    ruleCallout: "Im Nebensatz mit 'weil' steht das konjugierte Modalverb (möchte) ganz am Ende."
                ),
                GrammarExercise(
                    englishPrompt: "He is going for a run today although it is very cold outside.",
                    targetSentence: "Er geht heute joggen, obwohl es draußen sehr kalt ist.",
                    ruleCallout: "Nach 'obwohl' steht das konjugierte Verb (ist) am Satzende."
                ),
                GrammarExercise(
                    englishPrompt: "She hopes that the train arrives on time today.",
                    targetSentence: "Sie hofft, dass der Zug heute pünktlich ankommt.",
                    ruleCallout: "Bei trennbaren Verben (ankommen) verschmelzen Präfix und Verb am Ende des Nebensatzes (ankommt)."
                )
            ]
        ),
        
        GrammarTopic(
            id: "b1_nebensatz_vorfeld",
            title: "Nebensatz auf Position 1 (Verb-Verb)",
            subtitle: "Inversion im darauffolgenden Hauptsatz",
            level: "B1",
            category: .satzbau,
            formula: "[Konnektor + ... + Verb] , [Verb + Subjekt + ...]",
            explanation: "Wenn ein Satz mit dem Nebensatz beginnt, nimmt der gesamte Nebensatz Position 1 ein. Direkt nach dem Komma folgt sofort das konjugierte Verb des Hauptsatzes (Verb-Komma-Verb-Regel).",
            signalWords: ["Obwohl ..., Verb", "Weil ..., Verb", "Wenn ..., Verb", "Als ..., Verb"],
            examples: [
                "Obwohl er wenig Zeit hatte, half er seinem Nachbarn.",
                "Wenn das Wetter morgen schön ist, machen wir einen Ausflug."
            ],
            exercises: [
                GrammarExercise(
                    englishPrompt: "Although he had little time, he helped his neighbor.",
                    targetSentence: "Obwohl er wenig Zeit hatte, half er seinem Nachbarn.",
                    ruleCallout: "Verb-Komma-Verb: Der Nebensatz endet mit 'hatte,', der Hauptsatz beginnt direkt mit 'half er'."
                ),
                GrammarExercise(
                    englishPrompt: "If the weather is nice tomorrow, we will go on a trip.",
                    targetSentence: "Wenn das Wetter morgen schön ist, machen wir einen Ausflug.",
                    ruleCallout: "Der Nebensatz besetzt Position 1 -> nach dem Komma steht sofort das Verb 'machen'."
                )
            ]
        ),
        
        GrammarTopic(
            id: "b1_infinitivsaetze_zu",
            title: "Infinitivsätze (um/ohne/anstatt ... zu)",
            subtitle: "Finalsätze & Infinitivkonstruktionen",
            level: "B1",
            category: .satzbau,
            formula: "Hauptsatz , [um / ohne / anstatt] + ... + [zu + Infinitiv]",
            explanation: "'um ... zu' drückt ein Ziel aus, 'ohne ... zu' das Fehlen einer Handlung und 'anstatt ... zu' eine Alternative. Bei trennbaren Verben steht '-zu-' zwischen Präfix und Stamm (z.B. anzurufen).",
            signalWords: ["um ... zu", "ohne ... zu", "anstatt ... zu", "versuchen zu", "vergessen zu"],
            examples: [
                "Sie fährt nach München, um ihre beste Freundin zu besuchen.",
                "Er verließ das Büro, ohne sich von seinen Kollegen zu verabschieden."
            ],
            exercises: [
                GrammarExercise(
                    englishPrompt: "She travels to Munich in order to visit her best friend.",
                    targetSentence: "Sie fährt nach München, um ihre beste Freundin zu besuchen.",
                    ruleCallout: "'um' leitet die Infinitivgruppe ein, 'zu besuchen' bildet die Satzklammer am Ende."
                ),
                GrammarExercise(
                    englishPrompt: "Instead of complaining for a long time, we are looking for a solution.",
                    targetSentence: "Anstatt lange zu klagen, suchen wir nach einer Lösung.",
                    ruleCallout: "Steht die Infinitivgruppe auf Position 1, folgt nach dem Komma direkt das Verb 'suchen'."
                ),
                GrammarExercise(
                    englishPrompt: "He forgot to call his boss back yesterday.",
                    targetSentence: "Er hat gestern vergessen, seinen Chef zurückzurufen.",
                    ruleCallout: "Bei trennbaren Verben (zurückrufen) steht 'zu' in der Mitte: zurückzurufen."
                )
            ]
        ),
        
        GrammarTopic(
            id: "b1_tekamolo",
            title: "Wortstellung im Mittelfeld (TeKaMoLo)",
            subtitle: "Temporal – Kausal – Modal – Lokal",
            level: "B1",
            category: .satzbau,
            formula: "Subjekt + Verb + [Temporal] + [Kausal] + [Modal] + [Lokal] + Verbklammer",
            explanation: "Im deutschen Satz-Mittelfeld ordnet man Angaben in der Reihenfolge: Wann? (Temporal) -> Warum? (Kausal) -> Wie? (Modal) -> Wohin/Wo? (Lokal).",
            signalWords: ["heute (T)", "wegen des Regens (K)", "mit dem Zug (M)", "nach Berlin (L)"],
            examples: [
                "Wir fahren heute wegen des Streiks mit dem Bus in die Stadt.",
                "Sie hat gestern aus Freude spontan im Wohnzimmer getanzt."
            ],
            exercises: [
                GrammarExercise(
                    englishPrompt: "We are traveling to the city by bus today because of the strike.",
                    targetSentence: "Wir fahren heute wegen des Streiks mit dem Bus in die Stadt.",
                    ruleCallout: "TeKaMoLo: heute (Temporal) -> wegen des Streiks (Kausal) -> mit dem Bus (Modal) -> in die Stadt (Lokal)."
                ),
                GrammarExercise(
                    englishPrompt: "He worked very focused in the library all day yesterday.",
                    targetSentence: "Er hat gestern den ganzen Tag sehr konzentriert in der Bibliothek gearbeitet.",
                    ruleCallout: "Temporal (gestern den ganzen Tag) vor Modal (sehr konzentriert) vor Lokal (in der Bibliothek)."
                )
            ]
        ),
        
        GrammarTopic(
            id: "b1_indirekte_fragen",
            title: "Indirekte Fragesätze (ob & W-Fragen)",
            subtitle: "Höfliche Fragen mit Verb-Endstellung",
            level: "B1",
            category: .satzbau,
            formula: "Einleitungssatz , [W-Wort / ob] + Subjekt + ... + [Verb am Ende]",
            explanation: "Bei indirekten Fragen mit Fragewort (wann, wo, warum) bleibt das W-Wort erhalten. Bei Ja/Nein-Fragen nutzt man 'ob'. Das Verb steht immer am Ende.",
            signalWords: ["ob", "wann", "warum", "wie viel", "wohin", "Können Sie mir sagen"],
            examples: [
                "Können Sie mir bitte sagen, wann der nächste Zug abfährt?",
                "Ich weiß noch nicht, ob ich morgen zur Party kommen kann."
            ],
            exercises: [
                GrammarExercise(
                    englishPrompt: "Can you please tell me when the next train departs?",
                    targetSentence: "Können Sie mir bitte sagen, wann der nächste Zug abfährt?",
                    ruleCallout: "Indirekte W-Frage: 'wann' leitet den Nebensatz ein, das Verb 'abfährt' steht am Ende."
                ),
                GrammarExercise(
                    englishPrompt: "I do not know yet whether I can come to the party tomorrow.",
                    targetSentence: "Ich weiß noch nicht, ob ich morgen zur Party kommen kann.",
                    ruleCallout: "Ja/Nein-Fragen werden mit 'ob' eingebettet; das konjugierte Verb (kann) steht ganz am Ende."
                )
            ]
        ),
        
        GrammarTopic(
            id: "b2_zweiteilige_konnektoren",
            title: "Zweiteilige Konnektoren (je...desto, zwar...aber)",
            subtitle: "Gehobene B2-Satzverbindungen",
            level: "B2",
            category: .satzbau,
            formula: "[Je + Komparativ + ... + Verb] , [desto + Komparativ + Verb + Subjekt]",
            explanation: "Bei 'je ... desto/umso' ist der erste Teil ein Nebensatz (Verb am Ende) und der zweite Teil ein Hauptsatz, bei dem das Verb direkt nach dem Komparativ folgt!",
            signalWords: ["je ... desto", "nicht nur ... sondern auch", "sowohl ... als auch", "zwar ... aber", "weder ... noch"],
            examples: [
                "Je mehr man auf Deutsch liest, desto größer wird der Wortschatz.",
                "Er spricht nicht nur fließend Deutsch, sondern versteht auch Schweizerdeutsch."
            ],
            exercises: [
                GrammarExercise(
                    englishPrompt: "The more one reads in German, the larger the vocabulary becomes.",
                    targetSentence: "Je mehr man auf Deutsch liest, desto größer wird der Wortschatz.",
                    ruleCallout: "Im 'Je'-Teilsatz steht das Verb am Ende (liest); nach 'desto + Komparativ' folgt direkt das Verb (wird)."
                ),
                GrammarExercise(
                    englishPrompt: "The apartment is indeed somewhat expensive, but it is located right in the center.",
                    targetSentence: "Die Wohnung ist zwar etwas teuer, aber sie liegt direkt im Zentrum.",
                    ruleCallout: "'zwar' schränkt im ersten Satz ein, 'aber' leitet den Gegengrund auf Position 0 ein."
                ),
                GrammarExercise(
                    englishPrompt: "She has neither answered the email nor called back today.",
                    targetSentence: "Sie hat heute weder die E-Mail beantwortet noch zurückgerufen.",
                    ruleCallout: "'weder ... noch' verneint beide Satzglieder ohne Komma."
                )
            ]
        ),
        
        GrammarTopic(
            id: "b2_adverbiale_konnektoren",
            title: "Adverbiale Konnektoren (deshalb, trotzdem, folglich)",
            subtitle: "Position 1 mit Inversion im Hauptsatz",
            level: "B2",
            category: .satzbau,
            formula: "Satz 1 . [Deshalb / Trotzdem / Dennoch] + [Verb] + [Subjekt] + ...",
            explanation: "Konjunktionaladverbien wie 'deshalb', 'trotzdem', 'dennoch', 'allerdings', 'folglich' und 'stattdessen' besetzen Position 1. Das konjugierte Verb muss direkt danach auf Position 2 stehen!",
            signalWords: ["deshalb", "trotzdem", "dennoch", "folglich", "allerdings", "stattdessen"],
            examples: [
                "Die Straßen waren vereist, deshalb fuhren alle Autos besonders vorsichtig.",
                "Das Projekt war sehr komplex, dennoch haben wir es rechtzeitig abgeschlossen."
            ],
            exercises: [
                GrammarExercise(
                    englishPrompt: "The roads were icy, therefore all cars drove especially carefully.",
                    targetSentence: "Die Straßen waren vereist, deshalb fuhren alle Autos besonders vorsichtig.",
                    ruleCallout: "'deshalb' steht auf Position 1 des zweiten Hauptsatzes -> sofort danach folgt das Verb 'fuhren'."
                ),
                GrammarExercise(
                    englishPrompt: "The project was very complex, nevertheless we completed it on time.",
                    targetSentence: "Das Projekt war sehr komplex, dennoch haben wir es rechtzeitig abgeschlossen.",
                    ruleCallout: "Nach 'dennoch' auf Position 1 erfolgt Inversion: 'haben wir'."
                )
            ]
        ),
        
        GrammarTopic(
            id: "b2_doppelter_infinitiv",
            title: "Doppelter Infinitiv im Nebensatz",
            subtitle: "Sonderstellung von 'haben' vor zwei Infinitiven",
            level: "B2",
            category: .satzbau,
            formula: "..., weil + Subjekt + ... + [hat / hätte] + [Verb im Infinitiv + Modalverb im Infinitiv]",
            explanation: "Im Perfekt, Plusquamperfekt oder Konjunktiv II mit Modalverben steht im Nebensatz das Hilfsverb 'haben/hätte' VOR den beiden Infinitiven am Satzende!",
            signalWords: ["hat machen müssen", "hätte sagen können", "hat arbeiten wollen"],
            examples: [
                "Er ärgert sich, weil er gestern Überstunden hat machen müssen.",
                "Sie sagte, dass man das Problem viel früher hätte lösen können."
            ],
            exercises: [
                GrammarExercise(
                    englishPrompt: "He is annoyed because he had to work overtime yesterday.",
                    targetSentence: "Er ärgert sich, weil er gestern Überstunden hat machen müssen.",
                    ruleCallout: "Bei Ersatzinfinitiv im Nebensatz steht 'hat' VOR den beiden Infinitiven: 'hat machen müssen'."
                ),
                GrammarExercise(
                    englishPrompt: "She said that one could have solved the problem much earlier.",
                    targetSentence: "Sie sagte, dass man das Problem viel früher hätte lösen können.",
                    ruleCallout: "'hätte' steht im Nebensatz vor dem doppelten Infinitiv 'lösen können'."
                )
            ]
        ),
        
        // ==========================================
        // 2. VERBEN, ZEITEN & MODI (B1 & B2)
        // ==========================================
        GrammarTopic(
            id: "b1_plusquamperfekt_nachdem",
            title: "Plusquamperfekt & 'nachdem'",
            subtitle: "Vorzeitigkeit in der Vergangenheit",
            level: "B1",
            category: .verben,
            formula: "[Nachdem + Subjekt + ... + Partizip II + hatte/war] , [Präteritum / Perfekt]",
            explanation: "Mit 'nachdem' beschreibt man eine Handlung, die komplett abgeschlossen war, bevor die nächste begann. Im 'nachdem'-Satz steht das Plusquamperfekt, im Hauptsatz Präteritum oder Perfekt.",
            signalWords: ["nachdem", "hatte + Partizip II", "war + Partizip II", "bevor"],
            examples: [
                "Nachdem er die Prüfung bestanden hatte, feierte er mit seinen Freunden.",
                "Nachdem sie in Hamburg angekommen war, rief sie sofort ihre Mutter an."
            ],
            exercises: [
                GrammarExercise(
                    englishPrompt: "After he had passed the exam, he celebrated with his friends.",
                    targetSentence: "Nachdem er die Prüfung bestanden hatte, feierte er mit seinen Freunden.",
                    ruleCallout: "'Nachdem'-Satz im Plusquamperfekt (bestanden hatte), Hauptsatz im Präteritum mit Inversion (feierte er)."
                ),
                GrammarExercise(
                    englishPrompt: "After she had arrived in Hamburg, she called her mother immediately.",
                    targetSentence: "Nachdem sie in Hamburg angekommen war, rief sie sofort ihre Mutter an.",
                    ruleCallout: "Bewegungsverben bilden das Plusquamperfekt mit 'war' (angekommen war)."
                )
            ]
        ),
        
        GrammarTopic(
            id: "b1_vorgangspassiv",
            title: "Vorgangspassiv (Präsens & Präteritum)",
            subtitle: "Fokus auf die Handlung statt auf den Täter",
            level: "B1",
            category: .verben,
            formula: "Subjekt + [werden / wurde] + (von + Dat / durch + Akk) + [Partizip II]",
            explanation: "Das Vorgangspassiv wird mit 'werden' (Präsens) oder 'wurde' (Präteritum) + Partizip II am Satzende gebildet. Personen nennt man mit 'von + Dativ', Mittel/Ursachen mit 'durch + Akkusativ'.",
            signalWords: ["wird ... gemacht", "wurde ... gebaut", "von + Dativ", "durch + Akkusativ"],
            examples: [
                "Das Paket wird heute Vormittag von der Post zugestellt.",
                "Die alte Brücke wurde im letzten Jahr komplett renoviert."
            ],
            exercises: [
                GrammarExercise(
                    englishPrompt: "The package is being delivered by the postal service this morning.",
                    targetSentence: "Das Paket wird heute Vormittag von der Post zugestellt.",
                    ruleCallout: "Passiv-Klammer: 'wird' auf Position 2 und das Partizip II 'zugestellt' ganz am Ende."
                ),
                GrammarExercise(
                    englishPrompt: "The old bridge was completely renovated last year.",
                    targetSentence: "Die alte Brücke wurde im letzten Jahr komplett renoviert.",
                    ruleCallout: "Passiv Präteritum: 'wurde' auf Position 2 + 'renoviert' am Satzende."
                )
            ]
        ),
        
        GrammarTopic(
            id: "b1_konjunktiv2_gegenwart",
            title: "Konjunktiv II (Gegenwart & Wünsche)",
            subtitle: "Irreale Bedingungen, Ratschläge & Höflichkeit",
            level: "B1",
            category: .verben,
            formula: "Wenn + Subjekt + ... + [wäre / hätte / würde] , [würde / wäre / hätte] + Subjekt + ...",
            explanation: "Der Konjunktiv II der Gegenwart drückt irreale Wünsche, höfliche Bitten und Ratschläge aus. Für sein/haben/Modalverben nutzt man die Originalformen (wäre, hätte, könnte, sollte).",
            signalWords: ["wäre", "hätte", "würde + Infinitiv", "könnte", "sollte", "Wenn ich ... wäre"],
            examples: [
                "Wenn ich mehr Freizeit hätte, würde ich ein Musikinstrument lernen.",
                "An deiner Stelle würde ich vor dem Kauf die Bewertungen lesen."
            ],
            exercises: [
                GrammarExercise(
                    englishPrompt: "If I had more free time, I would learn a musical instrument.",
                    targetSentence: "Wenn ich mehr Freizeit hätte, würde ich ein Musikinstrument lernen.",
                    ruleCallout: "Irrealer Bedingungssatz: 'hätte' am Ende des Wenn-Satzes, 'würde ich ... lernen' im Hauptsatz."
                ),
                GrammarExercise(
                    englishPrompt: "In your place, I would read the reviews before buying.",
                    targetSentence: "An deiner Stelle würde ich vor dem Kauf die Bewertungen lesen.",
                    ruleCallout: "'An deiner Stelle' steht auf Position 1, gefolgt von 'würde ich' und dem Infinitiv 'lesen' am Ende."
                )
            ]
        ),
        
        GrammarTopic(
            id: "b2_konjunktiv2_vergangenheit",
            title: "Konjunktiv II der Vergangenheit",
            subtitle: "Irreale Vergangenheit & nachträgliche Kritik",
            level: "B2",
            category: .verben,
            formula: "Wenn + ... + [Partizip II + hätte / wäre] , [hätte / wäre] + Subjekt + ... + [Partizip II]",
            explanation: "Um über Dinge in der Vergangenheit zu sprechen, die nicht mehr zu ändern sind, nutzt man 'hätte' oder 'wäre' + Partizip II.",
            signalWords: ["hätte ... gemacht", "wäre ... geblieben", "hätte machen sollen"],
            examples: [
                "Wenn wir früher losgefahren wären, hätten wir den Zug nicht verpasst.",
                "Du hättest mir das Problem sofort ehrlich erklären sollen."
            ],
            exercises: [
                GrammarExercise(
                    englishPrompt: "If we had left earlier, we would not have missed the train.",
                    targetSentence: "Wenn wir früher losgefahren wären, hätten wir den Zug nicht verpasst.",
                    ruleCallout: "Konjunktiv II Vergangenheit: 'losgefahren wären' im Nebensatz, 'hätten wir ... verpasst' im Hauptsatz."
                ),
                GrammarExercise(
                    englishPrompt: "You should have explained the problem to me honestly right away.",
                    targetSentence: "Du hättest mir das Problem sofort ehrlich erklären sollen.",
                    ruleCallout: "'hättest' auf Position 2 + doppelter Infinitiv 'erklären sollen' am Satzende."
                )
            ]
        ),
        
        GrammarTopic(
            id: "b2_passiv_modalverben_ersatz",
            title: "Passiv mit Modalverben & Passiversatz",
            subtitle: "sein + zu + Infinitiv & sich lassen + Infinitiv",
            level: "B2",
            category: .verben,
            formula: "Subjekt + [muss + ... + Partizip II + werden]  ≈  Subjekt + [ist + ... + zu + Infinitiv]",
            explanation: "Statt 'kann/muss gemacht werden' nutzt man auf B2-Niveau oft elegante Passiversatzformen: 'lässt sich + Infinitiv' (kann gemacht werden) oder 'ist + zu + Infinitiv' (muss/kann gemacht werden).",
            signalWords: ["muss ... werden", "lässt sich + Infinitiv", "ist ... zu + Infinitiv", "-bar / -lich"],
            examples: [
                "Der Antrag muss bis spätestens Freitag im Büro eingereicht werden.",
                "Dieses technische Problem lässt sich mit einem Update leicht beheben."
            ],
            exercises: [
                GrammarExercise(
                    englishPrompt: "The application must be submitted to the office by Friday at the latest.",
                    targetSentence: "Der Antrag muss bis spätestens Freitag im Büro eingereicht werden.",
                    ruleCallout: "Passiv mit Modalverb: 'muss' auf Position 2, 'eingereicht werden' (Partizip II + werden) am Ende."
                ),
                GrammarExercise(
                    englishPrompt: "This technical problem can easily be fixed with an update.",
                    targetSentence: "Dieses technische Problem lässt sich mit einem Update leicht beheben.",
                    ruleCallout: "'lässt sich ... beheben' ersetzt 'kann behoben werden' im gehobenen B2-Stil."
                ),
                GrammarExercise(
                    englishPrompt: "The safety rules are to be strictly observed by all employees.",
                    targetSentence: "Die Sicherheitsregeln sind von allen Mitarbeitern strikt zu beachten.",
                    ruleCallout: "'sind ... zu beachten' entspricht 'müssen beachtet werden'."
                )
            ]
        ),
        
        GrammarTopic(
            id: "b2_subjektive_modalverben",
            title: "Subjektive Modalverben (Vermutungen)",
            subtitle: "Wahrscheinlichkeit & fremde Behauptungen ausdrücken",
            level: "B2",
            category: .verben,
            formula: "Subjekt + [muss / dürfte / könnte / soll / will] + ... + [Infinitiv I / Partizip II + haben/sein]",
            explanation: "Modalverben drücken auf B2-Niveau auch Vermutungen aus: 'muss' (~95% sicher), 'dürfte' (~75% wahrscheinlich), 'könnte' (~50% möglich). 'soll' bedeutet 'Man sagt, dass...', 'will' bedeutet 'Er behauptet über sich selbst'.",
            signalWords: ["muss wohl", "dürfte", "soll ... sein", "will ... gewesen sein"],
            examples: [
                "Das Licht brennt noch, also muss mein Mitbewohner zu Hause sein.",
                "Die neue Direktorin soll mehrere Jahre im Ausland gearbeitet haben."
            ],
            exercises: [
                GrammarExercise(
                    englishPrompt: "The light is still on, so my roommate must be at home.",
                    targetSentence: "Das Licht brennt noch, also muss mein Mitbewohner zu Hause sein.",
                    ruleCallout: "'muss ... sein' drückt eine fast sichere logische Schlussfolgerung aus."
                ),
                GrammarExercise(
                    englishPrompt: "The new director is said to have worked abroad for several years.",
                    targetSentence: "Die neue Direktorin soll mehrere Jahre im Ausland gearbeitet haben.",
                    ruleCallout: "'soll ... gearbeitet haben' gibt ein Gerücht über die Vergangenheit wieder (Infinitiv Perfekt am Ende)."
                )
            ]
        ),
        
        GrammarTopic(
            id: "b2_konjunktiv1_indirekte_rede",
            title: "Konjunktiv I (Indirekte Rede)",
            subtitle: "Neutrale Wiedergabe in Nachrichten & Berichten",
            level: "B2",
            category: .verben,
            formula: "Der Sprecher betonte, [Subjekt + sei / habe / werde + ...]",
            explanation: "In formellen Texten und Nachrichten gibt man Aussagen Dritter im Konjunktiv I wieder (er sei, er habe, es gebe, sie komme). Wenn Konjunktiv I mit dem Indikativ identisch ist (z.B. 'sie haben'), weicht man auf Konjunktiv II ('sie hätten') aus.",
            signalWords: ["er sei", "er habe", "es gebe", "laut Experten", "betonte, dass"],
            examples: [
                "Der Minister erklärte, die wirtschaftliche Lage sei derzeit stabil.",
                "Die Zeugin gab an, sie habe den Vorfall genau beobachtet."
            ],
            exercises: [
                GrammarExercise(
                    englishPrompt: "The minister explained that the economic situation is currently stable.",
                    targetSentence: "Der Minister erklärte, die wirtschaftliche Lage sei derzeit stabil.",
                    ruleCallout: "Ohne 'dass' bleibt das Verb im Konjunktiv I ('sei') auf Position 2 des indirekten Satzes."
                ),
                GrammarExercise(
                    englishPrompt: "The witness stated that she had observed the incident closely.",
                    targetSentence: "Die Zeugin gab an, sie habe den Vorfall genau beobachtet.",
                    ruleCallout: "Für die Vergangenheit in der indirekten Rede nutzt man 'habe/sei + Partizip II'."
                )
            ]
        ),
        
        GrammarTopic(
            id: "b2_funktionsverbgefuege",
            title: "Funktionsverbgefüge (Nomen-Verb)",
            subtitle: "Gehobener Ausdruck im Beruf & Alltag",
            level: "B2",
            category: .verben,
            formula: "Subjekt + [konjugiertes Funktionsverb] + ... + [Präposition + Nomen]",
            explanation: "Feste Nomen-Verb-Verbindungen (wie 'eine Entscheidung treffen', 'zur Verfügung stehen', 'in Kauf nehmen') bilden eine Satzklammer: Das Nomen steht möglichst weit hinten vor dem Satzende.",
            signalWords: ["eine Entscheidung treffen", "zur Verfügung stehen", "in Frage kommen", "Rücksicht nehmen auf"],
            examples: [
                "Der Vorstand wird morgen eine endgültige Entscheidung treffen.",
                "Beim Umzug sollten wir unbedingt auf die älteren Nachbarn Rücksicht nehmen."
            ],
            exercises: [
                GrammarExercise(
                    englishPrompt: "The board will make a final decision tomorrow.",
                    targetSentence: "Der Vorstand wird morgen eine endgültige Entscheidung treffen.",
                    ruleCallout: "'eine Entscheidung treffen' bildet das Funktionsverbgefüge am Satzende."
                ),
                GrammarExercise(
                    englishPrompt: "Our customer service is at your disposal around the clock.",
                    targetSentence: "Unser Kundenservice steht Ihnen rund um die Uhr zur Verfügung.",
                    ruleCallout: "'steht ... zur Verfügung': Das Verb steht auf Position 2, 'zur Verfügung' schließt die Satzklammer."
                )
            ]
        ),
        
        // ==========================================
        // 3. KASUS, KONNEKTOREN & NOMEN (B1 & B2)
        // ==========================================
        GrammarTopic(
            id: "b1_relativsaetze_kasus",
            title: "Relativsätze (Nom, Akk, Dat & Präposition)",
            subtitle: "Bezugswort-Genus + Kasus im Relativsatz",
            level: "B1",
            category: .kasus,
            formula: "Bezugsnomen , [(Präposition) + der/den/dem/die/das + ... + Verb am Ende]",
            explanation: "Das Relativpronomen richtet sich im Genus (m/f/n/Pl) nach dem Bezugswort im Hauptsatz, aber im Kasus (Nom/Akk/Dat/Gen) nach seiner Funktion oder Präposition im Relativsatz!",
            signalWords: ["der / den / dem", "die / der", "das / dem", "über den", "mit der"],
            examples: [
                "Das ist der Kollege, mit dem ich täglich im selben Büro arbeite.",
                "Der Roman, über den alle Kritiker sprechen, hat einen Preis gewonnen."
            ],
            exercises: [
                GrammarExercise(
                    englishPrompt: "That is the colleague with whom I work daily in the same office.",
                    targetSentence: "Das ist der Kollege, mit dem ich täglich im selben Büro arbeite.",
                    ruleCallout: "'mit' verlangt den Dativ -> maskulin Dativ 'mit dem'; das Verb 'arbeite' steht am Ende."
                ),
                GrammarExercise(
                    englishPrompt: "The novel that all critics are talking about won a prize.",
                    targetSentence: "Der Roman, über den alle Kritiker sprechen, hat einen Preis gewonnen.",
                    ruleCallout: "'sprechen über + Akkusativ' -> 'über den'; der eingeschobene Relativsatz wird durch Kommas getrennt."
                )
            ]
        ),
        
        GrammarTopic(
            id: "b1_verben_praepositionen",
            title: "Verben mit Präpositionen & Pronominaladverbien",
            subtitle: "darauf / worauf, davon / wovon",
            level: "B1",
            category: .kasus,
            formula: "Sachen: [darauf / davon] , dass ...  |  Personen: [auf ihn / von ihr]",
            explanation: "Verben mit fester Präposition (warten auf + Akk, abhängen von + Dat, sich freuen auf/über + Akk) nutzen bei Sachen 'da(r)- + Präposition' als Platzhalter für einen dass- oder Infinitivsatz.",
            signalWords: ["sich verlassen auf", "abhängen von", "darauf, dass", "worüber"],
            examples: [
                "Ich verlasse mich fest darauf, dass du mich morgen pünktlich abholst.",
                "Unser Erfolg hängt stark von einer guten Vorbereitung ab."
            ],
            exercises: [
                GrammarExercise(
                    englishPrompt: "I firmly rely on you picking me up on time tomorrow.",
                    targetSentence: "Ich verlasse mich fest darauf, dass du mich morgen pünktlich abholst.",
                    ruleCallout: "'sich verlassen auf' + Nebensatz erfordert das Pronominaladverb 'darauf' im Hauptsatz."
                ),
                GrammarExercise(
                    englishPrompt: "Our success depends strongly on good preparation.",
                    targetSentence: "Unser Erfolg hängt stark von einer guten Vorbereitung ab.",
                    ruleCallout: "'abhängen von + Dativ': 'hängt' auf Position 2, 'von einer guten Vorbereitung', Präfix 'ab' am Ende."
                )
            ]
        ),
        
        GrammarTopic(
            id: "b1_n_deklination",
            title: "N-Deklination (schwache Maskulina)",
            subtitle: "-en / -n in Akkusativ, Dativ und Genitiv",
            level: "B1",
            category: .kasus,
            formula: "Nominativ: der Student / Kunde / Mensch  ➔  Akk/Dat/Gen: den/dem/des Studenten",
            explanation: "Maskuline Nomen der N-Deklination (oft Personen/Tiere auf -e, -ent, -ant, -ist, -oge) erhalten in allen Kasus außer dem Nominativ Singular die Endung -(e)n.",
            signalWords: ["den Kunden", "dem Kollegen", "des Präsidenten", "des Namens", "dem Nachbarn"],
            examples: [
                "Die Ärztin untersucht den jungen Patienten sehr gründlich.",
                "Wir haben gestern lange mit unserem neuen Nachbarn gesprochen."
            ],
            exercises: [
                GrammarExercise(
                    englishPrompt: "The doctor examines the young patient very thoroughly.",
                    targetSentence: "Die Ärztin untersucht den jungen Patienten sehr gründlich.",
                    ruleCallout: "'der Patient' gehört zur N-Deklination -> im Akkusativ Singular: 'den jungen Patienten'."
                ),
                GrammarExercise(
                    englishPrompt: "We spoke for a long time with our new neighbor yesterday.",
                    targetSentence: "Wir haben gestern lange mit unserem neuen Nachbarn gesprochen.",
                    ruleCallout: "'der Nachbar' erhält im Dativ Singular die Endung -n: 'mit unserem neuen Nachbarn'."
                )
            ]
        ),
        
        GrammarTopic(
            id: "b2_genitiv_praepositionen",
            title: "Genitiv-Präpositionen (trotz, während, aufgrund)",
            subtitle: "Nominalstil für Kausal-, Konzessiv- und Temporalsätze",
            level: "B2",
            category: .kasus,
            formula: "[Trotz / Während / Aufgrund / Wegen] + [des / eines / der] + Adjektiv(-en) + Nomen(-s)",
            explanation: "Präpositionen wie 'während', 'wegen', 'trotz', '(an)statt', 'aufgrund', 'infolge' und 'angesichts' verlangen den Genitiv. Sie ersetzen ganze Nebensätze durch kompakte B2-Nominalphrasen.",
            signalWords: ["trotz + Gen", "während + Gen", "aufgrund + Gen", "infolge + Gen", "angesichts + Gen"],
            examples: [
                "Trotz des starken Schneefalls landete das Flugzeug pünktlich.",
                "Aufgrund einer technischen Störung fällt der heutige Zug leider aus."
            ],
            exercises: [
                GrammarExercise(
                    englishPrompt: "Despite the heavy snowfall, the plane landed on time.",
                    targetSentence: "Trotz des starken Schneefalls landete das Flugzeug pünktlich.",
                    ruleCallout: "'Trotz + Genitiv' (des starken Schneefalls) steht auf Position 1, danach folgt direkt das Verb 'landete'."
                ),
                GrammarExercise(
                    englishPrompt: "Due to a technical malfunction, today's train is unfortunately canceled.",
                    targetSentence: "Aufgrund einer technischen Störung fällt der heutige Zug leider aus.",
                    ruleCallout: "'Aufgrund + Genitiv' (einer technischen Störung) auf Position 1, Verb 'fällt' auf Position 2."
                )
            ]
        ),
        
        GrammarTopic(
            id: "b2_relativsaetze_genitiv_wo_was",
            title: "Relativsätze im Genitiv (dessen / deren & was)",
            subtitle: "Besitzverhältnisse und Bezüge auf ganze Sätze",
            level: "B2",
            category: .kasus,
            formula: "Bezugswort , [dessen (m/n) / deren (f/Pl) + Nomen ohne Artikel + ... + Verb]",
            explanation: "'dessen' (maskulin/neutral) und 'deren' (feminin/Plural) drücken Besitz im Relativsatz aus; nach ihnen steht kein Artikel! Nach 'alles', 'nichts', 'etwas' oder einem ganzen Satz nutzt man 'was'.",
            signalWords: ["dessen", "deren", "alles, was", "das Beste, was", "worüber"],
            examples: [
                "Der Autor, dessen neues Buch gestern erschien, gibt heute ein Interview.",
                "Die Firma hat ihren Umsatz verdoppelt, was alle Experten überraschte."
            ],
            exercises: [
                GrammarExercise(
                    englishPrompt: "The author whose new book came out yesterday is giving an interview today.",
                    targetSentence: "Der Autor, dessen neues Buch gestern erschien, gibt heute ein Interview.",
                    ruleCallout: "Nach 'dessen' steht kein Artikel, und das Adjektiv wird stark dekliniert ('dessen neues Buch')."
                ),
                GrammarExercise(
                    englishPrompt: "The company doubled its revenue, which surprised all experts.",
                    targetSentence: "Die Firma hat ihren Umsatz verdoppelt, was alle Experten überraschte.",
                    ruleCallout: "Bezieht sich der Relativsatz auf den gesamten vorherigen Satz, leitet man ihn mit 'was' ein."
                )
            ]
        ),
        
        GrammarTopic(
            id: "b2_partizipialattribute",
            title: "Partizip I & II als Adjektive (Partizipialattribute)",
            subtitle: "Kompakte B2-Attribute statt langer Relativsätze",
            level: "B2",
            category: .kasus,
            formula: "Artikel + [Erweiterung + Partizip I (-end) / Partizip II + Adjektivendung] + Nomen",
            explanation: "Partizip I (Infinitiv + d: 'steigend') ist aktiv & gleichzeitig. Partizip II ('gelöst') ist passiv oder abgeschlossen. Auf B2-Niveau stehen ganze Wortgruppen zwischen Artikel und Nomen.",
            signalWords: ["die steigenden Kosten", "das gestern gelöste Problem", "der schnell wachsende Markt"],
            examples: [
                "Die im Vertrag festgelegten Bedingungen gelten ab dem nächsten Monat.",
                "Wir suchen nach einer für beide Seiten zufriedenstellenden Lösung."
            ],
            exercises: [
                GrammarExercise(
                    englishPrompt: "The conditions stipulated in the contract apply starting next month.",
                    targetSentence: "Die im Vertrag festgelegten Bedingungen gelten ab dem nächsten Monat.",
                    ruleCallout: "Zwischen 'Die' und 'Bedingungen' steht das erweiterte Partizip II 'im Vertrag festgelegten'."
                ),
                GrammarExercise(
                    englishPrompt: "We are looking for a solution that is satisfactory for both sides.",
                    targetSentence: "Wir suchen nach einer für beide Seiten zufriedenstellenden Lösung.",
                    ruleCallout: "Partizip I mit Erweiterung ('für beide Seiten zufriedenstellenden') steht direkt vor dem Nomen 'Lösung'."
                )
            ]
        ),
        
        GrammarTopic(
            id: "b2_nominalisierung_verbalisierung",
            title: "Nominalisierung & Verbalisierung",
            subtitle: "Nebensätze in kompakte Nominalphrasen umwandeln",
            level: "B2",
            category: .kasus,
            formula: "Verbal: [Weil / Wenn / Bevor + Subjekt + Verb]  ➔  Nominal: [Präposition + Nomen + Genitiv]",
            explanation: "In der Wissenschafts-, Nachrichten- und Berufssprache (B2/C1) ersetzt man Nebensätze häufig durch Präposition + Nomen im Dativ/Genitiv (z.B. 'Vor Beginn der Konferenz' statt 'Bevor die Konferenz beginnt').",
            signalWords: ["bei + Dat (wenn)", "vor/nach + Dat (bevor/nachdem)", "durch + Akk (indem)", "zur + Dat (um ... zu)"],
            examples: [
                "Vor dem Abschluss des Vertrags sollten Sie alle Klauseln genau prüfen.",
                "Durch regelmäßiges Lesen anspruchsvoller Texte verbessert sich das Sprachgefühl."
            ],
            exercises: [
                GrammarExercise(
                    englishPrompt: "Before signing the contract, you should check all clauses carefully.",
                    targetSentence: "Vor dem Abschluss des Vertrags sollten Sie alle Klauseln genau prüfen.",
                    ruleCallout: "Nominalisierung mit 'Vor + Dativ + Genitiv' auf Position 1, danach folgt direkt das Verb 'sollten'."
                ),
                GrammarExercise(
                    englishPrompt: "By regularly reading demanding texts, one's feel for the language improves.",
                    targetSentence: "Durch regelmäßiges Lesen anspruchsvoller Texte verbessert sich das Sprachgefühl.",
                    ruleCallout: "Modale Nominalisierung ('Durch regelmäßiges Lesen...') auf Position 1 -> Verb 'verbessert' auf Position 2."
                )
            ]
        )
    ]
}
