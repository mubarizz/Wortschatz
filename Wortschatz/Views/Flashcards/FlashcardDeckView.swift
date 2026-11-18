import SwiftUI
import UIKit

public enum FlashcardDeckFilter: String, CaseIterable {
    case unlearned = "Neu"
    case srsQueue = "SRS Queue"
    case allWords = "Alle"
}

public struct FlashcardDeckView: View {
    @ObservedObject var store: VocabularyStore
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedFilter: FlashcardDeckFilter = .srsQueue
    @State private var deckWords: [VocabularyWord] = []
    @State private var currentIndex: Int = 0
    @State private var isCardFlipped: Bool = false
    @State private var cardDragOffset: CGSize = .zero
    
    // Session summary
    @State private var isSessionComplete: Bool = false
    @State private var wordsMasteredInSession: Int = 0
    @State private var wordsToReviewAgain: [VocabularyWord] = []
    
    public init(store: VocabularyStore) {
        self.store = store
    }
    
    private var currentWord: VocabularyWord? {
        guard currentIndex < deckWords.count else { return nil }
        return deckWords[currentIndex]
    }
    
    public var body: some View {
        NavigationView {
            ZStack {
                Color(UIColor.systemGroupedBackground)
                    .ignoresSafeArea()
                
                if isSessionComplete {
                    deckCompleteView
                } else if let word = currentWord {
                    activeDeckView(word: word)
                } else {
                    emptyDeckView
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
                    if !deckWords.isEmpty && !isSessionComplete {
                        VStack(spacing: 2) {
                            Text("Karteikarten")
                                .font(.system(size: 13, weight: .bold))
                            Text("\(currentIndex + 1) von \(deckWords.count)")
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
                buildDeck()
            }
        }
    }
    
    // MARK: - Active Deck View
    @ViewBuilder
    private func activeDeckView(word: VocabularyWord) -> some View {
        VStack(spacing: 12) {
            
            // Filter Selector (Compact)
            Picker("Filter", selection: $selectedFilter) {
                ForEach(FlashcardDeckFilter.allCases, id: \.self) { filter in
                    Text(filter.rawValue).tag(filter)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.top, 4)
            .onChange(of: selectedFilter) { _ in
                buildDeck()
            }
            
            // Progress Bar
            GeometryReader { geo in
                let progress = CGFloat(currentIndex) / CGFloat(max(1, deckWords.count))
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
            
            Spacer()
            
            // Interactive 3D Flashcard with Swipe Gesture
            ZStack {
                FlashcardView(word: word, isFlipped: $isCardFlipped)
                    .offset(x: cardDragOffset.width)
                    .rotationEffect(.degrees(Double(cardDragOffset.width / 20)))
                    .gesture(
                        DragGesture()
                            .onChanged { gesture in
                                cardDragOffset = gesture.translation
                            }
                            .onEnded { gesture in
                                if gesture.translation.width > 100 {
                                    // Swiped Right -> Mastered
                                    rateWord(success: true)
                                } else if gesture.translation.width < -100 {
                                    // Swiped Left -> Repeat
                                    rateWord(success: false)
                                } else {
                                    withAnimation(.spring()) {
                                        cardDragOffset = .zero
                                    }
                                }
                            }
                    )
            }
            .padding(.horizontal, 16)
            
            Spacer()
            
            // Bottom Action Ratings (Large touch targets >= 48pt)
            VStack(spacing: 8) {
                HStack(spacing: 10) {
                    
                    // 1. "Noch nicht" / Hard button
                    Button(action: { rateWord(success: false) }) {
                        VStack(spacing: 2) {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.system(size: 15, weight: .bold))
                            Text("Noch üben")
                                .font(.system(size: 11, weight: .bold))
                        }
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.red.opacity(0.12))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.red.opacity(0.25), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    
                    // 2. "Gelernt" / Easy button
                    Button(action: { rateWord(success: true) }) {
                        VStack(spacing: 2) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 15, weight: .bold))
                            Text("Gelernt")
                                .font(.system(size: 11, weight: .bold))
                        }
                        .foregroundColor(.green)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.green.opacity(0.12))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.green.opacity(0.25), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                
                Text("Tippen zum Umdrehen • Wischen nach rechts für 'Gelernt'")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(Color(UIColor.tertiaryLabel))
            }
            .padding(.bottom, 12)
        }
    }
    
    // MARK: - Card Rating Logic
    private func rateWord(success: Bool) {
        guard let word = currentWord else { return }
        
        UIImpactFeedbackGenerator(style: success ? .medium : .light).impactOccurred()
        
        if success {
            wordsMasteredInSession += 1
            // Record mastery in store Elo engine
            store.recordAttempt(wordId: word.id, success: true)
        } else {
            wordsToReviewAgain.append(word)
        }
        
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            cardDragOffset = .zero
            isCardFlipped = false
            
            if currentIndex + 1 < deckWords.count {
                currentIndex += 1
            } else {
                isSessionComplete = true
            }
        }
    }
    
    private func buildDeck() {
        switch selectedFilter {
        case .unlearned:
            let newWords = store.words.filter { $0.reviewsCount == 0 }
            deckWords = newWords.isEmpty ? Array(store.words.prefix(10)) : newWords
        case .srsQueue:
            deckWords = Array(store.spacedRepetitionQueue.prefix(15))
        case .allWords:
            deckWords = store.words
        }
        currentIndex = 0
        isCardFlipped = false
        cardDragOffset = .zero
        isSessionComplete = false
        wordsMasteredInSession = 0
        wordsToReviewAgain = []
    }
    
    // MARK: - Deck Complete View
    private var deckCompleteView: some View {
        VStack(spacing: 20) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.12))
                    .frame(width: 84, height: 84)
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 42))
                    .foregroundColor(.blue)
            }
            
            VStack(spacing: 6) {
                Text("Stapel Durchgearbeitet!")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                
                Text("\(wordsMasteredInSession) von \(deckWords.count) Wörtern als 'Gelernt' markiert")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
            }
            
            if !wordsToReviewAgain.isEmpty {
                VStack(spacing: 4) {
                    Text("\(wordsToReviewAgain.count) Wörter zum Wiederholen vorgemerkt")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.orange)
                    Text("Diese werden in der SRS Queue priorisiert.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .padding(12)
                .frame(maxWidth: .infinity)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(10)
                .padding(.horizontal, 24)
            }
            
            Spacer()
            
            VStack(spacing: 10) {
                Button(action: buildDeck) {
                    Text("Nochmal üben")
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
    
    private var emptyDeckView: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray.fill")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            Text("Keine Karten in diesem Stapel")
                .font(.system(size: 16, weight: .bold))
            Button("Alle Wörter laden", action: {
                selectedFilter = .allWords
                buildDeck()
            })
            .font(.system(size: 14, weight: .semibold))
        }
    }
}
