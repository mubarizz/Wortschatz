import Foundation
import SwiftUI
import Combine

// MARK: - VocabularyStore (ObservableObject Central State)
public final class VocabularyStore: ObservableObject {
    
    // MARK: - Published State
    @Published public var words: [VocabularyWord] = []
    @Published public var userElo: Double = 1200.0
    @Published public var dailyStreak: Int = 1
    @Published public var totalReviews: Int = 0
    @Published public var lastStudyDate: Date? = nil
    @Published public var isLoading: Bool = false
    @Published public var errorMessage: String? = nil
    
    // MARK: - Persistence Keys & Paths
    private let userDefaultsKeyUserElo = "wortschatz_user_elo"
    private let userDefaultsKeyStreak = "wortschatz_daily_streak"
    private let userDefaultsKeyTotalReviews = "wortschatz_total_reviews"
    private let userDefaultsKeyLastDate = "wortschatz_last_study_date"
    
    private var wordsStorageURL: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("wortschatz_saved_words.json")
    }
    
    public init() {
        loadData()
    }
    
    // MARK: - Data Ingestion & Persistence
    
    public func loadData() {
        isLoading = true
        errorMessage = nil
        
        // 1. Load User Meta
        let savedElo = UserDefaults.standard.double(forKey: userDefaultsKeyUserElo)
        if savedElo > 0 {
            self.userElo = savedElo
        }
        self.dailyStreak = max(1, UserDefaults.standard.integer(forKey: userDefaultsKeyStreak))
        self.totalReviews = UserDefaults.standard.integer(forKey: userDefaultsKeyTotalReviews)
        if let lastDate = UserDefaults.standard.object(forKey: userDefaultsKeyLastDate) as? Date {
            self.lastStudyDate = lastDate
            checkStreakContinuity(lastDate: lastDate)
        }
        
        // 2. Load Words: Try local JSON cache first
        if FileManager.default.fileExists(atPath: wordsStorageURL.path) {
            do {
                let data = try Data(contentsOf: wordsStorageURL)
                let decoded = try JSONDecoder().decode([VocabularyWord].self, from: data)
                if !decoded.isEmpty {
                    self.words = decoded
                    self.isLoading = false
                    importPendingWordsFromExtension()
                    SharedLookupBridge.shared.saveVocabularySnapshot(self.words)
                    return
                }
            } catch {
                print("Failed to load cached words: \(error.localizedDescription). Falling back to CSV.")
            }
        }
        
        // 3. Fallback to bundled wortschatz.csv or embedded dataset
        loadFromBundledCSV()
        importPendingWordsFromExtension()
    }
    
    public func loadFromBundledCSV() {
        // Try Bundle.main
        if let bundleURL = Bundle.main.url(forResource: "wortschatz", withExtension: "csv") {
            do {
                let parsed = try CSVParser.shared.parse(fileURL: bundleURL)
                if !parsed.isEmpty {
                    mergeWords(parsed)
                    self.isLoading = false
                    return
                }
            } catch {
                print("Bundle CSV failed: \(error.localizedDescription)")
            }
        }
        
        // Try direct file path (useful for local development testing)
        let localPath = "/home/antigravity/wortschatz.csv"
        let fallbackURL = URL(fileURLWithPath: localPath)
        if FileManager.default.fileExists(atPath: fallbackURL.path) {
            if let parsed = try? CSVParser.shared.parse(fileURL: fallbackURL), !parsed.isEmpty {
                mergeWords(parsed)
                self.isLoading = false
                return
            }
        }
        
        // Embedded 34-word dataset fallback: 100% reliable in any Xcode simulator or test
        loadEmbeddedFallbackData()
    }
    
    /// Merges incoming CSV words without losing custom added words or existing Elo/review progress
    private func mergeWords(_ incoming: [VocabularyWord]) {
        if self.words.isEmpty {
            self.words = incoming
        } else {
            var existingKeys = Set(self.words.map { $0.cleanTargetWord.lowercased() })
            for item in incoming {
                let key = item.cleanTargetWord.lowercased()
                if !existingKeys.contains(key) {
                    self.words.append(item)
                    existingKeys.insert(key)
                }
            }
        }
        saveWordsToDisk()
    }
    
    // MARK: - Custom Word Addition & Editing
    
    public func hasWord(_ rawWord: String) -> Bool {
        let cleaned = rawWord
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: #"^(der|die|das)\s+"#, with: "", options: [.regularExpression, .caseInsensitive])
            .lowercased()
        return words.contains { $0.cleanTargetWord.lowercased() == cleaned }
    }
    
    @discardableResult
    public func addWord(_ newWord: VocabularyWord) -> Bool {
        guard !hasWord(newWord.cleanTargetWord) else {
            return false
        }
        words.insert(newWord, at: 0)
        saveWordsToDisk()
        return true
    }
    
    public func updateWord(_ updatedWord: VocabularyWord) {
        if let idx = words.firstIndex(where: { $0.id == updatedWord.id }) {
            words[idx] = updatedWord
            saveWordsToDisk()
        }
    }
    
    public func deleteWord(id: UUID) {
        words.removeAll { $0.id == id }
        saveWordsToDisk()
    }
    
    /// Awards Elo and records review activity from game modes (such as Preposition Sprint or Schreiben)
    public func recordExternalGameActivity(points: Double, reviewsCount: Int) {
        self.userElo = max(1000.0, self.userElo + points)
        self.totalReviews += reviewsCount
        self.lastStudyDate = Date()
        updateDailyStreak()
        saveWordsToDisk()
    }
    
    public func loadFromCSVURL(_ url: URL) {
        isLoading = true
        do {
            let parsed = try CSVParser.shared.parse(fileURL: url)
            self.words = parsed
            saveWordsToDisk()
            self.isLoading = false
        } catch {
            self.errorMessage = "Fehler beim Laden der CSV: \(error.localizedDescription)"
            self.isLoading = false
        }
    }
    
    public func loadFromRawCSV(text: String) {
        isLoading = true
        do {
            let parsed = try CSVParser.shared.parse(csvString: text)
            self.words = parsed
            saveWordsToDisk()
            self.isLoading = false
        } catch {
            self.errorMessage = "CSV Parsing-Fehler: \(error.localizedDescription)"
            self.isLoading = false
        }
    }
    
    /// Imports any words saved via the iOS Share Extension ("Im Wortschatz nachschlagen") and awards +5 Elo per discovered word
    @discardableResult
    public func importPendingWordsFromExtension() -> [VocabularyWord] {
        let pending = SharedLookupBridge.shared.loadPendingWords()
        guard !pending.isEmpty else { return [] }
        
        var newlyAdded: [VocabularyWord] = []
        for item in pending.reversed() {
            if !hasWord(item.cleanTargetWord) {
                words.insert(item, at: 0)
                newlyAdded.append(item)
            }
        }
        
        SharedLookupBridge.shared.clearPendingWords()
        
        if !newlyAdded.isEmpty {
            let bonusElo = Double(newlyAdded.count) * 5.0
            self.userElo = max(1000.0, self.userElo + bonusElo)
            self.lastStudyDate = Date()
            updateDailyStreak()
            saveWordsToDisk()
        }
        return newlyAdded
    }
    
    public func saveWordsToDisk() {
        do {
            let data = try JSONEncoder().encode(words)
            try data.write(to: wordsStorageURL, options: .atomic)
            
            // Save User Meta
            UserDefaults.standard.set(userElo, forKey: userDefaultsKeyUserElo)
            UserDefaults.standard.set(dailyStreak, forKey: userDefaultsKeyStreak)
            UserDefaults.standard.set(totalReviews, forKey: userDefaultsKeyTotalReviews)
            UserDefaults.standard.set(lastStudyDate, forKey: userDefaultsKeyLastDate)
            
            // Sync vocabulary snapshot for iOS Share Extension
            SharedLookupBridge.shared.saveVocabularySnapshot(words)
        } catch {
            print("Error persisting words: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Spaced Repetition, Learn Score & Elo Interaction
    
    @discardableResult
    public func recordAttempt(wordId: UUID, success: Bool, mode: LearningGameMode = .cloze) -> EloResult? {
        guard let index = words.firstIndex(where: { $0.id == wordId }) else {
            return nil
        }
        
        var word = words[index]
        let result = EloEngine.calculateOutcome(userElo: userElo, word: word, success: success, mode: mode)
        
        // Update user
        self.userElo = result.newUserElo
        self.totalReviews += 1
        self.lastStudyDate = Date()
        updateDailyStreak()
        
        // Update word stats & Learn Score (0–100%)
        word.elo = result.newWordElo
        word.learnScore = result.newLearnScore
        word.reviewsCount += 1
        word.lastReviewedAt = Date()
        
        if success {
            word.correctCount += 1
            word.consecutiveCorrect += 1
        } else {
            word.incorrectCount += 1
            word.consecutiveCorrect = 0
        }
        
        words[index] = word
        saveWordsToDisk()
        
        return result
    }
    
    // MARK: - Queue & Matching Selectors
    
    /// Generates an 80% Unlearned (<75%) / 20% Learned (>=75%) session so learned words show up less without disappearing
    public func generateSmartSession(count: Int = 10) -> [VocabularyWord] {
        return EloEngine.buildSmartSession(from: words, count: count)
    }
    
    /// Spaced Repetition queue sorted by dynamic urgency (unlearned & lowest Learn Score first)
    public var spacedRepetitionQueue: [VocabularyWord] {
        let now = Date()
        return words.sorted { w1, w2 in
            let u1 = EloEngine.calculateUrgency(word: w1, userElo: userElo, now: now)
            let u2 = EloEngine.calculateUrgency(word: w2, userElo: userElo, now: now)
            return u1 > u2
        }
    }
    
    /// Words that have reached >= 75% Learn Score ("Gelernt")
    public var learnedWords: [VocabularyWord] {
        words.filter { $0.isLearned }
    }
    
    /// Words still below 75% Learn Score ("Zu lernen / Im Training")
    public var unlearnedWords: [VocabularyWord] {
        words.filter { !$0.isLearned }
    }
    
    /// Words that have unlocked B2-level testing
    public var b2UnlockedWords: [VocabularyWord] {
        words.filter { $0.isB2MasteryReached }
    }
    
    /// Words currently in B1 training phase
    public var b1TrainingWords: [VocabularyWord] {
        words.filter { !$0.isB2MasteryReached }
    }
    
    // MARK: - User Rank / Tier (1.000 ➔ 5.000 B2 Scale)
    public var userRankTitle: String {
        switch userElo {
        case ..<1500: return "A2 / B1 Einsteiger"
        case 1500..<2300: return "B1 Lernender"
        case 2300..<3200: return "B1+ Festiger"
        case 3200..<4200: return "B2 Anwärter"
        case 4200..<5000: return "B2 Fortgeschritten"
        case 5000..<6000: return "B2 Meister ✓"
        default: return "C1 Virtuose"
        }
    }
    
    public var userRankColor: Color {
        switch userElo {
        case ..<1500: return Color(red: 0.14, green: 0.46, blue: 0.96)
        case 1500..<2300: return .teal
        case 2300..<3200: return .indigo
        case 3200..<4200: return .purple
        case 4200..<5000: return Color(red: 0.85, green: 0.32, blue: 0.55)
        case 5000..<6000: return .orange
        default: return .green
        }
    }
    
    // MARK: - Streaks & Stats
    private func updateDailyStreak() {
        let calendar = Calendar.current
        guard let last = lastStudyDate else {
            dailyStreak = 1
            return
        }
        if calendar.isDateInToday(last) {
            return
        }
        if calendar.isDateInYesterday(last) {
            dailyStreak += 1
        } else {
            dailyStreak = 1
        }
    }
    
    private func checkStreakContinuity(lastDate: Date) {
        let calendar = Calendar.current
        if !calendar.isDateInToday(lastDate) && !calendar.isDateInYesterday(lastDate) {
            dailyStreak = 1
        }
    }
    
    public func resetProgress() {
        userElo = 1200.0
        totalReviews = 0
        dailyStreak = 1
        lastStudyDate = nil
        words = []
        try? FileManager.default.removeItem(at: wordsStorageURL)
        loadFromBundledCSV()
    }
    
    // MARK: - Fallback Seed Data (Loads all 34 real words)
    private func loadEmbeddedFallbackData() {
        loadFromRawCSV(text: EmbeddedDataset.csvString)
    }
}
