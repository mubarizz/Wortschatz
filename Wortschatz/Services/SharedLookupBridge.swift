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
    
    /// Searches the user's vocabulary deck (exact & genuine inflection matches only, avoiding unrelated substring hits)
    public func findLocalVocabularyMatches(for query: String, in words: [VocabularyWord]) -> [VocabularyWord] {
        let cleaned = stripLeadingArticleIfSingleNoun(query).lowercased()
        guard !cleaned.isEmpty else { return [] }
        
        var results: [VocabularyWord] = []
        var seenIds = Set<UUID>()
        
        // 1. Exact target word match
        for word in words {
            let target = stripParentheticalNote(from: word.cleanTargetWord).lowercased()
            let fullTarget = word.cleanTargetWord.lowercased()
            if target == cleaned || fullTarget == cleaned || word.word.lowercased() == cleaned || word.displayTitle.lowercased() == cleaned {
                results.append(word)
                seenIds.insert(word.id)
            }
        }
        
        // 2. Direct inflection match of the SAME lemma (e.g. "Herausforderungen" <-> "Herausforderung", "beeinträchtigt" <-> "beeinträchtigen")
        for word in words where !seenIds.contains(word.id) {
            let target = stripParentheticalNote(from: word.cleanTargetWord).lowercased()
            if isDirectGermanInflectionMatch(query: cleaned, lemma: target) {
                results.append(word)
                seenIds.insert(word.id)
            }
        }
        
        // 3. Whole-word match in English definition (excluding parenthetical grammar notes and short stopwords)
        let englishStopwords: Set<String> = [
            "to", "in", "on", "at", "by", "of", "or", "be", "an", "as", "is", "it", "for", "the", "and",
            "with", "from", "into", "that", "this", "have", "make", "take", "give", "come", "something",
            "someone", "somebody", "past", "participle", "colloquial", "literally", "also"
        ]
        if cleaned.count >= 4 && !englishStopwords.contains(cleaned) {
            for word in words where !seenIds.contains(word.id) {
                let cleanEnglish = stripParentheticalNote(from: word.englishDefinition).lowercased()
                if containsWholeWord(cleaned, in: cleanEnglish) {
                    results.append(word)
                    seenIds.insert(word.id)
                }
            }
        }
        
        return Array(results.prefix(3))
    }
    
    /// Searches the B1–C1 Verb-Preposition bank (PrepositionDatabase) for exact or conjugated forms of the verb
    public func findPrepositionMatches(for query: String) -> [PrepositionEntry] {
        let cleaned = stripLeadingArticleIfSingleNoun(query)
            .lowercased()
            .replacingOccurrences(of: "sich ", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard cleaned.count >= 3 else { return [] }
        
        return PrepositionDatabase.entries.filter { entry in
            let rawVerb = entry.verb.lowercased()
            let baseVerb = stripParentheticalNote(from: rawVerb)
                .replacingOccurrences(of: "sich ", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            
            if baseVerb == cleaned || rawVerb == cleaned {
                return true
            }
            return isConjugatedFormOfVerb(query: cleaned, infinitive: baseVerb)
        }
    }
    
    private func stripParentheticalNote(from text: String) -> String {
        text.replacingOccurrences(of: #"\s*\([^)]*\)"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func containsWholeWord(_ word: String, in text: String) -> Bool {
        let escaped = NSRegularExpression.escapedPattern(for: word)
        let pattern = #"(?:^|[^A-Za-zÄÖÜäöüß])"# + escaped + #"(?:$|[^A-Za-zÄÖÜäöüß])"#
        return text.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
    }
    
    /// Checks if `query` is a declined/plural/conjugated inflection of `lemma` without false-matching unrelated prefixes
    private func isDirectGermanInflectionMatch(query: String, lemma: String) -> Bool {
        guard query.count >= 4, lemma.count >= 4, !lemma.contains(" ") else { return false }
        if query == lemma { return true }
        
        // Plural / case endings on nouns & adjectives (e.g. Herausforderung -> Herausforderungen)
        let validNominalSuffixes: Set<String> = ["e", "en", "n", "er", "ern", "es", "em", "s"]
        if query.hasPrefix(lemma) {
            let suffix = String(query.dropFirst(lemma.count))
            if validNominalSuffixes.contains(suffix) { return true }
        }
        if lemma.hasPrefix(query) {
            let suffix = String(lemma.dropFirst(query.count))
            if validNominalSuffixes.contains(suffix) { return true }
        }
        
        // Verb conjugation check if lemma is an infinitive
        if lemma.hasSuffix("en") || lemma.hasSuffix("eln") || lemma.hasSuffix("ern") {
            if isConjugatedFormOfVerb(query: query, infinitive: lemma) {
                return true
            }
        }
        return false
    }
    
    /// Strictly checks if `query` is a conjugated form or regular past participle of `infinitive`
    private func isConjugatedFormOfVerb(query: String, infinitive: String) -> Bool {
        guard infinitive.count >= 4, query.count >= 3 else { return false }
        if query == infinitive { return true }
        
        let stem: String
        if infinitive.hasSuffix("en") {
            stem = String(infinitive.dropLast(2))
        } else if infinitive.hasSuffix("n") {
            stem = String(infinitive.dropLast(1))
        } else {
            return false
        }
        guard stem.count >= 3 else { return false }
        
        let validVerbEndings: Set<String> = [
            "", "e", "st", "t", "en", "et", "est", "te", "ten", "test", "tet", "end", "ende", "enden"
        ]
        
        if query.hasPrefix(stem) {
            let ending = String(query.dropFirst(stem.count))
            if validVerbEndings.contains(ending) {
                return true
            }
        }
        
        // Regular Partizip II: "ge" + stem + ("t" / "et" / "en")
        if query.hasPrefix("ge" + stem) {
            let ending = String(query.dropFirst(2 + stem.count))
            if ending == "t" || ending == "et" || ending == "en" {
                return true
            }
        }
        
        return false
    }
    
    // MARK: - 4. Wiktionary DE + EN Zero-Key Live Dictionary Engine
    
    private struct WiktionaryPOSSection {
        let header: String
        let articleOrType: String
        let body: String
    }
    
    /// Looks up any German (or English) word via de.wiktionary.org + en.wiktionary.org without requiring an API key.
    public func lookupViaWiktionary(query: String) async -> [GeminiWordCandidate] {
        let trimmed = stripLeadingArticleIfSingleNoun(query).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        
        let candidateTitles = await resolveWiktionaryTitles(for: trimmed)
        
        // 1. Try finding a valid German ("== ... (Deutsch) ==") page among the resolved titles
        for title in candidateTitles {
            if let rawDe = await fetchWiktionaryExtract(title: title, language: "de") {
                if let germanSection = extractGermanLanguageSection(from: rawDe) {
                    // Check if this page is ONLY an inflected stub (no "Bedeutungen:" of its own)
                    if !germanSection.contains("Bedeutungen:"),
                       let baseLemma = extractBaseLemmaFromInflectedPage(germanSection),
                       baseLemma.lowercased() != title.lowercased(),
                       let baseRawDe = await fetchWiktionaryExtract(title: baseLemma, language: "de"),
                       let baseGermanSection = extractGermanLanguageSection(from: baseRawDe) {
                        let baseEn = await fetchWiktionaryExtract(title: baseLemma, language: "en")
                        return await buildCandidatesFromWiktionary(
                            title: baseLemma,
                            germanDeExtract: baseGermanSection,
                            enExtract: baseEn
                        )
                    }
                    
                    let enExtract = await fetchWiktionaryExtract(title: title, language: "en")
                    let built = await buildCandidatesFromWiktionary(
                        title: title,
                        germanDeExtract: germanSection,
                        enExtract: enExtract
                    )
                    if !built.isEmpty {
                        return built
                    }
                } else {
                    // The de.wiktionary.org page exists, but ONLY for a foreign language (e.g. "== apply (Englisch) ==")
                    // Extract German translations listed on that page or translate EN -> DE!
                    if let translatedGermanWords = extractGermanTranslationsFromForeignPage(rawDe),
                       !translatedGermanWords.isEmpty {
                        var englishQueryResults: [GeminiWordCandidate] = []
                        for deWord in translatedGermanWords.prefix(3) {
                            if let deRaw = await fetchWiktionaryExtract(title: deWord, language: "de"),
                               let deSec = extractGermanLanguageSection(from: deRaw) {
                                let enRaw = await fetchWiktionaryExtract(title: deWord, language: "en")
                                let cands = await buildCandidatesFromWiktionary(
                                    title: deWord,
                                    germanDeExtract: deSec,
                                    enExtract: enRaw
                                )
                                if let first = cands.first {
                                    englishQueryResults.append(first)
                                }
                            }
                        }
                        if !englishQueryResults.isEmpty {
                            return englishQueryResults
                        }
                    }
                }
            }
        }
        
        // 2. If query wasn't found as a German lemma (e.g. English word like "sustainable"), translate EN -> DE first
        if let translatedDe = await fetchFallbackGermanTranslation(for: trimmed),
           translatedDe.lowercased() != trimmed.lowercased() {
            let deTitles = await resolveWiktionaryTitles(for: translatedDe)
            if let firstDeTitle = deTitles.first,
               let rawDe = await fetchWiktionaryExtract(title: firstDeTitle, language: "de"),
               let germanSection = extractGermanLanguageSection(from: rawDe) {
                let enExtract = await fetchWiktionaryExtract(title: firstDeTitle, language: "en")
                return await buildCandidatesFromWiktionary(
                    title: firstDeTitle,
                    germanDeExtract: germanSection,
                    enExtract: enExtract
                )
            }
        }
        
        return []
    }
    
    private func performWiktionaryRequest(url: URL) async -> Data? {
        var request = URLRequest(url: url)
        request.setValue("WortschatzApp/2.0 (iOS; German Learning Assistant)", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 8.0
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
            return data
        } catch {
            return nil
        }
    }
    
    private func resolveWiktionaryTitles(for query: String) async -> [String] {
        let capitalized = query.prefix(1).uppercased() + query.dropFirst()
        var fallbacks: [String] = [query]
        if capitalized != query {
            fallbacks.append(capitalized)
        }
        
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        guard let url = URL(string: "https://de.wiktionary.org/w/api.php?action=opensearch&search=\(encoded)&limit=4&namespace=0&format=json"),
              let data = await performWiktionaryRequest(url: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [Any],
              json.count >= 2,
              let titles = json[1] as? [String],
              !titles.isEmpty else {
            return fallbacks
        }
        
        // Prefer exact case-insensitive match first if present in opensearch results
        let exactMatches = titles.filter { $0.lowercased() == query.lowercased() }
        let others = titles.filter { $0.lowercased() != query.lowercased() }
        return exactMatches + others
    }
    
    private func fetchWiktionaryExtract(title: String, language: String) async -> String? {
        let encoded = title.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? title
        guard let url = URL(string: "https://\(language).wiktionary.org/w/api.php?action=query&prop=extracts&titles=\(encoded)&explaintext=1&redirects=1&format=json"),
              let data = await performWiktionaryRequest(url: url),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
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
        return nil
    }
    
    /// Strictly isolates the `== ... (Deutsch) ==` section from a de.wiktionary.org extract
    private func extractGermanLanguageSection(from deExtract: String) -> String? {
        let pattern = #"==\s*[^=\n]+\(Deutsch\)\s*==\n"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []),
              let match = regex.firstMatch(in: deExtract, options: [], range: NSRange(deExtract.startIndex..<deExtract.endIndex, in: deExtract)),
              let startRange = Range(match.range, in: deExtract) else {
            return nil
        }
        
        let afterStart = String(deExtract[startRange.upperBound...])
        // Stop before the next top-level language section `\n== ... ==` (two equals, not three)
        let nextLangPattern = #"\n==\s*[^=][^\n]*==\s*\n"#
        if let nextRegex = try? NSRegularExpression(pattern: nextLangPattern, options: []),
           let nextMatch = nextRegex.firstMatch(in: afterStart, options: [], range: NSRange(afterStart.startIndex..<afterStart.endIndex, in: afterStart)),
           let endRange = Range(nextMatch.range, in: afterStart) {
            return String(afterStart[..<endRange.lowerBound])
        }
        return afterStart
    }
    
    /// Extracts base lemma ONLY when the page is a pure inflection stub (no Bedeutungen:) and ONLY from Grammatische Merkmale / Grundformverweis
    private func extractBaseLemmaFromInflectedPage(_ germanSection: String) -> String? {
        // Never hijack a page that already has its own meanings (e.g. "Haus", "Erfahrung", "schnell", "geraten")
        if germanSection.contains("Bedeutungen:") {
            return nil
        }
        
        // Search only after "Grammatische Merkmale:" or "Grundformverweis" (never inside "Herkunft:")
        let searchScope: String
        if let gmRange = germanSection.range(of: "Grammatische Merkmale:") {
            searchScope = String(germanSection[gmRange.upperBound...])
        } else {
            searchScope = germanSection
        }
        
        let patterns = [
            #"des Verbs\s+([A-Za-zÄÖÜäöüß]+)"#,
            #"des Substantivs\s+([A-Za-zÄÖÜäöüß]+)"#,
            #"des Adjektivs\s+([A-Za-zÄÖÜäöüß]+)"#,
            #"Grundformverweis[^\n]*\s+([A-Za-zÄÖÜäöüß]+)"#
        ]
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []),
               let match = regex.firstMatch(in: searchScope, options: [], range: NSRange(searchScope.startIndex..<searchScope.endIndex, in: searchScope)),
               match.numberOfRanges >= 2,
               let range = Range(match.range(at: 1), in: searchScope) {
                return String(searchScope[range])
            }
        }
        return nil
    }
    
    /// When a user searches an English word that has an `== word (Englisch) ==` page on de.wiktionary.org, extract the German meanings listed in `Bedeutungen:`
    private func extractGermanTranslationsFromForeignPage(_ rawDe: String) -> [String]? {
        let isVerbPage = rawDe.contains("=== Verb")
        guard let bedRange = rawDe.range(of: "Bedeutungen:") else { return nil }
        let after = rawDe[bedRange.upperBound...]
        var extractedWords: [String] = []
        
        for rawLine in after.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            if line.isEmpty { continue }
            if line.hasSuffix(":") || line.hasPrefix("==") {
                if !extractedWords.isEmpty { break }
                continue
            }
            // Strip parenthetical examples like "(wie Salbe, Farbe, Lack)" FIRST, then sense numbers like "[1]"
            var cleaned = stripParentheticalNote(from: line)
                .replacingOccurrences(of: #"^\[\d+[a-z]?\]\s*"#, with: "", options: .regularExpression)
            if let lastColon = cleaned.lastIndex(of: ":") {
                cleaned = String(cleaned[cleaned.index(after: lastColon)...])
            }
            for part in cleaned.components(separatedBy: CharacterSet(charactersIn: ",;")) {
                let candidate = part.trimmingCharacters(in: .whitespacesAndNewlines)
                guard candidate.count >= 3 && !candidate.contains(" ") && candidate.rangeOfCharacter(from: .letters) != nil else {
                    continue
                }
                // If the English query is a verb, skip capitalized German nouns (like "Lack" or "Farbe" inside prose explanations)
                if isVerbPage && candidate.first?.isUppercase == true {
                    continue
                }
                if !extractedWords.contains(where: { $0.lowercased() == candidate.lowercased() }) {
                    extractedWords.append(candidate)
                }
            }
            if extractedWords.count >= 3 { break }
        }
        return extractedWords.isEmpty ? nil : extractedWords
    }
    
    private func parsePOSSections(from germanSection: String, word: String) -> [WiktionaryPOSSection] {
        let pattern = #"(?:^|\n)===\s*([^=\n]+?)\s*===\n"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return []
        }
        let matches = regex.matches(in: germanSection, options: [], range: NSRange(germanSection.startIndex..<germanSection.endIndex, in: germanSection))
        guard !matches.isEmpty else {
            if germanSection.contains("Bedeutungen:") {
                return [WiktionaryPOSSection(header: "", articleOrType: inferFallbackArticleOrType(for: word), body: germanSection)]
            }
            return []
        }
        
        var sections: [WiktionaryPOSSection] = []
        for (i, match) in matches.enumerated() {
            guard match.numberOfRanges >= 2,
                  let headerRange = Range(match.range(at: 1), in: germanSection),
                  let fullMatchRange = Range(match.range, in: germanSection) else {
                continue
            }
            let header = String(germanSection[headerRange]).trimmingCharacters(in: .whitespacesAndNewlines)
            let bodyStart = fullMatchRange.upperBound
            let bodyEnd: String.Index
            if i + 1 < matches.count, let nextRange = Range(matches[i + 1].range, in: germanSection) {
                bodyEnd = nextRange.lowerBound
            } else {
                bodyEnd = germanSection.endIndex
            }
            let body = String(germanSection[bodyStart..<bodyEnd])
            
            // Skip pure inflection sub-sections ("Konjugierte Form", "Deklinierte Form", "Partizip II") unless they have their own Bedeutungen:
            guard body.contains("Bedeutungen:") else { continue }
            
            let articleOrType = mapHeaderToArticleOrType(header: header, body: body, word: word)
            sections.append(WiktionaryPOSSection(header: header, articleOrType: articleOrType, body: body))
        }
        return sections
    }
    
    private func mapHeaderToArticleOrType(header: String, body: String, word: String) -> String {
        let h = header.lowercased()
        if header.contains("Substantiv, m") || h.contains(", m") { return "der" }
        if header.contains("Substantiv, f") || h.contains(", f") { return "die" }
        if header.contains("Substantiv, n") || h.contains(", n") { return "das" }
        if h.contains("adjektiv") || h.contains("partizip") { return "Adjektiv" }
        if h.contains("adverb") || h.contains("partikel") || h.contains("konjunktion") || h.contains("subjunktion") || h.contains("präposition") {
            return "Adverb"
        }
        if h.contains("verb") { return "Verb" }
        if h.contains("redewendung") || h.contains("wortverbindung") || word.contains(" ") { return "Ausdruck" }
        
        if body.contains("Substantiv, m") { return "der" }
        if body.contains("Substantiv, f") { return "die" }
        if body.contains("Substantiv, n") { return "das" }
        return inferFallbackArticleOrType(for: word)
    }
    
    private func inferFallbackArticleOrType(for word: String) -> String {
        if word.contains(" ") { return "Ausdruck" }
        if let first = word.first, first.isUppercase {
            let lower = word.lowercased()
            if lower.hasSuffix("ung") || lower.hasSuffix("heit") || lower.hasSuffix("keit") || lower.hasSuffix("schaft") || lower.hasSuffix("tion") || lower.hasSuffix("tät") || lower.hasSuffix("ik") || lower.hasSuffix("enz") || lower.hasSuffix("anz") {
                return "die"
            }
            if lower.hasSuffix("chen") || lower.hasSuffix("lein") || lower.hasSuffix("ment") || lower.hasSuffix("um") || lower.hasSuffix("nis") || lower.hasSuffix("tum") {
                return "das"
            }
            return "der"
        }
        let lower = word.lowercased()
        if lower.hasSuffix("en") || lower.hasSuffix("eln") || lower.hasSuffix("ern") {
            return "Verb"
        }
        return "Adjektiv"
    }
    
    private func buildCandidatesFromWiktionary(
        title: String,
        germanDeExtract: String,
        enExtract: String?
    ) async -> [GeminiWordCandidate] {
        let posSections = parsePOSSections(from: germanDeExtract, word: title)
        guard !posSections.isEmpty else {
            return []
        }
        
        var candidates: [GeminiWordCandidate] = []
        var seenTypes = Set<String>()
        
        // Build candidate(s) strictly for the queried word itself across its distinct parts of speech (e.g. "überlegen" as Verb & Adjektiv)
        for section in posSections {
            guard !seenTypes.contains(section.articleOrType),
                  let germanDef = parseSectionLine(from: section.body, sectionHeader: "Bedeutungen:") else {
                continue
            }
            seenTypes.insert(section.articleOrType)
            
            let examples = parseExamples(from: section.body, fallbackWord: title, articleOrType: section.articleOrType)
            var englishDef = parseEnglishDefinition(from: enExtract, targetWord: title, preferredPOS: section.articleOrType)
            if englishDef == nil {
                englishDef = await fetchFallbackEnglishTranslation(for: title)
            }
            let cefr = estimateCEFRLevel(for: title, definition: germanDef)
            
            candidates.append(
                GeminiWordCandidate(
                    articleOrType: section.articleOrType,
                    word: title,
                    cefrLevel: cefr,
                    englishDefinition: englishDef ?? "German vocabulary: \(title)",
                    germanDefinition: germanDef,
                    b1Example: examples.b1,
                    b2Example: examples.b2
                )
            )
            if candidates.count >= 3 { break }
        }
        
        return candidates
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
            if cleaned.count >= 3 {
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
            // Prefer primary sense [1] synonyms so secondary/archaic senses don't pollute results
            if !results.isEmpty && !line.hasPrefix("[1]") {
                break
            }
            let cleaned = stripParentheticalNote(
                from: line.replacingOccurrences(of: #"^\[\d+[a-z]?\]\s*"#, with: "", options: .regularExpression)
            )
            let parts = cleaned.components(separatedBy: CharacterSet(charactersIn: ",;"))
            for part in parts {
                let word = part.trimmingCharacters(in: .whitespacesAndNewlines)
                if word.count >= 3 && !word.contains(" ") && !word.contains(":") && word.rangeOfCharacter(from: .letters) != nil {
                    results.append(word)
                }
            }
            if results.count >= 3 { break }
        }
        return results
    }
    
    /// Strictly extracts the English definition from the `== German ==` section of en.wiktionary.org
    private func parseEnglishDefinition(from enExtract: String?, targetWord: String, preferredPOS: String) -> String? {
        guard let text = enExtract else { return nil }
        // MUST contain "== German ==", never fall back to Swedish/Norwegian/Old High German sections!
        guard let range = text.range(of: "== German ==") else {
            return nil
        }
        
        let afterGerman = String(text[range.upperBound...])
        let germanSection: String
        let nextLangPattern = #"\n==\s*[^=][^\n]*==\s*\n"#
        if let nextRegex = try? NSRegularExpression(pattern: nextLangPattern, options: []),
           let nextMatch = nextRegex.firstMatch(in: afterGerman, options: [], range: NSRange(afterGerman.startIndex..<afterGerman.endIndex, in: afterGerman)),
           let endRange = Range(nextMatch.range, in: afterGerman) {
            germanSection = String(afterGerman[..<endRange.lowerBound])
        } else {
            germanSection = afterGerman
        }
        
        let allHeaders: [String]
        switch preferredPOS {
        case "der", "die", "das":
            allHeaders = ["=== Noun ===", "=== Proper noun ==="]
        case "Verb":
            allHeaders = ["=== Verb ==="]
        case "Adjektiv":
            allHeaders = ["=== Adjective ===", "=== Participle ===", "=== Adverb ==="]
        case "Adverb":
            allHeaders = ["=== Adverb ===", "=== Conjunction ===", "=== Subjunction ===", "=== Particle ===", "=== Preposition ===", "=== Adjective ==="]
        default:
            allHeaders = ["=== Noun ===", "=== Verb ===", "=== Adjective ===", "=== Adverb ===", "=== Conjunction ===", "=== Phrase ==="]
        }
        
        let fallbackHeaders = ["=== Noun ===", "=== Verb ===", "=== Adjective ===", "=== Adverb ===", "=== Conjunction ===", "=== Preposition ===", "=== Particle ===", "=== Phrase ==="]
        
        for header in (allHeaders + fallbackHeaders) {
            if let hRange = germanSection.range(of: header) {
                let after = germanSection[hRange.upperBound...]
                let lines = after.components(separatedBy: .newlines)
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                
                var defs: [String] = []
                let lowerTarget = targetWord.lowercased()
                for (index, line) in lines.enumerated() {
                    if line.hasPrefix("==") { break }
                    let lowerLine = line.lowercased()
                    // Always skip headword inflection lines (e.g. "überlegen (weak, third-person singular...)" or "Haus n (strong...)")
                    if index == 0 ||
                       lowerLine.hasPrefix(lowerTarget + " (") ||
                       lowerLine.hasPrefix(lowerTarget + " m ") ||
                       lowerLine.hasPrefix(lowerTarget + " f ") ||
                       lowerLine.hasPrefix(lowerTarget + " n ") ||
                       lowerLine.contains("third-person singular present") ||
                       lowerLine.contains("nominative masculine singular") {
                        continue
                    }
                    if lowerLine.hasPrefix("ipa") ||
                       lowerLine.hasPrefix("hyphenation") ||
                       lowerLine.hasPrefix("audio") ||
                       lowerLine.hasPrefix("rhymes") ||
                       lowerLine.hasPrefix("definite singular of") ||
                       lowerLine.hasPrefix("indefinite plural of") ||
                       lowerLine.hasPrefix("alternative form of") ||
                       lowerLine.hasPrefix("inflection of") {
                        continue
                    }
                    if line.count >= 2 {
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
        guard let url = URL(string: "https://api.mymemory.translated.net/get?q=\(encoded)&langpair=de|en"),
              let data = await performWiktionaryRequest(url: url),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let respData = root["responseData"] as? [String: Any],
              let translated = respData["translatedText"] as? String else {
            return nil
        }
        let clean = translated.trimmingCharacters(in: CharacterSet.punctuationCharacters.union(.whitespacesAndNewlines))
        if clean.count >= 2 && clean.lowercased() != word.lowercased() {
            return clean
        }
        return nil
    }
    
    private func fetchFallbackGermanTranslation(for englishWord: String) async -> String? {
        let encoded = englishWord.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? englishWord
        guard let url = URL(string: "https://api.mymemory.translated.net/get?q=\(encoded)&langpair=en|de"),
              let data = await performWiktionaryRequest(url: url),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let respData = root["responseData"] as? [String: Any],
              let translated = respData["translatedText"] as? String else {
            return nil
        }
        let clean = stripLeadingArticleIfSingleNoun(
            translated.trimmingCharacters(in: CharacterSet.punctuationCharacters.union(.whitespacesAndNewlines))
        )
        if clean.count >= 2 && clean.lowercased() != englishWord.lowercased() {
            return clean
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
