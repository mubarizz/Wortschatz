import SwiftUI
import UIKit

public struct SchreibenExamWorkspaceView: View {
    public let task: SchreibenTask
    @ObservedObject public var schreibenStore: SchreibenStore
    @ObservedObject public var vocabStore: VocabularyStore
    public var onCompleteEvaluation: ((SchreibenSubmission) -> Void)?
    
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isEditorFocused: Bool
    
    @State private var userText: String = ""
    @State private var checkedLeitpunkte: Set<Int> = []
    @State private var isPromptExpanded: Bool = true
    @State private var showRedemittelHelper: Bool = false
    @State private var showVocabularySheet: Bool = false
    
    @State private var elapsedSeconds: Int = 0
    @State private var isTimerPaused: Bool = false
    @State private var showCountdownMode: Bool = true
    @State private var isEvaluating: Bool = false
    @State private var errorMessage: String? = nil
    @State private var showOfflineSavedBanner: Bool = false
    @State private var completedSubmission: SchreibenSubmission? = nil
    
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    public init(
        task: SchreibenTask,
        schreibenStore: SchreibenStore,
        vocabStore: VocabularyStore = VocabularyStore(),
        onCompleteEvaluation: ((SchreibenSubmission) -> Void)? = nil
    ) {
        self.task = task
        self.schreibenStore = schreibenStore
        self.vocabStore = vocabStore
        self.onCompleteEvaluation = onCompleteEvaluation
    }
    
    private var wordCount: Int {
        userText.trimmingCharacters(in: .whitespacesAndNewlines)
            .split { $0.isWhitespace || $0.isNewline }
            .count
    }
    
    private var wordCountColor: Color {
        let ratio = Double(wordCount) / Double(max(1, task.targetWords))
        if ratio >= 0.85 {
            return .green
        } else if ratio >= 0.50 {
            return .orange
        } else {
            return .secondary
        }
    }
    
    private var totalTargetSeconds: Int {
        max(60, task.recommendedTimeMinutes * 60)
    }
    
    private var remainingSeconds: Int {
        totalTargetSeconds - elapsedSeconds
    }
    
    private var isOverTime: Bool {
        remainingSeconds < 0
    }
    
    private var timerColor: Color {
        if isTimerPaused {
            return .secondary
        } else if isOverTime {
            return .red
        } else if Double(remainingSeconds) / Double(totalTargetSeconds) <= 0.25 {
            return .orange
        } else {
            return levelColor
        }
    }
    
    private var formattedTimer: String {
        if showCountdownMode {
            if remainingSeconds >= 0 {
                let mins = remainingSeconds / 60
                let secs = remainingSeconds % 60
                return String(format: "%02d:%02d übrig", mins, secs)
            } else {
                let over = abs(remainingSeconds)
                let mins = over / 60
                let secs = over % 60
                return String(format: "+%02d:%02d überzogen", mins, secs)
            }
        } else {
            let mins = elapsedSeconds / 60
            let secs = elapsedSeconds % 60
            return String(format: "%02d:%02d / %d:00", mins, secs, task.recommendedTimeMinutes)
        }
    }
    
    private var levelColor: Color {
        task.level == .b1
            ? Color(red: 0.08, green: 0.58, blue: 0.42)
            : Color(red: 0.14, green: 0.44, blue: 0.94)
    }
    
    public var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 12) {
                        examTimerCard
                        promptCard
                        redemittelHelperSection
                        editorCard
                        
                        if let error = errorMessage {
                            errorBanner(message: error)
                        }
                        
                        if showOfflineSavedBanner {
                            offlineSavedSuccessBanner
                        }
                    }
                    .padding(14)
                }
                
                umlautAndSubmitFooter
            }
            .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle(task.teil.fullTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        schreibenStore.updateDraft(userText, durationSeconds: elapsedSeconds, for: task.id)
                        dismiss()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "xmark")
                                .font(.system(size: 13, weight: .bold))
                            Text("Entwurf")
                                .font(.system(size: 13, weight: .semibold))
                        }
                    }
                    .disabled(isEvaluating)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        showCountdownMode.toggle()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: isTimerPaused ? "pause.circle.fill" : "timer")
                                .font(.system(size: 11, weight: .bold))
                            Text(formattedTimer)
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                        }
                        .foregroundColor(timerColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(timerColor.opacity(0.12))
                        .clipShape(Capsule())
                    }
                }
            }
            .onAppear {
                let existingDraft = schreibenStore.draft(for: task.id)
                if !existingDraft.isEmpty && userText.isEmpty {
                    userText = existingDraft
                }
                let savedDuration = schreibenStore.draftDuration(for: task.id)
                if savedDuration > 0 && elapsedSeconds == 0 {
                    elapsedSeconds = savedDuration
                }
            }
            .onChange(of: userText) { newValue in
                schreibenStore.updateDraft(newValue, durationSeconds: elapsedSeconds, for: task.id)
            }
            .onReceive(timer) { _ in
                if !isEvaluating && !isTimerPaused && completedSubmission == nil {
                    elapsedSeconds += 1
                }
            }
            .sheet(item: $completedSubmission, onDismiss: {
                dismiss()
            }) { submission in
                SchreibenResultSheetView(submission: submission)
            }
            .sheet(isPresented: $showVocabularySheet) {
                SchreibenVocabularyLookupSheet(
                    vocabStore: vocabStore,
                    onInsertWord: { inserted in
                        insertTextSnippet(inserted)
                    }
                )
            }
        }
    }
    
    // MARK: - 0. Interactive Goethe Exam Timer Card
    private var examTimerCard: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                // Tap to toggle Countdown vs Stopwatch
                Button(action: {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    showCountdownMode.toggle()
                }) {
                    HStack(spacing: 8) {
                        ZStack {
                            Circle()
                                .fill(timerColor.opacity(0.14))
                                .frame(width: 34, height: 34)
                            Image(systemName: isTimerPaused ? "pause.fill" : (showCountdownMode ? "hourglass" : "stopwatch.fill"))
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(timerColor)
                        }
                        
                        VStack(alignment: .leading, spacing: 1) {
                            HStack(spacing: 5) {
                                Text(formattedTimer)
                                    .font(.system(size: 16, weight: .black, design: .monospaced))
                                    .foregroundColor(timerColor)
                                
                                if !isOverTime {
                                    Text("+4 Elo Zeit-Bonus")
                                        .font(.system(size: 9.5, weight: .heavy, design: .rounded))
                                        .foregroundColor(.green)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.green.opacity(0.12))
                                        .cornerRadius(4)
                                }
                            }
                            Text(showCountdownMode ? "Goethe-Richtzeit: \(task.recommendedTimeMinutes) Min. (Tippen für Stoppuhr)" : "Stoppuhr-Modus (Tippen für Countdown)")
                                .font(.system(size: 10.5, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                // Pause / Resume Button
                Button(action: {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    isTimerPaused.toggle()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: isTimerPaused ? "play.fill" : "pause.fill")
                            .font(.system(size: 10, weight: .bold))
                        Text(isTimerPaused ? "Weiter" : "Pause")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                    }
                    .foregroundColor(isTimerPaused ? .white : .primary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(isTimerPaused ? levelColor : Color(UIColor.tertiarySystemGroupedBackground))
                    )
                }
                .buttonStyle(.plain)
                
                // Reset Timer Button
                Button(action: {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    elapsedSeconds = 0
                    schreibenStore.updateDraft(userText, durationSeconds: 0, for: task.id)
                }) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.secondary)
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(Color(UIColor.tertiarySystemGroupedBackground)))
                }
                .buttonStyle(.plain)
            }
            
            // Visual Time Progress Bar
            GeometryReader { geo in
                let fraction: Double = showCountdownMode
                    ? max(0.0, min(1.0, Double(max(0, remainingSeconds)) / Double(totalTargetSeconds)))
                    : max(0.0, min(1.0, Double(elapsedSeconds) / Double(totalTargetSeconds)))
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color(UIColor.tertiarySystemFill))
                        .frame(height: 5)
                    Capsule()
                        .fill(timerColor)
                        .frame(width: max(6, geo.size.width * fraction), height: 5)
                }
            }
            .frame(height: 5)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(UIColor.secondarySystemGroupedBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(timerColor.opacity(0.22), lineWidth: 1)
        )
    }
    
    // MARK: - 1. Goethe Prompt & Checkable Leitpunkte Card
    private var promptCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button(action: {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
                    isPromptExpanded.toggle()
                }
            }) {
                HStack {
                    HStack(spacing: 6) {
                        Text(task.level.rawValue)
                            .font(.system(size: 11, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(levelColor))
                        
                        Text(task.title)
                            .font(.system(size: 15, weight: .black, design: .rounded))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 4) {
                        Text("\(checkedLeitpunkte.count)/\(task.leitpunkte.count) Punkte")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(checkedLeitpunkte.count == task.leitpunkte.count ? .green : .secondary)
                        Image(systemName: isPromptExpanded ? "chevron.up.circle.fill" : "chevron.down.circle.fill")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(levelColor)
                    }
                }
            }
            .buttonStyle(.plain)
            
            if isPromptExpanded {
                Divider().opacity(0.6)
                
                Text(task.situation)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(.primary)
                    .lineSpacing(3)
                
                // Register Hint Pill
                HStack(spacing: 6) {
                    Image(systemName: "person.2.wave.2.fill")
                        .font(.system(size: 11, weight: .bold))
                    Text(task.registerHint)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                }
                .foregroundColor(levelColor)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(levelColor.opacity(0.11))
                .cornerRadius(8)
                
                // Interactive Checkable Leitpunkte
                VStack(alignment: .leading, spacing: 6) {
                    Text("Leitpunkte (Tippe zum Abhaken während du schreibst):")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.secondary)
                    
                    ForEach(Array(task.leitpunkte.enumerated()), id: \.offset) { idx, point in
                        let isChecked = checkedLeitpunkte.contains(idx)
                        Button(action: {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            if isChecked {
                                checkedLeitpunkte.remove(idx)
                            } else {
                                checkedLeitpunkte.insert(idx)
                            }
                        }) {
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: isChecked ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundColor(isChecked ? .green : levelColor)
                                    .padding(.top, 1)
                                
                                Text(point)
                                    .font(.system(size: 12.5, weight: .semibold))
                                    .foregroundColor(isChecked ? .secondary : .primary)
                                    .strikethrough(isChecked, color: .secondary)
                                    .multilineTextAlignment(.leading)
                                
                                Spacer(minLength: 0)
                            }
                            .padding(8)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(isChecked ? Color.green.opacity(0.08) : Color(UIColor.tertiarySystemGroupedBackground))
                            )
                        }
                        .buttonStyle(.plain)
                    }
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
                .strokeBorder(levelColor.opacity(0.22), lineWidth: 1)
        )
    }
    
    // MARK: - 2. Optional Redemittel & Wortschatz Helpers
    private var redemittelHelperSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                // Button 1: Wortschatz Quick-Lookup Drawer
                Button(action: {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    showVocabularySheet = true
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "books.vertical.fill")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.blue)
                        Text("Wortschatz (\(vocabStore.words.count))")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                        Spacer(minLength: 0)
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.blue)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color(UIColor.secondarySystemGroupedBackground))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(Color.blue.opacity(0.22), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                
                // Button 2: Redemittel Helper Toggle
                Button(action: {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
                        showRedemittelHelper.toggle()
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "lightbulb.fill")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.orange)
                        Text("Redemittel (\(task.teil.shortTitle))")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                        Spacer(minLength: 0)
                        Image(systemName: showRedemittelHelper ? "chevron.up" : "chevron.down")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.orange)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color(UIColor.secondarySystemGroupedBackground))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(Color.orange.opacity(0.22), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
            
            if showRedemittelHelper {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(redemittelSuggestions(for: task.teil), id: \.self) { phrase in
                            Button(action: {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                insertTextSnippet(phrase)
                            }) {
                                Text(phrase)
                                    .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                                    .foregroundColor(.primary)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(
                                        Capsule()
                                            .fill(Color.orange.opacity(0.14))
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 2)
                }
            }
        }
    }
    
    private func redemittelSuggestions(for teil: SchreibenExamTeil) -> [String] {
        switch teil {
        case .b1Teil1:
            return [
                "Liebe/r ..., ",
                "Wie geht es dir? ",
                "Ich schreibe dir, weil ",
                "Hast du am Wochenende Zeit? ",
                "Bis bald und liebe Grüße"
            ]
        case .b1Teil2:
            return [
                "Meiner Meinung nach ",
                "Ich finde dieses Thema sehr wichtig, weil ",
                "Einerseits ..., andererseits ",
                "Aus meiner eigenen Erfahrung kann ich sagen, dass ",
                "Deshalb bin ich der Ansicht, dass "
            ]
        case .b1Teil3:
            return [
                "Sehr geehrte/r Frau/Herr ..., ",
                "leider muss ich Ihnen mitteilen, dass ",
                "Ich bitte Sie vielmals um Entschuldigung. ",
                "Könnten wir bitte einen neuen Termin vereinbaren? ",
                "Mit freundlichen Grüßen"
            ]
        case .b2Teil1:
            return [
                "In der heutigen Gesellschaft wird häufig darüber diskutiert, ob ",
                "Ich vertrete den Standpunkt, dass ",
                "Auf der einen Seite ..., auf der anderen Seite ",
                "Ein entscheidender Vorteil besteht darin, dass ",
                "Zusammenfassend lässt sich festhalten, dass "
            ]
        case .b2Teil2:
            return [
                "Sehr geehrte/r Frau/Herr ..., ",
                "ich wende mich an Sie, da ",
                "Ich wäre Ihnen sehr dankbar, wenn Sie ",
                "Für Ihr Verständnis bedanke ich mich im Voraus. ",
                "Mit freundlichen Grüßen"
            ]
        }
    }
    
    // MARK: - 3. Writing Editor Card
    private var editorCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Dein Prüfungstext", systemImage: "pencil.and.outline")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                
                Spacer()
                
                // Live Word Counter Pill
                HStack(spacing: 4) {
                    Image(systemName: wordCount >= Int(Double(task.targetWords) * 0.85) ? "checkmark.circle.fill" : "text.word.spacing")
                        .font(.system(size: 11, weight: .bold))
                    Text("\(wordCount) / ~\(task.targetWords) Wörter")
                        .font(.system(size: 11.5, weight: .black, design: .rounded))
                }
                .foregroundColor(wordCountColor)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(wordCountColor.opacity(0.12))
                .clipShape(Capsule())
                
                if isEditorFocused {
                    Button("Tastatur ↓") {
                        isEditorFocused = false
                    }
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(.blue)
                }
            }
            
            ZStack(alignment: .topLeading) {
                if userText.isEmpty {
                    Text("Beginne hier mit deinem Text (\(task.registerHint))...\n\nDein Entwurf wird automatisch offline gespeichert.")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(.secondary.opacity(0.65))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 12)
                        .allowsHitTesting(false)
                }
                
                TextEditor(text: $userText)
                    .focused($isEditorFocused)
                    .font(.system(size: 15, weight: .regular))
                    .frame(minHeight: 220)
                    .padding(4)
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
            }
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(UIColor.tertiarySystemGroupedBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(isEditorFocused ? levelColor : Color.primary.opacity(0.08), lineWidth: isEditorFocused ? 1.5 : 1)
            )
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(UIColor.secondarySystemGroupedBackground))
        )
    }
    
    // MARK: - 4. Error & Offline Fallback Banners
    private func errorBanner(message: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "wifi.exclamationmark")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.orange)
                VStack(alignment: .leading, spacing: 3) {
                    Text("KI-Prüfung aktuell nicht erreichbar")
                        .font(.system(size: 13, weight: .black, design: .rounded))
                        .foregroundColor(.primary)
                    Text(message)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(.secondary)
                }
            }
            
            Button(action: {
                saveForOfflineGrading()
            }) {
                HStack {
                    Image(systemName: "tray.and.arrow.down.fill")
                        .font(.system(size: 13, weight: .bold))
                    Text("Jetzt offline speichern & später mit Internet prüfen")
                        .font(.system(size: 12.5, weight: .bold, design: .rounded))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Capsule().fill(Color.orange))
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
    
    private var offlineSavedSuccessBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.icloud.fill")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.green)
            VStack(alignment: .leading, spacing: 2) {
                Text("Offline gespeichert!")
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .foregroundColor(.primary)
                Text("Du findest deinen Text unter 'Verlauf & Offline-Warteschlange' und kannst ihn prüfen, sobald du Internet hast.")
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundColor(.secondary)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.green.opacity(0.12))
        )
    }
    
    // MARK: - 5. Footer: German Umlaut Bar + Submit / Offline Save Buttons
    private var umlautAndSubmitFooter: some View {
        VStack(spacing: 8) {
            // Quick German special characters bar + quick Wortschatz drawer button
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        showVocabularySheet = true
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "books.vertical.fill")
                                .font(.system(size: 11, weight: .bold))
                            Text("Wortschatz")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                        }
                        .foregroundColor(.blue)
                        .padding(.horizontal, 10)
                        .frame(height: 32)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color.blue.opacity(0.14))
                        )
                    }
                    
                    ForEach(["ä", "ö", "ü", "ß", "Ä", "Ö", "Ü", "„", "“"], id: \.self) { char in
                        Button(action: {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            userText.append(char)
                        }) {
                            Text(char)
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundColor(.primary)
                                .frame(width: 36, height: 32)
                                .background(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(Color(UIColor.tertiarySystemGroupedBackground))
                                )
                        }
                    }
                }
                .padding(.horizontal, 14)
            }
            
            HStack(spacing: 10) {
                // Offline Save Button (Save now, check with Gemini when online)
                Button(action: {
                    saveForOfflineGrading()
                }) {
                    HStack(spacing: 5) {
                        Image(systemName: "tray.and.arrow.down.fill")
                            .font(.system(size: 12, weight: .bold))
                        Text("Später prüfen")
                            .font(.system(size: 12.5, weight: .bold, design: .rounded))
                    }
                    .foregroundColor(.orange)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 13)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.orange.opacity(0.14))
                    )
                }
                .disabled(isEvaluating || wordCount < 3)
                
                // Primary Gemini 3 Flash Goethe Examiner Submit Button
                Button(action: {
                    triggerEvaluation()
                }) {
                    HStack(spacing: 8) {
                        if isEvaluating {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.85)
                            Text("Goethe-Prüfer wertet aus...")
                                .font(.system(size: 14, weight: .black, design: .rounded))
                        } else {
                            Image(systemName: "sparkles")
                                .font(.system(size: 14, weight: .bold))
                            Text("Abgeben & mit KI prüfen")
                                .font(.system(size: 14, weight: .black, design: .rounded))
                        }
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(wordCount < 3 || isEvaluating ? Color.gray : levelColor)
                    )
                }
                .disabled(wordCount < 3 || isEvaluating)
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 10)
        }
        .padding(.top, 8)
        .background(
            Color(UIColor.secondarySystemGroupedBackground)
                .shadow(color: Color.black.opacity(0.06), radius: 8, y: -2)
        )
    }
    
    // MARK: - Actions
    private func insertTextSnippet(_ snippet: String) {
        if userText.isEmpty || userText.hasSuffix(" ") || userText.hasSuffix("\n") {
            userText.append(snippet)
        } else {
            userText.append(" " + snippet)
        }
    }
    
    private func saveForOfflineGrading() {
        guard wordCount >= 3 else { return }
        isEditorFocused = false
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        let saved = schreibenStore.saveOfflineSubmission(
            task: task,
            userText: userText,
            durationSeconds: elapsedSeconds
        )
        onCompleteEvaluation?(saved)
        dismiss()
    }
    
    private func triggerEvaluation() {
        guard wordCount >= 3, !isEvaluating else { return }
        isEditorFocused = false
        isEvaluating = true
        errorMessage = nil
        
        Task {
            do {
                let submission = try await schreibenStore.submitAndEvaluate(
                    task: task,
                    userText: userText,
                    durationSeconds: elapsedSeconds,
                    vocabStore: vocabStore
                )
                await MainActor.run {
                    self.isEvaluating = false
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    self.onCompleteEvaluation?(submission)
                    self.completedSubmission = submission
                }
            } catch {
                await MainActor.run {
                    self.isEvaluating = false
                    UINotificationFeedbackGenerator().notificationOccurred(.warning)
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }
}

// MARK: - In-Exam Wortschatz Quick-Lookup & Insert Sheet
private enum SchreibenVocabFilter: String, CaseIterable, Identifiable {
    case all = "Alle"
    case inTraining = "Im Training"
    case unlearned = "Zu lernen"
    case learned = "Gelernt ✓"
    case b2 = "B2-Aktiv"
    case nouns = "Nomen"
    case verbs = "Verben"
    case adjectives = "Adjektive"
    
    var id: String { rawValue }
}

private struct SchreibenVocabularyLookupSheet: View {
    @ObservedObject var vocabStore: VocabularyStore
    let onInsertWord: (String) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var searchText: String = ""
    @State private var selectedFilter: SchreibenVocabFilter = .all
    @State private var expandedWordIds: Set<UUID> = []
    @State private var insertedToastText: String? = nil
    
    // Optional Gemini Live Lookup when a searched word is not in local Wortschatz
    @State private var isSearchingGemini: Bool = false
    @State private var geminiCandidates: [GeminiWordCandidate] = []
    @State private var geminiError: String? = nil
    @State private var savedCandidateIds: Set<UUID> = []
    
    private var trimmedQuery: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private var filteredWords: [VocabularyWord] {
        var list = vocabStore.words
        
        // 1. Category / Mastery Filter
        switch selectedFilter {
        case .all:
            break
        case .inTraining:
            list = list.filter { !$0.isLearned && ($0.learnScore > 0 || $0.reviewsCount > 0) }
        case .unlearned:
            list = list.filter { !$0.isLearned }
        case .learned:
            list = list.filter { $0.isLearned }
        case .b2:
            list = list.filter { $0.isB2MasteryReached }
        case .nouns:
            list = list.filter { $0.partOfSpeech == .noun }
        case .verbs:
            list = list.filter { $0.partOfSpeech == .verb }
        case .adjectives:
            list = list.filter { $0.partOfSpeech == .adjective }
        }
        
        // 2. Search Query (German word, English definition, or German definition)
        let q = trimmedQuery
        if !q.isEmpty {
            list = list.filter { word in
                word.word.localizedStandardContains(q)
                || word.displayTitle.localizedStandardContains(q)
                || word.cleanTargetWord.localizedStandardContains(q)
                || word.englishDefinition.localizedStandardContains(q)
                || word.germanDefinition.localizedStandardContains(q)
            }
        }
        
        return list
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search Bar + Filter Chips Header
                VStack(spacing: 10) {
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.secondary)
                        
                        TextField("Deutsch oder Englisch suchen...", text: $searchText)
                            .font(.system(size: 14, weight: .medium))
                            .autocorrectionDisabled(true)
                            .onChange(of: searchText) { _ in
                                geminiCandidates = []
                                geminiError = nil
                            }
                        
                        if !searchText.isEmpty {
                            Button(action: {
                                searchText = ""
                                geminiCandidates = []
                                geminiError = nil
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color(UIColor.tertiarySystemGroupedBackground))
                    )
                    
                    // Filter Chips
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(SchreibenVocabFilter.allCases) { filter in
                                let isSelected = selectedFilter == filter
                                Button(action: {
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    selectedFilter = filter
                                }) {
                                    Text(filter.rawValue)
                                        .font(.system(size: 11.5, weight: .bold, design: .rounded))
                                        .foregroundColor(isSelected ? .white : .primary)
                                        .padding(.horizontal, 11)
                                        .padding(.vertical, 6)
                                        .background(
                                            Capsule()
                                                .fill(isSelected ? Color.blue : Color(UIColor.tertiarySystemGroupedBackground))
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    
                    if let toast = insertedToastText {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("„\(toast)“ in deinen Prüfungstext eingefügt!")
                                .font(.system(size: 11.5, weight: .bold, design: .rounded))
                                .foregroundColor(.green)
                            Spacer()
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color.green.opacity(0.12))
                        )
                    }
                }
                .padding(12)
                .background(Color(UIColor.secondarySystemGroupedBackground))
                
                Divider().opacity(0.6)
                
                // Results List
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 10) {
                        // Optional Gemini 3 Live Dictionary Search Button when searching
                        if !trimmedQuery.isEmpty && (filteredWords.isEmpty || geminiCandidates.isEmpty) {
                            geminiSearchCard
                        }
                        
                        // Gemini Results if searched
                        if !geminiCandidates.isEmpty {
                            ForEach(geminiCandidates) { candidate in
                                geminiCandidateCard(candidate)
                            }
                        }
                        
                        // Local Wortschatz Words
                        ForEach(filteredWords) { word in
                            localWordCard(word)
                        }
                    }
                    .padding(12)
                }
            }
            .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Wortschatz-Spickzettel (\(filteredWords.count))")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Schließen") {
                        AudioSpeaker.shared.stop()
                        dismiss()
                    }
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                }
            }
        }
    }
    
    // MARK: - Local Vocabulary Word Card
    private func localWordCard(_ word: VocabularyWord) -> some View {
        let isExpanded = expandedWordIds.contains(word.id)
        let badgeColor = word.category.badgeColor
        
        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 8) {
                // Article / POS Badge
                Text(word.compactCategoryTag)
                    .font(.system(size: 10.5, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(badgeColor))
                
                // Word Title
                Text(word.cleanTargetWord)
                    .font(.system(size: 16, weight: .black, design: .rounded))
                    .foregroundColor(.primary)
                
                // Mastery Tag
                Text(word.masteryLabel)
                    .font(.system(size: 9.5, weight: .bold, design: .rounded))
                    .foregroundColor(word.learnScoreColor)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(word.learnScoreColor.opacity(0.12))
                    .cornerRadius(5)
                
                Spacer()
                
                // Audio button
                Button(action: {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    AudioSpeaker.shared.speak(text: word.displayTitle)
                }) {
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.blue)
                        .padding(6)
                        .background(Circle().fill(Color.blue.opacity(0.12)))
                }
                .buttonStyle(.plain)
                
                // Insert into Essay Button
                Button(action: {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    onInsertWord(word.cleanTargetWord)
                    withAnimation {
                        insertedToastText = word.cleanTargetWord
                    }
                }) {
                    HStack(spacing: 3) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 11, weight: .bold))
                        Text("Einfügen")
                            .font(.system(size: 11.5, weight: .bold, design: .rounded))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color.blue))
                }
                .buttonStyle(.plain)
            }
            
            // English & German Definitions
            HStack(alignment: .top, spacing: 6) {
                Text("🇬🇧 \(word.englishDefinition)")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.primary)
                Spacer()
                Button(action: {
                    withAnimation(.spring(response: 0.26, dampingFraction: 0.85)) {
                        if isExpanded {
                            expandedWordIds.remove(word.id)
                        } else {
                            expandedWordIds.insert(word.id)
                        }
                    }
                }) {
                    Text(isExpanded ? "Beispiele ▲" : "Beispiele ▼")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(.blue)
                }
                .buttonStyle(.plain)
            }
            
            Text(word.germanDefinition)
                .font(.system(size: 11.5, weight: .regular))
                .foregroundColor(.secondary)
                .lineLimit(isExpanded ? nil : 2)
            
            if isExpanded {
                VStack(alignment: .leading, spacing: 6) {
                    if !word.b1Example.isEmpty {
                        HStack(alignment: .top, spacing: 6) {
                            Text("B1")
                                .font(.system(size: 9.5, weight: .heavy, design: .rounded))
                                .foregroundColor(.green)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(Color.green.opacity(0.12))
                                .cornerRadius(4)
                            Text(word.b1Example)
                                .font(.system(size: 11.5, weight: .medium))
                                .foregroundColor(.primary)
                        }
                    }
                    if !word.b2Example.isEmpty {
                        HStack(alignment: .top, spacing: 6) {
                            Text("B2")
                                .font(.system(size: 9.5, weight: .heavy, design: .rounded))
                                .foregroundColor(.blue)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(Color.blue.opacity(0.12))
                                .cornerRadius(4)
                            Text(word.b2Example)
                                .font(.system(size: 11.5, weight: .medium))
                                .foregroundColor(.primary)
                        }
                    }
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color(UIColor.tertiarySystemGroupedBackground))
                )
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(UIColor.secondarySystemGroupedBackground))
        )
    }
    
    // MARK: - Live Gemini 3 Lookup Inside Sheet
    private var geminiSearchCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: {
                triggerGeminiLookup()
            }) {
                HStack(spacing: 8) {
                    if isSearchingGemini {
                        ProgressView()
                            .scaleEffect(0.85)
                        Text("Gemini 3 sucht nach „\(trimmedQuery)“...")
                            .font(.system(size: 12.5, weight: .bold, design: .rounded))
                    } else {
                        Image(systemName: "sparkles")
                            .font(.system(size: 13, weight: .bold))
                        Text("„\(trimmedQuery)“ mit Gemini 3 suchen & nachschlagen")
                            .font(.system(size: 12.5, weight: .bold, design: .rounded))
                    }
                    Spacer()
                }
                .foregroundColor(.purple)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.purple.opacity(0.12))
                )
            }
            .buttonStyle(.plain)
            .disabled(isSearchingGemini)
            
            if let error = geminiError {
                Text(error)
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundColor(.red)
                    .padding(.horizontal, 4)
            }
        }
    }
    
    private func geminiCandidateCard(_ candidate: GeminiWordCandidate) -> some View {
        let isSaved = savedCandidateIds.contains(candidate.id)
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(candidate.articleOrType)
                    .font(.system(size: 10, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Color.purple))
                
                Text(candidate.word)
                    .font(.system(size: 16, weight: .black, design: .rounded))
                    .foregroundColor(.primary)
                
                Text(candidate.cefrLevel)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(.purple)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.purple.opacity(0.12))
                    .cornerRadius(4)
                
                Spacer()
                
                Button(action: {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    if !isSaved {
                        _ = vocabStore.addWord(candidate.toVocabularyWord())
                        savedCandidateIds.insert(candidate.id)
                    }
                    onInsertWord(candidate.word)
                    withAnimation {
                        insertedToastText = candidate.word
                    }
                }) {
                    HStack(spacing: 3) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 11, weight: .bold))
                        Text(isSaved ? "Eingefügt ✓" : "Speichern & Einfügen")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color.purple))
                }
                .buttonStyle(.plain)
            }
            
            Text("🇬🇧 \(candidate.englishDefinition) • 🇩🇪 \(candidate.germanDefinition)")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)
            
            Text("B2: \(candidate.b2Example)")
                .font(.system(size: 11.5, weight: .regular))
                .foregroundColor(.primary)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(UIColor.secondarySystemGroupedBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.purple.opacity(0.28), lineWidth: 1)
        )
    }
    
    private func triggerGeminiLookup() {
        let q = trimmedQuery
        guard !q.isEmpty, !isSearchingGemini else { return }
        isSearchingGemini = true
        geminiError = nil
        
        Task {
            do {
                let results = try await GeminiService.shared.searchWords(query: q)
                await MainActor.run {
                    self.isSearchingGemini = false
                    self.geminiCandidates = results
                }
            } catch {
                await MainActor.run {
                    self.isSearchingGemini = false
                    self.geminiError = error.localizedDescription
                }
            }
        }
    }
}
