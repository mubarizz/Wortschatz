import SwiftUI
import UIKit

public enum GameHubCategory: String, Identifiable, Hashable {
    case vocabulary = "Wortschatz-Spiele"
    case grammar = "Grammatik-Spiele"
    case schreiben = "Schreiben-Prüfung"
    
    public var id: String { rawValue }
}

public struct GameHubView: View {
    @ObservedObject var store: VocabularyStore
    @ObservedObject var grammarStore: GrammarStore
    @ObservedObject var schreibenStore: SchreibenStore
    let onSelectCloze: () -> Void
    let onSelectReverseQuiz: () -> Void
    let onSelectFlashcards: () -> Void
    var onSelectDictation: (() -> Void)? = nil
    var onSelectPrepositionSprint: (() -> Void)? = nil
    
    @State private var selectedCategory: GameHubCategory? = nil
    @State private var grammarLevelFilter: String = "Alle"
    @State private var selectedGrammarTopicId: String? = nil
    @State private var activeGrammarSession: SatzbauSessionRequest? = nil
    
    private let grammarLevels = ["Alle", "B1", "B2"]
    
    private var selectedGrammarTopic: GrammarTopic? {
        guard let id = selectedGrammarTopicId else { return nil }
        return grammarStore.topics.first(where: { $0.id == id })
    }
    
    public init(
        store: VocabularyStore,
        grammarStore: GrammarStore = GrammarStore(),
        schreibenStore: SchreibenStore = SchreibenStore(),
        onSelectCloze: @escaping () -> Void,
        onSelectReverseQuiz: @escaping () -> Void,
        onSelectFlashcards: @escaping () -> Void,
        onSelectDictation: (() -> Void)? = nil,
        onSelectPrepositionSprint: (() -> Void)? = nil
    ) {
        self.store = store
        self.grammarStore = grammarStore
        self.schreibenStore = schreibenStore
        self.onSelectCloze = onSelectCloze
        self.onSelectReverseQuiz = onSelectReverseQuiz
        self.onSelectFlashcards = onSelectFlashcards
        self.onSelectDictation = onSelectDictation
        self.onSelectPrepositionSprint = onSelectPrepositionSprint
    }
    
    public var body: some View {
        NavigationView {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    if let category = selectedCategory {
                        categoryDetailContent(for: category)
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .move(edge: .leading).combined(with: .opacity)
                            ))
                    } else {
                        categoryOverviewContent
                            .transition(.asymmetric(
                                insertion: .move(edge: .leading).combined(with: .opacity),
                                removal: .move(edge: .trailing).combined(with: .opacity)
                            ))
                    }
                }
                .padding(14)
            }
            .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle(selectedCategory?.rawValue ?? "Spiele")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if selectedCategory != nil {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button(action: {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            withAnimation(.spring(response: 0.32, dampingFraction: 0.84)) {
                                selectedCategory = nil
                            }
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 13, weight: .bold))
                                Text("Kategorien")
                                    .font(.system(size: 14, weight: .semibold))
                            }
                            .foregroundColor(.blue)
                        }
                    }
                }
            }
            .fullScreenCover(item: $activeGrammarSession) { request in
                if request.gameType == .strukturSprint {
                    StrukturSprintGameView(
                        grammarStore: grammarStore,
                        vocabStore: store,
                        focusTopic: request.focusTopic,
                        levelFilter: request.levelFilter
                    )
                } else {
                    SatzbauGameView(
                        grammarStore: grammarStore,
                        vocabStore: store,
                        focusTopic: request.focusTopic,
                        levelFilter: request.levelFilter
                    )
                }
            }
        }
    }
    
    // MARK: - 1. Root Category Selection View (Option 1)
    private var categoryOverviewContent: some View {
        VStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Spiel-Kategorien")
                    .font(.system(size: 20, weight: .black, design: .rounded))
                    .foregroundColor(.primary)
                Text("Wähle einen Trainingsbereich • Smart-Mix (80% Zu lernen / 20% Gelernt)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
            
            // Category Card 1: Wortschatz-Spiele
            GameCategoryCard(
                title: "Wortschatz-Spiele",
                subtitle: "Vokabeln, Kontext, Kasus & Hörverständnis",
                badge: "5 Spiele",
                description: "Trainiere deinen B1–C1 Wortschatz mit Präpositionen-Sprint, 3D-Karteikarten, progressiven Lückentexten, Rückwärts-Definitionen und Audio-Diktat.",
                progressFraction: Double(store.learnedWords.count) / Double(max(1, store.words.count)),
                progressText: "\(store.learnedWords.count) von \(store.words.count) Vokabeln gelernt",
                secondaryStat: "\(store.b2UnlockedWords.count) B2 aktiv",
                gameTags: ["Präpositionen-Sprint (B1–C1)", "Karteikarten", "Lückentext", "Rückwärts-Quiz", "Hör-Diktat"],
                icon: "books.vertical.fill",
                color: Color(red: 0.14, green: 0.46, blue: 0.96),
                action: {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.84)) {
                        selectedCategory = .vocabulary
                    }
                }
            )
            
            // Category Card 2: Grammatik-Spiele
            GameCategoryCard(
                title: "Grammatik-Spiele",
                subtitle: "Satzbau, Kasus & Konnektoren (B1–B2)",
                badge: "2 Spiele",
                description: "Meistere deutsche Wortstellung, Nebensätze, Präpositionen und Endungen in 23 B1–B2 Grammatik-Themen mit 1.150 Übungssätzen.",
                progressFraction: Double(grammarStore.learnedTopics.count) / Double(max(1, grammarStore.topics.count)),
                progressText: "\(grammarStore.learnedTopics.count) von \(grammarStore.topics.count) Themen gelernt",
                secondaryStat: "1.150 Sätze",
                gameTags: ["Satzbau-Architekt", "Kasus- & Konnektoren-Sprint"],
                icon: "rectangle.3.group.fill",
                color: Color(red: 0.53, green: 0.28, blue: 0.92),
                action: {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.84)) {
                        selectedCategory = .grammar
                    }
                }
            )
            
            // Category Card 3: Schreiben-Prüfung (Goethe B1 & B2)
            let evaluatedCount = schreibenStore.evaluatedSubmissions.count
            let pendingCount = schreibenStore.pendingOfflineSubmissions.count
            let avgScore = schreibenStore.overallAverageScore
            GameCategoryCard(
                title: "Schreiben-Prüfung",
                subtitle: "Goethe-Institut B1 & B2 • Gemini 3 KI-Prüfer",
                badge: pendingCount > 0 ? "\(pendingCount) ⏳ Offline" : "B1 & B2",
                description: "Schreibe authentische Goethe B1 (Teil 1–3) und B2 (Teil 1–2) Prüfungen. Gemini 3 Flash bewertet nach den 4 Goethe-Kriterien (0–100 Pkt.), generiert neue Aufgaben und zeigt deine Schwachstellen.",
                progressFraction: evaluatedCount > 0 ? Double(avgScore) / 100.0 : 0.08,
                progressText: evaluatedCount > 0 ? "Ø \(avgScore)/100 Pkt. • \(evaluatedCount) Prüfungen" : "\(schreibenStore.allTasks.count) Prüfungsaufgaben bereit (Offline & KI)",
                secondaryStat: pendingCount > 0 ? "\(pendingCount) ausstehend" : (schreibenStore.weakestTeil.map { "Fokus: \($0.teil.level.rawValue) \($0.teil.shortTitle)" } ?? "Bestanden ab 60 Pkt."),
                gameTags: ["Goethe B1 (Teil 1–3)", "Goethe B2 (Teil 1–2)", "KI-Aufgabengenerator", "Schwachstellen-Analyse"],
                icon: "pencil.and.list.clipboard",
                color: Color(red: 0.08, green: 0.58, blue: 0.42),
                action: {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.84)) {
                        selectedCategory = .schreiben
                    }
                }
            )
        }
    }
    
    // MARK: - 2. Category Detail Views
    @ViewBuilder
    private func categoryDetailContent(for category: GameHubCategory) -> some View {
        switch category {
        case .vocabulary:
            vocabularyGamesSection
        case .grammar:
            grammarGamesSection
        case .schreiben:
            SchreibenHubView(schreibenStore: schreibenStore, vocabStore: store)
        }
    }
    
    // MARK: - Wortschatz Games List
    private var vocabularyGamesSection: some View {
        VStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Wortschatz-Spiele")
                    .font(.system(size: 20, weight: .black, design: .rounded))
                    .foregroundColor(.primary)
                Text("5 Lernmodi • Verben mit Präpositionen, Kasus & Vokabular")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
            
            if let onSelectPrepositionSprint = onSelectPrepositionSprint {
                GameHubCard(
                    title: "Präpositionen-Sprint",
                    subtitle: "Verben mit festen Präpositionen & Kasus",
                    badge: "B1–C1 Neu!",
                    description: "Meistere 50+ unverzichtbare Verben mit festen Präpositionen (Dativ vs. Akkusativ) im rasanten 60s-Blitz oder im gezielten Schwachstellen-Training.",
                    footerLabel: "+15 Pkt. • 60s Blitz & Multiplikator-Streak",
                    footerIcon: "bolt.fill",
                    icon: "bolt.horizontal.fill",
                    color: Color.orange,
                    buttonTitle: "Sprinten",
                    action: onSelectPrepositionSprint
                )
            }
            
            GameHubCard(
                title: "Karteikarten",
                subtitle: "Lernen & Verinnerlichen",
                badge: "Audio & 3D",
                description: "Verinnerliche neue Vokabeln mit deutscher Sprachausgabe, taktilen 3D-Drehkarten und B1/B2-Beispielsätzen.",
                footerLabel: "+20% Lern-Score • Swipe-System",
                footerIcon: "hand.draw.fill",
                icon: "rectangle.stack.fill",
                color: Color(red: 0.94, green: 0.50, blue: 0.10),
                buttonTitle: "Lernen",
                action: onSelectFlashcards
            )
            
            GameHubCard(
                title: "Lückentext-Arena",
                subtitle: "Progressive B1 ➔ B2 Cloze",
                badge: "Aktiv Schreiben",
                description: "Neue Wörter starten mit dem B1-Beispielsatz. Ab 50% Lern-Score schaltet die Arena dynamisch auf den B2-Satz um.",
                footerLabel: "+30% Lern-Score • \(store.b2UnlockedWords.count) B2 aktiv",
                footerIcon: "sparkles",
                icon: "character.cursor.ibeam",
                color: Color(red: 0.14, green: 0.46, blue: 0.96),
                buttonTitle: "Starten",
                action: onSelectCloze
            )
            
            GameHubCard(
                title: "Rückwärts-Quiz",
                subtitle: "100% Zielsprachen-Deduktion",
                badge: "Multiple Choice",
                description: "Versteckt die englische Übersetzung! Leite das gesuchte Zielwort anhand der deutschen Definition aus 4 Optionen derselben Wortart ab.",
                footerLabel: "+25% Lern-Score • Kein Englisch",
                footerIcon: "eye.slash.fill",
                icon: "arrow.triangle.turn.up.right.diamond.fill",
                color: Color(red: 0.55, green: 0.27, blue: 0.93),
                buttonTitle: "Starten",
                action: onSelectReverseQuiz
            )
            
            if let onSelectDictation = onSelectDictation {
                GameHubCard(
                    title: "Hör-Diktat",
                    subtitle: "Hörverständnis & Rechtschreibung",
                    badge: "Normal & 0.7x",
                    description: "Das Zielwort ist ausgeblendet – höre dir das Wort (normal oder langsam) sowie den Beispielsatz an und schreibe die Vokabel auf.",
                    footerLabel: "+10% Lern-Score • Audio-Training",
                    footerIcon: "ear.and.waveform",
                    icon: "headphones",
                    color: Color(red: 0.06, green: 0.62, blue: 0.66),
                    buttonTitle: "Starten",
                    action: onSelectDictation
                )
            }
        }
    }
    
    // MARK: - Grammatik Games List
    private var grammarGamesSection: some View {
        VStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Grammatik-Spiele")
                    .font(.system(size: 20, weight: .black, design: .rounded))
                    .foregroundColor(.primary)
                Text("23 B1–B2 Themen • 1.150 interaktive Sätze")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
            
            // Optional Level & Topic Filter (Alle / B1 / B2 + Topic Menu)
            VStack(alignment: .leading, spacing: 8) {
                Text("Niveau- & Themen-Filter für deine Spielrunde")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 4)
                
                Picker("Niveau", selection: $grammarLevelFilter) {
                    ForEach(grammarLevels, id: \.self) { level in
                        Text(level == "Alle" ? "Alle (B1 & B2)" : "Nur \(level)").tag(level)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: grammarLevelFilter) { _ in
                    if let topic = selectedGrammarTopic,
                       grammarLevelFilter != "Alle",
                       topic.level != grammarLevelFilter {
                        selectedGrammarTopicId = nil
                    }
                }
                
                Menu {
                    Button(action: { selectedGrammarTopicId = nil }) {
                        HStack {
                            Text("Alle Themen (80/20 Smart-Mix)")
                            if selectedGrammarTopicId == nil {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                    
                    Divider()
                    
                    let availableTopics = grammarStore.topics.filter {
                        grammarLevelFilter == "Alle" || $0.level == grammarLevelFilter
                    }
                    ForEach(availableTopics) { topic in
                        Button(action: { selectedGrammarTopicId = topic.id }) {
                            HStack {
                                Text("[\(topic.level)] \(topic.title) (\(topic.learnScore)%)")
                                if selectedGrammarTopicId == topic.id {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack {
                        Image(systemName: "line.3.horizontal.decrease.circle.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.purple)
                        Text(selectedGrammarTopic.map { "[\($0.level)] \($0.title)" } ?? "Thema: Alle Themen (80/20 Smart-Mix)")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        Spacer()
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color(UIColor.secondarySystemGroupedBackground))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                    )
                }
            }
            
            GameHubCard(
                title: "Satzbau-Architekt",
                subtitle: "Wortstellung & Satzklammer",
                badge: "Tap & Drag",
                description: "Konstruiere fehlerfreie B1/B2-Sätze aus Wort-Bausteinen. Unterstützt Tippen zum Tauschen, Links/Rechts-Verschieben und Drag & Drop.",
                footerLabel: "2–3 Runden bis Gelernt • \(grammarStore.learnedTopics.count)/\(grammarStore.topics.count) Themen",
                footerIcon: "rectangle.3.group.fill",
                icon: "rectangle.3.group.fill",
                color: Color(red: 0.14, green: 0.45, blue: 0.96),
                buttonTitle: "Starten",
                action: {
                    activeGrammarSession = SatzbauSessionRequest(
                        gameType: .satzbau,
                        focusTopic: selectedGrammarTopic,
                        levelFilter: (grammarLevelFilter == "B1" || grammarLevelFilter == "B2") ? grammarLevelFilter : nil
                    )
                }
            )
            
            GameHubCard(
                title: "Kasus- & Konnektoren-Sprint",
                subtitle: "Präpositionen, Endungen & Modi",
                badge: "4 Optionen",
                description: "Wähle im Satzzusammenhang blitzschnell den richtigen Konnektor, Kasus-Artikel, Relativpronomen oder Konjunktiv II aus 4 Optionen.",
                footerLabel: "Sofort-Regel-Erklärung & Audio",
                footerIcon: "bolt.fill",
                icon: "scope",
                color: Color(red: 0.53, green: 0.28, blue: 0.92),
                buttonTitle: "Starten",
                action: {
                    activeGrammarSession = SatzbauSessionRequest(
                        gameType: .strukturSprint,
                        focusTopic: selectedGrammarTopic,
                        levelFilter: (grammarLevelFilter == "B1" || grammarLevelFilter == "B2") ? grammarLevelFilter : nil
                    )
                }
            )
        }
    }
}

// MARK: - Big Category Selection Card
private struct GameCategoryCard: View {
    let title: String
    let subtitle: String
    let badge: String
    let description: String
    let progressFraction: Double
    let progressText: String
    let secondaryStat: String
    let gameTags: [String]
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            action()
        }) {
            VStack(alignment: .leading, spacing: 12) {
                // Header
                HStack(alignment: .center, spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(color.opacity(0.15))
                            .frame(width: 52, height: 52)
                        Image(systemName: icon)
                            .font(.system(size: 23, weight: .bold))
                            .foregroundColor(color)
                    }
                    
                    VStack(alignment: .leading, spacing: 3) {
                        Text(title)
                            .font(.system(size: 18, weight: .black, design: .rounded))
                            .foregroundColor(.primary)
                        Text(subtitle)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(color)
                    }
                    
                    Spacer()
                    
                    Text(badge)
                        .font(.system(size: 11, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(color))
                }
                
                Text(description)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(.secondary)
                    .lineSpacing(2.5)
                    .multilineTextAlignment(.leading)
                
                // Included Game Chips
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(gameTags, id: \.self) { tag in
                            HStack(spacing: 4) {
                                Image(systemName: "gamecontroller.fill")
                                    .font(.system(size: 9, weight: .bold))
                                Text(tag)
                                    .font(.system(size: 10, weight: .bold, design: .rounded))
                            }
                            .foregroundColor(color)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(color.opacity(0.11))
                            .cornerRadius(6)
                        }
                    }
                }
                
                // Progress Bar
                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        Text(progressText)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(secondaryStat)
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(color)
                    }
                    
                    GeometryReader { geo in
                        let clamped = min(1.0, max(0.0, progressFraction))
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color(UIColor.tertiarySystemFill))
                                .frame(height: 6)
                            Capsule()
                                .fill(color)
                                .frame(width: max(6, geo.size.width * clamped), height: 6)
                        }
                    }
                    .frame(height: 6)
                }
                
                Divider()
                    .opacity(0.6)
                
                HStack {
                    Text("Kategorie öffnen")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(color)
                    Spacer()
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(color)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color(UIColor.secondarySystemGroupedBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(color.opacity(0.18), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.04), radius: 10, y: 4)
        }
        .buttonStyle(ScaleButtonStyle(scaleAmount: 0.97))
    }
}

private struct GameHubCard: View {
    let title: String
    let subtitle: String
    let badge: String
    let description: String
    let footerLabel: String
    let footerIcon: String
    let icon: String
    let color: Color
    let buttonTitle: String
    let action: () -> Void
    
    var body: some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        }) {
            VStack(alignment: .leading, spacing: 11) {
                HStack(alignment: .center, spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(color.opacity(0.14))
                            .frame(width: 46, height: 46)
                        Image(systemName: icon)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(color)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                        Text(subtitle)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(color)
                    }
                    
                    Spacer()
                    
                    Text(badge)
                        .font(.system(size: 10, weight: .heavy, design: .rounded))
                        .foregroundColor(color)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(color.opacity(0.12))
                        .cornerRadius(6)
                }
                
                Text(description)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(.secondary)
                    .lineSpacing(2.5)
                    .multilineTextAlignment(.leading)
                
                Divider()
                    .opacity(0.6)
                
                HStack {
                    Label(footerLabel, systemImage: footerIcon)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(color)
                    
                    Spacer()
                    
                    HStack(spacing: 5) {
                        Text(buttonTitle)
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                        Image(systemName: "play.fill")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(
                        Capsule()
                            .fill(color)
                    )
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color(UIColor.secondarySystemGroupedBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.035), radius: 8, y: 3)
        }
        .buttonStyle(ScaleButtonStyle(scaleAmount: 0.97))
    }
}
