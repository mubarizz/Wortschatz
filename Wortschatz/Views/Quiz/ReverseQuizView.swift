import SwiftUI
import UIKit

public struct ReverseQuizView: View {
    @ObservedObject var store: VocabularyStore
    @Environment(\.dismiss) private var dismiss
    
    // Session state
    @State private var questions: [QuizQuestion] = []
    @State private var currentIndex: Int = 0
    @State private var selectedOptionIndex: Int? = nil
    @State private var isAnswerLocked: Bool = false
    
    // Result stats
    @State private var latestEloResult: EloResult? = nil
    @State private var sessionCorrectCount: Int = 0
    @State private var isSessionComplete: Bool = false
    @State private var startingUserElo: Double = 1200.0
    
    public init(store: VocabularyStore) {
        self.store = store
    }
    
    private var currentQuestion: QuizQuestion? {
        guard currentIndex < questions.count else { return nil }
        return questions[currentIndex]
    }
    
    public var body: some View {
        NavigationView {
            ZStack {
                Color(UIColor.systemGroupedBackground)
                    .ignoresSafeArea()
                
                if isSessionComplete {
                    sessionCompleteView
                } else if let q = currentQuestion {
                    activeQuizView(question: q)
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
                    if !questions.isEmpty && !isSessionComplete {
                        VStack(spacing: 2) {
                            Text("Rückwärts-Quiz")
                                .font(.system(size: 13, weight: .bold))
                            Text("\(currentIndex + 1) von \(questions.count)")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    if let q = currentQuestion {
                        LearnScoreBadge(word: q.targetWord, showLabel: false, compact: true)
                    }
                }
            }
            .onAppear {
                startNewSession()
            }
        }
    }
    
    // MARK: - Active Question View
    @ViewBuilder
    private func activeQuizView(question: QuizQuestion) -> some View {
        VStack(spacing: 0) {
            
            // Progress Bar
            GeometryReader { geo in
                let progress = CGFloat(currentIndex) / CGFloat(max(1, questions.count))
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color(UIColor.tertiarySystemFill))
                        .frame(height: 3)
                    Rectangle()
                        .fill(Color.purple)
                        .frame(width: geo.size.width * progress, height: 3)
                }
            }
            .frame(height: 3)
            
            ScrollView {
                VStack(spacing: 12) {
                    
                    // German Definition Deduction Card
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            // Mode Pill
                            HStack(spacing: 4) {
                                Image(systemName: "eye.slash.fill")
                                    .font(.system(size: 10))
                                Text("Kein Englisch")
                                    .font(.system(size: 9, weight: .bold))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color.purple)
                            .cornerRadius(5)
                            
                            Spacer()
                            
                            // Word Category / Part of Speech Hint
                            HStack(spacing: 4) {
                                Text("Wortart:")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(.secondary)
                                Text(question.targetWord.partOfSpeech.rawValue)
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(question.targetWord.category.badgeColor)
                            }
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(question.targetWord.category.badgeColor.opacity(0.12))
                            .cornerRadius(5)
                        }
                        
                        Text("Deutsche Definition:")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.secondary)
                            .padding(.top, 2)
                        
                        Text(question.germanDefinition)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.primary)
                            .lineSpacing(3.5)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(14)
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(14)
                    .padding(.horizontal, 12)
                    .padding(.top, 10)
                    
                    // 4 Multiple Choice Options (Height >= 50pt for iPhone 13 mini)
                    VStack(spacing: 8) {
                        ForEach(0..<question.options.count, id: \.self) { idx in
                            let option = question.options[idx]
                            optionButton(option: option, index: idx, question: question)
                        }
                    }
                    .padding(.horizontal, 12)
                    
                    // Post-Answer Context Box
                    if isAnswerLocked {
                        postAnswerCard(question: question)
                            .padding(.horizontal, 12)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .padding(.bottom, 20)
            }
        }
    }
    
    // MARK: - Option Button Component
    @ViewBuilder
    private func optionButton(option: VocabularyWord, index: Int, question: QuizQuestion) -> some View {
        let isSelected = selectedOptionIndex == index
        let isCorrectTarget = index == question.correctIndex
        
        Button(action: {
            guard !isAnswerLocked else { return }
            selectAnswer(index: index, question: question)
        }) {
            HStack(spacing: 12) {
                // Letter Badge A, B, C, D
                ZStack {
                    Circle()
                        .fill(buttonBadgeBackground(isSelected: isSelected, isCorrect: isCorrectTarget))
                        .frame(width: 28, height: 28)
                    Text(["A", "B", "C", "D"][index])
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(buttonBadgeForeground(isSelected: isSelected, isCorrect: isCorrectTarget))
                }
                
                // Word Title
                Text(option.displayTitle)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(buttonTextForeground(isSelected: isSelected, isCorrect: isCorrectTarget))
                
                Spacer()
                
                // Result Icon
                if isAnswerLocked {
                    if isCorrectTarget {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.green)
                    } else if isSelected {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.red)
                    }
                }
            }
            .padding(.horizontal, 14)
            .frame(height: 52) // Safe iOS touch target >= 44pt
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(buttonBackground(isSelected: isSelected, isCorrect: isCorrectTarget))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(buttonBorder(isSelected: isSelected, isCorrect: isCorrectTarget), lineWidth: isAnswerLocked && (isSelected || isCorrectTarget) ? 2 : 1)
            )
            .shadow(color: Color.black.opacity(0.025), radius: 4, y: 2)
        }
        .buttonStyle(ScaleButtonStyle(scaleAmount: 0.97))
        .disabled(isAnswerLocked)
    }
    
    // MARK: - Post Answer Feedback & Next Action Card
    @ViewBuilder
    private func postAnswerCard(question: QuizQuestion) -> some View {
        let wasCorrect = selectedOptionIndex == question.correctIndex
        
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center) {
                HStack(spacing: 6) {
                    Image(systemName: wasCorrect ? "checkmark.seal.fill" : "xmark.circle.fill")
                        .foregroundColor(wasCorrect ? .green : .red)
                    Text(wasCorrect ? "Richtig deduziert!" : "Leider falsch!")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(wasCorrect ? .green : .red)
                }
                
                Spacer()
                
                if let result = latestEloResult {
                    HStack(spacing: 5) {
                        Text(result.learnScoreDelta >= 0 ? "+\(result.learnScoreDelta)%" : "\(result.learnScoreDelta)%")
                            .font(.system(size: 13, weight: .heavy, design: .rounded))
                            .foregroundColor(result.learnScoreDelta >= 0 ? .green : .red)
                        Text("➔ \(result.newLearnScore)%")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(result.newLearnScore >= 75 ? .green : .secondary)
                    }
                }
            }
            
            // Revealed English Definition
            VStack(alignment: .leading, spacing: 2) {
                Text("Englische Bedeutung:")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary)
                Text(question.targetWord.englishDefinition)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.primary)
            }
            
            // Example Sentence
            VStack(alignment: .leading, spacing: 2) {
                Text("Beispielsatz (\(question.targetWord.activeExampleLevelTag)):")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary)
                Text(question.targetWord.activeExample)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(.primary)
            }
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(UIColor.tertiarySystemBackground))
            .cornerRadius(8)
            
            // Next Button
            Button(action: advanceToNextQuestion) {
                HStack {
                    Text("Nächste Frage")
                        .font(.system(size: 14, weight: .bold))
                    Image(systemName: "arrow.right")
                        .font(.system(size: 12, weight: .bold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 46)
                .background(wasCorrect ? Color.green : Color.purple)
                .cornerRadius(10)
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
        .padding(14)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(14)
    }
    
    // MARK: - Answer Selection & Elo Logic
    private func selectAnswer(index: Int, question: QuizQuestion) {
        selectedOptionIndex = index
        isAnswerLocked = true
        
        let isCorrect = (index == question.correctIndex)
        if isCorrect {
            sessionCorrectCount += 1
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } else {
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
        
        // Record attempt in store Learn Score & Elo engine
        latestEloResult = store.recordAttempt(wordId: question.targetWord.id, success: isCorrect, mode: .reverseQuiz)
    }
    
    private func advanceToNextQuestion() {
        AudioSpeaker.shared.stop()
        selectedOptionIndex = nil
        isAnswerLocked = false
        latestEloResult = nil
        
        if currentIndex + 1 < questions.count {
            currentIndex += 1
        } else {
            isSessionComplete = true
        }
    }
    
    private func startNewSession() {
        // Use 80% Unlearned (<75%) / 20% Learned (>=75%) smart session
        let smartQueue = store.generateSmartSession(count: 10)
        self.questions = QuizEngine.generateSession(
            queue: smartQueue,
            allWords: store.words,
            count: 10
        )
        self.currentIndex = 0
        self.selectedOptionIndex = nil
        self.isAnswerLocked = false
        self.sessionCorrectCount = 0
        self.isSessionComplete = false
        self.startingUserElo = store.userElo
    }
    
    // MARK: - Button State Helpers
    private func buttonBackground(isSelected: Bool, isCorrect: Bool) -> Color {
        if !isAnswerLocked {
            return Color(UIColor.secondarySystemBackground)
        }
        if isCorrect {
            return Color.green.opacity(0.12)
        }
        if isSelected {
            return Color.red.opacity(0.12)
        }
        return Color(UIColor.secondarySystemBackground).opacity(0.6)
    }
    
    private func buttonBorder(isSelected: Bool, isCorrect: Bool) -> Color {
        if !isAnswerLocked {
            return Color(UIColor.separator).opacity(0.4)
        }
        if isCorrect {
            return Color.green
        }
        if isSelected {
            return Color.red
        }
        return Color.clear
    }
    
    private func buttonBadgeBackground(isSelected: Bool, isCorrect: Bool) -> Color {
        if !isAnswerLocked {
            return Color(UIColor.tertiarySystemFill)
        }
        if isCorrect {
            return Color.green
        }
        if isSelected {
            return Color.red
        }
        return Color(UIColor.tertiarySystemFill)
    }
    
    private func buttonBadgeForeground(isSelected: Bool, isCorrect: Bool) -> Color {
        if isAnswerLocked && (isCorrect || isSelected) {
            return .white
        }
        return .primary
    }
    
    private func buttonTextForeground(isSelected: Bool, isCorrect: Bool) -> Color {
        if isAnswerLocked && isCorrect {
            return .green
        }
        if isAnswerLocked && isSelected {
            return .red
        }
        return .primary
    }
    
    // MARK: - Session Complete View
    private var sessionCompleteView: some View {
        VStack(spacing: 20) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(Color.purple.opacity(0.12))
                    .frame(width: 84, height: 84)
                Image(systemName: "trophy.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.orange)
            }
            
            VStack(spacing: 6) {
                Text("Quiz Abgeschlossen!")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                
                Text("\(sessionCorrectCount) von \(questions.count) Wörtern richtig deduziert")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
            }
            
            // Elo Summary
            VStack(spacing: 6) {
                let eloDelta = store.userElo - startingUserElo
                HStack(spacing: 6) {
                    Text("Neues Elo-Rating:")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.secondary)
                    Text("\(Int(round(store.userElo)))")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    Text(eloDelta >= 0 ? "(+\(Int(round(eloDelta))))" : "(\(Int(round(eloDelta))))")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(eloDelta >= 0 ? .green : .red)
                }
                
                Text("Deine Spaced Repetition Queue wurde aktualisiert.")
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
                    Text("Nächste Runde starten")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(Color.purple)
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
    
    private var emptyQueueView: some View {
        VStack(spacing: 12) {
            Image(systemName: "questionmark.circle.fill")
                .font(.system(size: 40))
                .foregroundColor(.purple)
            Text("Keine Fragen verfügbar")
                .font(.system(size: 16, weight: .bold))
            Button("Neu laden", action: startNewSession)
        }
    }
}
