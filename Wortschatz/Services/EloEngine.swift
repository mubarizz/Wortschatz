import Foundation

// MARK: - Learning Game Mode (Weights Learn Score Progress)
public enum LearningGameMode {
    case flashcard
    case reverseQuiz
    case cloze
    case audioDictation
}

// MARK: - Elo & Learn Score Result
public struct EloResult {
    public let newUserElo: Double
    public let newWordElo: Double
    public let userDelta: Double
    public let wordDelta: Double
    public let expectedUserWinProbability: Double
    public let newLearnScore: Int
    public let learnScoreDelta: Int
}

public enum EloEngine {
    
    /// Calculates the standard Elo expected score (win probability)
    public static func expectedScore(playerRating: Double, opponentRating: Double) -> Double {
        return 1.0 / (1.0 + pow(10.0, (opponentRating - playerRating) / 400.0))
    }
    
    /// Dynamic K-factor based on item experience to facilitate rapid initial calibration
    public static func kFactor(reviewsCount: Int) -> Double {
        if reviewsCount < 5 {
            return 32.0
        } else if reviewsCount < 15 {
            return 24.0
        } else {
            return 16.0
        }
    }
    
    /// Computes the updated User Elo (on a 1.000 ➔ 5.000 B2 scale) and Word Learn Score (0–100%) following an attempt.
    public static func calculateOutcome(
        userElo: Double,
        word: VocabularyWord,
        success: Bool,
        mode: LearningGameMode = .cloze
    ) -> EloResult {
        // Dynamic opponent challenge anchored around user progression + word's remaining difficulty
        let effectiveOpponentRating = max(1200.0, userElo + Double(50 - word.learnScore) * 3.5)
        let expectedUser = expectedScore(playerRating: userElo, opponentRating: effectiveOpponentRating)
        
        // Base Elo gain/loss scaled by game mode difficulty so reaching 5.000 Elo requires sustained mastery (~750+ answers)
        let isAlreadyLearned = word.isLearned
        let userDelta: Double
        switch mode {
        case .audioDictation:
            userDelta = success ? (isAlreadyLearned ? 1.0 : 2.5) : -2.5
        case .flashcard:
            userDelta = success ? (isAlreadyLearned ? 1.5 : 3.5) : -3.0
        case .reverseQuiz:
            userDelta = success ? (isAlreadyLearned ? 2.5 : 5.5) : -4.5
        case .cloze:
            userDelta = success ? (isAlreadyLearned ? 3.5 : 7.5) : -5.5
        }
        
        let wordDelta = -userDelta
        let newUserElo = max(1000.0, userElo + userDelta)
        let newWordElo = max(400.0, word.elo + wordDelta)
        
        // Learn Score (0–100%) delta calculation by game mode
        let streakBonus = (success && word.consecutiveCorrect >= 1) ? 5 : 0
        let rawScoreDelta: Int
        switch mode {
        case .flashcard:
            rawScoreDelta = success ? (20 + streakBonus) : -15
        case .reverseQuiz:
            rawScoreDelta = success ? (25 + streakBonus) : -20
        case .cloze:
            rawScoreDelta = success ? (30 + streakBonus) : -20
        case .audioDictation:
            let smallStreakBonus = (success && word.consecutiveCorrect >= 1) ? 2 : 0
            rawScoreDelta = success ? (10 + smallStreakBonus) : -10
        }
        
        let newLearnScore = min(100, max(0, word.learnScore + rawScoreDelta))
        let actualScoreDelta = newLearnScore - word.learnScore
        
        return EloResult(
            newUserElo: newUserElo,
            newWordElo: newWordElo,
            userDelta: userDelta,
            wordDelta: wordDelta,
            expectedUserWinProbability: expectedUser,
            newLearnScore: newLearnScore,
            learnScoreDelta: actualScoreDelta
        )
    }
    
    /// Spaced Repetition Urgency Priority (used for sorting the focus queue):
    /// Unlearned words (< 75%) have highest urgency, ordered by lowest learnScore + mistakes + time elapsed.
    /// Learned words (>= 75%) have lower urgency, ordered by how long ago they were last reviewed.
    public static func calculateUrgency(word: VocabularyWord, userElo: Double, now: Date = Date()) -> Double {
        let hoursSinceReview: Double
        if let lastReview = word.lastReviewedAt {
            hoursSinceReview = max(0, now.timeIntervalSince(lastReview)) / 3600.0
        } else {
            hoursSinceReview = 24.0
        }
        
        if word.isLearned {
            // Learned words (>= 75%) sit below unlearned words, but rise gently over time
            return Double(100 - word.learnScore) * 0.4 + min(40.0, hoursSinceReview * 1.5)
        } else {
            // Unlearned words (< 75%) get priority based on how far from 100% they are + mistakes + time
            let baseNeed = Double(100 - word.learnScore) * 1.5
            let errorBoost = Double(word.incorrectCount) * 10.0
            let timeBoost = min(36.0, hoursSinceReview * 1.5)
            return 100.0 + baseNeed + errorBoost + timeBoost
        }
    }
    
    /// Builds a smart 80% Unlearned / 20% Learned session using weighted spaced-repetition sampling
    /// so learned words never disappear, but appear ~4x less frequently than unlearned words.
    public static func buildSmartSession(
        from words: [VocabularyWord],
        count: Int = 10,
        now: Date = Date()
    ) -> [VocabularyWord] {
        guard !words.isEmpty else { return [] }
        let targetTotal = min(count, words.count)
        
        let unlearnedPool = words.filter { !$0.isLearned }
        let learnedPool = words.filter { $0.isLearned }
        
        // Target ~20% learned words (e.g. 2 out of 10), capped by available learned words
        var targetLearnedCount = min(learnedPool.count, max(1, Int(round(Double(targetTotal) * 0.2))))
        if learnedPool.isEmpty {
            targetLearnedCount = 0
        }
        var targetUnlearnedCount = min(unlearnedPool.count, targetTotal - targetLearnedCount)
        
        // If we have fewer unlearned words than 80%, fill the remaining slots with learned words
        if targetUnlearnedCount + targetLearnedCount < targetTotal {
            targetLearnedCount = min(learnedPool.count, targetTotal - targetUnlearnedCount)
        }
        // Conversely, if we have fewer learned words, fill with unlearned words
        if targetUnlearnedCount + targetLearnedCount < targetTotal {
            targetUnlearnedCount = min(unlearnedPool.count, targetTotal - targetLearnedCount)
        }
        
        let selectedUnlearned = weightedSample(
            pool: unlearnedPool,
            count: targetUnlearnedCount,
            weightFor: { word in
                let hours = word.lastReviewedAt.map { max(0.05, now.timeIntervalSince($0) / 3600.0) } ?? 18.0
                let scoreNeed = Double(105 - word.learnScore) * 1.6
                let mistakeWeight = Double(word.incorrectCount) * 14.0
                let recencyFactor = hours < 0.05 ? 0.35 : min(48.0, hours * 2.0)
                return max(1.0, (scoreNeed + mistakeWeight) * recencyFactor)
            }
        )
        
        let selectedLearned = weightedSample(
            pool: learnedPool,
            count: targetLearnedCount,
            weightFor: { word in
                let hours = word.lastReviewedAt.map { max(0.05, now.timeIntervalSince($0) / 3600.0) } ?? 24.0
                // Prioritize learned words that haven't been reviewed in the longest time
                let scoreSlack = Double(105 - word.learnScore) * 0.5
                return max(1.0, (hours * 4.0) + scoreSlack)
            }
        )
        
        var combined = selectedUnlearned + selectedLearned
        combined.shuffle()
        return combined
    }
    
    private static func weightedSample(
        pool: [VocabularyWord],
        count: Int,
        weightFor: (VocabularyWord) -> Double
    ) -> [VocabularyWord] {
        guard count > 0, !pool.isEmpty else { return [] }
        if pool.count <= count { return pool.shuffled() }
        
        var remaining = pool
        var chosen: [VocabularyWord] = []
        chosen.reserveCapacity(count)
        
        for _ in 0..<count {
            let weights = remaining.map { max(0.001, weightFor($0)) }
            let totalWeight = weights.reduce(0, +)
            var pick = Double.random(in: 0..<totalWeight)
            var selectedIndex = 0
            
            for (idx, w) in weights.enumerated() {
                pick -= w
                if pick <= 0 {
                    selectedIndex = idx
                    break
                }
            }
            
            chosen.append(remaining.remove(at: selectedIndex))
        }
        
        return chosen
    }
}
