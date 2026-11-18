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
    
    @Published public var apiKey: String {
        didSet {
            let trimmed = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
            UserDefaults.standard.set(trimmed, forKey: apiKeyDefaultsKey)
        }
    }
    
    private init() {
        let saved = UserDefaults.standard.string(forKey: apiKeyDefaultsKey)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !saved.isEmpty {
            self.apiKey = saved
        } else if let envKey = ProcessInfo.processInfo.environment["GEMINI_API_KEY"], !envKey.isEmpty {
            self.apiKey = envKey
        } else {
            self.apiKey = ""
        }
    }
    
    public var hasValidKey: Bool {
        !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    /// Queries Gemini for 3 related German vocabulary candidates across CEFR levels (A1–C2)
    public func searchWords(query: String) async throws -> [GeminiWordCandidate] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else {
            throw GeminiServiceError.emptyQuery
        }
        
        let currentKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !currentKey.isEmpty else {
            throw GeminiServiceError.missingAPIKey
        }
        
        let models = ["gemini-flash-lite-latest", "gemini-3.5-flash-lite", "gemini-3.8-flash", "gemini-flash-latest"]
        var lastError: Error = GeminiServiceError.invalidResponse
        
        for model in models {
            do {
                return try await performRequest(query: trimmedQuery, apiKey: currentKey, model: model)
            } catch let error as GeminiServiceError {
                lastError = error
                if case .apiError(let msg) = error, msg.contains("404") {
                    continue
                }
                throw error
            } catch {
                lastError = error
                throw error
            }
        }
        
        throw lastError
    }
    
    private func performRequest(query: String, apiKey: String, model: String) async throws -> [GeminiWordCandidate] {
        guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent?key=\(apiKey)") else {
            throw GeminiServiceError.invalidResponse
        }
        
        let prompt = """
        You are an expert German lexicographer and language teacher covering all CEFR levels (A1, A2, B1, B2, C1, C2).
        The user searched for: "\(query)" (this could be a German word, an inflected German form, an English word/phrase, or a concept).

        Return exactly 3 German vocabulary entries related to "\(query)":
        1. The most direct/exact canonical German word matching the query (at its true CEFR level, whether A1, A2, B1, B2, C1, or C2).
        2. A closely related alternative, synonym, or different part-of-speech (e.g., corresponding noun/verb/adjective) at an everyday or intermediate level (A1–B2).
        3. A more nuanced, expressive, or advanced synonym/related word (B2–C2).

        Strict Rules for every candidate:
        - `articleOrType`: MUST be one of: "der", "die", "das" (for nouns), "Verb", "Adjektiv", "Adverb", or "Ausdruck".
        - `word`: The canonical German dictionary lemma WITHOUT leading article (e.g., "Nachhaltigkeit" not "die Nachhaltigkeit", "überzeugen", "fortschrittlich").
        - `cefrLevel`: One of "A1", "A2", "B1", "B2", "C1", "C2".
        - `englishDefinition`: Concise, accurate English translation(s).
        - `germanDefinition`: Clear German definition explaining the meaning WITHOUT using the target word itself (used for reverse-engineering quizzes).
        - `b1Example`: A clear, natural German sentence (A2/B1 difficulty) that explicitly contains the target `word` (or a regular inflected form of it) so it can be masked in a cloze test.
        - `b2Example`: A richer, advanced German sentence (B2/C1 difficulty) that explicitly contains the target `word` (or a regular inflected form of it) so it can be masked in a cloze test.
        """
        
        let requestBody: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        ["text": prompt]
                    ]
                ]
            ],
            "generationConfig": [
                "temperature": 0.3,
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
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 20.0
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
}
