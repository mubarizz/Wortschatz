import Foundation
import SwiftUI
import Combine

@MainActor
public final class PrepositionStore: ObservableObject {
    public static let shared = PrepositionStore()
    
    // MARK: - Published Properties
    @Published public private(set) var entries: [PrepositionEntry] = []
    @Published public private(set) var troublemakerIds: Set<String> = []
    @Published public private(set) var bestBlitzScore: Int = 0
    @Published public private(set) var totalAnsweredCount: Int = 0
    @Published public private(set) var totalCorrectCount: Int = 0
    
    private let troublemakersDefaultsKey = "wortschatz_troublemaker_preposition_ids"
    private let blitzBestScoreDefaultsKey = "wortschatz_preposition_blitz_best_score"
    private let statsDefaultsKey = "wortschatz_preposition_stats_answered_correct"
    
    public init() {
        self.entries = PrepositionDatabase.entries
        loadStoredData()
    }
    
    // MARK: - Persistence
    private func loadStoredData() {
        if let storedIds = UserDefaults.standard.stringArray(forKey: troublemakersDefaultsKey) {
            self.troublemakerIds = Set(storedIds)
        }
        self.bestBlitzScore = UserDefaults.standard.integer(forKey: blitzBestScoreDefaultsKey)
        
        let stats = UserDefaults.standard.array(forKey: statsDefaultsKey) as? [Int] ?? [0, 0]
        if stats.count >= 2 {
            self.totalAnsweredCount = stats[0]
            self.totalCorrectCount = stats[1]
        }
    }
    
    private func saveTroublemakers() {
        UserDefaults.standard.set(Array(troublemakerIds), forKey: troublemakersDefaultsKey)
    }
    
    public func saveBlitzBestScore(_ score: Int) {
        if score > bestBlitzScore {
            bestBlitzScore = score
            UserDefaults.standard.set(score, forKey: blitzBestScoreDefaultsKey)
        }
    }
    
    public func recordAnswer(entryId: String, wasCorrect: Bool) {
        totalAnsweredCount += 1
        if wasCorrect {
            totalCorrectCount += 1
            // Remove from troublemakers if correctly answered 
            if troublemakerIds.contains(entryId) {
                troublemakerIds.remove(entryId)
                saveTroublemakers()
            }
        } else {
            troublemakerIds.insert(entryId)
            saveTroublemakers()
        }
        UserDefaults.standard.set([totalAnsweredCount, totalCorrectCount], forKey: statsDefaultsKey)
    }
    
    // MARK: - Question Factory
    public enum GameMode: String, CaseIterable, Identifiable {
        case blitz = "60s Blitz"
        case classic = "Klassik (15)"
        case troublemakers = "Schwachstellen"
        
        public var id: String { rawValue }
        
        public var icon: String {
            switch self {
            case .blitz: return "bolt.fill"
            case .classic: return "book.fill"
            case .troublemakers: return "exclamationmark.triangle.fill"
            }
        }
    }
    
    public func buildQuestions(mode: GameMode, levelFilter: String = "Alle") -> [PrepositionQuestion] {
        var pool = entries
        
        if levelFilter != "Alle" {
            pool = pool.filter { $0.cefrLevel == levelFilter }
        }
        
        if mode == .troublemakers {
            let weakPool = pool.filter { troublemakerIds.contains($0.id) }
            if !weakPool.isEmpty {
                pool = weakPool
            }
        }
        
        guard !pool.isEmpty else { return [] }
        
        let targetCount: Int
        switch mode {
        case .blitz:
            targetCount = min(40, pool.count * 2) // Large pool for rapid blitz
        case .classic:
            targetCount = min(15, pool.count)
        case .troublemakers:
            targetCount = pool.count
        }
        
        var selectedEntries: [PrepositionEntry] = []
        let shuffled = pool.shuffled()
        
        if mode == .blitz && targetCount > shuffled.count {
            while selectedEntries.count < targetCount {
                selectedEntries.append(contentsOf: shuffled.shuffled())
            }
            selectedEntries = Array(selectedEntries.prefix(targetCount))
        } else {
            selectedEntries = Array(shuffled.prefix(targetCount))
        }
        
        return selectedEntries.map { entry in
            makeQuestion(for: entry)
        }
    }
    
    private func makeQuestion(for entry: PrepositionEntry) -> PrepositionQuestion {
        let correct = entry.correctCombination
        var optionsSet = Set<String>([correct])
        
        // 1. Add curated distractors from entry
        for d in entry.distractorOptions {
            optionsSet.insert(d)
        }
        
        // 2. Fallback pool of high frequency German combinations
        let commonCombinations = [
            "an + Dat.", "an + Akk.",
            "auf + Akk.", "auf + Dat.",
            "aus + Dat.", "bei + Dat.",
            "für + Akk.", "gegen + Akk.",
            "in + Dat.", "in + Akk.",
            "mit + Dat.", "nach + Dat.",
            "über + Akk.", "um + Akk.",
            "unter + Dat.", "von + Dat.",
            "vor + Dat.", "zu + Dat."
        ]
        
        for cand in commonCombinations.shuffled() where optionsSet.count < 4 {
            optionsSet.insert(cand)
        }
        
        var finalOptions = Array(optionsSet.prefix(4))
        finalOptions.shuffle()
        let correctIndex = finalOptions.firstIndex(of: correct) ?? 0
        
        return PrepositionQuestion(
            entry: entry,
            options: finalOptions,
            correctIndex: correctIndex
        )
    }
}
