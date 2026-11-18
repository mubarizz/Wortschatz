import SwiftUI
import UIKit

public struct AudioDictationView: View {
    @ObservedObject var store: VocabularyStore
    @Environment(\.dismiss) private var dismiss
    
    // Session state
    @State private var sessionWords: [VocabularyWord] = []
    @State private var currentIndex: Int = 0
    @State private var userInput: String = ""
    @FocusState private var isInputFocused: Bool
    
    // Hints state
    @State private var showStructureHint: Bool = false
    @State private var showMeaningHint: Bool = false
    
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
    
    public var body: some View {
        NavigationView {
            ZStack {
                Color(UIColor.systemGroupedBackground)
                    .ignoresSafeArea()
                
                if isSessionComplete {
                    sessionCompleteView
                } else if let word = currentWord {
                    activeDictationView(word: word)
                } else {
                    emptyQueueView
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: {
                        AudioSpeaker.shared.stop()
                        dismiss()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.secondary)
                    }
                }
                
                ToolbarItem(placement: .principal) {
                    if !sessionWords.isEmpty && !isSessionComplete {
                        VStack(spacing: 2) {
                            Text("Hör-Diktat")
                                .font(.system(size: 13, weight: .bold))
                            Text("\(currentIndex + 1) von \(sessionWords.count)")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    if let word = currentWord {
                        LearnScoreBadge(word: word, showLabel: false, compact: true)
                    }
                }
            }
            .onAppear {
                startNewSession()
            }
            .onDisappear {
                AudioSpeaker.shared.stop()
            }
        }
    }
    
    // MARK: - Active Dictation View
    @ViewBuilder
    private func activeDictationView(word: VocabularyWord) -> some View {
        VStack(spacing: 0) {
            
            // Progress Bar
            GeometryReader { geo in
                let progress = CGFloat(currentIndex) / CGFloat(max(1, sessionWords.count))
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color(UIColor.tertiarySystemFill))
                        .frame(height: 3)
                    Rectangle()
                        .fill(Color.teal)
                        .frame(width: geo.size.width * progress, height: 3)
                }
            }
            .frame(height: 3)
            
            ScrollView {
                VStack(spacing: 12) {
                    
                    // Audio Stage Card
                    VStack(spacing: 14) {
                        HStack {
                            Label("Hören & Schreiben", systemImage: "headphones")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.teal)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.teal.opacity(0.14))
                                .cornerRadius(6)
                            
                            Spacer()
                            
                            if let cefr = word.cefrLevel, !cefr.isEmpty {
                                Text(cefr)
                                    .font(.system(size: 10, weight: .heavy))
                                    .foregroundColor(.indigo)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 3)
                                    .background(Color.indigo.opacity(0.12))
                                    .cornerRadius(5)
                            }
                        }
                        
                        // Main Speaker & Slow Turtle Buttons
                        HStack(spacing: 12) {
                            // Normal Speed Button
                            Button(action: {
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                AudioSpeaker.shared.speak(text: word.displayTitle, rate: 0.48)
                            }) {
                                VStack(spacing: 6) {
                                    ZStack {
                                        Circle()
                                            .fill(Color.teal)
                                            .frame(width: 58, height: 58)
                                            .shadow(color: Color.teal.opacity(0.3), radius: 6, y: 3)
                                        Image(systemName: "speaker.wave.3.fill")
                                            .font(.system(size: 24, weight: .bold))
                                            .foregroundColor(.white)
                                    }
                                    Text("Wort hören")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(.primary)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(Color(UIColor.tertiarySystemBackground))
                                .cornerRadius(12)
                            }
                            .buttonStyle(ScaleButtonStyle(scaleAmount: 0.95))
                            
                            // Slow Speed (Turtle) Button
                            Button(action: {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                AudioSpeaker.shared.speak(text: word.displayTitle, rate: 0.32)
                            }) {
                                VStack(spacing: 6) {
                                    ZStack {
                                        Circle()
                                            .fill(Color.orange.opacity(0.18))
                                            .frame(width: 58, height: 58)
                                        Image(systemName: "tortoise.fill")
                                            .font(.system(size: 22, weight: .bold))
                                            .foregroundColor(.orange)
                                    }
                                    Text("Langsam (0.7x)")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(.primary)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(Color(UIColor.tertiarySystemBackground))
                                .cornerRadius(12)
                            }
                            .buttonStyle(ScaleButtonStyle(scaleAmount: 0.95))
                        }
                        
                        // Hear Context Sentence Button (Audio only, text hidden!)
                        Button(action: {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            AudioSpeaker.shared.speak(text: word.activeExample, rate: 0.46)
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "waveform.circle.fill")
                                    .font(.system(size: 18))
                                    .foregroundColor(.indigo)
                                Text("Beispielsatz (\(word.activeExampleLevelTag)) anhören")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.indigo)
                                Spacer()
                                Image(systemName: "play.fill")
                                    .font(.system(size: 11))
                                    .foregroundColor(.indigo)
                            }
                            .padding(.horizontal, 12)
                            .frame(height: 42)
                            .background(Color.indigo.opacity(0.1))
                            .cornerRadius(10)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(14)
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(14)
                    .padding(.horizontal, 12)
                    .padding(.top, 8)
                    
                    // Optional Hints Section
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            // Hint 1: Structure & Article
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    showStructureHint.toggle()
                                }
                            }) {
                                HStack(spacing: 5) {
                                    Image(systemName: showStructureHint ? "eye.fill" : "eye")
                                    Text("Wortart & Länge")
                                }
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(showStructureHint ? .white : .blue)
                                .padding(.horizontal, 10)
                                .frame(height: 34)
                                .frame(maxWidth: .infinity)
                                .background(showStructureHint ? Color.blue : Color.blue.opacity(0.12))
                                .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                            
                            // Hint 2: English Meaning
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    showMeaningHint.toggle()
                                }
                            }) {
                                HStack(spacing: 5) {
                                    Image(systemName: "lightbulb.fill")
                                    Text("Bedeutung")
                                }
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(showMeaningHint ? .white : .orange)
                                .padding(.horizontal, 10)
                                .frame(height: 34)
                                .frame(maxWidth: .infinity)
                                .background(showMeaningHint ? Color.orange : Color.orange.opacity(0.12))
                                .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                        }
                        
                        if showStructureHint {
                            HStack(spacing: 8) {
                                Text(word.articleOrType)
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(word.category.badgeColor)
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 3)
                                    .background(word.category.badgeColor.opacity(0.15))
                                    .cornerRadius(5)
                                
                                Text(maskedLetterPattern(for: word.cleanTargetWord))
                                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                                Text("\(word.cleanTargetWord.count) Buchst.")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(.secondary)
                            }
                            .padding(10)
                            .background(Color(UIColor.secondarySystemBackground))
                            .cornerRadius(10)
                        }
                        
                        if showMeaningHint {
                            HStack(spacing: 8) {
                                Image(systemName: "translate")
                                    .foregroundColor(.orange)
                                    .font(.system(size: 13))
                                Text(word.englishDefinition)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.primary)
                                Spacer()
                            }
                            .padding(10)
                            .background(Color(UIColor.secondarySystemBackground))
                            .cornerRadius(10)
                        }
                    }
                    .padding(.horizontal, 12)
                }
            }
            
            // Bottom Input & Umlaut Bar
            VStack(spacing: 0) {
                UmlautKeyboardBar(text: $userInput, onQuickSubmit: submitAnswer)
                
                HStack(spacing: 8) {
                    TextField("Gehörtes Wort schreiben...", text: $userInput)
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
                            .background(userInput.trimmingCharacters(in: .whitespaces).isEmpty ? Color.gray.opacity(0.5) : Color.teal)
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
            if let word = currentWord {
                ClozeFeedbackSheet(
                    word: word,
                    isCorrect: isAnswerCorrect,
                    eloResult: latestEloResult,
                    userAnswer: userInput,
                    maskedToken: word.cleanTargetWord,
                    onNext: advanceToNextWord
                )
                .presentationDetents([.fraction(0.58), .large])
            }
        }
    }
    
    // MARK: - Helpers & Actions
    private func maskedLetterPattern(for target: String) -> String {
        let chars = Array(target)
        guard !chars.isEmpty else { return "" }
        return chars.enumerated().map { idx, ch in
            if idx == 0 || (chars.count > 4 && idx == chars.count - 1) || ch == " " || ch == "-" {
                return String(ch)
            }
            return "_"
        }.joined(separator: " ")
    }
    
    private func submitAnswer() {
        guard let word = currentWord, !userInput.trimmingCharacters(in: .whitespaces).isEmpty else {
            return
        }
        
        let correct = ClozeSentenceEngine.validate(
            input: userInput,
            target: word,
            maskedToken: word.cleanTargetWord
        )
        
        isAnswerCorrect = correct
        if correct {
            sessionCorrectCount += 1
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } else {
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
        
        latestEloResult = store.recordAttempt(wordId: word.id, success: correct, mode: .audioDictation)
        if let updated = store.words.first(where: { $0.id == word.id }) {
            sessionWords[currentIndex] = updated
        }
        isAnswerSubmitted = true
    }
    
    private func advanceToNextWord() {
        AudioSpeaker.shared.stop()
        isAnswerSubmitted = false
        userInput = ""
        showStructureHint = false
        showMeaningHint = false
        
        if currentIndex + 1 < sessionWords.count {
            currentIndex += 1
            isInputFocused = true
            speakCurrentWordAfterDelay()
        } else {
            isSessionComplete = true
        }
    }
    
    private func startNewSession() {
        AudioSpeaker.shared.stop()
        self.sessionWords = store.generateSmartSession(count: 10)
        self.currentIndex = 0
        self.userInput = ""
        self.showStructureHint = false
        self.showMeaningHint = false
        self.isAnswerSubmitted = false
        self.isSessionComplete = false
        self.sessionCorrectCount = 0
        self.startingUserElo = store.userElo
        self.isInputFocused = true
        speakCurrentWordAfterDelay()
    }
    
    private func speakCurrentWordAfterDelay() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            if let word = self.currentWord, !self.isSessionComplete {
                AudioSpeaker.shared.speak(text: word.displayTitle, rate: 0.48)
            }
        }
    }
    
    // MARK: - Session Complete View
    private var sessionCompleteView: some View {
        VStack(spacing: 20) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(Color.teal.opacity(0.14))
                    .frame(width: 84, height: 84)
                Image(systemName: "headphones.circle.fill")
                    .font(.system(size: 44))
                    .foregroundColor(.teal)
            }
            
            VStack(spacing: 6) {
                Text("Hör-Diktat Abgeschlossen!")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                
                Text("\(sessionCorrectCount) von \(sessionWords.count) Wörtern richtig gehört & geschrieben")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
            }
            
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
                
                Text("Lern-Scores wurden aktualisiert (80/20 Smart-Warteschlange).")
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
                    Text("Nächste 10 Wörter hören")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(Color.teal)
                        .cornerRadius(12)
                }
                
                Button(action: {
                    AudioSpeaker.shared.stop()
                    dismiss()
                }) {
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
            Image(systemName: "headphones")
                .font(.system(size: 40))
                .foregroundColor(.teal)
            Text("Keine Vokabeln verfügbar")
                .font(.system(size: 16, weight: .bold))
            Button("Neu starten", action: startNewSession)
                .font(.system(size: 14, weight: .semibold))
        }
    }
}
