import SwiftUI
import UIKit

public struct ClozeArenaView: View {
    @ObservedObject var store: VocabularyStore
    @Environment(\.dismiss) private var dismiss
    
    // Session state
    @State private var sessionWords: [VocabularyWord] = []
    @State private var currentIndex: Int = 0
    @State private var userInput: String = ""
    @FocusState private var isInputFocused: Bool
    
    // Outcome state
    @State private var isAnswerSubmitted: Bool = false
    @State private var isAnswerCorrect: Bool = false
    @State private var latestEloResult: EloResult? = nil
    @State private var isSessionComplete: Bool = false
    @State private var sessionCorrectCount: Int = 0
    @State private var startingUserElo: Double = 1200.0
    
    public init(store: VocabularyStore) {
        self.store = store
    }
    
    private var currentWord: VocabularyWord? {
        guard currentIndex < sessionWords.count else { return nil }
        return sessionWords[currentIndex]
    }
    
    private var maskedSentenceData: ClozeMaskedSentence? {
        guard let word = currentWord else { return nil }
        return ClozeSentenceEngine.mask(sentence: word.activeExample, targetWord: word)
    }
    
    public var body: some View {
        NavigationView {
            ZStack {
                Color(UIColor.systemGroupedBackground)
                    .ignoresSafeArea()
                
                if isSessionComplete {
                    sessionCompleteView
                } else if let word = currentWord, let cloze = maskedSentenceData {
                    activeClozeView(word: word, cloze: cloze)
                } else {
                    emptyQueueView
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.secondary)
                    }
                }
                
                ToolbarItem(placement: .principal) {
                    if !sessionWords.isEmpty && !isSessionComplete {
                        VStack(spacing: 2) {
                            Text("Lückentext-Arena")
                                .font(.system(size: 13, weight: .bold))
                            Text("\(currentIndex + 1) von \(sessionWords.count)")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    if let word = currentWord {
                        EloBadge(elo: word.elo, showLabel: false, compact: true)
                    }
                }
            }
            .onAppear {
                startNewSession()
            }
        }
    }
    
    // MARK: - Active Cloze Challenge View
    @ViewBuilder
    private func activeClozeView(word: VocabularyWord, cloze: ClozeMaskedSentence) -> some View {
        VStack(spacing: 0) {
            
            // Progress Bar
            GeometryReader { geo in
                let progress = CGFloat(currentIndex) / CGFloat(max(1, sessionWords.count))
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color(UIColor.tertiarySystemFill))
                        .frame(height: 3)
                    Rectangle()
                        .fill(Color.blue)
                        .frame(width: geo.size.width * progress, height: 3)
                }
            }
            .frame(height: 3)
            
            ScrollView {
                VStack(spacing: 12) {
                    
                    // Level & Mastery Header Card
                    HStack {
                        // Level Tag
                        HStack(spacing: 4) {
                            Text(word.activeExampleLevelTag)
                                .font(.system(size: 10, weight: .heavy))
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(word.isB2MasteryReached ? Color.purple : Color.blue)
                                .cornerRadius(4)
                            
                            Text(word.isB2MasteryReached ? "B2-Satz aktiviert" : "B1-Satz (Ziel: 2x Folgeerfolg)")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(word.isB2MasteryReached ? .purple : .blue)
                        }
                        
                        Spacer()
                        
                        // Consecutive Wins Dots for B2 Unlock
                        HStack(spacing: 3) {
                            ForEach(0..<2) { i in
                                Circle()
                                    .fill(i < word.consecutiveCorrect ? Color.green : Color(UIColor.tertiarySystemFill))
                                    .frame(width: 7, height: 7)
                            }
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.top, 8)
                    
                    // Main Cloze Sentence Card
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text(word.articleOrType)
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(word.category.badgeColor)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(word.category.badgeColor.opacity(0.12))
                                .cornerRadius(5)
                            
                            Spacer()
                            
                            Text("Fülle die Lücke")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        
                        // Sentence with visual gap
                        VStack(alignment: .leading, spacing: 6) {
                            if cloze.isMasked {
                                (Text(cloze.prefix + " ")
                                    .font(.system(size: 16, weight: .medium))
                                 + Text(" [ \(userInput.isEmpty ? "______" : userInput) ] ")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(userInput.isEmpty ? .blue : .primary)
                                 + Text(" " + cloze.suffix)
                                    .font(.system(size: 16, weight: .medium)))
                                    .lineSpacing(4)
                                    .foregroundColor(.primary)
                            } else {
                                Text(cloze.originalSentence)
                                    .font(.system(size: 16, weight: .medium))
                                    .lineSpacing(4)
                            }
                        }
                        
                        Divider()
                            .padding(.vertical, 2)
                        
                        // Definition Hint Card
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "lightbulb.fill")
                                .font(.system(size: 13))
                                .foregroundColor(.amber)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(word.englishDefinition)
                                    .font(.system(size: 12, weight: .regular))
                                    .foregroundColor(.secondary)
                                    .lineLimit(2)
                            }
                        }
                    }
                    .padding(14)
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(14)
                    .padding(.horizontal, 12)
                }
            }
            
            // Bottom Input & Controls (Optimized for iPhone 13 mini)
            VStack(spacing: 0) {
                
                // Umlaut bar right above keyboard
                UmlautKeyboardBar(text: $userInput, onQuickSubmit: submitAnswer)
                
                // Input TextField & Submit Button
                HStack(spacing: 8) {
                    TextField("Zielwort eingeben...", text: $userInput)
                        .font(.system(size: 15, weight: .semibold))
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                        .padding(.horizontal, 12)
                        .frame(height: 46)
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(10)
                        .focused($isInputFocused)
                        .submitLabel(.done)
                        .onSubmit {
                            submitAnswer()
                        }
                    
                    Button(action: submitAnswer) {
                        Text("Prüfen")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 76, height: 46)
                            .background(userInput.trimmingCharacters(in: .whitespaces).isEmpty ? Color.gray.opacity(0.5) : Color.blue)
                            .cornerRadius(10)
                    }
                    .disabled(userInput.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(Color(UIColor.systemBackground))
            }
        }
        .sheet(isPresented: $isAnswerSubmitted) {
            if let word = currentWord, let cloze = maskedSentenceData {
                ClozeFeedbackSheet(
                    word: word,
                    isCorrect: isAnswerCorrect,
                    eloResult: latestEloResult,
                    userAnswer: userInput,
                    maskedToken: cloze.maskedWord,
                    onNext: advanceToNextWord
                )
                .presentationDetents([.fraction(0.58), .large])
            }
        }
    }
    
    // MARK: - Answer Submission & Elo Updating
    private func submitAnswer() {
        guard let word = currentWord, let cloze = maskedSentenceData, !userInput.trimmingCharacters(in: .whitespaces).isEmpty else {
            return
        }
        
        let correct = ClozeSentenceEngine.validate(
            input: userInput,
            target: word,
            maskedToken: cloze.maskedWord
        )
        
        isAnswerCorrect = correct
        if correct {
            sessionCorrectCount += 1
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } else {
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
        
        // Update Spaced Repetition Elo via store
        latestEloResult = store.recordAttempt(wordId: word.id, success: correct)
        isAnswerSubmitted = true
    }
    
    private func advanceToNextWord() {
        isAnswerSubmitted = false
        userInput = ""
        
        if currentIndex + 1 < sessionWords.count {
            currentIndex += 1
            isInputFocused = true
        } else {
            isSessionComplete = true
        }
    }
    
    private func startNewSession() {
        // Draw top 10 highest-urgency items from spaced repetition queue
        let queue = store.spacedRepetitionQueue
        self.sessionWords = Array(queue.prefix(10))
        self.currentIndex = 0
        self.userInput = ""
        self.isAnswerSubmitted = false
        self.isSessionComplete = false
        self.sessionCorrectCount = 0
        self.startingUserElo = store.userElo
        self.isInputFocused = true
    }
    
    // MARK: - Session Complete View
    private var sessionCompleteView: some View {
        VStack(spacing: 20) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.12))
                    .frame(width: 84, height: 84)
                Image(systemName: "trophy.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.amber)
            }
            
            VStack(spacing: 6) {
                Text("Runde Abgeschlossen!")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                
                Text("\(sessionCorrectCount) von \(sessionWords.count) Wörtern gemeistert")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
            }
            
            // Elo Summary Tile
            VStack(spacing: 6) {
                let eloDelta = store.userElo - startingUserElo
                HStack(spacing: 6) {
                    Text("Neues Rating:")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.secondary)
                    Text("\(Int(round(store.userElo))) Elo")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    Text(eloDelta >= 0 ? "(+\(Int(round(eloDelta))))" : "(\(Int(round(eloDelta))))")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(eloDelta >= 0 ? .green : .red)
                }
                
                Text("Deine Spaced Repetition Queue wurde neu kalibriert.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            .padding(14)
            .frame(maxWidth: .infinity)
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(12)
            .padding(.horizontal, 24)
            
            Spacer()
            
            VStack(spacing: 10) {
                Button(action: startNewSession) {
                    Text("Nächste 10 Wörter trainieren")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(Color.blue)
                        .cornerRadius(12)
                }
                
                Button(action: { dismiss() }) {
                    Text("Zurück zur Arena")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 14)
        }
    }
    
    // Empty Queue View
    private var emptyQueueView: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 40))
                .foregroundColor(.green)
            Text("Keine Vokabeln in der Warteschlange")
                .font(.system(size: 16, weight: .bold))
            Button("Neue Runde starten", action: startNewSession)
                .font(.system(size: 14, weight: .semibold))
        }
    }
}
