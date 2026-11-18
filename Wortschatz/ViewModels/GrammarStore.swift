import Foundation
import SwiftUI

public struct SatzbauChallenge: Identifiable, Equatable {
    public let id = UUID()
    public let topic: GrammarTopic
    public let exercise: GrammarExercise
}

public struct GrammarAttemptResult {
    public let previousScore: Int
    public let newScore: Int
    public let scoreDelta: Int
    public let userEloDelta: Double
    public let newUserElo: Double
}

public final class GrammarStore: ObservableObject {
    @Published public var topics: [GrammarTopic] = []
    
    private var storageURL: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("wortschatz_saved_grammar.json")
    }
    
    public init() {
        loadTopics()
    }
    
    public func loadTopics() {
        let seed = GrammarCurriculum.loadAllTopicsWithExercises()
        
        if FileManager.default.fileExists(atPath: storageURL.path),
           let data = try? Data(contentsOf: storageURL),
           let saved = try? JSONDecoder().decode([GrammarTopic].self, from: data),
           !saved.isEmpty {
            // Merge saved progress with seed curriculum so new topics/exercises are always up to date
            var savedMap: [String: GrammarTopic] = [:]
            for item in saved {
                savedMap[item.id] = item
            }
            
            var merged: [GrammarTopic] = []
            for var topic in seed {
                if let existing = savedMap[topic.id] {
                    topic.learnScore = existing.learnScore
                    topic.reviewsCount = existing.reviewsCount
                    topic.correctCount = existing.correctCount
                    topic.incorrectCount = existing.incorrectCount
                    topic.consecutiveCorrect = existing.consecutiveCorrect
                    topic.lastReviewedAt = existing.lastReviewedAt
                }
                merged.append(topic)
            }
            self.topics = merged
            saveTopics()
        } else {
            self.topics = seed
            saveTopics()
        }
    }
    
    public func saveTopics() {
        if let data = try? JSONEncoder().encode(topics) {
            try? data.write(to: storageURL, options: .atomic)
        }
    }
    
    // MARK: - Computed Filters
    public var unlearnedTopics: [GrammarTopic] {
        topics.filter { !$0.isLearned }
    }
    
    public var learnedTopics: [GrammarTopic] {
        topics.filter { $0.isLearned }
    }
    
    public var b1Topics: [GrammarTopic] {
        topics.filter { $0.level == "B1" }
    }
    
    public var b2Topics: [GrammarTopic] {
        topics.filter { $0.level == "B2" }
    }
    
    // MARK: - Record Attempt (Updates Topic Learn Score + User Elo)
    @discardableResult
    public func recordAttempt(
        topicId: String,
        success: Bool,
        vocabStore: VocabularyStore? = nil
    ) -> GrammarAttemptResult? {
        guard let idx = topics.firstIndex(where: { $0.id == topicId }) else { return nil }
        var topic = topics[idx]
        
        let prevScore = topic.learnScore
        let wasAlreadyLearned = topic.isLearned
        let streakBonus = (success && topic.consecutiveCorrect >= 1) ? 5 : 0
        let rawDelta = success ? (25 + streakBonus) : -15
        
        let updatedScore = min(100, max(0, prevScore + rawDelta))
        let actualDelta = updatedScore - prevScore
        
        topic.learnScore = updatedScore
        topic.reviewsCount += 1
        topic.lastReviewedAt = Date()
        if success {
            topic.correctCount += 1
            topic.consecutiveCorrect += 1
        } else {
            topic.incorrectCount += 1
            topic.consecutiveCorrect = 0
        }
        
        topics[idx] = topic
        saveTopics()
        
        // Update User Elo on the 1.000 -> 5.000 scale if vocabStore is provided
        let eloDelta: Double = success ? (wasAlreadyLearned ? 2.5 : 6.0) : -4.0
        var updatedUserElo: Double = vocabStore?.userElo ?? 1200.0
        if let store = vocabStore {
            updatedUserElo = max(1000.0, store.userElo + eloDelta)
            store.userElo = updatedUserElo
            store.totalReviews += 1
            store.lastStudyDate = Date()
            store.saveWordsToDisk()
        }
        
        return GrammarAttemptResult(
            previousScore: prevScore,
            newScore: updatedScore,
            scoreDelta: actualDelta,
            userEloDelta: eloDelta,
            newUserElo: updatedUserElo
        )
    }
    
    // MARK: - Smart 80/20 Satzbau Session Generator
    public func generateSatzbauSession(
        focusTopic: GrammarTopic? = nil,
        levelFilter: String? = nil,
        count: Int = 10
    ) -> [SatzbauChallenge] {
        // 1. If a specific topic was selected, draw `count` random exercises from its 50-sentence bank
        if let focus = focusTopic,
           let liveTopic = topics.first(where: { $0.id == focus.id }) ?? Optional(focus) {
            return Array(liveTopic.exercises.shuffled().prefix(count)).map {
                SatzbauChallenge(topic: liveTopic, exercise: $0)
            }
        }
        
        // 2. Otherwise, build an 80% Unlearned (<75%) / 20% Learned (>=75%) Smart Session
        let pool: [GrammarTopic]
        if let lvl = levelFilter, (lvl == "B1" || lvl == "B2") {
            pool = topics.filter { $0.level == lvl }
        } else {
            pool = topics
        }
        
        let unlearned = pool.filter { !$0.isLearned }
        let learned = pool.filter { $0.isLearned }
        
        var targetLearned = learned.isEmpty ? 0 : max(1, Int(round(Double(count) * 0.2)))
        targetLearned = min(learned.count, targetLearned)
        var targetUnlearned = min(unlearned.count, count - targetLearned)
        
        if targetUnlearned + targetLearned < count {
            targetLearned = min(learned.count, count - targetUnlearned)
        }
        if targetUnlearned + targetLearned < count {
            targetUnlearned = min(unlearned.count, count - targetLearned)
        }
        
        let now = Date()
        let chosenUnlearned = weightedTopicSample(pool: unlearned, count: targetUnlearned) { t in
            let hours = t.lastReviewedAt.map { max(0.05, now.timeIntervalSince($0) / 3600.0) } ?? 18.0
            let need = Double(105 - t.learnScore) * 1.5 + Double(t.incorrectCount) * 12.0
            return max(1.0, need * min(36.0, hours * 1.8))
        }
        
        let chosenLearned = weightedTopicSample(pool: learned, count: targetLearned) { t in
            let hours = t.lastReviewedAt.map { max(0.05, now.timeIntervalSince($0) / 3600.0) } ?? 24.0
            return max(1.0, hours * 4.0 + Double(105 - t.learnScore) * 0.5)
        }
        
        var selectedTopics = chosenUnlearned + chosenLearned
        if selectedTopics.isEmpty {
            selectedTopics = Array(pool.shuffled().prefix(count))
        }
        
        var challenges: [SatzbauChallenge] = []
        for t in selectedTopics {
            if let ex = t.exercises.randomElement() {
                challenges.append(SatzbauChallenge(topic: t, exercise: ex))
            }
        }
        
        // If we still need more challenges to reach `count`, add remaining exercises from unlearned/pool
        if challenges.count < count {
            let usedExerciseIDs = Set(challenges.map { $0.exercise.id })
            let extraPool = (unlearned.isEmpty ? pool : unlearned).shuffled()
            for t in extraPool {
                for ex in t.exercises.shuffled() where !usedExerciseIDs.contains(ex.id) {
                    challenges.append(SatzbauChallenge(topic: t, exercise: ex))
                    if challenges.count >= count { break }
                }
                if challenges.count >= count { break }
            }
        }
        
        return challenges.shuffled()
    }
    
    private func weightedTopicSample(
        pool: [GrammarTopic],
        count: Int,
        weightFor: (GrammarTopic) -> Double
    ) -> [GrammarTopic] {
        guard count > 0, !pool.isEmpty else { return [] }
        if pool.count <= count { return pool.shuffled() }
        
        var remaining = pool
        var result: [GrammarTopic] = []
        
        for _ in 0..<count {
            let weights = remaining.map { max(0.001, weightFor($0)) }
            let sum = weights.reduce(0, +)
            var pick = Double.random(in: 0..<sum)
            var chosenIdx = 0
            for (idx, w) in weights.enumerated() {
                pick -= w
                if pick <= 0 {
                    chosenIdx = idx
                    break
                }
            }
            result.append(remaining.remove(at: chosenIdx))
        }
        return result
    }
}
