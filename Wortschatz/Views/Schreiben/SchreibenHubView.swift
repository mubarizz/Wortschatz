import SwiftUI
import UIKit

public enum SchreibenHubTab: String, CaseIterable, Identifiable {
    case tasks = "Aufgaben"
    case weaknesses = "Schwachstellen"
    case history = "Verlauf"
    
    public var id: String { rawValue }
}

public struct SchreibenHubView: View {
    @ObservedObject public var schreibenStore: SchreibenStore
    @ObservedObject public var vocabStore: VocabularyStore
    
    @State private var selectedHubTab: SchreibenHubTab = .tasks
    @State private var selectedLevel: SchreibenExamLevel = .b1
    @State private var selectedTeil: SchreibenExamTeil = .b1Teil1
    
    @State private var activeExamTask: SchreibenTask? = nil
    @State private var selectedReviewSubmission: SchreibenSubmission? = nil
    
    @State private var isGeneratingTask: Bool = false
    @State private var evaluatingSubmissionId: UUID? = nil
    @State private var errorMessage: String? = nil
    
    public init(
        schreibenStore: SchreibenStore,
        vocabStore: VocabularyStore = VocabularyStore()
    ) {
        self.schreibenStore = schreibenStore
        self.vocabStore = vocabStore
    }
    
    private var levelColor: Color {
        selectedLevel == .b1
            ? Color(red: 0.08, green: 0.58, blue: 0.42)
            : Color(red: 0.14, green: 0.44, blue: 0.94)
    }
    
    public var body: some View {
        VStack(spacing: 14) {
            // Header
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text("Goethe-Schreiben Prüfer")
                        .font(.system(size: 20, weight: .black, design: .rounded))
                        .foregroundColor(.primary)
                    Spacer()
                    Text("Gemini 3 Flash")
                        .font(.system(size: 10, weight: .heavy, design: .rounded))
                        .foregroundColor(.blue)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.12))
                        .clipShape(Capsule())
                }
                Text("Offizielle Goethe-Kriterien (B1 & B2) • KI-Aufgabengenerator & Schwachstellen-Analyse")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
            
            // Top Mode Picker (Aufgaben / Schwachstellen / Verlauf)
            Picker("Bereich", selection: $selectedHubTab) {
                ForEach(SchreibenHubTab.allCases) { tab in
                    if tab == .history && !schreibenStore.pendingOfflineSubmissions.isEmpty {
                        Text("Verlauf (\(schreibenStore.pendingOfflineSubmissions.count) ⏳)").tag(tab)
                    } else {
                        Text(tab.rawValue).tag(tab)
                    }
                }
            }
            .pickerStyle(.segmented)
            
            // Pending Offline Queue Quick Alert if any exist
            if !schreibenStore.pendingOfflineSubmissions.isEmpty && selectedHubTab != .history {
                pendingOfflineQuickBanner
            }
            
            if let error = errorMessage {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text(error)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.primary)
                    Spacer()
                    Button(action: { errorMessage = nil }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.orange.opacity(0.14))
                )
            }
            
            switch selectedHubTab {
            case .tasks:
                tasksTabContent
            case .weaknesses:
                weaknessesTabContent
            case .history:
                historyTabContent
            }
        }
        .fullScreenCover(item: $activeExamTask) { task in
            SchreibenExamWorkspaceView(
                task: task,
                schreibenStore: schreibenStore,
                vocabStore: vocabStore
            )
        }
        .sheet(item: $selectedReviewSubmission) { submission in
            SchreibenResultSheetView(submission: submission)
        }
    }
    
    // MARK: - Pending Offline Quick Banner
    private var pendingOfflineQuickBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "icloud.and.arrow.up.fill")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.orange)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("\(schreibenStore.pendingOfflineSubmissions.count) Offline-Prüfung(en) warten auf Auswertung")
                    .font(.system(size: 12.5, weight: .black, design: .rounded))
                    .foregroundColor(.primary)
                Text("Du kannst deine offline geschriebenen Texte jetzt mit Gemini 3 prüfen.")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button(action: {
                withAnimation {
                    selectedHubTab = .history
                }
            }) {
                Text("Jetzt prüfen")
                    .font(.system(size: 11.5, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color.orange))
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(UIColor.secondarySystemGroupedBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.orange.opacity(0.35), lineWidth: 1)
        )
    }
    
    // MARK: - TAB 1: Prüfungen & KI-Aufgabengenerator
    private var tasksTabContent: some View {
        VStack(spacing: 14) {
            // 1. Level Selector (Goethe B1 vs Goethe B2)
            HStack(spacing: 10) {
                ForEach(SchreibenExamLevel.allCases) { level in
                    let isSelected = selectedLevel == level
                    let color = level == .b1
                        ? Color(red: 0.08, green: 0.58, blue: 0.42)
                        : Color(red: 0.14, green: 0.44, blue: 0.94)
                    
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
                            selectedLevel = level
                            if selectedTeil.level != level {
                                selectedTeil = SchreibenExamTeil.teile(for: level).first ?? .b1Teil1
                            }
                        }
                    }) {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(level.rawValue)
                                    .font(.system(size: 18, weight: .black, design: .rounded))
                                    .foregroundColor(isSelected ? .white : color)
                                Spacer()
                                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(isSelected ? .white : color.opacity(0.5))
                            }
                            Text(level.title)
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundColor(isSelected ? .white : .primary)
                            Text(level == .b1 ? "Teil 1, Teil 2 & Teil 3" : "Teil 1 & Teil 2")
                                .font(.system(size: 10.5, weight: .medium))
                                .foregroundColor(isSelected ? .white.opacity(0.85) : .secondary)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(isSelected ? color : Color(UIColor.secondarySystemGroupedBackground))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .strokeBorder(color.opacity(isSelected ? 0.0 : 0.22), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            
            // 2. Teil Selector Pills
            let availableTeile = SchreibenExamTeil.teile(for: selectedLevel)
            HStack(spacing: 8) {
                ForEach(availableTeile) { teil in
                    let isSelected = selectedTeil == teil
                    let stats = schreibenStore.statistics(for: teil)
                    
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
                            selectedTeil = teil
                        }
                    }) {
                        VStack(spacing: 3) {
                            HStack(spacing: 4) {
                                Image(systemName: teil.iconName)
                                    .font(.system(size: 11, weight: .bold))
                                Text(teil.shortTitle)
                                    .font(.system(size: 13, weight: .black, design: .rounded))
                            }
                            Text("~\(teil.defaultTargetWords) Wörter")
                                .font(.system(size: 10, weight: .semibold))
                                .opacity(0.85)
                            if stats.attemptCount > 0 {
                                Text("Ø \(stats.averageScore)/100")
                                    .font(.system(size: 9.5, weight: .heavy, design: .rounded))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(
                                        Capsule()
                                            .fill(isSelected ? Color.white.opacity(0.22) : levelColor.opacity(0.12))
                                    )
                            }
                        }
                        .foregroundColor(isSelected ? .white : .primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(isSelected ? levelColor : Color(UIColor.secondarySystemGroupedBackground))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(levelColor.opacity(isSelected ? 0 : 0.18), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            
            // 3. Teil Info & AI Question Generator Card
            teilHeaderAndGeneratorCard
            
            // 4. Tasks List for Selected Teil
            let currentTasks = schreibenStore.tasks(for: selectedTeil)
            ForEach(currentTasks) { task in
                taskCard(for: task)
            }
        }
    }
    
    private var teilHeaderAndGeneratorCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(selectedTeil.fullTitle)
                        .font(.system(size: 15, weight: .black, design: .rounded))
                        .foregroundColor(.primary)
                    Text(selectedTeil.categoryDescription)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(.secondary)
                        .lineSpacing(2)
                }
                Spacer()
                Text("~\(selectedTeil.defaultTimeMinutes) Min.")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(levelColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(levelColor.opacity(0.12))
                    .cornerRadius(6)
            }
            
            HStack(spacing: 8) {
                Label("\(selectedTeil.leitpunkteCount) Leitpunkte", systemImage: "list.bullet.circle.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                Text("•")
                    .foregroundColor(.secondary)
                Text(selectedTeil.defaultRegisterHint)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            // AI Task Generator Button
            Button(action: {
                triggerGenerateTask()
            }) {
                HStack(spacing: 8) {
                    if isGeneratingTask {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.85)
                        Text("Gemini 3 erstellt neue Goethe-Aufgabe...")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                    } else {
                        Image(systemName: "wand.and.stars")
                            .font(.system(size: 13, weight: .bold))
                        Text("Neue KI-Prüfungsaufgabe generieren (\(selectedTeil.shortTitle))")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                    }
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(isGeneratingTask ? Color.gray : levelColor)
                )
            }
            .disabled(isGeneratingTask)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(UIColor.secondarySystemGroupedBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(levelColor.opacity(0.22), lineWidth: 1)
        )
    }
    
    private func taskCard(for task: SchreibenTask) -> some View {
        let hasDraft = !schreibenStore.draft(for: task.id).isEmpty
        let best = schreibenStore.bestScore(for: task.id)
        let pendingCount = schreibenStore.submissions(for: task.id).filter { $0.status == .pendingOfflineEvaluation }.count
        
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 8) {
                if task.isAIGenerated {
                    HStack(spacing: 3) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 9, weight: .bold))
                        Text("KI-Aufgabe")
                            .font(.system(size: 10, weight: .heavy, design: .rounded))
                    }
                    .foregroundColor(.purple)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Color.purple.opacity(0.12))
                    .cornerRadius(6)
                } else {
                    Text("Goethe-Standard")
                        .font(.system(size: 10, weight: .heavy, design: .rounded))
                        .foregroundColor(levelColor)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(levelColor.opacity(0.12))
                        .cornerRadius(6)
                }
                
                if hasDraft {
                    Text("Entwurf gespeichert")
                        .font(.system(size: 10, weight: .heavy, design: .rounded))
                        .foregroundColor(.orange)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Color.orange.opacity(0.14))
                        .cornerRadius(6)
                }
                
                if pendingCount > 0 {
                    Text("Offline abgegeben ⏳")
                        .font(.system(size: 10, weight: .heavy, design: .rounded))
                        .foregroundColor(.orange)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Color.orange.opacity(0.14))
                        .cornerRadius(6)
                }
                
                Spacer()
                
                if let bestScore = best {
                    HStack(spacing: 3) {
                        Image(systemName: bestScore >= 60 ? "checkmark.seal.fill" : "exclamationmark.circle.fill")
                            .font(.system(size: 11, weight: .bold))
                        Text("Bestwert: \(bestScore)/100")
                            .font(.system(size: 11, weight: .black, design: .rounded))
                    }
                    .foregroundColor(bestScore >= 60 ? .green : .red)
                }
            }
            
            Text(task.title)
                .font(.system(size: 16, weight: .black, design: .rounded))
                .foregroundColor(.primary)
            
            Text(task.situation)
                .font(.system(size: 12.5, weight: .regular))
                .foregroundColor(.secondary)
                .lineSpacing(2.5)
            
            // Leitpunkte preview
            VStack(alignment: .leading, spacing: 5) {
                ForEach(Array(task.leitpunkte.enumerated()), id: \.offset) { idx, point in
                    HStack(alignment: .top, spacing: 6) {
                        Text("\(idx + 1).")
                            .font(.system(size: 11.5, weight: .black, design: .rounded))
                            .foregroundColor(levelColor)
                        Text(point)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.primary)
                    }
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(UIColor.tertiarySystemGroupedBackground))
            )
            
            HStack {
                Text("Ziel: ~\(task.targetWords) Wörter • \(task.recommendedTimeMinutes) Min.")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button(action: {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    activeExamTask = task
                }) {
                    HStack(spacing: 5) {
                        Text(hasDraft ? "Entwurf fortsetzen" : (best != nil ? "Nochmal schreiben" : "Prüfung starten"))
                            .font(.system(size: 12.5, weight: .bold, design: .rounded))
                        Image(systemName: "pencil.line")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(levelColor))
                }
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
    }
    
    // MARK: - TAB 2: Schwachstellen-Analyse & Statistik
    private var weaknessesTabContent: some View {
        VStack(spacing: 14) {
            // 1. Overall KPI Summary
            HStack(spacing: 10) {
                statMetricTile(
                    title: "Ø Punktzahl",
                    value: schreibenStore.evaluatedSubmissions.isEmpty ? "—" : "\(schreibenStore.overallAverageScore)/100",
                    subtitle: "Bestehen: ≥ 60",
                    color: schreibenStore.overallAverageScore >= 60 ? .green : .blue
                )
                statMetricTile(
                    title: "Bestanden",
                    value: schreibenStore.evaluatedSubmissions.isEmpty ? "—" : "\(schreibenStore.overallPassRatePercentage)%",
                    subtitle: "\(schreibenStore.evaluatedSubmissions.count) Prüfungen",
                    color: .purple
                )
                statMetricTile(
                    title: "Bestwert",
                    value: schreibenStore.evaluatedSubmissions.isEmpty ? "—" : "\(schreibenStore.overallBestScore)/100",
                    subtitle: "Top-Ergebnis",
                    color: .orange
                )
            }
            
            // 2. Weakest Teil Spotlight Card
            if let weakest = schreibenStore.weakestTeil {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Label("Deine größte Schwachstelle (Prüfungsteil)", systemImage: "exclamationmark.triangle.fill")
                            .font(.system(size: 13, weight: .black, design: .rounded))
                            .foregroundColor(.red)
                        Spacer()
                        Text("Ø \(weakest.averageScore) / 100 Pkt.")
                            .font(.system(size: 12, weight: .black, design: .rounded))
                            .foregroundColor(.red)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.red.opacity(0.12))
                            .cornerRadius(6)
                    }
                    
                    Text(weakest.teil.fullTitle)
                        .font(.system(size: 16, weight: .black, design: .rounded))
                        .foregroundColor(.primary)
                    
                    Text("Du hast diesen Teil \(weakest.attemptCount)× absolviert (Bestehensquote: \(weakest.passRatePercentage)%). Trainiere gezielt eine Aufgabe aus diesem Teil, um deinen Schnitt zu heben.")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(.secondary)
                    
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        selectedLevel = weakest.teil.level
                        selectedTeil = weakest.teil
                        selectedHubTab = .tasks
                    }) {
                        HStack {
                            Image(systemName: "flame.fill")
                                .font(.system(size: 12, weight: .bold))
                            Text("\(weakest.teil.fullTitle) jetzt gezielt trainieren")
                                .font(.system(size: 12.5, weight: .bold, design: .rounded))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Capsule().fill(Color.red))
                    }
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color(UIColor.secondarySystemGroupedBackground))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(Color.red.opacity(0.28), lineWidth: 1.2)
                )
            }
            
            // 3. Weakest Goethe Criterion Card (0-25 Pkt. Rubric Breakdown)
            if !schreibenStore.criterionWeaknesses.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Goethe-Kriterien Durchschnitt (je 0–25 Pkt.)")
                        .font(.system(size: 15, weight: .black, design: .rounded))
                        .foregroundColor(.primary)
                    
                    ForEach(schreibenStore.criterionWeaknesses) { item in
                        let isWeakest = schreibenStore.weakestCriterion?.id == item.id
                        VStack(alignment: .leading, spacing: 5) {
                            HStack {
                                Text(item.title)
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .foregroundColor(.primary)
                                if isWeakest {
                                    Text("SCHWACHPUNKT")
                                        .font(.system(size: 9, weight: .heavy, design: .rounded))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Capsule().fill(Color.orange))
                                }
                                Spacer()
                                Text(String(format: "Ø %.1f / 25", item.averageOutOf25))
                                    .font(.system(size: 12.5, weight: .black, design: .rounded))
                                    .foregroundColor(isWeakest ? .orange : .blue)
                            }
                            
                            GeometryReader { geo in
                                let fraction = min(1.0, max(0.0, item.averageOutOf25 / 25.0))
                                ZStack(alignment: .leading) {
                                    Capsule()
                                        .fill(Color(UIColor.tertiarySystemFill))
                                        .frame(height: 6)
                                    Capsule()
                                        .fill(isWeakest ? Color.orange : Color.blue)
                                        .frame(width: max(6, geo.size.width * fraction), height: 6)
                                }
                            }
                            .frame(height: 6)
                            
                            if isWeakest {
                                Text("💡 Prüfer-Tipp: \(item.advice)")
                                    .font(.system(size: 11.5, weight: .medium))
                                    .foregroundColor(.secondary)
                                    .padding(.top, 2)
                            }
                        }
                    }
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color(UIColor.secondarySystemGroupedBackground))
                )
            }
            
            // 4. Per-Teil Breakdown (B1 Teil 1-3 & B2 Teil 1-2)
            VStack(alignment: .leading, spacing: 10) {
                Text("Leistung nach Prüfungsteil (B1 & B2)")
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundColor(.primary)
                    .padding(.horizontal, 4)
                
                ForEach(schreibenStore.allTeilStatistics) { stat in
                    teilStatCard(stat: stat)
                }
            }
        }
    }
    
    private func statMetricTile(title: String, value: String, subtitle: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.secondary)
            Text(value)
                .font(.system(size: 20, weight: .black, design: .rounded))
                .foregroundColor(color)
            Text(subtitle)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(UIColor.secondarySystemGroupedBackground))
        )
    }
    
    private func teilStatCard(stat: SchreibenTeilStatistics) -> some View {
        let isWeakest = schreibenStore.weakestTeil?.teil == stat.teil && stat.attemptCount > 0
        let accent: Color = stat.teil.level == .b1
            ? Color(red: 0.08, green: 0.58, blue: 0.42)
            : Color(red: 0.14, green: 0.44, blue: 0.94)
        
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: stat.teil.iconName)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(accent)
                    Text(stat.teil.fullTitle)
                        .font(.system(size: 14, weight: .black, design: .rounded))
                        .foregroundColor(.primary)
                }
                Spacer()
                if stat.attemptCount > 0 {
                    Text("Ø \(stat.averageScore)/100")
                        .font(.system(size: 13, weight: .black, design: .rounded))
                        .foregroundColor(stat.averageScore >= 60 ? .green : .red)
                } else {
                    Text("Noch nicht geprüft")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                }
            }
            
            if stat.attemptCount > 0 {
                HStack(spacing: 12) {
                    Text("\(stat.attemptCount) Versuche")
                    Text("•")
                    Text("Bestwert: \(stat.bestScore)/100")
                    Text("•")
                    Text("Bestanden: \(stat.passRatePercentage)%")
                }
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)
                
                HStack(spacing: 6) {
                    miniCriterionPill(label: "Inhalt", val: stat.avgErfuellung)
                    miniCriterionPill(label: "Kohärenz", val: stat.avgKohaerenz)
                    miniCriterionPill(label: "Wortschatz", val: stat.avgWortschatz)
                    miniCriterionPill(label: "Grammatik", val: stat.avgStrukturen)
                }
            } else {
                Text(stat.teil.categoryDescription)
                    .font(.system(size: 11.5, weight: .regular))
                    .foregroundColor(.secondary)
            }
            
            HStack {
                if isWeakest {
                    Label("Niedrigster Durchschnitt", systemImage: "arrow.down.right.circle.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.red)
                }
                Spacer()
                Button(action: {
                    selectedLevel = stat.teil.level
                    selectedTeil = stat.teil
                    selectedHubTab = .tasks
                }) {
                    Text("Aufgaben öffnen →")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(accent)
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(UIColor.secondarySystemGroupedBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(isWeakest ? Color.red.opacity(0.3) : Color.primary.opacity(0.06), lineWidth: 1)
        )
    }
    
    private func miniCriterionPill(label: String, val: Double) -> some View {
        VStack(spacing: 1) {
            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(.secondary)
            Text(String(format: "%.0f/25", val))
                .font(.system(size: 10.5, weight: .black, design: .rounded))
                .foregroundColor(val >= 15 ? .primary : .orange)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(UIColor.tertiarySystemGroupedBackground))
        )
    }
    
    // MARK: - TAB 3: Verlauf & Offline-Warteschlange
    private var historyTabContent: some View {
        VStack(spacing: 14) {
            // 1. Offline Queue Section
            if !schreibenStore.pendingOfflineSubmissions.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Label("Offline-Warteschlange (\(schreibenStore.pendingOfflineSubmissions.count))", systemImage: "icloud.and.arrow.up.fill")
                            .font(.system(size: 15, weight: .black, design: .rounded))
                            .foregroundColor(.orange)
                        Spacer()
                    }
                    
                    ForEach(schreibenStore.pendingOfflineSubmissions) { sub in
                        pendingOfflineRow(submission: sub)
                    }
                }
            }
            
            // 2. Evaluated History Section
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("Geprüfte Ergebnisse (\(schreibenStore.evaluatedSubmissions.count))", systemImage: "clock.badge.checkmark.fill")
                        .font(.system(size: 15, weight: .black, design: .rounded))
                        .foregroundColor(.primary)
                    Spacer()
                }
                .padding(.horizontal, 4)
                
                if schreibenStore.evaluatedSubmissions.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundColor(.secondary)
                        Text("Noch keine ausgewerteten Prüfungen")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                        Text("Wähle unter 'Aufgaben' einen B1- oder B2-Prüfungsteil aus, schreibe deinen Text und lass ihn vom Goethe-KI-Prüfer bewerten.")
                            .font(.system(size: 12, weight: .regular))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(24)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color(UIColor.secondarySystemGroupedBackground))
                    )
                } else {
                    ForEach(schreibenStore.evaluatedSubmissions) { sub in
                        evaluatedHistoryRow(submission: sub)
                    }
                }
            }
        }
    }
    
    private func pendingOfflineRow(submission: SchreibenSubmission) -> some View {
        let isCurrentlyEvaluating = evaluatingSubmissionId == submission.id
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(submission.task.teil.fullTitle)
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .foregroundColor(.orange)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.orange.opacity(0.14))
                    .cornerRadius(6)
                
                Spacer()
                
                Text(submission.submittedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
            }
            
            Text(submission.task.title)
                .font(.system(size: 15, weight: .black, design: .rounded))
                .foregroundColor(.primary)
            
            Text(submission.userText)
                .font(.system(size: 12, weight: .regular))
                .foregroundColor(.secondary)
                .lineLimit(2)
            
            HStack {
                Text("\(submission.wordCount) Wörter gespeichert")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button(action: {
                    evaluateOfflineSubmission(submission)
                }) {
                    HStack(spacing: 6) {
                        if isCurrentlyEvaluating {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                            Text("Wird geprüft...")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                        } else {
                            Image(systemName: "sparkles")
                                .font(.system(size: 11, weight: .bold))
                            Text("Jetzt mit KI prüfen")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                        }
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(isCurrentlyEvaluating ? Color.gray : Color.orange))
                }
                .disabled(isCurrentlyEvaluating)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(UIColor.secondarySystemGroupedBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.orange.opacity(0.35), lineWidth: 1)
        )
    }
    
    private func evaluatedHistoryRow(submission: SchreibenSubmission) -> some View {
        let eval = submission.evaluation
        let score = eval?.totalScore ?? 0
        let passed = eval?.passed ?? false
        
        return Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            selectedReviewSubmission = submission
        }) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(submission.task.teil.fullTitle)
                        .font(.system(size: 11, weight: .heavy, design: .rounded))
                        .foregroundColor(.blue)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.blue.opacity(0.12))
                        .cornerRadius(6)
                    
                    Spacer()
                    
                    Text(submission.submittedAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                }
                
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(submission.task.title)
                            .font(.system(size: 15, weight: .black, design: .rounded))
                            .foregroundColor(.primary)
                        HStack(spacing: 6) {
                            Text("\(submission.wordCount) Wörter • ⏱ \(submission.formattedDuration) • GER: \(eval?.estimatedLevel ?? submission.task.level.rawValue)")
                                .font(.system(size: 11.5, weight: .medium))
                                .foregroundColor(.secondary)
                            
                            if let delta = submission.eloDelta {
                                Text(delta >= 0 ? "+\(Int(delta)) Elo" : "\(Int(delta)) Elo")
                                    .font(.system(size: 10.5, weight: .heavy, design: .rounded))
                                    .foregroundColor(delta >= 0 ? .green : .red)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background((delta >= 0 ? Color.green : Color.red).opacity(0.12))
                                    .cornerRadius(4)
                            }
                        }
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 3) {
                        Text("\(score) / 100")
                            .font(.system(size: 17, weight: .black, design: .rounded))
                            .foregroundColor(passed ? .green : .red)
                        Text(passed ? "Bestanden ✓" : "Nicht best. ✕")
                            .font(.system(size: 10, weight: .heavy, design: .rounded))
                            .foregroundColor(passed ? .green : .red)
                    }
                }
                
                if let eval = eval {
                    HStack(spacing: 6) {
                        miniCriterionPill(label: "Inhalt", val: Double(eval.erfuellungScore))
                        miniCriterionPill(label: "Kohärenz", val: Double(eval.kohaerenzScore))
                        miniCriterionPill(label: "Wortschatz", val: Double(eval.wortschatzScore))
                        miniCriterionPill(label: "Grammatik", val: Double(eval.strukturenScore))
                    }
                }
                
                HStack {
                    Text("Vollständigen Prüfbericht & Korrekturen öffnen")
                        .font(.system(size: 11.5, weight: .bold, design: .rounded))
                        .foregroundColor(.blue)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.blue)
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(UIColor.secondarySystemGroupedBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Async Actions
    private func triggerGenerateTask() {
        guard !isGeneratingTask else { return }
        isGeneratingTask = true
        errorMessage = nil
        
        Task {
            do {
                let newTask = try await schreibenStore.generateNewTask(for: selectedTeil)
                await MainActor.run {
                    self.isGeneratingTask = false
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    self.activeExamTask = newTask
                }
            } catch {
                await MainActor.run {
                    self.isGeneratingTask = false
                    UINotificationFeedbackGenerator().notificationOccurred(.warning)
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    private func evaluateOfflineSubmission(_ submission: SchreibenSubmission) {
        guard evaluatingSubmissionId == nil else { return }
        evaluatingSubmissionId = submission.id
        errorMessage = nil
        
        Task {
            do {
                let evaluated = try await schreibenStore.evaluatePendingSubmission(
                    submission,
                    vocabStore: vocabStore
                )
                await MainActor.run {
                    self.evaluatingSubmissionId = nil
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    self.selectedReviewSubmission = evaluated
                }
            } catch {
                await MainActor.run {
                    self.evaluatingSubmissionId = nil
                    UINotificationFeedbackGenerator().notificationOccurred(.warning)
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }
}
