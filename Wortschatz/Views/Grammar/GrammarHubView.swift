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

public enum LearnHubCategory: String, Identifiable, Hashable {
    case grammarRules = "Grammatik-Regeln"
    case schreibenSamples = "Schreiben-Beispiele"
    
    public var id: String { rawValue }
}

public struct GrammarHubView: View {
    @ObservedObject var grammarStore: GrammarStore
    @ObservedObject var vocabStore: VocabularyStore
    
    @State private var selectedLearnCategory: LearnHubCategory? = nil
    
    // Grammar section state
    @State private var masteryFilter: GrammarMasteryFilter = .all
    @State private var selectedChip: String = "Alle"
    @State private var sortOrder: GrammarSortOrder = .lowestScoreFirst
    @State private var searchText: String = ""
    @State private var selectedTopicForDetail: GrammarTopic? = nil
    
    // Official Goethe & telc/ALTE Schreiben samples state
    @State private var selectedSampleFilter: String = "Alle"
    @State private var sampleSearchText: String = ""
    @State private var showOfficialRubricTable: Bool = false
    @State private var selectedOfficialSample: OfficialGoetheSample? = nil
    
    private let chipOptions = ["Alle", "B1", "B2", "Satzbau", "Verben & Modi", "Kasus & Nomen"]
    private let sampleFilterOptions = ["Alle", "Goethe-Institut", "telc / ALTE", "Nur B1", "Nur B2", "B1 Teil 1", "B1 Teil 2", "B1 Teil 3", "B2 Teil 1", "B2 Teil 2"]
    
    public init(grammarStore: GrammarStore, vocabStore: VocabularyStore) {
        self.grammarStore = grammarStore
        self.vocabStore = vocabStore
    }
    
    private var filteredOfficialSamples: [OfficialGoetheSample] {
        OfficialGoetheSamplesBank.allSamples.filter { sample in
            let matchesCategory: Bool
            switch selectedSampleFilter {
            case "Alle": matchesCategory = true
            case "Goethe-Institut": matchesCategory = sample.officialSourcePDF.localizedStandardContains("Goethe")
            case "telc / ALTE": matchesCategory = sample.officialSourcePDF.localizedStandardContains("telc")
            case "Nur B1": matchesCategory = sample.level == .b1
            case "Nur B2": matchesCategory = sample.level == .b2
            case "B1 Teil 1": matchesCategory = sample.teil == .b1Teil1
            case "B1 Teil 2": matchesCategory = sample.teil == .b1Teil2
            case "B1 Teil 3": matchesCategory = sample.teil == .b1Teil3
            case "B2 Teil 1": matchesCategory = sample.teil == .b2Teil1
            case "B2 Teil 2": matchesCategory = sample.teil == .b2Teil2
            default: matchesCategory = true
            }
            guard matchesCategory else { return false }
            
            let q = sampleSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
            if !q.isEmpty {
                return sample.title.localizedStandardContains(q)
                    || sample.officialSourcePDF.localizedStandardContains(q)
                    || sample.candidateLabel.localizedStandardContains(q)
                    || sample.authenticCandidateText.localizedStandardContains(q)
                    || sample.officialPromptText.localizedStandardContains(q)
            }
            return true
        }
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
                VStack(spacing: 14) {
                    if let category = selectedLearnCategory {
                        switch category {
                        case .grammarRules:
                            grammarRulesSection
                                .transition(.asymmetric(
                                    insertion: .move(edge: .trailing).combined(with: .opacity),
                                    removal: .move(edge: .leading).combined(with: .opacity)
                                ))
                        case .schreibenSamples:
                            officialSchreibenSamplesSection
                                .transition(.asymmetric(
                                    insertion: .move(edge: .trailing).combined(with: .opacity),
                                    removal: .move(edge: .leading).combined(with: .opacity)
                                ))
                        }
                    } else {
                        learnOverviewContent
                            .transition(.asymmetric(
                                insertion: .move(edge: .leading).combined(with: .opacity),
                                removal: .move(edge: .trailing).combined(with: .opacity)
                            ))
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
            }
            .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle(selectedLearnCategory?.rawValue ?? "Lernen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if selectedLearnCategory != nil {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button(action: {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            withAnimation(.spring(response: 0.32, dampingFraction: 0.84)) {
                                selectedLearnCategory = nil
                            }
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 13, weight: .bold))
                                Text("Lernen")
                                    .font(.system(size: 14, weight: .semibold))
                            }
                            .foregroundColor(.blue)
                        }
                    }
                }
            }
            .sheet(item: $selectedTopicForDetail) { topic in
                GrammarTopicDetailSheet(
                    topic: grammarStore.topics.first(where: { $0.id == topic.id }) ?? topic,
                    onStartTopicPractice: nil,
                    onStartTopicSprint: nil
                )
            }
            .sheet(item: $selectedOfficialSample) { sample in
                OfficialGoetheSampleDetailSheet(sample: sample)
            }
        }
    }
    
    // MARK: - 1. Root "Lernen" Category Overview (Grammatik-Regeln + Echte Schreiben-Beispiele)
    private var learnOverviewContent: some View {
        VStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Lern- & Nachschlagewerk")
                    .font(.system(size: 20, weight: .black, design: .rounded))
                    .foregroundColor(.primary)
                Text("100% Offline • Grammatik-Regeln & echte Goethe-Prüfungsbeispiele (Kein KI-Text)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
            
            // Card 1: Grammatik-Regeln (B1 & B2)
            LearnCategoryCard(
                title: "Grammatik-Regeln (B1–B2)",
                subtitle: "Formeln, Signalwörter & Beispielsätze",
                badge: "23 Themen",
                description: "Nachschlagewerk für alle wichtigen B1- und B2-Grammatikregeln: Satzbau, Nebensätze, Konnektoren, Konjunktiv II, Passiv, Kasus und Präpositionen.",
                footerLeft: "\(grammarStore.learnedTopics.count) von \(grammarStore.topics.count) Themen gelernt",
                footerRight: "100% Offline",
                tags: ["Satzbau & Konnektoren", "Verben & Modi", "Kasus & Nomen", "Spickzettel"],
                icon: "rectangle.3.group.fill",
                color: Color(red: 0.53, green: 0.28, blue: 0.92),
                action: {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.84)) {
                        selectedLearnCategory = .grammarRules
                    }
                }
            )
            
            // Card 2: Echte Goethe & telc/ALTE Schreiben-Leistungsbeispiele (B1 & B2)
            let totalSamples = OfficialGoetheSamplesBank.allSamples.count
            let b1SamplesCount = OfficialGoetheSamplesBank.allSamples.filter { $0.level == .b1 }.count
            let b2SamplesCount = OfficialGoetheSamplesBank.allSamples.filter { $0.level == .b2 }.count
            LearnCategoryCard(
                title: "Schreiben-Leistungsbeispiele",
                subtitle: "Goethe-Institut & telc/ALTE B1–B2 Prüfungsakten",
                badge: "\(totalSamples) Echte Texte",
                description: "Lies \(totalSamples) echte, authentische Kandidatentexte, Original-Aufgabenstellungen, Prüferbewertungen und linguistische Korrekturen aus offiziellen Goethe-Institut PDFs und dem europäischen telc/ALTE MERLIN-Prüfungskorpus (0% KI-generiert).",
                footerLeft: "\(b1SamplesCount)× B1 • \(b2SamplesCount)× B2 (14 pro Teil)",
                footerRight: "Goethe & telc/ALTE",
                tags: ["14× Goethe-Institut PDFs", "56× telc/ALTE Prüfungsakten", "Mit Linguisten-Korrektur"],
                icon: "doc.text.magnifyingglass",
                color: Color(red: 0.08, green: 0.58, blue: 0.42),
                action: {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.84)) {
                        selectedLearnCategory = .schreibenSamples
                    }
                }
            )
        }
    }
    
    // MARK: - 2A. Grammatik-Regeln Section
    private var grammarRulesSection: some View {
        VStack(spacing: 12) {
            // Inline search bar for grammar rules
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.secondary)
                TextField("Regel oder Signalwort suchen (z.B. obwohl, Passiv)...", text: $searchText)
                    .font(.system(size: 13.5, weight: .medium))
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(UIColor.secondarySystemGroupedBackground))
            )
            
            // 1. Mastery Segmented Filter
            Picker("Lernstatus", selection: $masteryFilter) {
                Text("Alle (\(grammarStore.topics.count))").tag(GrammarMasteryFilter.all)
                Text("Zu lernen (\(grammarStore.unlearnedTopics.count))").tag(GrammarMasteryFilter.unlearned)
                Text("Gelernt (\(grammarStore.learnedTopics.count))").tag(GrammarMasteryFilter.learned)
            }
            .pickerStyle(.segmented)
            
            // 2. Level & Category Chips
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
            
            // 3. Count & Sort Row
            HStack {
                Text("\(filteredTopics.count) Grammatik-Regeln")
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
            
            // 4. Topics List (Pure Rule & Spickzettel Reference)
            VStack(spacing: 9) {
                ForEach(filteredTopics) { topic in
                    GrammarTopicRowCard(
                        topic: topic,
                        onTapSpickzettel: {
                            selectedTopicForDetail = topic
                        }
                    )
                }
            }
        }
    }
    
    // MARK: - 2B. Official Goethe-Institut & telc/ALTE Schreiben-Leistungsbeispiele Section (100% Real, Non-AI)
    private var officialSchreibenSamplesSection: some View {
        VStack(spacing: 12) {
            // Authenticity Verification Banner
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(Color(red: 0.08, green: 0.58, blue: 0.42))
                    .padding(.top, 2)
                
                VStack(alignment: .leading, spacing: 3) {
                    Text("70 Echte B1 & B2 Prüfungsakten (0% KI-generiert)")
                        .font(.system(size: 13, weight: .black, design: .rounded))
                        .foregroundColor(.primary)
                    Text("14 Originalbeispiele aus den offiziellen Goethe-Institut PDFs (goethe.de) + 56 echte Kandidatenprüfungen aus dem offiziellen telc / ALTE MERLIN-Prüfungskorpus (TU Dresden / Eurac Research) inklusive linguistischer Zielkorrektur.")
                        .font(.system(size: 11.5, weight: .regular))
                        .foregroundColor(.secondary)
                        .lineSpacing(2)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(red: 0.08, green: 0.58, blue: 0.42).opacity(0.10))
            )
            
            // Inline search bar for the 70 official writing samples
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.secondary)
                TextField("Thema, Quelle oder Stichwort suchen (z.B. Praktikum, Au-pair, Umwelt)...", text: $sampleSearchText)
                    .font(.system(size: 13, weight: .medium))
                if !sampleSearchText.isEmpty {
                    Button(action: { sampleSearchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(UIColor.secondarySystemGroupedBackground))
            )
            
            // Collapsible Official Goethe Bewertungskriterien & Point Distribution Card
            officialRubricReferenceCard
            
            // Filter Chips (Alle / Goethe-Institut / telc / Nur B1 / Nur B2 / Teil 1-3)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(sampleFilterOptions, id: \.self) { option in
                        let isSelected = selectedSampleFilter == option
                        Button(action: {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            selectedSampleFilter = option
                        }) {
                            Text(option)
                                .font(.system(size: 12, weight: isSelected ? .bold : .semibold, design: .rounded))
                                .foregroundColor(isSelected ? .white : .primary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    Capsule()
                                        .fill(isSelected ? Color(red: 0.08, green: 0.58, blue: 0.42) : Color(UIColor.secondarySystemGroupedBackground))
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            
            HStack {
                Text("\(filteredOfficialSamples.count) echte Kandidatentexte angezeigt")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding(.horizontal, 4)
            
            // List of 70 Verbatim Official Samples
            ForEach(filteredOfficialSamples) { sample in
                officialSampleRowCard(sample)
            }
        }
    }
    
    private var officialRubricReferenceCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button(action: {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
                    showOfficialRubricTable.toggle()
                }
            }) {
                HStack {
                    Image(systemName: "tablecells.badge.ellipsis")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.blue)
                    Text("Offizielle Goethe-Punkteverteilung (Prüferblätter S. 44 / S. 47)")
                        .font(.system(size: 12.5, weight: .black, design: .rounded))
                        .foregroundColor(.primary)
                    Spacer()
                    Image(systemName: showOfficialRubricTable ? "chevron.up.circle.fill" : "chevron.down.circle.fill")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.blue)
                }
            }
            .buttonStyle(.plain)
            
            if showOfficialRubricTable {
                Divider().opacity(0.6)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("1. Goethe-Zertifikat B1 (60 Min. • 100 Punkte • Bestanden ab 60 Pkt.)")
                        .font(.system(size: 12, weight: .black, design: .rounded))
                        .foregroundColor(Color(red: 0.08, green: 0.58, blue: 0.42))
                    
                    Text("• Teil 1 (E-Mail ~80 W.): Max. 40 Pkt. (Erfüllung 10 | Kohärenz 10 | Wortschatz 10 | Strukturen 10)\n• Teil 2 (Forum ~80 W.): Max. 40 Pkt. (Erfüllung 10 | Kohärenz 10 | Wortschatz 10 | Strukturen 10)\n• Teil 3 (Kurzmitteilung ~40 W.): Max. 20 Pkt. (Erfüllung 4 | Kohärenz 4 | Wortschatz 6 | Strukturen 6)")
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundColor(.primary)
                        .lineSpacing(3)
                    
                    Divider().opacity(0.5)
                    
                    Text("2. Goethe-Zertifikat B2 (75 Min. • 100 Punkte • Bestanden ab 60 Pkt.)")
                        .font(.system(size: 12, weight: .black, design: .rounded))
                        .foregroundColor(.blue)
                    
                    Text("• Teil 1 (Forumsbeitrag ~150 W.): Max. 60 Pkt. (Erfüllung 14 | Kohärenz 14 | Wortschatz 16 | Strukturen 16)\n• Teil 2 (Nachricht ~100 W.): Max. 40 Pkt. (Erfüllung 10 | Kohärenz 10 | Wortschatz 10 | Strukturen 10)")
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundColor(.primary)
                        .lineSpacing(3)
                    
                    Text("⚠️ Offizielle 0-Punkte-Regel (Prüferblatt S. 42/46): Wird das Kriterium ‚Erfüllung‘ mit Stufe E (0 Pkt.) bewertet (Textumfang < 50% der geforderten Wortanzahl oder Thema verfehlt), ist die Punktzahl für diese Aufgabe insgesamt 0 Punkte.")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.orange)
                        .padding(8)
                        .background(Color.orange.opacity(0.10))
                        .cornerRadius(8)
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(UIColor.secondarySystemGroupedBackground))
        )
    }
    
    private func officialSampleRowCard(_ sample: OfficialGoetheSample) -> some View {
        let accent: Color = sample.level == .b1
            ? Color(red: 0.08, green: 0.58, blue: 0.42)
            : Color(red: 0.14, green: 0.44, blue: 0.94)
        
        return Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            selectedOfficialSample = sample
        }) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Text(sample.teil.fullTitle)
                        .font(.system(size: 10.5, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(accent))
                    
                    Text("Max. \(sample.maxOfficialPoints) Pkt.")
                        .font(.system(size: 10.5, weight: .bold, design: .rounded))
                        .foregroundColor(accent)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(accent.opacity(0.12))
                        .cornerRadius(6)
                    
                    Spacer()
                    
                    Text("\(sample.candidateWordCount) Wörter")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                }
                
                Text(sample.title)
                    .font(.system(size: 16, weight: .black, design: .rounded))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.leading)
                
                Text("📄 \(sample.officialSourcePDF) • \(sample.officialPages)")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(accent)
                
                Text("✍️ \(sample.candidateLabel)")
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text(sample.authenticCandidateText)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(.secondary)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                
                HStack {
                    Text("Original-Aufgabe, Kandidatentext & Prüferblatt lesen")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(accent)
                    Spacer()
                    Image(systemName: "chevron.right.circle.fill")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(accent)
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color(UIColor.secondarySystemGroupedBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(accent.opacity(0.20), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Big Category Card for "Lernen" Tab
private struct LearnCategoryCard: View {
    let title: String
    let subtitle: String
    let badge: String
    let description: String
    let footerLeft: String
    let footerRight: String
    let tags: [String]
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            action()
        }) {
            VStack(alignment: .leading, spacing: 12) {
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
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(tags, id: \.self) { tag in
                            HStack(spacing: 4) {
                                Image(systemName: "book.fill")
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
                
                Divider().opacity(0.6)
                
                HStack {
                    Text(footerLeft)
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(footerRight)
                        .font(.system(size: 11.5, weight: .bold, design: .rounded))
                        .foregroundColor(color)
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.system(size: 17, weight: .bold))
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

// MARK: - Full Reader Sheet for Official Goethe-Institut Leistungsbeispiel
private struct OfficialGoetheSampleDetailSheet: View {
    let sample: OfficialGoetheSample
    @Environment(\.dismiss) private var dismiss
    
    private var accentColor: Color {
        sample.level == .b1
            ? Color(red: 0.08, green: 0.58, blue: 0.42)
            : Color(red: 0.14, green: 0.44, blue: 0.94)
    }
    
    var body: some View {
        NavigationView {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    // 1. Official Source Header Card
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(sample.teil.fullTitle)
                                .font(.system(size: 11, weight: .heavy, design: .rounded))
                                .foregroundColor(.white)
                                .padding(.horizontal, 9)
                                .padding(.vertical, 4)
                                .background(Capsule().fill(accentColor))
                            
                            Spacer()
                            
                            Text("Offiziell: Max. \(sample.maxOfficialPoints) Pkt.")
                                .font(.system(size: 11, weight: .black, design: .rounded))
                                .foregroundColor(accentColor)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(accentColor.opacity(0.12))
                                .cornerRadius(6)
                        }
                        
                        Text(sample.title)
                            .font(.system(size: 19, weight: .black, design: .rounded))
                            .foregroundColor(.primary)
                        
                        Label(sample.officialSourcePDF, systemImage: "checkmark.seal.fill")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(accentColor)
                        
                        Text("Fundstelle: \(sample.officialPages) • Arbeitszeit: \(sample.workingTimeMinutes) Min. • Richtwert: ca. \(sample.targetWords) Wörter")
                            .font(.system(size: 11.5, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color(UIColor.secondarySystemGroupedBackground))
                    )
                    
                    // 2. Original Kandidatenblatt (Prompt & Leitpunkte)
                    VStack(alignment: .leading, spacing: 10) {
                        Label("Original-Aufgabenstellung (Kandidatenblatt)", systemImage: "doc.text.fill")
                            .font(.system(size: 15, weight: .black, design: .rounded))
                            .foregroundColor(.primary)
                        
                        Text(sample.officialPromptText)
                            .font(.system(size: 13, weight: .regular))
                            .foregroundColor(.primary)
                            .lineSpacing(3)
                        
                        if let quote = sample.impulseQuote {
                            Text(quote)
                                .font(.system(size: 12.5, weight: .medium))
                                .foregroundColor(.primary)
                                .lineSpacing(3)
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(Color(UIColor.tertiarySystemGroupedBackground))
                                )
                        }
                        
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Geforderte Inhaltspunkte (Leitpunkte):")
                                .font(.system(size: 11.5, weight: .bold))
                                .foregroundColor(.secondary)
                            
                            ForEach(Array(sample.officialLeitpunkte.enumerated()), id: \.offset) { idx, point in
                                HStack(alignment: .top, spacing: 8) {
                                    Text("\(idx + 1).")
                                        .font(.system(size: 12.5, weight: .black, design: .rounded))
                                        .foregroundColor(accentColor)
                                    Text(point)
                                        .font(.system(size: 12.5, weight: .semibold))
                                        .foregroundColor(.primary)
                                }
                            }
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(accentColor.opacity(0.08))
                        )
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color(UIColor.secondarySystemGroupedBackground))
                    )
                    
                    // 3. Verbatim Authentic Candidate Writing (Leistungsbeispiel aus den Prüferblättern)
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Label("Echter Kandidatentext (Unkorrigiert)", systemImage: "person.text.rectangle.fill")
                                    .font(.system(size: 15, weight: .black, design: .rounded))
                                    .foregroundColor(.primary)
                                Text("\(sample.candidateLabel) • \(sample.candidateWordCount) Wörter")
                                    .font(.system(size: 11.5, weight: .semibold))
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Button(action: {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                AudioSpeaker.shared.speak(text: sample.authenticCandidateText)
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "speaker.wave.2.fill")
                                        .font(.system(size: 11, weight: .bold))
                                    Text("Vorlesen")
                                        .font(.system(size: 11.5, weight: .bold, design: .rounded))
                                }
                                .foregroundColor(accentColor)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(accentColor.opacity(0.12))
                                .clipShape(Capsule())
                            }
                        }
                        
                        Text(sample.authenticCandidateText)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.primary)
                            .lineSpacing(4.5)
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(Color(UIColor.tertiarySystemGroupedBackground))
                            )
                        
                        Text("Original-Vermerk: „Bei diesen Texten handelt es sich um authentische Beispiele von Deutschlernenden auf dem Niveau. Fehler wurden im Originaltext nicht korrigiert.“")
                            .font(.system(size: 11, weight: .medium))
                            .italic()
                            .foregroundColor(.secondary)
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color(UIColor.secondarySystemGroupedBackground))
                    )
                    
                    // 3B. Human Linguist Corrected Version (Target Hypothesis from TU Dresden / MERLIN Corpus)
                    if let corrected = sample.linguistCorrectedText, !corrected.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Label("Linguistische Zielkorrektur (TU Dresden / telc)", systemImage: "checkmark.seal.fill")
                                        .font(.system(size: 15, weight: .black, design: .rounded))
                                        .foregroundColor(Color(red: 0.08, green: 0.58, blue: 0.42))
                                    Text("Vom Prüferteam sprachlich korrigierte Fassung des Kandidatentextes (Kein KI-Text)")
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                Button(action: {
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    AudioSpeaker.shared.speak(text: corrected)
                                }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "speaker.wave.2.fill")
                                            .font(.system(size: 11, weight: .bold))
                                        Text("Vorlesen")
                                            .font(.system(size: 11.5, weight: .bold, design: .rounded))
                                    }
                                    .foregroundColor(Color(red: 0.08, green: 0.58, blue: 0.42))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Color(red: 0.08, green: 0.58, blue: 0.42).opacity(0.12))
                                    .clipShape(Capsule())
                                }
                            }
                            
                            Text(corrected)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.primary)
                                .lineSpacing(4.5)
                                .padding(14)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(Color(red: 0.08, green: 0.58, blue: 0.42).opacity(0.08))
                                )
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(Color(UIColor.secondarySystemGroupedBackground))
                        )
                    }
                    
                    // 4. Official Scoring & Examiner Assessment
                    VStack(alignment: .leading, spacing: 10) {
                        Label("Offizielle Prüfer-Einordnung & Bewertung", systemImage: "person.badge.shield.checkmark.fill")
                            .font(.system(size: 15, weight: .black, design: .rounded))
                            .foregroundColor(.blue)
                        
                        Text(sample.officialScoringBreakdown)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.primary)
                            .lineSpacing(3.5)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color(UIColor.secondarySystemGroupedBackground))
                    )
                    
                    // 5. Unedited Candidate Mistakes Explained
                    if !sample.uneditedErrorsNote.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Label("Originalfehler im Kandidatentext (So machst du es richtig)", systemImage: "wand.and.stars")
                                .font(.system(size: 14, weight: .black, design: .rounded))
                                .foregroundColor(.orange)
                            
                            ForEach(sample.uneditedErrorsNote, id: \.self) { note in
                                HStack(alignment: .top, spacing: 8) {
                                    Image(systemName: "arrow.turn.down.right")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(.orange)
                                        .padding(.top, 2)
                                    Text(note)
                                        .font(.system(size: 12.5, weight: .medium))
                                        .foregroundColor(.primary)
                                }
                                .padding(10)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(Color(UIColor.tertiarySystemGroupedBackground))
                                )
                            }
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(Color(UIColor.secondarySystemGroupedBackground))
                        )
                    }
                }
                .padding(16)
            }
            .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Goethe-Leistungsbeispiel")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Fertig") {
                        AudioSpeaker.shared.stop()
                        dismiss()
                    }
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                }
            }
        }
    }
}

// MARK: - Grammar Topic Row Card (Rule Reference Only)
private struct GrammarTopicRowCard: View {
    let topic: GrammarTopic
    let onTapSpickzettel: () -> Void
    
    var body: some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            onTapSpickzettel()
        }) {
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
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.secondary.opacity(0.6))
                        .padding(.leading, 2)
                }
                
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
            .contentShape(Rectangle())
        }
        .buttonStyle(ScaleButtonStyle(scaleAmount: 0.98))
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
