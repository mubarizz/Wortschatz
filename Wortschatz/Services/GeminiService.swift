import Foundation

// MARK: - Gemini Candidate Model
public struct GeminiWordCandidate: Identifiable, Codable, Equatable {
    public var id: UUID
    public var articleOrType: String
    public var word: String
    public var cefrLevel: String
    public var englishDefinition: String
    public var germanDefinition: String
    public var b1Example: String
    public var b2Example: String
    
    enum CodingKeys: String, CodingKey {
        case articleOrType
        case word
        case cefrLevel
        case englishDefinition
        case germanDefinition
        case b1Example
        case b2Example
    }
    
    public init(
        id: UUID = UUID(),
        articleOrType: String,
        word: String,
        cefrLevel: String = "B1",
        englishDefinition: String,
        germanDefinition: String,
        b1Example: String,
        b2Example: String
    ) {
        self.id = id
        self.articleOrType = articleOrType
        self.word = word
        self.cefrLevel = cefrLevel
        self.englishDefinition = englishDefinition
        self.germanDefinition = germanDefinition
        self.b1Example = b1Example
        self.b2Example = b2Example
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = UUID()
        self.articleOrType = try container.decode(String.self, forKey: .articleOrType)
        self.word = try container.decode(String.self, forKey: .word)
        self.cefrLevel = (try? container.decode(String.self, forKey: .cefrLevel)) ?? "B1"
        self.englishDefinition = try container.decode(String.self, forKey: .englishDefinition)
        self.germanDefinition = try container.decode(String.self, forKey: .germanDefinition)
        self.b1Example = try container.decode(String.self, forKey: .b1Example)
        self.b2Example = try container.decode(String.self, forKey: .b2Example)
    }
    
    public func toVocabularyWord() -> VocabularyWord {
        let cleanLemma = stripRedundantArticle(from: word)
        return VocabularyWord(
            articleOrType: articleOrType.trimmingCharacters(in: .whitespacesAndNewlines),
            word: cleanLemma,
            englishDefinition: englishDefinition.trimmingCharacters(in: .whitespacesAndNewlines),
            germanDefinition: germanDefinition.trimmingCharacters(in: .whitespacesAndNewlines),
            b1Example: b1Example.trimmingCharacters(in: .whitespacesAndNewlines),
            b2Example: b2Example.trimmingCharacters(in: .whitespacesAndNewlines),
            cefrLevel: cefrLevel.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        )
    }
    
    private func stripRedundantArticle(from raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        for prefix in ["der ", "die ", "das "] {
            if trimmed.lowercased().hasPrefix(prefix) {
                return String(trimmed.dropFirst(prefix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        return trimmed
    }
}

private struct GeminiCandidateListResponse: Codable {
    let candidates: [GeminiWordCandidate]
}

private struct GeminiGeneratedSchreibenTaskResponse: Codable {
    let title: String
    let situation: String
    let leitpunkte: [String]
    let registerHint: String
}

// MARK: - Gemini API Errors
public enum GeminiServiceError: LocalizedError {
    case missingAPIKey
    case emptyQuery
    case invalidResponse
    case apiError(String)
    
    public var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "Kein Gemini API-Schlüssel hinterlegt. Bitte gib deinen API-Schlüssel ein."
        case .emptyQuery:
            return "Bitte gib ein deutsches oder englisches Suchwort ein."
        case .invalidResponse:
            return "Unerwartete Antwort von der Gemini API. Bitte versuche es erneut."
        case .apiError(let message):
            return message
        }
    }
}

// MARK: - Gemini Service
public final class GeminiService: ObservableObject {
    public static let shared = GeminiService()
    
    private let apiKeyDefaultsKey = "wortschatz_gemini_api_key"
    private var queryCache: [String: [GeminiWordCandidate]] = [:]
    
    @Published public private(set) var lastUsedModel: String = "gemini-3-flash-preview"
    
    @Published public var apiKey: String {
        didSet {
            let trimmed = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
            UserDefaults.standard.set(trimmed, forKey: apiKeyDefaultsKey)
            SharedLookupBridge.shared.saveSharedGeminiAPIKey(trimmed)
            queryCache.removeAll()
        }
    }
    
    private init() {
        let saved = UserDefaults.standard.string(forKey: apiKeyDefaultsKey)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !saved.isEmpty {
            self.apiKey = saved
            SharedLookupBridge.shared.saveSharedGeminiAPIKey(saved)
        } else if let sharedKey = SharedLookupBridge.shared.loadSharedGeminiAPIKey(), !sharedKey.isEmpty {
            self.apiKey = sharedKey
        } else if let envKey = ProcessInfo.processInfo.environment["GEMINI_API_KEY"], !envKey.isEmpty {
            self.apiKey = envKey
            SharedLookupBridge.shared.saveSharedGeminiAPIKey(envKey)
        } else {
            self.apiKey = ""
        }
    }
    
    public var hasValidKey: Bool {
        !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    /// Queries Gemini 3 Flash with zero thinking overhead (~1.8–2.1s latency) for 3 German vocabulary candidates across CEFR levels (A1–C2), with automatic zero-key fallback to Wiktionary DE+EN lexicon
    public func searchWords(query: String) async throws -> [GeminiWordCandidate] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else {
            throw GeminiServiceError.emptyQuery
        }
        
        let cacheKey = trimmedQuery.lowercased()
        if let cached = queryCache[cacheKey], !cached.isEmpty {
            return cached
        }
        
        let currentKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if currentKey.isEmpty {
            let fallbackCandidates = await SharedLookupBridge.shared.lookupViaWiktionary(query: trimmedQuery)
            if !fallbackCandidates.isEmpty {
                await MainActor.run {
                    self.lastUsedModel = "Wiktionary DE/EN"
                    self.queryCache[cacheKey] = fallbackCandidates
                }
                return fallbackCandidates
            }
            throw GeminiServiceError.missingAPIKey
        }
        
        // Benchmarked models ordered by ~2.0s latency with thinkingBudget: 0 enabled
        let modelConfigs: [(name: String, disableThinking: Bool)] = [
            ("gemini-3-flash-preview", true),
            ("gemini-3.1-flash-lite", true),
            ("gemini-flash-lite-latest", false)
        ]
        var lastError: Error = GeminiServiceError.invalidResponse
        
        for config in modelConfigs {
            do {
                let candidates = try await performRequest(
                    query: trimmedQuery,
                    apiKey: currentKey,
                    model: config.name,
                    disableThinking: config.disableThinking
                )
                await MainActor.run {
                    self.lastUsedModel = config.name
                    self.queryCache[cacheKey] = candidates
                }
                return candidates
            } catch let error as GeminiServiceError {
                lastError = error
                // Stop immediately only if the API key itself is rejected as invalid
                if case .apiError(let msg) = error,
                   (msg.contains("API_KEY_INVALID") || msg.contains("API key not valid") || msg.contains("(401)")) {
                    break
                }
                continue
            } catch {
                lastError = error
                continue
            }
        }
        
        // Fallback to Wiktionary DE+EN so lookup never fails even if API key quota is exceeded
        let fallbackCandidates = await SharedLookupBridge.shared.lookupViaWiktionary(query: trimmedQuery)
        if !fallbackCandidates.isEmpty {
            await MainActor.run {
                self.lastUsedModel = "Wiktionary DE/EN"
                self.queryCache[cacheKey] = fallbackCandidates
            }
            return fallbackCandidates
        }
        
        throw lastError
    }
    
    private func performRequest(
        query: String,
        apiKey: String,
        model: String,
        disableThinking: Bool
    ) async throws -> [GeminiWordCandidate] {
        guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent?key=\(apiKey)") else {
            throw GeminiServiceError.invalidResponse
        }
        
        let prompt = """
        You are an authoritative German-English lexicographer (CEFR A1-C2).
        User search query: "\(query)".

        TASK:
        Return 3 highly accurate German vocabulary entries that directly answer the query "\(query)":

        CASE 1 — If "\(query)" is a German word (including conjugated verbs, declined nouns/adjectives, plurals, participles, or phrases):
        - Candidate 1 MUST be the exact canonical German base lemma (Grundform) of "\(query)" in its primary meaning.
        - Candidate 2:
          * If the word has a second distinct meaning, homonym, or part of speech (e.g. "das Schloss" = castle vs. lock; "überlegen" = Verb [to consider] vs. Adjektiv [superior]; "ausmachen" = to switch off vs. to agree upon / matter; "umfahren" = to drive around vs. to run over; "der/die Leiter"; "anhalten"; "geraten"), Candidate 2 MUST be that second distinct meaning or part of speech of the SAME word.
          * Otherwise, Candidate 2 MUST be a direct fixed expression, reflexive/prepositional usage (e.g. "sich entscheiden für + Akk.", "Eindruck hinterlassen"), or direct word-family derivative of "\(query)" (sharing the same root stem).
        - Candidate 3:
          * Either a third distinct meaning/collocation of "\(query)", or one strict, interchangeable synonym with the EXACT same meaning and part of speech as Candidate 1.
          * NEVER return loosely associated objects or unrelated words (e.g. NEVER return "Schlüssel" for "Schloss").

        CASE 2 — If "\(query)" is an English word or phrase (e.g. "sustainable", "apply", "decision"):
        - Return the 3 best German translations for "\(query)" (ordered from the most direct everyday lemma to B2/C1 nuances). Never return the English word itself as the German lemma.

        STRICT FIELD RULES:
        - articleOrType: MUST be exact: "der", "die", "das" (for nouns — double-check grammatical gender!), "Verb", "Adjektiv", "Adverb", or "Ausdruck".
        - word: Canonical German lemma WITHOUT leading article (der/die/das).
        - cefrLevel: "A1", "A2", "B1", "B2", "C1", or "C2".
        - englishDefinition: Precise English translation of THIS specific meaning.
        - germanDefinition: Clear German explanation of THIS specific meaning WITHOUT using the target word itself.
        - b1Example: Natural German B1 sentence demonstrating THIS specific meaning.
        - b2Example: Rich German B2 sentence demonstrating THIS specific meaning.
        """
        
        var generationConfig: [String: Any] = [
            "temperature": 0.1,
            "responseMimeType": "application/json",
            "responseSchema": [
                "type": "OBJECT",
                "properties": [
                    "candidates": [
                        "type": "ARRAY",
                        "items": [
                            "type": "OBJECT",
                            "properties": [
                                "articleOrType": ["type": "STRING"],
                                "word": ["type": "STRING"],
                                "cefrLevel": ["type": "STRING"],
                                "englishDefinition": ["type": "STRING"],
                                "germanDefinition": ["type": "STRING"],
                                "b1Example": ["type": "STRING"],
                                "b2Example": ["type": "STRING"]
                            ],
                            "required": [
                                "articleOrType",
                                "word",
                                "cefrLevel",
                                "englishDefinition",
                                "germanDefinition",
                                "b1Example",
                                "b2Example"
                            ]
                        ]
                    ]
                ],
                "required": ["candidates"]
            ]
        ]
        
        // Disable internal thinking tokens so Gemini 3 Flash responds in ~1.8-2.0s instead of 15-25s
        if disableThinking {
            generationConfig["thinkingConfig"] = [
                "thinkingBudget": 0
            ]
        }
        
        let requestBody: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        ["text": prompt]
                    ]
                ]
            ],
            "generationConfig": generationConfig
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 12.0
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
        
        guard statusCode == 200 else {
            if let errorJSON = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let errorObj = errorJSON["error"] as? [String: Any],
               let message = errorObj["message"] as? String {
                throw GeminiServiceError.apiError("Gemini API Fehler (\(statusCode)): \(message)")
            }
            throw GeminiServiceError.apiError("HTTP Fehler \(statusCode)")
        }
        
        guard let rootJSON = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let candidatesArray = rootJSON["candidates"] as? [[String: Any]],
              let firstCandidate = candidatesArray.first,
              let content = firstCandidate["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]],
              let textPart = parts.last(where: { ($0["thought"] as? Bool) != true }) ?? parts.last,
              let text = textPart["text"] as? String,
              let jsonData = text.data(using: .utf8) else {
            throw GeminiServiceError.invalidResponse
        }
        
        let decoded = try JSONDecoder().decode(GeminiCandidateListResponse.self, from: jsonData)
        return decoded.candidates
    }
    
    // MARK: - Goethe-Institut Schreiben Examiner (B1 & B2)
    /// Evaluates a user's German B1/B2 Schreiben exam text using official Goethe-Institut 4-criterion rubric (100 points total).
    public func evaluateSchreiben(
        task: SchreibenTask,
        userText: String
    ) async throws -> SchreibenEvaluationResult {
        let trimmedText = userText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else {
            throw GeminiServiceError.apiError("Bitte schreibe zuerst deinen Text, bevor du die Prüfung abgibst.")
        }
        
        let currentKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !currentKey.isEmpty else {
            throw GeminiServiceError.missingAPIKey
        }
        
        let modelConfigs: [(name: String, disableThinking: Bool)] = [
            ("gemini-3-flash-preview", true),
            ("gemini-3.1-flash-lite", true),
            ("gemini-flash-lite-latest", false),
            ("gemini-3.5-flash-lite", false)
        ]
        var lastError: Error = GeminiServiceError.invalidResponse
        
        for config in modelConfigs {
            do {
                let evaluation = try await performSchreibenEvaluationRequest(
                    task: task,
                    userText: trimmedText,
                    apiKey: currentKey,
                    model: config.name,
                    disableThinking: config.disableThinking
                )
                await MainActor.run {
                    self.lastUsedModel = config.name
                }
                return evaluation
            } catch let error as GeminiServiceError {
                lastError = error
                if case .apiError(let msg) = error,
                   (msg.contains("API_KEY_INVALID") || msg.contains("API key not valid") || msg.contains("(401)")) {
                    throw error
                }
                continue
            } catch {
                lastError = error
                continue
            }
        }
        
        throw lastError
    }
    
    private func performSchreibenEvaluationRequest(
        task: SchreibenTask,
        userText: String,
        apiKey: String,
        model: String,
        disableThinking: Bool
    ) async throws -> SchreibenEvaluationResult {
        guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent?key=\(apiKey)") else {
            throw GeminiServiceError.invalidResponse
        }
        
        let wordCount = userText.split { $0.isWhitespace || $0.isNewline }.count
        let leitpunkteFormatted = task.leitpunkte.enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: "\n")
        
        let prompt = """
        Du bist ein zertifizierter Prüfer des Goethe-Instituts für das \(task.level.title) (\(task.teil.fullTitle)).
        Bewerte den folgenden Prüfungstext streng, fair und objektiv nach den offiziellen Bewertungskriterien des Goethe-Instituts.
        
        AUFGABENSTELLUNG:
        - Niveau & Teil: \(task.teil.fullTitle)
        - Titel: \(task.title)
        - Situation: \(task.situation)
        - Geforderte Leitpunkte:
        \(leitpunkteFormatted)
        - Ziel-Wortanzahl: ca. \(task.targetWords) Wörter
        - Gefordertes Register: \(task.registerHint)
        
        EINGEREICHTER TEXT DES KANDIDATEN (\(wordCount) Wörter):
        \"\"\"
        \(userText)
        \"\"\"
        
        BEWERTUNGSREGELN (Goethe-Institut Maßstab, insgesamt 0 bis 100 Punkte, Bestehensgrenze = 60 Punkte):
        1. erfuellungScore (0-25 Punkte):
           - Wurden ALLE Leitpunkte inhaltlich sinnvoll bearbeitet?
           - Passt das Register (Du-Form vs. Sie-Form, passende Anrede & Grußformel)?
           - Passt der Textumfang? (Wenn der Text weniger als 50% der Ziel-Wortanzahl hat, ziehe deutlich Punkte ab; bei weniger als 25% maximal 5 Punkte).
        2. kohaerenzScore (0-25 Punkte):
           - Textaufbau, logische Verknüpfung, Absätze und Konnektoren (für B1: weil, obwohl, deshalb, trotzdem; für B2: einerseits/andererseits, infolgedessen, nichtsdestotrotz, je...desto).
        3. wortschatzScore (0-25 Punkte):
           - Spektrum und Angemessenheit des Wortschatzes, Ausdruck, Kollokationen (für B2 auch Nomen-Verb-Verbindungen und präzise Fach-/Alltagsausdrücke).
        4. strukturenScore (0-25 Punkte):
           - Korrektheit von Satzbau (Hauptsatz/Nebensatz-Verbstellung), Kasus, Präpositionen, Adjektivendungen, Konjunktiv II, Rechtschreibung und Zeichensetzung.
        
        AUSGABE-VORGABEN:
        - estimatedLevel: Geschätztes GER-Subniveau des Textes (z.B. "A2.2", "B1.1", "B1.2", "B2.1", "B2.2").
        - examinerSummary: 2-3 präzise, ermutigende aber ehrliche Sätze auf Deutsch als Prüfer-Gesamturteil (Stärken & wichtigster Verbesserungsbereich).
        - leitpunkteCheck: Genau ein Eintrag pro gefordertem Leitpunkt. status MUSS "erfuellt", "teilweise" oder "fehlt" sein, plus kurzer comment auf Deutsch.
        - corrections: Bis zu 6 konkrete Fehler oder Stil-Verbesserungen aus dem Kandidatentext (originalSentence, correctedSentence, category ["Grammatik", "Wortschatz", "Orthografie", "Stil / Register", "Konnektor"], explanation auf Deutsch).
        - improvedModelText: Eine natürliche, sehr gute Musterlösung (95-100 Punkte) auf \(task.level.rawValue)-Niveau zur selben Aufgabe (ca. \(task.targetWords) Wörter), die die Ideen des Kandidaten optimal auf Deutsch umsetzt.
        - recommendedRedemittel: 4 starke Redemittel oder Ausdrücke auf \(task.level.rawValue)-Niveau passend zu diesem Thema.
        """
        
        var generationConfig: [String: Any] = [
            "temperature": 0.2,
            "responseMimeType": "application/json",
            "responseSchema": [
                "type": "OBJECT",
                "properties": [
                    "erfuellungScore": ["type": "INTEGER"],
                    "kohaerenzScore": ["type": "INTEGER"],
                    "wortschatzScore": ["type": "INTEGER"],
                    "strukturenScore": ["type": "INTEGER"],
                    "estimatedLevel": ["type": "STRING"],
                    "examinerSummary": ["type": "STRING"],
                    "leitpunkteCheck": [
                        "type": "ARRAY",
                        "items": [
                            "type": "OBJECT",
                            "properties": [
                                "leitpunkt": ["type": "STRING"],
                                "status": ["type": "STRING"],
                                "comment": ["type": "STRING"]
                            ],
                            "required": ["leitpunkt", "status", "comment"]
                        ]
                    ],
                    "corrections": [
                        "type": "ARRAY",
                        "items": [
                            "type": "OBJECT",
                            "properties": [
                                "originalSentence": ["type": "STRING"],
                                "correctedSentence": ["type": "STRING"],
                                "category": ["type": "STRING"],
                                "explanation": ["type": "STRING"]
                            ],
                            "required": ["originalSentence", "correctedSentence", "category", "explanation"]
                        ]
                    ],
                    "improvedModelText": ["type": "STRING"],
                    "recommendedRedemittel": [
                        "type": "ARRAY",
                        "items": ["type": "STRING"]
                    ]
                ],
                "required": [
                    "erfuellungScore",
                    "kohaerenzScore",
                    "wortschatzScore",
                    "strukturenScore",
                    "estimatedLevel",
                    "examinerSummary",
                    "leitpunkteCheck",
                    "corrections",
                    "improvedModelText",
                    "recommendedRedemittel"
                ]
            ]
        ]
        
        if disableThinking {
            generationConfig["thinkingConfig"] = [
                "thinkingBudget": 0
            ]
        }
        
        let requestBody: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        ["text": prompt]
                    ]
                ]
            ],
            "generationConfig": generationConfig
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 14.0
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
        
        guard statusCode == 200 else {
            if let errorJSON = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let errorObj = errorJSON["error"] as? [String: Any],
               let message = errorObj["message"] as? String {
                throw GeminiServiceError.apiError("Gemini API Fehler (\(statusCode)): \(message)")
            }
            throw GeminiServiceError.apiError("HTTP Fehler \(statusCode)")
        }
        
        guard let rootJSON = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let candidatesArray = rootJSON["candidates"] as? [[String: Any]],
              let firstCandidate = candidatesArray.first,
              let content = firstCandidate["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]],
              let textPart = parts.last(where: { ($0["thought"] as? Bool) != true }) ?? parts.last,
              let text = textPart["text"] as? String,
              let jsonData = text.data(using: .utf8) else {
            throw GeminiServiceError.invalidResponse
        }
        
        let decoded = try JSONDecoder().decode(SchreibenEvaluationResult.self, from: jsonData)
        return SchreibenEvaluationResult(
            erfuellungScore: decoded.erfuellungScore,
            kohaerenzScore: decoded.kohaerenzScore,
            wortschatzScore: decoded.wortschatzScore,
            strukturenScore: decoded.strukturenScore,
            estimatedLevel: decoded.estimatedLevel,
            examinerSummary: decoded.examinerSummary,
            leitpunkteCheck: decoded.leitpunkteCheck,
            corrections: decoded.corrections,
            improvedModelText: decoded.improvedModelText,
            recommendedRedemittel: decoded.recommendedRedemittel
        )
    }
    
    // MARK: - Goethe-Institut Schreiben Task Generator (B1 & B2)
    /// Generates a brand-new, authentic Goethe-Zertifikat B1 or B2 Schreiben prompt via Gemini 3 Flash.
    public func generateSchreibenTask(
        teil: SchreibenExamTeil,
        existingTitles: [String]
    ) async throws -> SchreibenTask {
        let currentKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !currentKey.isEmpty else {
            throw GeminiServiceError.missingAPIKey
        }
        
        let modelConfigs: [(name: String, disableThinking: Bool)] = [
            ("gemini-3-flash-preview", true),
            ("gemini-3.1-flash-lite", true),
            ("gemini-flash-lite-latest", false),
            ("gemini-3.5-flash-lite", false)
        ]
        var lastError: Error = GeminiServiceError.invalidResponse
        
        for config in modelConfigs {
            do {
                let task = try await performGenerateTaskRequest(
                    teil: teil,
                    existingTitles: existingTitles,
                    apiKey: currentKey,
                    model: config.name,
                    disableThinking: config.disableThinking
                )
                await MainActor.run {
                    self.lastUsedModel = config.name
                }
                return task
            } catch let error as GeminiServiceError {
                lastError = error
                if case .apiError(let msg) = error,
                   (msg.contains("API_KEY_INVALID") || msg.contains("API key not valid") || msg.contains("(401)")) {
                    throw error
                }
                continue
            } catch {
                lastError = error
                continue
            }
        }
        
        throw lastError
    }
    
    private func performGenerateTaskRequest(
        teil: SchreibenExamTeil,
        existingTitles: [String],
        apiKey: String,
        model: String,
        disableThinking: Bool
    ) async throws -> SchreibenTask {
        guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent?key=\(apiKey)") else {
            throw GeminiServiceError.invalidResponse
        }
        
        let avoidList = existingTitles.suffix(15).joined(separator: ", ")
        let prompt = """
        Erstelle eine neue, realistische Prüfungsaufgabe nach dem Vorbild des Goethe-Instituts für:
        - Prüfung: \(teil.fullTitle) (\(teil.level.title))
        - Format-Beschreibung: \(teil.categoryDescription)
        - Ziel-Wortanzahl: ca. \(teil.defaultTargetWords) Wörter
        - Anzahl der Leitpunkte: GENAU \(teil.leitpunkteCount) Leitpunkte
        - Vermeide diese bereits vorhandenen Themen: [\(avoidList)]
        
        Regeln:
        - title: Kurzer, prägnanter Titel des Prüfungsthemas auf Deutsch (max. 6 Wörter).
        - situation: Realistische Ausgangssituation auf Deutsch (2-3 Sätze, genau wie im Goethe-Prüfungsheft).
        - leitpunkte: Array mit GENAU \(teil.leitpunkteCount) klaren Inhaltspunkten auf Deutsch, die der Kandidat bearbeiten muss.
        - registerHint: Hinweis zum Register (z.B. "\(teil.defaultRegisterHint)").
        """
        
        var generationConfig: [String: Any] = [
            "temperature": 0.85,
            "responseMimeType": "application/json",
            "responseSchema": [
                "type": "OBJECT",
                "properties": [
                    "title": ["type": "STRING"],
                    "situation": ["type": "STRING"],
                    "leitpunkte": [
                        "type": "ARRAY",
                        "items": ["type": "STRING"]
                    ],
                    "registerHint": ["type": "STRING"]
                ],
                "required": ["title", "situation", "leitpunkte", "registerHint"]
            ]
        ]
        
        if disableThinking {
            generationConfig["thinkingConfig"] = [
                "thinkingBudget": 0
            ]
        }
        
        let requestBody: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        ["text": prompt]
                    ]
                ]
            ],
            "generationConfig": generationConfig
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 9.0
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
        
        guard statusCode == 200 else {
            if let errorJSON = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let errorObj = errorJSON["error"] as? [String: Any],
               let message = errorObj["message"] as? String {
                throw GeminiServiceError.apiError("Gemini API Fehler (\(statusCode)): \(message)")
            }
            throw GeminiServiceError.apiError("HTTP Fehler \(statusCode)")
        }
        
        guard let rootJSON = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let candidatesArray = rootJSON["candidates"] as? [[String: Any]],
              let firstCandidate = candidatesArray.first,
              let content = firstCandidate["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]],
              let textPart = parts.last(where: { ($0["thought"] as? Bool) != true }) ?? parts.last,
              let text = textPart["text"] as? String,
              let jsonData = text.data(using: .utf8) else {
            throw GeminiServiceError.invalidResponse
        }
        
        let decoded = try JSONDecoder().decode(GeminiGeneratedSchreibenTaskResponse.self, from: jsonData)
        return SchreibenTask(
            level: teil.level,
            teil: teil,
            title: decoded.title.trimmingCharacters(in: .whitespacesAndNewlines),
            situation: decoded.situation.trimmingCharacters(in: .whitespacesAndNewlines),
            leitpunkte: decoded.leitpunkte.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) },
            targetWords: teil.defaultTargetWords,
            registerHint: decoded.registerHint.trimmingCharacters(in: .whitespacesAndNewlines),
            recommendedTimeMinutes: teil.defaultTimeMinutes,
            isAIGenerated: true,
            createdAt: Date()
        )
    }
}
