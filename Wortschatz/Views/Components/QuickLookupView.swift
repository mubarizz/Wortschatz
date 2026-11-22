import SwiftUI
import UIKit

// MARK: - iOS System Reference Dictionary Wrapper (Duden / Apple Dictionary)
public struct SystemDictionarySheet: UIViewControllerRepresentable {
    public let term: String
    
    public func makeUIViewController(context: Context) -> UIReferenceLibraryViewController {
        UIReferenceLibraryViewController(term: term)
    }
    
    public func updateUIViewController(_ uiViewController: UIReferenceLibraryViewController, context: Context) {}
}

// MARK: - QuickLookupView (Used in iOS Share Extension & In-App Quick Lookup)
public struct QuickLookupView: View {
    private var store: VocabularyStore?
    private let initialRawText: String
    private let isExtensionMode: Bool
    private let onClose: () -> Void
    private let onOpenInMainApp: ((String) -> Void)?
    
    @State private var context: LookupTextContext
    @State private var query: String
    @State private var localVocabularyPool: [VocabularyWord] = []
    @State private var localMatches: [VocabularyWord] = []
    @State private var prepositionMatches: [PrepositionEntry] = []
    @State private var aiCandidates: [GeminiWordCandidate] = []
    @State private var isLoadingAI: Bool = false
    @State private var aiErrorMessage: String? = nil
    @State private var savedWordKeys: Set<String> = []
    @State private var newlySavedCount: Int = 0
    @State private var showingSystemDictionary: Bool = false
    
    public init(
        rawText: String,
        store: VocabularyStore? = nil,
        isExtensionMode: Bool = false,
        onClose: @escaping () -> Void,
        onOpenInMainApp: ((String) -> Void)? = nil
    ) {
        self.initialRawText = rawText
        self.store = store
        self.isExtensionMode = isExtensionMode
        self.onClose = onClose
        self.onOpenInMainApp = onOpenInMainApp
        
        let extracted = SharedLookupBridge.shared.extractLookupContext(from: rawText)
        self._context = State(initialValue: extracted)
        self._query = State(initialValue: extracted.primaryQuery)
    }
    
    public var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    
                    // 1. Podcast Transcript / Multi-Word Selection Chip Bar
                    if context.isMultiWordSelection {
                        podcastTranscriptTokensCard
                    }
                    
                    // 2. Active Word Search & Pronunciation Bar
                    searchAndAudioBar
                    
                    // 3. Instant Local Vocabulary Matches (if already in user's deck)
                    if !localMatches.isEmpty {
                        localMatchesSection
                    }
                    
                    // 4. B1–C1 Verb + Preposition Matches (from PrepositionData)
                    if !prepositionMatches.isEmpty {
                        prepositionMatchesSection
                    }
                    
                    // 5. Live AI / Wiktionary DE+EN Lexicon Lookup Results
                    liveLexiconSection
                    
                    // 6. Apple iOS Native Dictionary Button & Deep Link Footer
                    footerActionsCard
                }
                .padding(14)
            }
            .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle(isExtensionMode ? "Wortschatz Lookup" : "Schnell-Nachschlagen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: {
                        AudioSpeaker.shared.stop()
                        onClose()
                    }) {
                        Text("Fertig")
                            .font(.system(size: 15, weight: .bold))
                    }
                }
                
                if isExtensionMode, let openApp = onOpenInMainApp {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(action: {
                            AudioSpeaker.shared.stop()
                            openApp(query)
                        }) {
                            HStack(spacing: 4) {
                                Text("In App")
                                Image(systemName: "arrow.up.forward.app.fill")
                            }
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.indigo)
                        }
                    }
                }
            }
            .sheet(isPresented: $showingSystemDictionary) {
                SystemDictionarySheet(term: query)
            }
            .onAppear {
                loadInitialPool()
                let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    performFullLookup(for: trimmed)
                }
            }
            .onDisappear {
                AudioSpeaker.shared.stop()
            }
        }
    }
    
    // MARK: - 1. Podcast Sentence Token Picker
    private var podcastTranscriptTokensCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "waveform.and.mic")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.indigo)
                Text("Ausgewählter Satz — Wort zum Nachschlagen antippen:")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.secondary)
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(context.sentenceTokens, id: \.self) { token in
                        let isSelected = token.lowercased() == query.lowercased()
                        Button(action: {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            query = token
                            performFullLookup(for: token)
                        }) {
                            Text(token)
                                .font(.system(size: 13, weight: isSelected ? .bold : .medium, design: .rounded))
                                .foregroundColor(isSelected ? .white : .primary)
                                .padding(.horizontal, 11)
                                .padding(.vertical, 6)
                                .background(
                                    Capsule()
                                        .fill(isSelected ? Color.indigo : Color(UIColor.secondarySystemGroupedBackground))
                                )
                                .overlay(
                                    Capsule()
                                        .strokeBorder(isSelected ? Color.clear : Color.primary.opacity(0.1), lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .padding(12)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    // MARK: - 2. Search & Audio Bar
    private var searchAndAudioBar: some View {
        HStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.indigo)
                    .font(.system(size: 14, weight: .bold))
                
                TextField("Deutsches Wort eingeben...", text: $query)
                    .font(.system(size: 15, weight: .semibold))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                    .submitLabel(.search)
                    .onSubmit {
                        performFullLookup(for: query)
                    }
                
                if !query.isEmpty {
                    Button(action: {
                        query = ""
                        localMatches = []
                        prepositionMatches = []
                        aiCandidates = []
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                            .font(.system(size: 15))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .frame(height: 44)
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(11)
            
            // Pronounce Query Button
            if !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Button(action: {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    AudioSpeaker.shared.speak(text: query)
                }) {
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.blue)
                        .frame(width: 44, height: 44)
                        .background(Color.blue.opacity(0.12))
                        .cornerRadius(11)
                }
                .buttonStyle(.plain)
            }
            
            Button(action: {
                performFullLookup(for: query)
            }) {
                Text("Suchen")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 13)
                    .frame(height: 44)
                    .background(query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.indigo.opacity(0.4) : Color.indigo)
                    .cornerRadius(11)
            }
            .disabled(query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoadingAI)
        }
    }
    
    // MARK: - 3. Local Vocabulary Matches Section
    private var localMatchesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("In deinem Wortschatz gefunden", systemImage: "checkmark.seal.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.green)
                Spacer()
            }
            
            ForEach(localMatches) { word in
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Text(word.articleOrType)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(word.category.badgeColor)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(word.category.badgeColor.opacity(0.15))
                            .cornerRadius(6)
                        
                        if let cefr = word.cefrLevel, !cefr.isEmpty {
                            Text(cefr)
                                .font(.system(size: 10, weight: .heavy, design: .rounded))
                                .foregroundColor(.indigo)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(Color.indigo.opacity(0.12))
                                .cornerRadius(5)
                        }
                        
                        Spacer()
                        
                        Text("Lernstatus: \(word.learnScore)%")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(word.learnScoreColor)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(word.learnScoreColor.opacity(0.12))
                            .cornerRadius(6)
                        
                        Button(action: {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            AudioSpeaker.shared.speak(text: word.displayTitle)
                        }) {
                            Image(systemName: "speaker.wave.2.fill")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.blue)
                                .padding(6)
                                .background(Color.blue.opacity(0.12))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                    }
                    
                    Text(word.cleanTargetWord)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    
                    Text(word.englishDefinition)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.blue)
                    
                    Text(word.germanDefinition)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                    
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("B1:")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.blue)
                            Text(word.b1Example)
                                .font(.system(size: 12))
                                .foregroundColor(.primary)
                        }
                        HStack {
                            Text("B2:")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.purple)
                            Text(word.b2Example)
                                .font(.system(size: 12))
                                .foregroundColor(.primary)
                        }
                    }
                }
                .padding(13)
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(14)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.green.opacity(0.35), lineWidth: 1.2)
                )
            }
        }
    }
    
    // MARK: - 4. Verb + Preposition Matches Section
    private var prepositionMatchesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("B1–C1 Verb mit fester Präposition", systemImage: "link.badge.plus")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.purple)
            
            ForEach(prepositionMatches) { entry in
                VStack(alignment: .leading, spacing: 7) {
                    HStack {
                        Text("\(entry.verb) \(entry.preposition)")
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                        
                        Text("+ \(entry.targetCase.fullName)")
                            .font(.system(size: 11, weight: .heavy, design: .rounded))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(entry.targetCase == .akkusativ ? Color.blue : Color.orange)
                            .cornerRadius(6)
                        
                        Text(entry.cefrLevel)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.purple)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.purple.opacity(0.14))
                            .cornerRadius(5)
                        
                        Spacer()
                        
                        Button(action: {
                            AudioSpeaker.shared.speak(text: entry.fullSentence)
                        }) {
                            Image(systemName: "speaker.wave.2.fill")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.purple)
                                .padding(6)
                                .background(Color.purple.opacity(0.12))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                    }
                    
                    Text(entry.englishTranslation)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.blue)
                    
                    Text("„\(entry.fullSentence)“")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.primary)
                    
                    Text(entry.ruleExplanation)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .padding(12)
                .background(Color.purple.opacity(0.08))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.purple.opacity(0.25), lineWidth: 1)
                )
            }
        }
    }
    
    // MARK: - 5. Live Lexicon / Gemini AI Results Section
    private var liveLexiconSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Bedeutung, Artikel & B1/B2-Beispiele", systemImage: "sparkles")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.indigo)
                Spacer()
                if newlySavedCount > 0 {
                    Text("+\(newlySavedCount * 5) Elo • \(newlySavedCount) gespeichert ✓")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.green)
                }
            }
            
            if isLoadingAI {
                VStack(spacing: 10) {
                    ProgressView()
                    Text("Analysiere „\(query)“ (Artikel, Bedeutung & B1/B2-Kontext)...")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 28)
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(14)
            } else if !aiCandidates.isEmpty {
                ForEach(aiCandidates) { candidate in
                    aiCandidateCard(candidate)
                }
            } else if let error = aiErrorMessage {
                VStack(alignment: .leading, spacing: 8) {
                    Text(error)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    
                    Button(action: {
                        saveQuickFallbackWord()
                    }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("„\(query)“ trotzdem zu meinem Wortschatz speichern")
                        }
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.indigo)
                        .cornerRadius(10)
                    }
                }
                .padding(12)
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(12)
            }
        }
    }
    
    private func aiCandidateCard(_ candidate: GeminiWordCandidate) -> some View {
        let vocabWord = candidate.toVocabularyWord()
        let key = vocabWord.cleanTargetWord.lowercased()
        let isSaved = savedWordKeys.contains(key)
        
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Text(vocabWord.articleOrType)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(vocabWord.category.badgeColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(vocabWord.category.badgeColor.opacity(0.14))
                    .cornerRadius(6)
                
                Text(candidate.cefrLevel.uppercased())
                    .font(.system(size: 10, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(cefrBadgeColor(candidate.cefrLevel))
                    .cornerRadius(5)
                
                Spacer()
                
                Button(action: {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    AudioSpeaker.shared.speak(text: vocabWord.displayTitle)
                }) {
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.blue)
                        .padding(6)
                        .background(Color.blue.opacity(0.12))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            
            VStack(alignment: .leading, spacing: 3) {
                Text(vocabWord.displayTitle)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                
                Text(vocabWord.englishDefinition)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.blue)
            }
            
            Text(vocabWord.germanDefinition)
                .font(.system(size: 13))
                .foregroundColor(.primary)
                .padding(9)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.indigo.opacity(0.07))
                .cornerRadius(8)
            
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .top, spacing: 6) {
                    Text("B1")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.blue)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.12))
                        .cornerRadius(4)
                    
                    Text(vocabWord.b1Example)
                        .font(.system(size: 12))
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Button(action: {
                        AudioSpeaker.shared.speak(text: vocabWord.b1Example)
                    }) {
                        Image(systemName: "speaker.wave.2")
                            .font(.system(size: 11))
                            .foregroundColor(.blue)
                    }
                    .buttonStyle(.plain)
                }
                
                HStack(alignment: .top, spacing: 6) {
                    Text("B2")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.purple)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.purple.opacity(0.12))
                        .cornerRadius(4)
                    
                    Text(vocabWord.b2Example)
                        .font(.system(size: 12))
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Button(action: {
                        AudioSpeaker.shared.speak(text: vocabWord.b2Example)
                    }) {
                        Image(systemName: "speaker.wave.2")
                            .font(.system(size: 11))
                            .foregroundColor(.purple)
                    }
                    .buttonStyle(.plain)
                }
            }
            
            // One-Tap Save Button
            Button(action: {
                saveWord(vocabWord)
            }) {
                HStack(spacing: 6) {
                    Image(systemName: isSaved ? "checkmark.circle.fill" : "plus.circle.fill")
                    Text(isSaved ? "Im Wortschatz gespeichert ✓" : "Zu Wortschatz hinzufügen (+5 Elo)")
                }
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(isSaved ? .green : .white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .background(isSaved ? Color.green.opacity(0.15) : Color.indigo)
                .cornerRadius(10)
            }
            .buttonStyle(.plain)
            .disabled(isSaved)
        }
        .padding(13)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(isSaved ? Color.green.opacity(0.4) : Color.primary.opacity(0.07), lineWidth: 1)
        )
    }
    
    // MARK: - 6. Footer Actions (iOS System Dictionary + Open App)
    private var footerActionsCard: some View {
        VStack(spacing: 8) {
            if !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Button(action: {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    showingSystemDictionary = true
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "book.closed.fill")
                            .foregroundColor(.blue)
                        Text("„\(query)“ im iOS System-Wörterbuch (Duden / Oxford) öffnen")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.primary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.secondary)
                    }
                    .padding(12)
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(11)
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    // MARK: - Logic & Actions
    
    private func loadInitialPool() {
        if let mainStore = store {
            localVocabularyPool = mainStore.words
        } else {
            localVocabularyPool = SharedLookupBridge.shared.loadVocabularySnapshot()
        }
        savedWordKeys = Set(localVocabularyPool.map { $0.cleanTargetWord.lowercased() })
    }
    
    private func performFullLookup(for rawQuery: String) {
        let trimmed = rawQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        // 1. Instant Local Vocabulary Matches
        localMatches = SharedLookupBridge.shared.findLocalVocabularyMatches(for: trimmed, in: localVocabularyPool)
        
        // 2. Instant Verb-Preposition Matches
        prepositionMatches = SharedLookupBridge.shared.findPrepositionMatches(for: trimmed)
        
        // 3. Async Live AI / Wiktionary DE+EN Lookup
        isLoadingAI = true
        aiErrorMessage = nil
        
        Task {
            do {
                let results = try await GeminiService.shared.searchWords(query: trimmed)
                await MainActor.run {
                    self.aiCandidates = results
                    self.isLoadingAI = false
                }
            } catch {
                let fallback = await SharedLookupBridge.shared.lookupViaWiktionary(query: trimmed)
                await MainActor.run {
                    if !fallback.isEmpty {
                        self.aiCandidates = fallback
                        self.aiErrorMessage = nil
                    } else {
                        self.aiCandidates = []
                        self.aiErrorMessage = "Keine Online-Details für „\(trimmed)“ gefunden. Du kannst das Wort direkt speichern."
                    }
                    self.isLoadingAI = false
                }
            }
        }
    }
    
    private func saveWord(_ vocabWord: VocabularyWord) {
        let key = vocabWord.cleanTargetWord.lowercased()
        guard !savedWordKeys.contains(key) else { return }
        
        if let mainStore = store {
            if mainStore.addWord(vocabWord) {
                mainStore.recordExternalGameActivity(points: 5.0, reviewsCount: 0)
            }
        } else {
            SharedLookupBridge.shared.enqueueSavedWordFromExtension(vocabWord)
        }
        
        savedWordKeys.insert(key)
        localVocabularyPool.insert(vocabWord, at: 0)
        newlySavedCount += 1
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
    
    private func saveQuickFallbackWord() {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let isCapitalized = trimmed.first?.isUppercase == true
        let fallbackWord = VocabularyWord(
            articleOrType: isCapitalized ? "die" : "Verb",
            word: trimmed,
            englishDefinition: "Saved from podcast / reading",
            germanDefinition: "Aus Podcast oder Text gespeichertes Wort („\(trimmed)“).",
            b1Example: "Ich habe das Wort \(trimmed) heute im Podcast gehört.",
            b2Example: "Im Kontext der Sendung wurde der Begriff \(trimmed) verwendet.",
            cefrLevel: "B2"
        )
        saveWord(fallbackWord)
    }
    
    private func cefrBadgeColor(_ level: String) -> Color {
        switch level.uppercased() {
        case "A1", "A2": return .teal
        case "B1": return .blue
        case "B2": return .indigo
        case "C1", "C2": return .purple
        default: return .indigo
        }
    }
}
