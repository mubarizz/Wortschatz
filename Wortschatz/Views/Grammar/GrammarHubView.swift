import SwiftUI
import UIKit

public enum GrammarMasteryFilter: String, CaseIterable {
    case all = "Alle"
    case unlearned = "Zu lernen"
    case learned = "Gelernt ✓"
}

public enum GrammarSortOrder: String, CaseIterable {
    case lowestScoreFirst = "Schwierigste (0% ➔ 100%)"
    case highestScoreFirst = "Gelernte (100% ➔ 0%)"
    case byLevel = "Niveau (B1 ➔ B2)"
}

public enum GrammarGameType: String, Equatable {
    case satzbau
    case strukturSprint
}

public struct SatzbauSessionRequest: Identifiable, Equatable {
    public let id = UUID()
    public let gameType: GrammarGameType
    public let focusTopic: GrammarTopic?
    public let levelFilter: String?
    
    public init(
        gameType: GrammarGameType = .satzbau,
        focusTopic: GrammarTopic? = nil,
        levelFilter: String? = nil
    ) {
        self.gameType = gameType
        self.focusTopic = focusTopic
        self.levelFilter = levelFilter
    }
}

public struct GrammarHubView: View {
    @ObservedObject var grammarStore: GrammarStore
    @ObservedObject var vocabStore: VocabularyStore
    
    @State private var masteryFilter: GrammarMasteryFilter = .all
    @State private var selectedChip: String = "Alle"
    @State private var sortOrder: GrammarSortOrder = .lowestScoreFirst
    @State private var searchText: String = ""
    
    @State private var selectedTopicForDetail: GrammarTopic? = nil
    @State private var activeSessionRequest: SatzbauSessionRequest? = nil
    
    private let chipOptions = ["Alle", "B1", "B2", "Satzbau", "Verben & Modi", "Kasus & Nomen"]
    
    public init(grammarStore: GrammarStore, vocabStore: VocabularyStore) {
        self.grammarStore = grammarStore
        self.vocabStore = vocabStore
    }
    
    private var filteredTopics: [GrammarTopic] {
        let filtered = grammarStore.topics.filter { topic in
            switch masteryFilter {
            case .all: break
            case .unlearned: if topic.isLearned { return false }
            case .learned: if !topic.isLearned { return false }
            }
            
            if !searchText.isEmpty {
                let q = searchText.lowercased()
                let matches = topic.title.lowercased().contains(q)
                    || topic.subtitle.lowercased().contains(q)
                    || topic.explanation.lowercased().contains(q)
                    || topic.signalWords.contains(where: { $0.lowercased().contains(q) })
                if !matches { return false }
            }
            
            switch selectedChip {
            case "Alle": return true
            case "B1", "B2": return topic.level == selectedChip
            case "Satzbau": return topic.category == .satzbau
            case "Verben & Modi": return topic.category == .verben
            case "Kasus & Nomen": return topic.category == .kasus
            default: return true
            }
        }
        
        switch sortOrder {
        case .lowestScoreFirst:
            return filtered.sorted {
                if $0.learnScore != $1.learnScore { return $0.learnScore < $1.learnScore }
                return $0.level < $1.level
            }
        case .highestScoreFirst:
            return filtered.sorted {
                if $0.learnScore != $1.learnScore { return $0.learnScore > $1.learnScore }
                return $0.level < $1.level
            }
        case .byLevel:
            return filtered.sorted {
                if $0.level != $1.level { return $0.level < $1.level }
                return $0.learnScore < $1.learnScore
            }
        }
    }
    
    public var body: some View {
        NavigationView {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 12) {
                    
                    // 1. Game #1 & Game #2 Launchers
                    VStack(spacing: 9) {
                        Button(action: {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            activeSessionRequest = SatzbauSessionRequest(
                                gameType: .satzbau,
                                focusTopic: nil,
                                levelFilter: (selectedChip == "B1" || selectedChip == "B2") ? selectedChip : nil
                            )
                        }) {
                            HStack(alignment: .center, spacing: 12) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(Color(red: 0.14, green: 0.45, blue: 0.96).opacity(0.15))
                                        .frame(width: 44, height: 44)
                                    Image(systemName: "rectangle.3.group.fill")
                                        .font(.system(size: 19, weight: .bold))
                                        .foregroundColor(Color(red: 0.14, green: 0.45, blue: 0.96))
                                }
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 6) {
                                        Text("Satzbau-Architekt")
                                            .font(.system(size: 15, weight: .bold, design: .rounded))
                                            .foregroundColor(.primary)
                                        
                                        Text("Wortstellung")
                                            .font(.system(size: 9, weight: .heavy, design: .rounded))
                                            .foregroundColor(Color(red: 0.14, green: 0.45, blue: 0.96))
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color(red: 0.14, green: 0.45, blue: 0.96).opacity(0.13))
                                            .cornerRadius(5)
                                    }
                                    
                                    Text("Sätze aus Wort-Bausteinen aktiv konstruieren")
                                        .font(.system(size: 11, weight: .regular))
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                }
                                
                                Spacer()
                                
                                Image(systemName: "play.circle.fill")
                                    .font(.system(size: 22))
                                    .foregroundColor(Color(red: 0.14, green: 0.45, blue: 0.96))
                            }
                            .padding(11)
                            .background(
                                RoundedRectangle(cornerRadius: 15, style: .continuous)
                                    .fill(Color(UIColor.secondarySystemGroupedBackground))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 15, style: .continuous)
                                    .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
                            )
                        }
                        .buttonStyle(ScaleButtonStyle(scaleAmount: 0.97))
                        
                        // Game #2 Launcher: Kasus- & Konnektoren-Sprint
                        Button(action: {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            activeSessionRequest = SatzbauSessionRequest(
                                gameType: .strukturSprint,
                                focusTopic: nil,
                                levelFilter: (selectedChip == "B1" || selectedChip == "B2") ? selectedChip : nil
                            )
                        }) {
                            HStack(alignment: .center, spacing: 12) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(Color(red: 0.53, green: 0.28, blue: 0.92).opacity(0.15))
                                        .frame(width: 44, height: 44)
                                    Image(systemName: "scope")
                                        .font(.system(size: 19, weight: .bold))
                                        .foregroundColor(Color(red: 0.53, green: 0.28, blue: 0.92))
                                }
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 6) {
                                        Text("Kasus- & Konnektoren-Sprint")
                                            .font(.system(size: 15, weight: .bold, design: .rounded))
                                            .foregroundColor(.primary)
                                        
                                        Text("4 Optionen")
                                            .font(.system(size: 9, weight: .heavy, design: .rounded))
                                            .foregroundColor(Color(red: 0.53, green: 0.28, blue: 0.92))
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color(red: 0.53, green: 0.28, blue: 0.92).opacity(0.13))
                                            .cornerRadius(5)
                                    }
                                    
                                    Text("Präpositionen, Endungen, Modi & Konnektoren im Kontext wählen")
                                        .font(.system(size: 11, weight: .regular))
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                }
                                
                                Spacer()
                                
                                Image(systemName: "play.circle.fill")
                                    .font(.system(size: 22))
                                    .foregroundColor(Color(red: 0.53, green: 0.28, blue: 0.92))
                            }
                            .padding(11)
                            .background(
                                RoundedRectangle(cornerRadius: 15, style: .continuous)
                                    .fill(Color(UIColor.secondarySystemGroupedBackground))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 15, style: .continuous)
                                    .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
                            )
                        }
                        .buttonStyle(ScaleButtonStyle(scaleAmount: 0.97))
                    }
                    
                    // 2. Mastery Segmented Filter
                    Picker("Lernstatus", selection: $masteryFilter) {
                        Text("Alle (\(grammarStore.topics.count))").tag(GrammarMasteryFilter.all)
                        Text("Zu lernen (\(grammarStore.unlearnedTopics.count))").tag(GrammarMasteryFilter.unlearned)
                        Text("Gelernt (\(grammarStore.learnedTopics.count))").tag(GrammarMasteryFilter.learned)
                    }
                    .pickerStyle(.segmented)
                    
                    // 3. Level & Category Chips
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(chipOptions, id: \.self) { chip in
                                Button(action: {
                                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                        selectedChip = chip
                                    }
                                }) {
                                    Text(chip)
                                        .font(.system(size: 12, weight: selectedChip == chip ? .bold : .semibold, design: .rounded))
                                        .foregroundColor(selectedChip == chip ? .white : .primary)
                                        .padding(.horizontal, 11)
                                        .padding(.vertical, 6)
                                        .background(
                                            Capsule()
                                                .fill(selectedChip == chip ? Color(red: 0.14, green: 0.46, blue: 0.96) : Color(UIColor.secondarySystemGroupedBackground))
                                        )
                                        .overlay(
                                            Capsule()
                                                .strokeBorder(selectedChip == chip ? Color.clear : Color.primary.opacity(0.08), lineWidth: 1)
                                        )
                                }
                                .buttonStyle(ScaleButtonStyle(scaleAmount: 0.95))
                            }
                        }
                    }
                    
                    // 4. Count & Sort Row
                    HStack {
                        Text("\(filteredTopics.count) Grammatik-Themen")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Menu {
                            ForEach(GrammarSortOrder.allCases, id: \.self) { order in
                                Button(action: { sortOrder = order }) {
                                    HStack {
                                        Text(order.rawValue)
                                        if sortOrder == order {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.up.arrow.down")
                                    .font(.system(size: 10, weight: .bold))
                                Text(sortOrder.rawValue)
                                    .font(.system(size: 11, weight: .semibold))
                            }
                            .foregroundColor(.blue)
                        }
                    }
                    .padding(.horizontal, 2)
                    
                    // 5. Topics List
                    VStack(spacing: 9) {
                        ForEach(filteredTopics) { topic in
                            GrammarTopicRowCard(
                                topic: topic,
                                onTapSpickzettel: {
                                    selectedTopicForDetail = topic
                                },
                                onTapSatzbau: {
                                    activeSessionRequest = SatzbauSessionRequest(
                                        gameType: .satzbau,
                                        focusTopic: topic,
                                        levelFilter: nil
                                    )
                                },
                                onTapSprint: {
                                    activeSessionRequest = SatzbauSessionRequest(
                                        gameType: .strukturSprint,
                                        focusTopic: topic,
                                        levelFilter: nil
                                    )
                                }
                            )
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
            }
            .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Grammatik (B1–B2)")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Regel oder Signalwort suchen (z.B. obwohl, Passiv)...")
            .sheet(item: $selectedTopicForDetail) { topic in
                GrammarTopicDetailSheet(
                    topic: grammarStore.topics.first(where: { $0.id == topic.id }) ?? topic,
                    onStartTopicPractice: { chosenTopic in
                        selectedTopicForDetail = nil
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            activeSessionRequest = SatzbauSessionRequest(
                                gameType: .satzbau,
                                focusTopic: chosenTopic,
                                levelFilter: nil
                            )
                        }
                    },
                    onStartTopicSprint: { chosenTopic in
                        selectedTopicForDetail = nil
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            activeSessionRequest = SatzbauSessionRequest(
                                gameType: .strukturSprint,
                                focusTopic: chosenTopic,
                                levelFilter: nil
                            )
                        }
                    }
                )
            }
            .fullScreenCover(item: $activeSessionRequest) { request in
                if request.gameType == .strukturSprint {
                    StrukturSprintGameView(
                        grammarStore: grammarStore,
                        vocabStore: vocabStore,
                        focusTopic: request.focusTopic,
                        levelFilter: request.levelFilter
                    )
                } else {
                    SatzbauGameView(
                        grammarStore: grammarStore,
                        vocabStore: vocabStore,
                        focusTopic: request.focusTopic,
                        levelFilter: request.levelFilter
                    )
                }
            }
        }
    }
}

// MARK: - Grammar Topic Row Card
private struct GrammarTopicRowCard: View {
    let topic: GrammarTopic
    let onTapSpickzettel: () -> Void
    let onTapSatzbau: () -> Void
    let onTapSprint: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                // Fixed-width Level Badge (B1 / B2)
                Text(topic.level)
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
                    .frame(width: 32, height: 22)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(topic.level == "B2" ? Color.purple : Color(red: 0.14, green: 0.45, blue: 0.96))
                    )
                
                // Category Chip
                Text(topic.category.rawValue)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(topic.category.badgeColor)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(topic.category.badgeColor.opacity(0.12))
                    .cornerRadius(6)
                
                Spacer()
                
                // Learn Score Badge
                LearnScoreBadge(
                    score: topic.learnScore,
                    reviewsCount: topic.reviewsCount,
                    showLabel: false,
                    compact: true
                )
                
                // Game 1 Button: Satzbau
                Button(action: {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    onTapSatzbau()
                }) {
                    HStack(spacing: 3) {
                        Image(systemName: "rectangle.3.group.fill")
                            .font(.system(size: 9, weight: .bold))
                        Text("Bau")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(Color(red: 0.14, green: 0.45, blue: 0.96)))
                }
                .buttonStyle(ScaleButtonStyle(scaleAmount: 0.93))
                
                // Game 2 Button: Sprint (Multiple Choice)
                Button(action: {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    onTapSprint()
                }) {
                    HStack(spacing: 3) {
                        Image(systemName: "scope")
                            .font(.system(size: 9, weight: .bold))
                        Text("Quiz")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(Color(red: 0.53, green: 0.28, blue: 0.92)))
                }
                .buttonStyle(ScaleButtonStyle(scaleAmount: 0.93))
            }
            
            // Tappable Info Area -> Opens Spickzettel
            Button(action: {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                onTapSpickzettel()
            }) {
                VStack(alignment: .leading, spacing: 6) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(topic.title)
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.leading)
                        
                        Text(topic.subtitle)
                            .font(.system(size: 12, weight: .regular))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.leading)
                    }
                    
                    // Formula Snippet
                    HStack(spacing: 6) {
                        Image(systemName: "function")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.indigo)
                        Text(topic.formula)
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundColor(.indigo)
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.indigo.opacity(0.07))
                    .cornerRadius(7)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(ScaleButtonStyle(scaleAmount: 0.99))
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(Color(UIColor.secondarySystemGroupedBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.025), radius: 5, y: 2)
    }
}

// MARK: - 30-Second Grammar Spickzettel (Rule Detail Sheet)
public struct GrammarTopicDetailSheet: View {
    let topic: GrammarTopic
    let onStartTopicPractice: ((GrammarTopic) -> Void)?
    var onStartTopicSprint: ((GrammarTopic) -> Void)? = nil
    @Environment(\.dismiss) private var dismiss
    
    public var body: some View {
        NavigationView {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    
                    // 1. Header Card
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text(topic.level)
                                .font(.system(size: 12, weight: .heavy, design: .rounded))
                                .foregroundColor(.white)
                                .padding(.horizontal, 9)
                                .padding(.vertical, 4)
                                .background(topic.level == "B2" ? Color.purple : Color.blue)
                                .cornerRadius(7)
                            
                            Text(topic.category.rawValue)
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundColor(topic.category.badgeColor)
                                .padding(.horizontal, 9)
                                .padding(.vertical, 4)
                                .background(topic.category.badgeColor.opacity(0.14))
                                .cornerRadius(7)
                            
                            Spacer()
                            
                            LearnScoreBadge(
                                score: topic.learnScore,
                                reviewsCount: topic.reviewsCount,
                                showLabel: true
                            )
                        }
                        
                        Text(topic.title)
                            .font(.system(size: 22, weight: .black, design: .rounded))
                            .foregroundColor(.primary)
                        
                        Text(topic.subtitle)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color(UIColor.secondarySystemGroupedBackground))
                    )
                    
                    // 2. Visual Formula Card
                    VStack(alignment: .leading, spacing: 6) {
                        Label("Bauplan / Formel", systemImage: "function")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.indigo)
                        
                        Text(topic.formula)
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                            .foregroundColor(.primary)
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.indigo.opacity(0.10))
                            .cornerRadius(10)
                        
                        Text(topic.explanation)
                            .font(.system(size: 13, weight: .regular))
                            .foregroundColor(.primary)
                            .lineSpacing(3)
                            .padding(.top, 2)
                    }
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color(UIColor.secondarySystemGroupedBackground))
                    )
                    
                    // 3. Signal Words Chips
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Signalwörter & Auslöser", systemImage: "sparkle.magnifyingglass")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.orange)
                        
                        WrappingTileFlowLayout(spacing: 6, lineSpacing: 6) {
                            ForEach(topic.signalWords, id: \.self) { sig in
                                Text(sig)
                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                                    .foregroundColor(.orange)
                                    .padding(.horizontal, 9)
                                    .padding(.vertical, 5)
                                    .background(Color.orange.opacity(0.12))
                                    .cornerRadius(7)
                            }
                        }
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color(UIColor.secondarySystemGroupedBackground))
                    )
                    
                    // 4. Audio Examples
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Beispielsätze (mit Aussprache)", systemImage: "speaker.wave.2.fill")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.blue)
                        
                        ForEach(topic.examples, id: \.self) { ex in
                            HStack(alignment: .center, spacing: 10) {
                                Text(ex)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.primary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                
                                Button(action: {
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    AudioSpeaker.shared.speak(text: ex)
                                }) {
                                    Image(systemName: "speaker.wave.2.fill")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundColor(.blue)
                                        .padding(8)
                                        .background(Color.blue.opacity(0.12))
                                        .clipShape(Circle())
                                }
                                .buttonStyle(ScaleButtonStyle(scaleAmount: 0.93))
                            }
                            .padding(10)
                            .background(Color(UIColor.tertiarySystemBackground))
                            .cornerRadius(10)
                        }
                    }
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color(UIColor.secondarySystemGroupedBackground))
                    )
                    
                    // 5. Practice This Topic Buttons
                    VStack(spacing: 9) {
                        if let onStart = onStartTopicPractice {
                            Button(action: {
                                AudioSpeaker.shared.stop()
                                onStart(topic)
                            }) {
                                HStack(spacing: 8) {
                                    Image(systemName: "rectangle.3.group.fill")
                                    Text("Satzbau-Architekt starten (\(topic.exercises.count) Sätze)")
                                        .font(.system(size: 14, weight: .bold, design: .rounded))
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                                .background(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(Color(red: 0.14, green: 0.45, blue: 0.96))
                                )
                            }
                            .buttonStyle(ScaleButtonStyle(scaleAmount: 0.97))
                        }
                        
                        if let onSprint = onStartTopicSprint {
                            Button(action: {
                                AudioSpeaker.shared.stop()
                                onSprint(topic)
                            }) {
                                HStack(spacing: 8) {
                                    Image(systemName: "scope")
                                    Text("Kasus- & Konnektoren-Sprint starten")
                                        .font(.system(size: 14, weight: .bold, design: .rounded))
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                                .background(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(Color(red: 0.53, green: 0.28, blue: 0.92))
                                )
                            }
                            .buttonStyle(ScaleButtonStyle(scaleAmount: 0.97))
                        }
                    }
                }
                .padding(14)
            }
            .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Grammatik-Spickzettel")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") {
                        AudioSpeaker.shared.stop()
                        dismiss()
                    }
                    .font(.system(size: 15, weight: .semibold))
                }
            }
            .onDisappear {
                AudioSpeaker.shared.stop()
            }
        }
    }
}
