import SwiftUI
import UIKit

public struct WordTileItem: Identifiable, Equatable {
    public let id = UUID()
    public let text: String
}

public struct SatzbauGameView: View {
    @ObservedObject var grammarStore: GrammarStore
    @ObservedObject var vocabStore: VocabularyStore
    let initialFocusTopic: GrammarTopic?
    let initialLevelFilter: String?
    
    @Environment(\.dismiss) private var dismiss
    
    // Session State
    @State private var challenges: [SatzbauChallenge] = []
    @State private var currentIndex: Int = 0
    @State private var selectedTiles: [WordTileItem] = []
    @State private var availableTiles: [WordTileItem] = []
    
    // Outcome State
    @State private var isSubmitted: Bool = false
    @State private var isCorrect: Bool = false
    @State private var latestResult: GrammarAttemptResult? = nil
    @State private var showingRuleSheet: Bool = false
    @State private var isSessionComplete: Bool = false
    @State private var sessionCorrectCount: Int = 0
    @State private var startingUserElo: Double = 1200.0
    
    public init(
        grammarStore: GrammarStore,
        vocabStore: VocabularyStore,
        focusTopic: GrammarTopic? = nil,
        levelFilter: String? = nil
    ) {
        self.grammarStore = grammarStore
        self.vocabStore = vocabStore
        self.initialFocusTopic = focusTopic
        self.initialLevelFilter = levelFilter
    }
    
    private var currentChallenge: SatzbauChallenge? {
        guard currentIndex < challenges.count else { return nil }
        return challenges[currentIndex]
    }
    
    public var body: some View {
        NavigationView {
            ZStack {
                Color(UIColor.systemGroupedBackground)
                    .ignoresSafeArea()
                
                if isSessionComplete {
                    sessionCompleteView
                } else if let challenge = currentChallenge {
                    activeGameView(challenge: challenge)
                } else {
                    emptyStateView
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
                    if !challenges.isEmpty && !isSessionComplete {
                        VStack(spacing: 2) {
                            Text("Satzbau-Architekt")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                            Text("\(currentIndex + 1) von \(challenges.count)")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    if let challenge = currentChallenge {
                        let liveTopic = grammarStore.topics.first(where: { $0.id == challenge.topic.id }) ?? challenge.topic
                        LearnScoreBadge(
                            score: liveTopic.learnScore,
                            reviewsCount: liveTopic.reviewsCount,
                            showLabel: false,
                            compact: true
                        )
                    }
                }
            }
            .sheet(isPresented: $showingRuleSheet) {
                if let challenge = currentChallenge {
                    let liveTopic = grammarStore.topics.first(where: { $0.id == challenge.topic.id }) ?? challenge.topic
                    GrammarTopicDetailSheet(
                        topic: liveTopic,
                        onStartTopicPractice: nil
                    )
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
    
    // MARK: - Active Satzbau View
    @ViewBuilder
    private func activeGameView(challenge: SatzbauChallenge) -> some View {
        VStack(spacing: 0) {
            
            // Progress Bar
            GeometryReader { geo in
                let progress = CGFloat(currentIndex) / CGFloat(max(1, challenges.count))
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.primary.opacity(0.08))
                        .frame(height: 4)
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [Color(red: 0.14, green: 0.45, blue: 0.96), .indigo],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * progress, height: 4)
                        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: progress)
                }
            }
            .frame(height: 4)
            
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 12) {
                    
                    // 1. Topic Header & Quick Spickzettel Button
                    HStack(spacing: 8) {
                        Text(challenge.topic.level)
                            .font(.system(size: 10, weight: .heavy, design: .rounded))
                            .foregroundColor(.white)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(challenge.topic.level == "B2" ? Color.purple : Color.blue)
                            .cornerRadius(6)
                        
                        Text(challenge.topic.title)
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        
                        Spacer()
                        
                        Button(action: {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            showingRuleSheet = true
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "book.pages.fill")
                                Text("Regel")
                            }
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(.indigo)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 4)
                            .background(Color.indigo.opacity(0.12))
                            .cornerRadius(8)
                        }
                        .buttonStyle(ScaleButtonStyle(scaleAmount: 0.95))
                    }
                    .padding(.top, 6)
                    
                    // 2. Prompt Card (English meaning + Formula hint)
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: "translate")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.blue)
                            Text("Bilde den deutschen Satz:")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.secondary)
                        }
                        
                        Text(challenge.exercise.englishPrompt)
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                        
                        // Formula chip
                        HStack(spacing: 6) {
                            Image(systemName: "function")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.indigo)
                            Text(challenge.topic.formula)
                                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                .foregroundColor(.indigo)
                                .lineLimit(2)
                        }
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.indigo.opacity(0.08))
                        .cornerRadius(8)
                    }
                    .padding(13)
                    .background(
                        RoundedRectangle(cornerRadius: 15, style: .continuous)
                            .fill(Color(UIColor.secondarySystemGroupedBackground))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 15, style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
                    )
                    
                    // 3. Assembled Sentence Construction Box
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Dein Satzbau")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            if !selectedTiles.isEmpty && !isSubmitted {
                                Button(action: resetCurrentTiles) {
                                    HStack(spacing: 3) {
                                        Image(systemName: "arrow.uturn.backward")
                                        Text("Leeren")
                                    }
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(.red)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        
                        if selectedTiles.isEmpty {
                            HStack {
                                Spacer()
                                VStack(spacing: 6) {
                                    Image(systemName: "hand.tap.fill")
                                        .font(.system(size: 18))
                                        .foregroundColor(.secondary.opacity(0.6))
                                    Text("Tippe unten auf die Wort-Bausteine in der richtigen Reihenfolge")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.secondary)
                                        .multilineTextAlignment(.center)
                                }
                                .padding(.vertical, 24)
                                Spacer()
                            }
                        } else {
                            WrappingTileFlowLayout(spacing: 7, lineSpacing: 8) {
                                ForEach(selectedTiles) { tile in
                                    Button(action: {
                                        guard !isSubmitted else { return }
                                        deselectTile(tile)
                                    }) {
                                        Text(tile.text)
                                            .font(.system(size: 14, weight: .bold, design: .rounded))
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 11)
                                            .padding(.vertical, 7)
                                            .background(
                                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                    .fill(tileColorForSubmittedState())
                                            )
                                            .shadow(color: Color.black.opacity(0.08), radius: 3, y: 1)
                                    }
                                    .buttonStyle(ScaleButtonStyle(scaleAmount: 0.94))
                                    .disabled(isSubmitted)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .padding(13)
                    .frame(minHeight: 115, alignment: .topLeading)
                    .background(
                        RoundedRectangle(cornerRadius: 15, style: .continuous)
                            .fill(Color(UIColor.secondarySystemGroupedBackground))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 15, style: .continuous)
                            .strokeBorder(borderForConstructionBox(), lineWidth: isSubmitted ? 2 : 1)
                    )
                    
                    // 4. Available Scrambled Word Pool (or Feedback Card after submission)
                    if isSubmitted {
                        feedbackCard(challenge: challenge)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Wort-Bausteine (\(availableTiles.count) übrig)")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.secondary)
                            
                            WrappingTileFlowLayout(spacing: 8, lineSpacing: 9) {
                                ForEach(availableTiles) { tile in
                                    Button(action: {
                                        selectTile(tile)
                                    }) {
                                        Text(tile.text)
                                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                                            .foregroundColor(.primary)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 8)
                                            .background(
                                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                    .fill(Color(UIColor.secondarySystemGroupedBackground))
                                            )
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                    .strokeBorder(Color.primary.opacity(0.12), lineWidth: 1)
                                            )
                                            .shadow(color: Color.black.opacity(0.03), radius: 3, y: 1)
                                    }
                                    .buttonStyle(ScaleButtonStyle(scaleAmount: 0.94))
                                }
                            }
                        }
                        .padding(.top, 2)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 16)
            }
            
            // Bottom Action Bar (when not yet submitted)
            if !isSubmitted {
                VStack(spacing: 0) {
                    Divider()
                    HStack(spacing: 10) {
                        Button(action: {
                            guard let last = selectedTiles.last else { return }
                            deselectTile(last)
                        }) {
                            Image(systemName: "delete.left.fill")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(selectedTiles.isEmpty ? .secondary.opacity(0.4) : .primary)
                                .frame(width: 50, height: 48)
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(Color(UIColor.secondarySystemGroupedBackground))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                                )
                        }
                        .buttonStyle(ScaleButtonStyle(scaleAmount: 0.95))
                        .disabled(selectedTiles.isEmpty)
                        
                        Button(action: checkAnswer) {
                            HStack(spacing: 6) {
                                Text("Satzbau prüfen")
                                    .font(.system(size: 15, weight: .bold, design: .rounded))
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 15, weight: .bold))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(availableTiles.isEmpty ? Color(red: 0.14, green: 0.45, blue: 0.96) : Color.gray.opacity(0.45))
                            )
                        }
                        .buttonStyle(ScaleButtonStyle(scaleAmount: 0.97))
                        .disabled(!availableTiles.isEmpty)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color(UIColor.systemBackground))
                }
            }
        }
    }
    
    // MARK: - Post-Submission Feedback Card
    @ViewBuilder
    private func feedbackCard(challenge: SatzbauChallenge) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center) {
                HStack(spacing: 6) {
                    Image(systemName: isCorrect ? "checkmark.seal.fill" : "xmark.circle.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(isCorrect ? .green : .red)
                    Text(isCorrect ? "Perfekter Satzbau!" : "Wortstellung beachten!")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(isCorrect ? .green : .red)
                }
                
                Spacer()
                
                if let res = latestResult {
                    Text(res.scoreDelta >= 0 ? "+\(res.scoreDelta)% ➔ \(res.newScore)%" : "\(res.scoreDelta)% ➔ \(res.newScore)%")
                        .font(.system(size: 12, weight: .heavy, design: .rounded))
                        .foregroundColor(res.scoreDelta >= 0 ? .green : .red)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background((res.scoreDelta >= 0 ? Color.green : Color.red).opacity(0.12))
                        .cornerRadius(6)
                }
            }
            
            // Correct Target Sentence + Audio Button
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Korrekter Satz:")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.secondary)
                    Text(challenge.exercise.targetSentence)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                Button(action: {
                    AudioSpeaker.shared.speak(text: challenge.exercise.targetSentence)
                }) {
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.blue)
                        .padding(8)
                        .background(Color.blue.opacity(0.12))
                        .clipShape(Circle())
                }
                .buttonStyle(ScaleButtonStyle(scaleAmount: 0.94))
            }
            .padding(10)
            .background(Color(UIColor.tertiarySystemBackground))
            .cornerRadius(10)
            
            // Grammar Rule Explanation Callout
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(.orange)
                    .font(.system(size: 13))
                    .padding(.top, 2)
                Text(challenge.exercise.ruleCallout)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.primary)
                    .lineSpacing(2)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.orange.opacity(0.10))
            .cornerRadius(10)
            
            Button(action: advanceToNextChallenge) {
                HStack(spacing: 6) {
                    Text("Nächster Satz")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                    Image(systemName: "arrow.right")
                        .font(.system(size: 13, weight: .bold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 46)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(isCorrect ? Color.green : Color(red: 0.14, green: 0.45, blue: 0.96))
                )
            }
            .buttonStyle(ScaleButtonStyle(scaleAmount: 0.97))
            .padding(.top, 2)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(UIColor.secondarySystemGroupedBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder((isCorrect ? Color.green : Color.red).opacity(0.35), lineWidth: 1)
        )
    }
    
    // MARK: - Tile Selection & Validation Logic
    private func selectTile(_ tile: WordTileItem) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        withAnimation(.spring(response: 0.26, dampingFraction: 0.78)) {
            if let idx = availableTiles.firstIndex(of: tile) {
                let removed = availableTiles.remove(at: idx)
                selectedTiles.append(removed)
            }
        }
    }
    
    private func deselectTile(_ tile: WordTileItem) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        withAnimation(.spring(response: 0.26, dampingFraction: 0.78)) {
            if let idx = selectedTiles.firstIndex(of: tile) {
                let removed = selectedTiles.remove(at: idx)
                availableTiles.append(removed)
            }
        }
    }
    
    private func resetCurrentTiles() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
            availableTiles.append(contentsOf: selectedTiles)
            selectedTiles.removeAll()
        }
    }
    
    private func prepareTilesForCurrentChallenge() {
        guard let challenge = currentChallenge else { return }
        let tokens = challenge.exercise.expectedTokens
        var shuffled = tokens.map { WordTileItem(text: $0) }.shuffled()
        // Ensure shuffled order isn't identical to original order
        if shuffled.map({ $0.text }) == tokens && shuffled.count > 1 {
            shuffled.swapAt(0, shuffled.count - 1)
        }
        selectedTiles = []
        availableTiles = shuffled
        isSubmitted = false
        isCorrect = false
        latestResult = nil
    }
    
    private func checkAnswer() {
        guard let challenge = currentChallenge else { return }
        let assembled = selectedTiles.map { $0.text }.joined(separator: " ")
        let expected = challenge.exercise.expectedTokens.joined(separator: " ")
        
        let match = assembled.trimmingCharacters(in: .whitespacesAndNewlines) == expected.trimmingCharacters(in: .whitespacesAndNewlines)
        isCorrect = match
        isSubmitted = true
        
        if match {
            sessionCorrectCount += 1
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } else {
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
        
        latestResult = grammarStore.recordAttempt(
            topicId: challenge.topic.id,
            success: match,
            vocabStore: vocabStore
        )
        
        // Speak the correct German sentence aloud to reinforce auditory grammar memory
        AudioSpeaker.shared.speak(text: challenge.exercise.targetSentence, rate: 0.47)
    }
    
    private func advanceToNextChallenge() {
        AudioSpeaker.shared.stop()
        if currentIndex + 1 < challenges.count {
            currentIndex += 1
            prepareTilesForCurrentChallenge()
        } else {
            isSessionComplete = true
        }
    }
    
    private func startNewSession() {
        AudioSpeaker.shared.stop()
        startingUserElo = vocabStore.userElo
        sessionCorrectCount = 0
        currentIndex = 0
        isSessionComplete = false
        challenges = grammarStore.generateSatzbauSession(
            focusTopic: initialFocusTopic,
            levelFilter: initialLevelFilter,
            count: 8
        )
        prepareTilesForCurrentChallenge()
    }
    
    private func tileColorForSubmittedState() -> Color {
        if !isSubmitted {
            return Color(red: 0.14, green: 0.45, blue: 0.96)
        }
        return isCorrect ? Color(red: 0.10, green: 0.66, blue: 0.44) : Color(red: 0.90, green: 0.25, blue: 0.32)
    }
    
    private func borderForConstructionBox() -> Color {
        if !isSubmitted {
            return Color.primary.opacity(0.08)
        }
        return isCorrect ? Color.green.opacity(0.6) : Color.red.opacity(0.6)
    }
    
    // MARK: - Session Complete View
    private var sessionCompleteView: some View {
        VStack(spacing: 20) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(Color.indigo.opacity(0.14))
                    .frame(width: 84, height: 84)
                Image(systemName: "rectangle.3.group.fill")
                    .font(.system(size: 38))
                    .foregroundColor(.indigo)
            }
            
            VStack(spacing: 6) {
                Text("Satzbau-Runde Abgeschlossen!")
                    .font(.system(size: 22, weight: .black, design: .rounded))
                    .foregroundColor(.primary)
                
                Text("\(sessionCorrectCount) von \(challenges.count) Sätzen fehlerfrei konstruiert")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
            }
            
            VStack(spacing: 6) {
                let eloDelta = vocabStore.userElo - startingUserElo
                HStack(spacing: 6) {
                    Text("Neues Elo-Rating:")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.secondary)
                    Text("\(Int(round(vocabStore.userElo)))")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    Text(eloDelta >= 0 ? "(+\(Int(round(eloDelta))))" : "(\(Int(round(eloDelta))))")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(eloDelta >= 0 ? .green : .red)
                }
                
                Text("Deine Grammatik Lern-Scores wurden aktualisiert (80/20 Smart-Mix).")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            .padding(14)
            .frame(maxWidth: .infinity)
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .cornerRadius(14)
            .padding(.horizontal, 24)
            
            Spacer()
            
            VStack(spacing: 10) {
                Button(action: startNewSession) {
                    Text("Weitere Sätze bauen")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(Color(red: 0.14, green: 0.45, blue: 0.96))
                        .cornerRadius(12)
                }
                .buttonStyle(ScaleButtonStyle(scaleAmount: 0.97))
                
                Button(action: {
                    AudioSpeaker.shared.stop()
                    dismiss()
                }) {
                    Text("Zurück zur Grammatik")
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
    
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "rectangle.3.group.fill")
                .font(.system(size: 40))
                .foregroundColor(.indigo)
            Text("Keine Übungen gefunden")
                .font(.system(size: 16, weight: .bold))
            Button("Neu laden", action: startNewSession)
        }
    }
}

// MARK: - Responsive Wrapping Tile Flow Layout (iOS 16+ Layout Protocol)
public struct WrappingTileFlowLayout: Layout {
    var spacing: CGFloat = 8
    var lineSpacing: CGFloat = 8
    
    public init(spacing: CGFloat = 8, lineSpacing: CGFloat = 8) {
        self.spacing = spacing
        self.lineSpacing = lineSpacing
    }
    
    public func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? UIScreen.main.bounds.width - 56
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > maxWidth && currentX > 0 {
                currentX = 0
                currentY += lineHeight + lineSpacing
                lineHeight = 0
            }
            lineHeight = max(lineHeight, size.height)
            currentX += size.width + spacing
        }
        
        return CGSize(width: maxWidth, height: currentY + lineHeight)
    }
    
    public func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var currentX: CGFloat = bounds.minX
        var currentY: CGFloat = bounds.minY
        var lineHeight: CGFloat = 0
        
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > bounds.maxX && currentX > bounds.minX {
                currentX = bounds.minX
                currentY += lineHeight + lineSpacing
                lineHeight = 0
            }
            subview.place(
                at: CGPoint(x: currentX, y: currentY),
                anchor: .topLeading,
                proposal: ProposedViewSize(size)
            )
            lineHeight = max(lineHeight, size.height)
            currentX += size.width + spacing
        }
    }
}
