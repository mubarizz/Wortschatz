import Foundation
import Security

// MARK: - Extracted Podcast / Share Selection Context
public struct LookupTextContext: Equatable {
    public let rawText: String
    public let cleanedFullText: String
    public let primaryQuery: String
    public let sentenceTokens: [String]
    
    public var isMultiWordSelection: Bool {
        sentenceTokens.count > 1
    }
}

// MARK: - Shared Lookup Bridge (App <-> Share Extension Sync + Wiktionary Live Fallback)
public final class SharedLookupBridge {
    public static let shared = SharedLookupBridge()
    
    private let keychainService = "com.mubarizz.Wortschatz.SharedBridge"
    private let appGroupSuiteName = "group.com.mubarizz.Wortschatz"
    
    private let keyPendingWords = "shared_pending_words_v1"
    private let keyVocabSnapshot = "shared_vocab_snapshot_v1"
    private let keyGeminiAPIKey = "shared_gemini_api_key_v1"
    private let keyLastLookupQuery = "shared_last_lookup_query_v1"
    
    private init() {}
    
    // MARK: - 1. Intelligent Text Extraction for Apple Podcasts & Share Sheet
    
    /// Cleans text shared from Apple Podcasts transcripts, episode descriptions, Safari, or Books.
    public func extractLookupContext(from rawInput: String) -> LookupTextContext {
        var working = rawInput.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 1. Remove any URLs (Apple Podcasts often appends https://podcasts.apple.com/... when sharing a transcript quote)
        if let urlRegex = try? NSRegularExpression(pattern: #"https?://\S+"#, options: [.caseInsensitive]) {
            let range = NSRange(working.startIndex..<working.endIndex, in: working)
            working = urlRegex.stringByReplacingMatches(in: working, options: [], range: range, withTemplate: "")
        }
        
        // 2. Remove common Apple Podcasts attribution lines if present
        let lines = working
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        if !lines.isEmpty {
            working = lines.joined(separator: " ")
        }
        
        // 3. Strip surrounding quote characters („ “ ” " « » ‚ ‘ ’ ')
        let quoteChars = CharacterSet(charactersIn: "„“”\"«»‚‘’'()[]{}<>—–-")
        let cleanedFull = working
            .trimmingCharacters(in: quoteChars.union(.whitespacesAndNewlines))
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        
        // 4. Tokenize into clean German words
        let rawTokens = cleanedFull
            .components(separatedBy: .whitespacesAndNewlines)
            .map { token in
                token.trimmingCharacters(in: CharacterSet.punctuationCharacters.union(quoteChars))
            }
            .filter { token in
                token.count >= 2 && token.rangeOfCharacter(from: .letters) != nil
            }
        
        // Deduplicate while preserving order
        var seen = Set<String>()
        var uniqueTokens: [String] = []
        for token in rawTokens {
            let lower = token.lowercased()
            if !seen.contains(lower) {
                seen.insert(lower)
                uniqueTokens.append(token)
            }
        }
        
        // 5. Determine primary query
        let primary: String
        if uniqueTokens.count <= 2 {
            // Single word or 2-word phrase (e.g. "der Eindruck" or "zur Verfügung")
            let joined = uniqueTokens.joined(separator: " ")
            primary = stripLeadingArticleIfSingleNoun(joined.isEmpty ? cleanedFull : joined)
        } else {
            // Multi-word sentence from a podcast transcript: pick the richest B2/C1 candidate word first
            primary = pickMostInterestingGermanWord(from: uniqueTokens) ?? uniqueTokens.first ?? cleanedFull
        }
        
        return LookupTextContext(
            rawText: rawInput,
            cleanedFullText: cleanedFull,
            primaryQuery: primary,
            sentenceTokens: uniqueTokens
        )
    }
    
    private func stripLeadingArticleIfSingleNoun(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        for prefix in ["der ", "die ", "das ", "den ", "dem ", "des ", "ein ", "eine ", "einen ", "einem ", "einer "] {
            if trimmed.lowercased().hasPrefix(prefix) {
                let rest = String(trimmed.dropFirst(prefix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
                if !rest.isEmpty && !rest.contains(" ") {
                    return rest
                }
            }
        }
        return trimmed
    }
    
    private func pickMostInterestingGermanWord(from tokens: [String]) -> String? {
        let basicStopwords: Set<String> = [
            "der", "die", "das", "den", "dem", "des", "ein", "eine", "einer", "einem", "einen", "eines",
            "und", "oder", "aber", "denn", "weil", "dass", "wenn", "als", "wie", "auch", "noch", "schon",
            "nicht", "kein", "keine", "keinen", "keinem", "sich", "ich", "du", "er", "sie", "es", "wir",
            "ihr", "mein", "dein", "sein", "unser", "ist", "sind", "war", "waren", "hat", "haben", "hatte",
            "wird", "werden", "wurde", "kann", "können", "muss", "müssen", "soll", "will", "mit", "von",
            "für", "auf", "aus", "bei", "nach", "über", "unter", "vor", "zwischen", "durch", "gegen", "ohne"
        ]
        
        let contentWords = tokens.filter { !basicStopwords.contains($0.lowercased()) }
        // Prefer longer words (typical of B2/C1 German vocabulary in podcasts)
        return contentWords.max(by: { $0.count < $1.count })
    }
    
    // MARK: - 2. Cross-Process Persistence (Shared Keychain + App Group Suite)
    
    /// Queues a word saved inside the Share Extension so the main Wortschatz app imports it automatically
    public func enqueueSavedWordFromExtension(_ word: VocabularyWord) {
        var current = loadPendingWords()
        let cleanKey = word.cleanTargetWord.lowercased()
        if !current.contains(where: { $0.cleanTargetWord.lowercased() == cleanKey }) {
            current.insert(word, at: 0)
            savePendingWords(current)
        }
        
        // Also add to the shared vocabulary snapshot immediately so the extension marks it as saved
        var snapshot = loadVocabularySnapshot()
        if !snapshot.contains(where: { $0.cleanTargetWord.lowercased() == cleanKey }) {
            snapshot.insert(word, at: 0)
            saveVocabularySnapshot(snapshot)
        }
    }
    
    public func loadPendingWords() -> [VocabularyWord] {
        guard let data = readSharedData(forKey: keyPendingWords),
              let decoded = try? JSONDecoder().decode([VocabularyWord].self, from: data) else {
            return []
        }
        return decoded
    }
    
    public func clearPendingWords() {
        deleteSharedData(forKey: keyPendingWords)
    }
    
    private func savePendingWords(_ words: [VocabularyWord]) {
        if let data = try? JSONEncoder().encode(words) {
            writeSharedData(data, forKey: keyPendingWords)
        }
    }
    
    /// Main app calls this to keep a lightweight snapshot of saved words available to the Share Extension
    public func saveVocabularySnapshot(_ words: [VocabularyWord]) {
        // Keep up to 400 words in the shared snapshot for fast cross-process access
        let subset = Array(words.prefix(400))
        if let data = try? JSONEncoder().encode(subset) {
            writeSharedData(data, forKey: keyVocabSnapshot)
        }
    }
    
    public func loadVocabularySnapshot() -> [VocabularyWord] {
        if let data = readSharedData(forKey: keyVocabSnapshot),
           let decoded = try? JSONDecoder().decode([VocabularyWord].self, from: data),
           !decoded.isEmpty {
            return decoded
        }
        // Fallback to bundled CSV if extension runs before main app synced
        if let bundleURL = Bundle.main.url(forResource: "wortschatz", withExtension: "csv"),
           let parsed = try? CSVParser.shared.parse(fileURL: bundleURL),
           !parsed.isEmpty {
            return parsed
        }
        return []
    }
    
    /// Syncs Gemini API Key across Main App and Share Extension
    public func saveSharedGeminiAPIKey(_ apiKey: String) {
        let trimmed = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if let data = trimmed.data(using: .utf8) {
            writeSharedData(data, forKey: keyGeminiAPIKey)
        }
    }
    
    public func loadSharedGeminiAPIKey() -> String? {
        guard let data = readSharedData(forKey: keyGeminiAPIKey),
              let str = String(data: data, encoding: .utf8) else {
            return nil
        }
        let trimmed = str.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
    
    // MARK: - Low-Level Shared Keychain + UserDefaults Storage
    
    private func writeSharedData(_ data: Data, forKey key: String) {
        // 1. Write to App Group UserDefaults if available
        if let groupDefaults = UserDefaults(suiteName: appGroupSuiteName) {
            groupDefaults.set(data, forKey: key)
        }
        UserDefaults.standard.set(data, forKey: key)
        
        // 2. Write to Shared Keychain (works across App + Extension on Personal Developer Team)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
        
        var addQuery = query
        addQuery[kSecValueData as String] = data
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(addQuery as CFDictionary, nil)
    }
    
    private func readSharedData(forKey key: String) -> Data? {
        // 1. Try Shared Keychain first (most reliable across App and Extension processes)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecSuccess, let data = item as? Data {
            return data
        }
        
        // 2. Fallback to App Group UserDefaults
        if let groupDefaults = UserDefaults(suiteName: appGroupSuiteName),
           let data = groupDefaults.data(forKey: key) {
            return data
        }
        
        // 3. Fallback to standard UserDefaults
        return UserDefaults.standard.data(forKey: key)
    }
    
    private func deleteSharedData(forKey key: String) {
        if let groupDefaults = UserDefaults(suiteName: appGroupSuiteName) {
            groupDefaults.removeObject(forKey: key)
        }
        UserDefaults.standard.removeObject(forKey: key)
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
    }
    
    // MARK: - 3. Local Dictionary & Verb-Preposition Matching
    
    /// Searches the user's vocabulary deck (including inflected/stem matches)
    public func findLocalVocabularyMatches(for query: String, in words: [VocabularyWord]) -> [VocabularyWord] {
        let cleaned = stripLeadingArticleIfSingleNoun(query).lowercased()
        guard !cleaned.isEmpty else { return [] }
        
        // Exact match first
        var results: [VocabularyWord] = []
        var seenIds = Set<UUID>()
        
        for word in words {
            let target = word.cleanTargetWord.lowercased()
            if target == cleaned || word.word.lowercased() == cleaned {
                results.append(word)
                seenIds.insert(word.id)
            }
        }
        
        // Stem / prefix / substring match (e.g., "beeinträchtigt" matches "beeinträchtigen", "Herausforderungen" matches "Herausforderung")
        let stem = deriveGermanStem(from: cleaned)
        for word in words where !seenIds.contains(word.id) {
            let target = word.cleanTargetWord.lowercased()
            if target.contains(cleaned) || cleaned.contains(target) || (stem.count >= 4 && target.hasPrefix(stem)) {
                results.append(word)
                seenIds.insert(word.id)
            } else if word.englishDefinition.lowercased().contains(cleaned) {
                results.append(word)
                seenIds.insert(word.id)
            }
        }
        
        return Array(results.prefix(3))
    }
    
    /// Searches the 55+ B1–C1 Verb-Preposition bank (PrepositionDatabase)
    public func findPrepositionMatches(for query: String) -> [PrepositionEntry] {
        let cleaned = stripLeadingArticleIfSingleNoun(query).lowercased()
        guard cleaned.count >= 3 else { return [] }
        let stem = deriveGermanStem(from: cleaned)
        
        return PrepositionDatabase.entries.filter { entry in
            let verbLower = entry.verb.lowercased()
            let cleanVerb = verbLower.replacingOccurrences(of: "sich ", with: "")
            return cleanVerb == cleaned ||
                   verbLower == cleaned ||
                   cleanVerb.hasPrefix(cleaned) ||
                   cleaned.hasPrefix(cleanVerb) ||
                   (stem.count >= 4 && cleanVerb.hasPrefix(stem))
        }
    }
    
    private func deriveGermanStem(from word: String) -> String {
        var s = word.lowercased()
        for prefix in ["ge"] {
            if s.hasPrefix(prefix) && s.count > 6 {
                // e.g. "gesprochen" or "gearbeitet"
                s = String(s.dropFirst(prefix.count))
            }
        }
        for suffix in ["ungen", "heiten", "keiten", "test", "ten", "tet", "est", "en", "et", "te", "st", "t", "e", "n", "s"] {
            if s.hasSuffix(suffix) && (s.count - suffix.count) >= 4 {
                return String(s.dropLast(suffix.count))
            }
        }
        return s
    }
    
    // MARK: - 4. Wiktionary DE + EN Zero-Key Live Dictionary Engine
    
    /// Looks up any German word via de.wiktionary.org + en.wiktionary.org without requiring an API key.
    public func lookupViaWiktionary(query: String) async -> [GeminiWordCandidate] {
        let trimmed = stripLeadingArticleIfSingleNoun(query).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        
        // Try exact title first, then capitalized/lowercased variants or search suggestion
        let candidateTitles = await resolveWiktionaryTitles(for: trimmed)
        guard let primaryTitle = candidateTitles.first else {
            return []
        }
        
        async let deExtractTask = fetchWiktionaryExtract(title: primaryTitle, language: "de")
        async let enExtractTask = fetchWiktionaryExtract(title: primaryTitle, language: "en")
        
        let (deExtract, enExtract) = await (deExtractTask, enExtractTask)
        
        // If the page is only an inflected form (e.g. "Konjugierte Form" / "Deklinierte Form"), resolve its base lemma!
        if let deText = deExtract,
           let baseLemma = extractBaseLemmaFromInflectedPage(deText),
           baseLemma.lowercased() != primaryTitle.lowercased() {
            async let baseDeTask = fetchWiktionaryExtract(title: baseLemma, language: "de")
            async let baseEnTask = fetchWiktionaryExtract(title: baseLemma, language: "en")
            let (baseDe, baseEn) = await (baseDeTask, baseEnTask)
            if let resolvedDe = baseDe {
                return await buildCandidatesFromWiktionary(
                    title: baseLemma,
                    deExtract: resolvedDe,
                    enExtract: baseEn,
                    originalQuery: trimmed
                )
            }
        }
        
        guard let validDe = deExtract ?? enExtract else {
            return []
        }
        
        return await buildCandidatesFromWiktionary(
            title: primaryTitle,
            deExtract: validDe,
            enExtract: enExtract,
            originalQuery: trimmed
        )
    }
    
    private func resolveWiktionaryTitles(for query: String) async -> [String] {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        guard let url = URL(string: "https://de.wiktionary.org/w/api.php?action=opensearch&search=\(encoded)&limit=3&namespace=0&format=json") else {
            return [query]
        }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let json = try JSONSerialization.jsonObject(with: data) as? [Any],
               json.count >= 2,
               let titles = json[1] as? [String],
               !titles.isEmpty {
                return titles
            }
        } catch {
            // Fallback to capitalized/lowercased variants
        }
        let capitalized = query.prefix(1).uppercased() + query.dropFirst()
        if capitalized != query {
            return [query, capitalized]
        }
        return [query]
    }
    
    private func fetchWiktionaryExtract(title: String, language: String) async -> String? {
        let encoded = title.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? title
        guard let url = URL(string: "https://\(language).wiktionary.org/w/api.php?action=query&prop=extracts&titles=\(encoded)&explaintext=1&redirects=1&format=json") else {
            return nil
        }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let queryDict = root["query"] as? [String: Any],
                  let pages = queryDict["pages"] as? [String: Any] else {
                return nil
            }
            for (pageId, pageVal) in pages {
                if pageId == "-1" { continue }
                if let pageObj = pageVal as? [String: Any],
                   let extract = pageObj["extract"] as? String,
                   !extract.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    return extract
                }
            }
        } catch {
            return nil
        }
        return nil
    }
    
    private func extractBaseLemmaFromInflectedPage(_ deExtract: String) -> String? {
        // German Wiktionary marks inflected forms with "Grammatische Merkmale:" e.g. "3. Person Singular ... des Verbs beeinträchtigen" or "Nominativ Plural des Substantivs Herausforderung"
        let patterns = [
            #"des Verbs\s+([A-Za-zÄÖÜäöüß]+)"#,
            #"des Substantivs\s+([A-Za-zÄÖÜäöüß]+)"#,
            #"des Adjektivs\s+([A-Za-zÄÖÜäöüß]+)"#,
            #"Grundformverweis[^\n]*\s+([A-Za-zÄÖÜäöüß]+)"#
        ]
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []),
               let match = regex.firstMatch(in: deExtract, options: [], range: NSRange(deExtract.startIndex..<deExtract.endIndex, in: deExtract)),
               match.numberOfRanges >= 2,
               let range = Range(match.range(at: 1), in: deExtract) {
                return String(deExtract[range])
            }
        }
        return nil
    }
    
    private func buildCandidatesFromWiktionary(
        title: String,
        deExtract: String,
        enExtract: String?,
        originalQuery: String
    ) async -> [GeminiWordCandidate] {
        let articleOrType = parseArticleOrType(from: deExtract, word: title)
        let germanDef = parseSectionLine(from: deExtract, sectionHeader: "Bedeutungen:")
            ?? "Deutsches Wort aus dem aktuellen Kontext („\(title)“)."
        let examples = parseExamples(from: deExtract, fallbackWord: title, articleOrType: articleOrType)
        
        var englishDef = parseEnglishDefinition(from: enExtract)
        if englishDef == nil {
            englishDef = await fetchFallbackEnglishTranslation(for: title)
        }
        
        let cefr = estimateCEFRLevel(for: title, definition: germanDef)
        
        var candidates: [GeminiWordCandidate] = [
            GeminiWordCandidate(
                articleOrType: articleOrType,
                word: title,
                cefrLevel: cefr,
                englishDefinition: englishDef ?? "German vocabulary: \(title)",
                germanDefinition: germanDef,
                b1Example: examples.b1,
                b2Example: examples.b2
            )
        ]
        
        // Extract up to 2 synonyms from Wiktionary "Synonyme:" section if available
        let synonyms = parseSynonyms(from: deExtract)
        for syn in synonyms.prefix(2) where syn.lowercased() != title.lowercased() {
            if let synExtract = await fetchWiktionaryExtract(title: syn, language: "de") {
                let synType = parseArticleOrType(from: synExtract, word: syn)
                let synDef = parseSectionLine(from: synExtract, sectionHeader: "Bedeutungen:") ?? "Synonym zu \(title)."
                let synEx = parseExamples(from: synExtract, fallbackWord: syn, articleOrType: synType)
                let synEn = await fetchWiktionaryExtract(title: syn, language: "en").flatMap { parseEnglishDefinition(from: $0) }
                
                candidates.append(
                    GeminiWordCandidate(
                        articleOrType: synType,
                        word: syn,
                        cefrLevel: "B2",
                        englishDefinition: synEn ?? "synonym of \(title) (\(englishDef ?? ""))",
                        germanDefinition: synDef,
                        b1Example: synEx.b1,
                        b2Example: synEx.b2
                    )
                )
            }
        }
        
        return candidates
    }
    
    private func parseArticleOrType(from deExtract: String, word: String) -> String {
        if deExtract.contains("Substantiv, m") { return "der" }
        if deExtract.contains("Substantiv, f") { return "die" }
        if deExtract.contains("Substantiv, n") { return "das" }
        if deExtract.contains("=== Verb") { return "Verb" }
        if deExtract.contains("=== Adjektiv") { return "Adjektiv" }
        if deExtract.contains("=== Adverb") { return "Adverb" }
        if deExtract.contains("Redewendung") || word.contains(" ") { return "Ausdruck" }
        
        // Heuristic fallback by German noun suffix capitalization
        if let first = word.first, first.isUppercase {
            let lower = word.lowercased()
            if lower.hasSuffix("ung") || lower.hasSuffix("heit") || lower.hasSuffix("keit") || lower.hasSuffix("schaft") || lower.hasSuffix("tion") || lower.hasSuffix("tät") {
                return "die"
            }
            if lower.hasSuffix("chen") || lower.hasSuffix("lein") || lower.hasSuffix("ment") || lower.hasSuffix("um") {
                return "das"
            }
            return "der"
        }
        if word.lowercased().hasSuffix("en") || word.lowercased().hasSuffix("eln") || word.lowercased().hasSuffix("ern") {
            return "Verb"
        }
        return "Adjektiv"
    }
    
    private func parseSectionLine(from extract: String, sectionHeader: String) -> String? {
        guard let range = extract.range(of: sectionHeader) else { return nil }
        let after = extract[range.upperBound...]
        let lines = after.components(separatedBy: .newlines)
        var collected: [String] = []
        
        for rawLine in lines {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            if line.isEmpty { continue }
            if line.hasSuffix(":") || line.hasPrefix("==") {
                if !collected.isEmpty { break }
                continue
            }
            let cleaned = line
                .replacingOccurrences(of: #"^\[\d+[a-z]?\]\s*"#, with: "", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if cleaned.count >= 4 {
                collected.append(cleaned)
                if collected.count >= 2 { break }
            }
        }
        return collected.isEmpty ? nil : collected.joined(separator: "; ")
    }
    
    private func parseExamples(from extract: String, fallbackWord: String, articleOrType: String) -> (b1: String, b2: String) {
        var found: [String] = []
        if let range = extract.range(of: "Beispiele:") {
            let after = extract[range.upperBound...]
            for rawLine in after.components(separatedBy: .newlines) {
                let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
                if line.isEmpty { continue }
                if line.hasSuffix(":") || line.hasPrefix("==") {
                    if !found.isEmpty { break }
                    continue
                }
                let cleaned = line
                    .replacingOccurrences(of: #"^\[\d+[a-z]?\]\s*"#, with: "", options: .regularExpression)
                    .replacingOccurrences(of: #"\[\d+\]$"#, with: "", options: .regularExpression)
                    .replacingOccurrences(of: "„", with: "")
                    .replacingOccurrences(of: "“", with: "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if cleaned.count >= 15 {
                    found.append(cleaned)
                    if found.count >= 2 { break }
                }
            }
        }
        
        let displayWord = (articleOrType == "der" || articleOrType == "die" || articleOrType == "das")
            ? "\(articleOrType) \(fallbackWord)"
            : fallbackWord
        
        let b1 = found.first ?? "Im Alltag spielt \(displayWord) eine wichtige Rolle."
        let b2 = found.count >= 2 ? found[1] : "In der heutigen Diskussion wird \(displayWord) immer häufiger thematisiert."
        return (b1, b2)
    }
    
    private func parseSynonyms(from extract: String) -> [String] {
        guard let range = extract.range(of: "Synonyme:") else { return [] }
        let after = extract[range.upperBound...]
        var results: [String] = []
        
        for rawLine in after.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            if line.isEmpty { continue }
            if line.hasSuffix(":") || line.hasPrefix("==") {
                if !results.isEmpty { break }
                continue
            }
            let cleaned = line.replacingOccurrences(of: #"^\[\d+[a-z]?\]\s*"#, with: "", options: .regularExpression)
            let parts = cleaned.components(separatedBy: CharacterSet(charactersIn: ",;"))
            for part in parts {
                let word = part.trimmingCharacters(in: .whitespacesAndNewlines)
                if word.count >= 3 && !word.contains(" ") && word.rangeOfCharacter(from: .letters) != nil {
                    results.append(word)
                }
            }
            if results.count >= 2 { break }
        }
        return results
    }
    
    private func parseEnglishDefinition(from enExtract: String?) -> String? {
        guard let text = enExtract else { return nil }
        // Find "== German ==" section if present
        let germanSection: Substring
        if let range = text.range(of: "== German ==") {
            germanSection = text[range.upperBound...]
        } else {
            germanSection = text[...]
        }
        
        let headers = ["=== Noun ===", "=== Verb ===", "=== Adjective ===", "=== Adverb ===", "=== Phrase ==="]
        for header in headers {
            if let hRange = germanSection.range(of: header) {
                let after = germanSection[hRange.upperBound...]
                let lines = after.components(separatedBy: .newlines)
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                // First line after POS header is the headword line; subsequent lines are definitions
                var defs: [String] = []
                for (index, line) in lines.enumerated() {
                    if index == 0 { continue } // Skip headword inflections line
                    if line.hasPrefix("==") { break }
                    if line.count >= 2 && !line.hasPrefix("IPA") && !line.hasPrefix("Hyphenation") {
                        defs.append(line)
                        if defs.count >= 2 { break }
                    }
                }
                if !defs.isEmpty {
                    return defs.joined(separator: "; ")
                }
            }
        }
        return nil
    }
    
    private func fetchFallbackEnglishTranslation(for word: String) async -> String? {
        let encoded = word.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? word
        guard let url = URL(string: "https://api.mymemory.translated.net/get?q=\(encoded)&langpair=de|en") else {
            return nil
        }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let respData = root["responseData"] as? [String: Any],
               let translated = respData["translatedText"] as? String {
                let clean = translated.trimmingCharacters(in: CharacterSet.punctuationCharacters.union(.whitespacesAndNewlines))
                if clean.count >= 2 && clean.lowercased() != word.lowercased() {
                    return clean
                }
            }
        } catch {
            return nil
        }
        return nil
    }
    
    private func estimateCEFRLevel(for word: String, definition: String) -> String {
        if word.count >= 13 || definition.count >= 95 {
            return "C1"
        } else if word.count >= 8 {
            return "B2"
        }
        return "B1"
    }
}
