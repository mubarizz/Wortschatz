import Foundation

// MARK: - Quiz Question & Distractor Engine
public struct QuizQuestion: Identifiable {
    public let id = UUID()
    public let targetWord: VocabularyWord
    public let options: [VocabularyWord]
    public let correctIndex: Int
    
    public var germanDefinition: String {
        targetWord.germanDefinition
    }
}

public enum QuizEngine {
    
    /// Generates a single quiz question with 3 plausible distractors
    /// Distractors prioritize words of the same grammatical category (nouns with nouns, verbs with verbs)
    public static func generateQuestion(target: VocabularyWord, allWords: [VocabularyWord]) -> QuizQuestion {
        let pool = allWords.filter { $0.id != target.id }
        
        // 1. Try to find distractors of the same category (e.g., both Verbs or both feminine nouns)
        var preferredDistractors = pool.filter { $0.category == target.category }
        
        // If not enough same-category words, supplement with any words
        if preferredDistractors.count < 3 {
            let remaining = pool.filter { !preferredDistractors.contains($0) }
            preferredDistractors.append(contentsOf: remaining.shuffled())
        } else {
            preferredDistractors.shuffle()
        }
        
        let selectedDistractors = Array(preferredDistractors.prefix(3))
        
        // Combine target with distractors and shuffle
        var allOptions = selectedDistractors
        allOptions.append(target)
        allOptions.shuffle()
        
        let correctIdx = allOptions.firstIndex(where: { $0.id == target.id }) ?? 0
        
        return QuizQuestion(
            targetWord: target,
            options: allOptions,
            correctIndex: correctIdx
        )
    }
    
    /// Generates a complete quiz session (default 10 questions) from the spaced repetition queue
    public static func generateSession(
        queue: [VocabularyWord],
        allWords: [VocabularyWord],
        count: Int = 10
    ) -> [QuizQuestion] {
        let sessionTargets = Array(queue.prefix(count))
        return sessionTargets.map { generateQuestion(target: $0, allWords: allWords) }
    }
}
