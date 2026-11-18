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
        let targetPoS = target.partOfSpeech
        
        // Strictly select distractors of the exact same part of speech (Noun, Verb, or Adjective)
        var matchingDistractors = pool.filter { $0.partOfSpeech == targetPoS }.shuffled()
        
        // Fallback safeguard only if a small dataset has fewer than 3 words of this part of speech
        if matchingDistractors.count < 3 {
            let remaining = pool.filter { !matchingDistractors.contains($0) }.shuffled()
            matchingDistractors.append(contentsOf: remaining)
        }
        
        let selectedDistractors = Array(matchingDistractors.prefix(3))
        
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
