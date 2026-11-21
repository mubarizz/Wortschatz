import SwiftUI
import UIKit

public struct PrepositionSprintGameView: View {
    @ObservedObject var vocabStore: VocabularyStore
    @StateObject private var prepStore = PrepositionStore.shared
    @Environment(\.dismiss) private var dismiss
    
    // Setup state
    @State private var selectedMode: PrepositionStore.GameMode = .blitz
    @State private var selectedLevel: String = "Alle"
    @State private var isGameActive: Bool = false
    @State private var isGameOver: Bool = false
    
    // In-game state
    @State private var questions: [PrepositionQuestion] = []
    @State private var currentIndex: Int = 0
    @State private var selectedOptionIndex: Int? = nil
    @State private var isAnswerLocked: Bool = false
    @State private var currentStreak: Int = 0
    @State private var maxStreak: Int = 0
    @State private var correctAnswersCount: Int = 0
    @State private var totalScore: Int = 0
    @State private var missedEntries: [PrepositionEntry] = []
    
    // Blitz Timer state
    @State private var timeRemaining: Int = 60
    @State private var timer: Timer? = nil
    
    private let levels = ["Alle", "B1", "B2", "C1"]
    
    public init(vocabStore: VocabularyStore) {
        self.vocabStore = vocabStore
    }
    
    private var currentQuestion: PrepositionQuestion? {
        guard currentIndex < questions.count else { return nil }
        return questions[currentIndex]
    }
    
    public var body: some View {
        NavigationView {
            ZStack {
                Color(UIColor.systemGroupedBackground)
                    .ignoresSafeArea()
                
                if !isGameActive {
                    gameSetupView
                } else if isGameOver {
                    gameOverView
                } else if let q = currentQuestion {
                    activeGameplayView(question: q)
                } else {
                    ProgressView()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: {
                        stopTimer()
                        dismiss()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.secondary)
                    }
                }
                
                ToolbarItem(placement: .principal) {
                    if isGameActive && !isGameOver {
                        HStack(spacing: 8) {
                            if selectedMode == .blitz {
                                HStack(spacing: 4) {
                                    Image(systemName: "timer")
                                        .foregroundColor(timeRemaining <= 10 ? .red : .orange)
                                    Text("\(timeRemaining)s")
                                        .font(.system(size: 15, weight: .black, design: .rounded))
                                        .monospacedDigit()
                                        .foregroundColor(timeRemaining <= 10 ? .red : .primary)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule()
                                        .fill(timeRemaining <= 10 ? Color.red.opacity(0.15) : Color(UIColor.tertiarySystemFill))
                                )
                            } else {
                                Text("\(currentIndex + 1) von \(questions.count)")
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .foregroundColor(.secondary)
                            }
                        }
                    } else if !isGameActive {
                        Text("Präpositionen-Sprint")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    if isGameActive && !isGameOver {
                        HStack(spacing: 4) {
                            Image(systemName: "flame.fill")
                                .foregroundColor(currentStreak > 1 ? .orange : .secondary)
                                .font(.system(size: 13, weight: .bold))
                            Text("\(currentStreak)x")
                                .font(.system(size: 13, weight: .heavy, design: .rounded))
                                .monospacedDigit()
                                .foregroundColor(currentStreak > 1 ? .orange : .secondary)
                        }
                    }
                }
            }
        }
        .onDisappear {
            stopTimer()
        }
    }
    
    // MARK: - 1. Setup & Mode Selection View
    private var gameSetupView: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                // Hero Header Card
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(LinearGradient(
                                colors: [Color.orange, Color.red],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
                            .frame(width: 72, height: 72)
                            .shadow(color: Color.orange.opacity(0.4), radius: 10, y: 5)
                        
                        Image(systemName: "bolt.horizontal.fill")
                            .font(.system(size: 32, weight: .black))
                            .foregroundColor(.white)
                    }
                    
                    VStack(spacing: 4) {
                        Text("Präpositionen- & Kasus-Sprint")
                            .font(.system(size: 22, weight: .black, design: .rounded))
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.center)
                        
                        Text("B1 • B2 • C1 Verben mit festen Präpositionen")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    
                    HStack(spacing: 16) {
                        VStack(spacing: 2) {
                            Text("\(prepStore.bestBlitzScore)")
                                .font(.system(size: 18, weight: .black, design: .rounded))
                                .foregroundColor(.orange)
                            Text("Blitz-Rekord")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.secondary)
                        }
                        
                        Divider().frame(height: 24)
                        
                        VStack(spacing: 2) {
                            Text("\(prepStore.entries.count)")
                                .font(.system(size: 18, weight: .black, design: .rounded))
                                .foregroundColor(.blue)
                            Text("Verben im Pool")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.secondary)
                        }
                        
                        Divider().frame(height: 24)
                        
                        VStack(spacing: 2) {
                            Text("\(prepStore.troublemakerIds.count)")
                                .font(.system(size: 18, weight: .black, design: .rounded))
                                .foregroundColor(.red)
                            Text("Schwachstellen")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.top, 4)
                }
                .padding(.vertical, 20)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color(UIColor.secondarySystemGroupedBackground))
                )
                
                // Mode Picker
                VStack(alignment: .leading, spacing: 8) {
                    Text("Spielmodus wählen")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 4)
                    
                    HStack(spacing: 10) {
                        ForEach(PrepositionStore.GameMode.allCases) { mode in
                            Button(action: {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                selectedMode = mode
                            }) {
                                VStack(spacing: 6) {
                                    Image(systemName: mode.icon)
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundColor(selectedMode == mode ? .white : .primary)
                                    
                                    Text(mode.rawValue)
                                        .font(.system(size: 12, weight: .bold, design: .rounded))
                                        .foregroundColor(selectedMode == mode ? .white : .primary)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(selectedMode == mode ? Color.orange : Color(UIColor.secondarySystemGroupedBackground))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .strokeBorder(selectedMode == mode ? Color.orange : Color.primary.opacity(0.06), lineWidth: 1)
                                )
                            }
                        }
                    }
                }
                
                // Level Filter
                VStack(alignment: .leading, spacing: 8) {
                    Text("Niveau-Filter")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 4)
                    
                    Picker("Niveau", selection: $selectedLevel) {
                        ForEach(levels, id: \.self) { lvl in
                            Text(lvl == "Alle" ? "Alle (B1–C1)" : lvl).tag(lvl)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                
                // Mode Description Banner
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "info.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.orange)
                        .padding(.top, 1)
                    
                    Text(modeDescription)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.orange.opacity(0.08))
                )
                
                // Start Button
                Button(action: startSession) {
                    HStack(spacing: 8) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 16, weight: .bold))
                        Text(selectedMode == .blitz ? "60s Sprint starten" : "Runde starten")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            colors: [Color.orange, Color.red],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(16)
                    .shadow(color: Color.orange.opacity(0.35), radius: 8, y: 4)
                }
                .padding(.top, 10)
            }
            .padding(16)
        }
    }
    
    private var modeDescription: String {
        switch selectedMode {
        case .blitz:
            return "60 Sekunden Zeit: Beantworte so viele Kombinationen wie möglich! Höhere Streaks bringen Multiplikatoren (1.5x bis 3x)."
        case .classic:
            return "15 Fragen ohne Zeitdruck: Ideal zum Verinnerlichen mit Erklärungen, Dativ/Akkusativ-Regeln und Audio-Aussprache."
        case .troublemakers:
            return "Gezieltes Training aller Verben, bei denen du in vergangenen Runden Fehler gemacht hast. Macht Schwachstellen zu Stärken!"
        }
    }
    
    // MARK: - 2. Active Gameplay View
    @ViewBuilder
    private func activeGameplayView(question: PrepositionQuestion) -> some View {
        VStack(spacing: 0) {
            // Linear Progress Bar
            GeometryReader { geo in
                let progress: CGFloat = selectedMode == .blitz
                    ? CGFloat(timeRemaining) / 60.0
                    : CGFloat(currentIndex) / CGFloat(max(1, questions.count))
                
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color(UIColor.tertiarySystemFill))
                        .frame(height: 4)
                    
                    Rectangle()
                        .fill(selectedMode == .blitz ? (timeRemaining <= 10 ? Color.red : Color.orange) : Color.blue)
                        .frame(width: geo.size.width * max(0, min(1, progress)), height: 4)
                        .animation(.linear(duration: selectedMode == .blitz ? 1.0 : 0.25), value: progress)
                }
            }
            .frame(height: 4)
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    
                    // Verb & Challenge Card
                    VStack(alignment: .center, spacing: 10) {
                        HStack {
                            // CEFR Level Badge
                            Text(question.entry.cefrLevel)
                                .font(.system(size: 11, weight: .black, design: .rounded))
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(
                                    Capsule().fill(levelColor(for: question.entry.cefrLevel))
                                )
                            
                            Spacer()
                            
                            // Audio Button
                            Button(action: {
                                AudioSpeaker.shared.speak(text: question.entry.fullSentence)
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "speaker.wave.2.fill")
                                        .font(.system(size: 12))
                                    Text("Anhören")
                                        .font(.system(size: 11, weight: .bold))
                                }
                                .foregroundColor(.blue)
                                .padding(.horizontal, 9)
                                .padding(.vertical, 4)
                                .background(Capsule().fill(Color.blue.opacity(0.1)))
                            }
                        }
                        
                        // Main Target Verb
                        Text(question.entry.verb)
                            .font(.system(size: 32, weight: .black, design: .rounded))
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.center)
                        
                        // English Translation
                        Text(question.entry.englishTranslation)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.secondary)
                        
                        Divider().padding(.vertical, 4)
                        
                        // Context Sentence with Gap
                        VStack(spacing: 6) {
                            Text(sentenceWithGap(question.entry))
                                .font(.system(size: 17, weight: .semibold, design: .serif))
                                .foregroundColor(.primary)
                                .multilineTextAlignment(.center)
                                .lineSpacing(4)
                                .padding(.horizontal, 4)
                        }
                    }
                    .padding(18)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color(UIColor.secondarySystemGroupedBackground))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
                    )
                    
                    // 4 Options Grid (2x2)
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                        ForEach(0..<question.options.count, id: \.self) { idx in
                            let option = question.options[idx]
                            optionButton(
                                option: option,
                                index: idx,
                                correctIndex: question.correctIndex
                            )
                        }
                    }
                    
                    // Feedback & Rule Card (Shown when an option is selected)
                    if isAnswerLocked {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 6) {
                                Image(systemName: selectedOptionIndex == question.correctIndex ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundColor(selectedOptionIndex == question.correctIndex ? .green : .red)
                                    .font(.system(size: 16, weight: .bold))
                                
                                Text(selectedOptionIndex == question.correctIndex ? "Richtig! +\(pointsForCurrentAnswer()) Pkt." : "Leider falsch!")
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                    .foregroundColor(selectedOptionIndex == question.correctIndex ? .green : .red)
                                
                                Spacer()
                                
                                Text("Lösung: \(question.entry.correctCombination)")
                                    .font(.system(size: 13, weight: .black, design: .rounded))
                                    .foregroundColor(.primary)
                            }
                            
                            Text(question.entry.ruleExplanation)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                            
                            if selectedMode != .blitz {
                                Button(action: advanceToNext) {
                                    HStack {
                                        Text("Weiter")
                                            .font(.system(size: 14, weight: .bold, design: .rounded))
                                        Image(systemName: "arrow.right")
                                            .font(.system(size: 12, weight: .bold))
                                    }
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(Color.blue)
                                    .cornerRadius(12)
                                }
                                .padding(.top, 4)
                            }
                        }
                        .padding(14)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(selectedOptionIndex == question.correctIndex ? Color.green.opacity(0.1) : Color.red.opacity(0.1))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(selectedOptionIndex == question.correctIndex ? Color.green.opacity(0.3) : Color.red.opacity(0.3), lineWidth: 1)
                        )
                        .transition(.scale.combined(with: .opacity))
                    }
                }
                .padding(16)
            }
        }
    }
    
    // MARK: - Option Button
    @ViewBuilder
    private func optionButton(option: String, index: Int, correctIndex: Int) -> some View {
        Button(action: {
            guard !isAnswerLocked else { return }
            handleAnswerSelection(index: index, correctIndex: correctIndex)
        }) {
            VStack(spacing: 4) {
                Text(option)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundColor(buttonTextColor(index: index, correctIndex: correctIndex))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(buttonBackgroundColor(index: index, correctIndex: correctIndex))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(buttonBorderColor(index: index, correctIndex: correctIndex), lineWidth: 1.5)
            )
        }
        .disabled(isAnswerLocked)
    }
    
    private func buttonBackgroundColor(index: Int, correctIndex: Int) -> Color {
        guard isAnswerLocked else {
            return Color(UIColor.secondarySystemGroupedBackground)
        }
        if index == correctIndex {
            return Color.green.opacity(0.2)
        }
        if index == selectedOptionIndex && index != correctIndex {
            return Color.red.opacity(0.2)
        }
        return Color(UIColor.secondarySystemGroupedBackground).opacity(0.5)
    }
    
    private func buttonBorderColor(index: Int, correctIndex: Int) -> Color {
        guard isAnswerLocked else {
            return Color.primary.opacity(0.08)
        }
        if index == correctIndex {
            return Color.green
        }
        if index == selectedOptionIndex && index != correctIndex {
            return Color.red
        }
        return Color.clear
    }
    
    private func buttonTextColor(index: Int, correctIndex: Int) -> Color {
        guard isAnswerLocked else {
            return .primary
        }
        if index == correctIndex {
            return .green
        }
        if index == selectedOptionIndex && index != correctIndex {
            return .red
        }
        return .secondary
    }
    
    // MARK: - 3. Game Over / Results View
    private var gameOverView: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                // Header Score Pill
                VStack(spacing: 12) {
                    Image(systemName: correctAnswersCount > 0 ? "trophy.fill" : "sparkles")
                        .font(.system(size: 44))
                        .foregroundColor(.orange)
                        .padding(.top, 8)
                    
                    VStack(spacing: 4) {
                        Text(selectedMode == .blitz ? "Sprint beendet!" : "Runde abgeschlossen!")
                            .font(.system(size: 24, weight: .black, design: .rounded))
                        
                        Text("Starke Vorbereitung für B2 & C1!")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    
                    // Stats Row
                    HStack(spacing: 20) {
                        VStack(spacing: 2) {
                            Text("\(totalScore)")
                                .font(.system(size: 26, weight: .black, design: .rounded))
                                .foregroundColor(.orange)
                            Text("Punkte")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.secondary)
                        }
                        
                        Divider().frame(height: 30)
                        
                        VStack(spacing: 2) {
                            Text("\(correctAnswersCount)")
                                .font(.system(size: 26, weight: .black, design: .rounded))
                                .foregroundColor(.green)
                            Text("Richtig")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.secondary)
                        }
                        
                        Divider().frame(height: 30)
                        
                        VStack(spacing: 2) {
                            Text("\(maxStreak)x")
                                .font(.system(size: 26, weight: .black, design: .rounded))
                                .foregroundColor(.red)
                            Text("Max Streak")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.top, 8)
                }
                .padding(20)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color(UIColor.secondarySystemGroupedBackground))
                )
                
                // Missed Questions List
                if !missedEntries.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text("Zur Wiederholung gemerkt (\(missedEntries.count))")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundColor(.primary)
                        }
                        .padding(.horizontal, 4)
                        
                        ForEach(missedEntries) { entry in
                            HStack(alignment: .center, spacing: 12) {
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 6) {
                                        Text(entry.verb)
                                            .font(.system(size: 14, weight: .bold))
                                        Text("➔ \(entry.correctCombination)")
                                            .font(.system(size: 14, weight: .black, design: .rounded))
                                            .foregroundColor(.orange)
                                    }
                                    Text(entry.englishTranslation)
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Button(action: {
                                    AudioSpeaker.shared.speak(text: entry.fullSentence)
                                }) {
                                    Image(systemName: "speaker.wave.2.circle.fill")
                                        .font(.system(size: 22))
                                        .foregroundColor(.blue)
                                }
                            }
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color(UIColor.secondarySystemGroupedBackground))
                            )
                        }
                    }
                }
                
                // Action Buttons
                VStack(spacing: 10) {
                    Button(action: startSession) {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 15, weight: .bold))
                            Text("Nochmal spielen")
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.orange)
                        .cornerRadius(14)
                    }
                    
                    Button(action: {
                        isGameActive = false
                        isGameOver = false
                    }) {
                        Text("Modus wechseln")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                    }
                }
                .padding(.top, 8)
            }
            .padding(16)
        }
    }
    
    // MARK: - Game Logic & Handlers
    private func startSession() {
        stopTimer()
        questions = prepStore.buildQuestions(mode: selectedMode, levelFilter: selectedLevel)
        currentIndex = 0
        selectedOptionIndex = nil
        isAnswerLocked = false
        currentStreak = 0
        maxStreak = 0
        correctAnswersCount = 0
        totalScore = 0
        missedEntries = []
        isGameOver = false
        isGameActive = true
        
        if selectedMode == .blitz {
            timeRemaining = 60
            startBlitzTimer()
        }
    }
    
    private func startBlitzTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            DispatchQueue.main.async {
                if timeRemaining > 1 {
                    timeRemaining -= 1
                    if timeRemaining == 10 {
                        UINotificationFeedbackGenerator().notificationOccurred(.warning)
                    }
                } else {
                    timeRemaining = 0
                    endSession()
                }
            }
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    private func handleAnswerSelection(index: Int, correctIndex: Int) {
        selectedOptionIndex = index
        isAnswerLocked = true
        
        guard let q = currentQuestion else { return }
        let isCorrect = (index == correctIndex)
        
        prepStore.recordAnswer(entryId: q.entry.id, wasCorrect: isCorrect)
        
        if isCorrect {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            currentStreak += 1
            if currentStreak > maxStreak {
                maxStreak = currentStreak
            }
            correctAnswersCount += 1
            totalScore += pointsForCurrentAnswer()
        } else {
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            currentStreak = 0
            missedEntries.append(q.entry)
        }
        
        // Auto-advance in Blitz mode after brief pause for adrenaline flow
        if selectedMode == .blitz {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                if isGameActive && !isGameOver {
                    advanceToNext()
                }
            }
        }
    }
    
    private func advanceToNext() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            selectedOptionIndex = nil
            isAnswerLocked = false
            
            if currentIndex + 1 < questions.count {
                currentIndex += 1
            } else {
                endSession()
            }
        }
    }
    
    private func endSession() {
        stopTimer()
        isGameOver = true
        
        if selectedMode == .blitz {
            prepStore.saveBlitzBestScore(correctAnswersCount)
        }
        
        // Award Elo rating / XP in VocabularyStore
        if correctAnswersCount > 0 {
            let eloGain = min(25.0, Double(correctAnswersCount) * 1.5)
            vocabStore.recordExternalGameActivity(points: eloGain, reviewsCount: correctAnswersCount)
        }
    }
    
    private func pointsForCurrentAnswer() -> Int {
        let base = 10
        let multiplier: Double
        switch currentStreak {
        case 0...2: multiplier = 1.0
        case 3...5: multiplier = 1.5
        case 6...9: multiplier = 2.0
        default: multiplier = 3.0
        }
        return Int(Double(base) * multiplier)
    }
    
    private func sentenceWithGap(_ entry: PrepositionEntry) -> String {
        return "\(entry.sentencePrefix) [ ___ ] \(entry.sentenceSuffix)"
    }
    
    private func levelColor(for level: String) -> Color {
        switch level {
        case "C1": return Color.purple
        case "B2": return Color.blue
        default: return Color.green
        }
    }
}
