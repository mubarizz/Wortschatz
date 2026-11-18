import Foundation

// MARK: - Elo Rating Engine for Spaced Repetition (SRS)
public struct EloResult {
    public let newUserElo: Double
    public let newWordElo: Double
    public let userDelta: Double
    public let wordDelta: Double
    public let expectedUserWinProbability: Double
}

public enum EloEngine {
    
    /// Calculates the standard Elo expected score (win probability)
    /// - Parameters:
    ///   - playerRating: The rating of the primary participant (e.g. User)
    ///   - opponentRating: The rating of the challenge (e.g. Word)
    /// - Returns: Expected probability between 0.0 and 1.0
    public static func expectedScore(playerRating: Double, opponentRating: Double) -> Double {
        return 1.0 / (1.0 + pow(10.0, (opponentRating - playerRating) / 400.0))
    }
    
    /// Dynamic K-factor based on item experience to facilitate rapid initial calibration
    public static func kFactor(reviewsCount: Int) -> Double {
        if reviewsCount < 5 {
            return 32.0 // Provisional rating
        } else if reviewsCount < 15 {
            return 24.0 // Intermediate calibration
        } else {
            return 16.0 // Established rating
        }
    }
    
    /// Computes the updated ratings following an attempt.
    /// In this model:
    /// - Correct answer (success = true): User rating rises; Word rating drops (word is conquered / pushed back in queue).
    /// - Incorrect answer (success = false): User rating falls; Word rating rises (word proves challenging / pulled forward in queue).
    public static func calculateOutcome(
        userElo: Double,
        word: VocabularyWord,
        success: Bool
    ) -> EloResult {
        let expectedUser = expectedScore(playerRating: userElo, opponentRating: word.elo)
        let actualUser: Double = success ? 1.0 : 0.0
        
        let k = kFactor(reviewsCount: word.reviewsCount)
        let userDelta = k * (actualUser - expectedUser)
        
        // When user succeeds, word difficulty decreases (mastery).
        // When user fails, word difficulty increases.
        let wordDelta = -userDelta
        
        let newUserElo = max(400.0, userElo + userDelta)
        let newWordElo = max(400.0, word.elo + wordDelta)
        
        return EloResult(
            newUserElo: newUserElo,
            newWordElo: newWordElo,
            userDelta: userDelta,
            wordDelta: wordDelta,
            expectedUserWinProbability: expectedUser
        )
    }
    
    /// Spaced Repetition Urgency Priority:
    /// Words with higher Elo (harder) or longer time since last review receive higher urgency scores.
    public static func calculateUrgency(word: VocabularyWord, userElo: Double, now: Date = Date()) -> Double {
        // Base ratio: higher word Elo compared to user means the word poses a greater challenge
        let relativeDifficulty = word.elo / max(userElo, 400.0)
        
        guard let lastReview = word.lastReviewedAt else {
            // Never-reviewed words get high baseline priority
            return 100.0 * relativeDifficulty
        }
        
        let secondsSinceReview = max(0, now.timeIntervalSince(lastReview))
        let hoursSinceReview = secondsSinceReview / 3600.0
        
        // Time factor: exponential growth based on hours elapsed
        let timeFactor = log10(hoursSinceReview + 1.0) + 1.0
        
        // Consecutive correct discount: mastered words with high streak get delayed longer
        let streakDiscount = 1.0 / Double(word.consecutiveCorrect + 1)
        
        return relativeDifficulty * timeFactor * (1.0 + streakDiscount * 2.0)
    }
}
