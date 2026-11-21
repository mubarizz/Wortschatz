import SwiftUI
import UIKit

public struct SchreibenResultSheetView: View {
    public let submission: SchreibenSubmission
    @Environment(\.dismiss) private var dismiss
    @State private var showOriginalPrompt: Bool = false
    @State private var showSubmittedText: Bool = true
    
    public init(submission: SchreibenSubmission) {
        self.submission = submission
    }
    
    private var evaluation: SchreibenEvaluationResult? {
        submission.evaluation
    }
    
    private var scoreColor: Color {
        guard let eval = evaluation else { return .orange }
        if eval.totalScore >= 80 {
            return Color(red: 0.10, green: 0.68, blue: 0.36)
        } else if eval.totalScore >= 60 {
            return Color(red: 0.14, green: 0.48, blue: 0.96)
        } else {
            return Color(red: 0.88, green: 0.24, blue: 0.24)
        }
    }
    
    public var body: some View {
        NavigationView {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    if let eval = evaluation {
                        heroScoreCard(eval: eval)
                        criteriaBreakdownCard(eval: eval)
                        examinerSummaryCard(eval: eval)
                        leitpunkteCard(eval: eval)
                        correctionsSection(eval: eval)
                        modelSolutionCard(eval: eval)
                        redemittelCard(eval: eval)
                        userTextAndPromptCard
                    } else {
                        pendingOfflineCard
                        userTextAndPromptCard
                    }
                }
                .padding(16)
            }
            .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Goethe-Prüfbericht")
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
    
    // MARK: - 1. Hero Score Card
    private func heroScoreCard(eval: SchreibenEvaluationResult) -> some View {
        VStack(spacing: 14) {
            HStack(alignment: .center, spacing: 16) {
                // Circular Score Ring
                ZStack {
                    Circle()
                        .stroke(scoreColor.opacity(0.16), lineWidth: 10)
                        .frame(width: 86, height: 86)
                    
                    Circle()
                        .trim(from: 0, to: CGFloat(eval.totalScore) / 100.0)
                        .stroke(
                            scoreColor,
                            style: StrokeStyle(lineWidth: 10, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .frame(width: 86, height: 86)
                    
                    VStack(spacing: 0) {
                        Text("\(eval.totalScore)")
                            .font(.system(size: 27, weight: .black, design: .rounded))
                            .foregroundColor(scoreColor)
                        Text("/ 100 Pkt.")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Text(eval.passed ? "BESTANDEN ✓" : "NICHT BESTANDEN ✕")
                            .font(.system(size: 11, weight: .heavy, design: .rounded))
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(eval.passed ? Color.green : Color.red))
                        
                        Text("GER: \(eval.estimatedLevel)")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(scoreColor)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(scoreColor.opacity(0.12))
                            .cornerRadius(6)
                    }
                    
                    Text(submission.task.title)
                        .font(.system(size: 17, weight: .black, design: .rounded))
                        .foregroundColor(.primary)
                        .lineLimit(2)
                    
                    Text("\(submission.task.teil.fullTitle) • Note: \(eval.gradeLabel)")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)
                }
                
                Spacer(minLength: 0)
            }
            
            if let eloDelta = submission.eloDelta {
                let isPositive = eloDelta >= 0
                HStack(spacing: 8) {
                    Image(systemName: isPositive ? "arrow.up.right.circle.fill" : "arrow.down.right.circle.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(isPositive ? .green : .red)
                    
                    if let newElo = submission.newUserElo {
                        Text("Neues Rating: \(Int(newElo)) Elo (\(isPositive ? "+" : "")\(Int(eloDelta)))")
                            .font(.system(size: 13, weight: .black, design: .rounded))
                            .foregroundColor(.primary)
                    } else {
                        Text("Elo-Änderung: \(isPositive ? "+" : "")\(Int(eloDelta)) Elo")
                            .font(.system(size: 13, weight: .black, design: .rounded))
                            .foregroundColor(.primary)
                    }
                    
                    Spacer()
                    
                    if submission.timeBonusAwarded == true {
                        Text("+4 Elo Zeit-Bonus ✓")
                            .font(.system(size: 10, weight: .heavy, design: .rounded))
                            .foregroundColor(.green)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.green.opacity(0.14))
                            .clipShape(Capsule())
                    }
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill((isPositive ? Color.green : Color.red).opacity(0.10))
                )
            }
            
            Divider().opacity(0.6)
            
            HStack {
                Label("\(submission.wordCount) / ~\(submission.task.targetWords) Wörter", systemImage: "text.word.spacing")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                
                Text("•")
                    .foregroundColor(.secondary)
                
                Label("\(submission.formattedDuration) / \(submission.task.recommendedTimeMinutes):00 Min.", systemImage: "timer")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(submission.finishedWithinTimeLimit ? .secondary : .orange)
                
                Spacer()
                
                if let model = submission.evaluatedModel {
                    Label(model, systemImage: "sparkles")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(.blue)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(UIColor.secondarySystemGroupedBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(scoreColor.opacity(0.25), lineWidth: 1.2)
        )
    }
    
    // MARK: - 2. 4 Official Goethe Criteria Breakdown
    private func criteriaBreakdownCard(eval: SchreibenEvaluationResult) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Goethe-Bewertungskriterien", systemImage: "slider.horizontal.3")
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundColor(.primary)
                Spacer()
                Text("Bestehensgrenze: 60 / 100")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
            }
            
            criterionRow(
                title: "1. Erfüllung der Aufgabenstellung",
                subtitle: "Leitpunkte, Textumfang & Register (Du/Sie)",
                score: eval.erfuellungScore,
                color: .blue
            )
            
            criterionRow(
                title: "2. Kohärenz & Textaufbau",
                subtitle: "Gliederung, roter Faden & Konnektoren",
                score: eval.kohaerenzScore,
                color: .purple
            )
            
            criterionRow(
                title: "3. Wortschatz & Ausdruck",
                subtitle: "Spektrum, Präzision & Nomen-Verb-Verbindungen",
                score: eval.wortschatzScore,
                color: .orange
            )
            
            criterionRow(
                title: "4. Strukturen, Grammatik & Orthografie",
                subtitle: "Verbstellung, Kasus, Endungen & Rechtschreibung",
                score: eval.strukturenScore,
                color: .teal
            )
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(UIColor.secondarySystemGroupedBackground))
        )
    }
    
    private func criterionRow(title: String, subtitle: String, score: Int, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    Text(subtitle)
                        .font(.system(size: 11, weight: .regular))
                        .foregroundColor(.secondary)
                }
                Spacer()
                Text("\(score) / 25")
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .foregroundColor(score >= 15 ? color : .red)
            }
            
            GeometryReader { geo in
                let fraction = min(1.0, max(0.0, Double(score) / 25.0))
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color(UIColor.tertiarySystemFill))
                        .frame(height: 7)
                    Capsule()
                        .fill(score >= 15 ? color : Color.red)
                        .frame(width: max(6, geo.size.width * fraction), height: 7)
                }
            }
            .frame(height: 7)
        }
    }
    
    // MARK: - 3. Examiner Summary Card
    private func examinerSummaryCard(eval: SchreibenEvaluationResult) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Prüfer-Gutachten", systemImage: "person.badge.shield.checkmark.fill")
                .font(.system(size: 15, weight: .black, design: .rounded))
                .foregroundColor(.blue)
            
            Text(eval.examinerSummary)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.primary)
                .lineSpacing(3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(UIColor.secondarySystemGroupedBackground))
        )
    }
    
    // MARK: - 4. Leitpunkte Checklist
    private func leitpunkteCard(eval: SchreibenEvaluationResult) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Leitpunkte-Kontrolle (\(eval.leitpunkteCheck.count))", systemImage: "checklist")
                .font(.system(size: 15, weight: .black, design: .rounded))
                .foregroundColor(.primary)
            
            ForEach(eval.leitpunkteCheck) { item in
                let statusInfo = leitpunktStatusBadge(for: item.status)
                VStack(alignment: .leading, spacing: 5) {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: statusInfo.icon)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(statusInfo.color)
                            .padding(.top, 1)
                        
                        VStack(alignment: .leading, spacing: 3) {
                            HStack {
                                Text(item.leitpunkt)
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(.primary)
                                Spacer()
                                Text(statusInfo.label)
                                    .font(.system(size: 10, weight: .heavy, design: .rounded))
                                    .foregroundColor(statusInfo.color)
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 3)
                                    .background(statusInfo.color.opacity(0.12))
                                    .cornerRadius(5)
                            }
                            
                            Text(item.comment)
                                .font(.system(size: 12, weight: .regular))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(11)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
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
    
    private func leitpunktStatusBadge(for raw: String) -> (label: String, icon: String, color: Color) {
        let lower = raw.lowercased()
        if lower.contains("erfuellt") || lower.contains("erfüllt") {
            return ("Erfüllt", "checkmark.circle.fill", .green)
        } else if lower.contains("teilweise") {
            return ("Teilweise", "exclamationmark.triangle.fill", .orange)
        } else {
            return ("Fehlt", "xmark.octagon.fill", .red)
        }
    }
    
    // MARK: - 5. Sentence-by-Sentence Corrections
    private func correctionsSection(eval: SchreibenEvaluationResult) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Satz-für-Satz Fehleranalyse", systemImage: "wand.and.stars")
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundColor(.primary)
                Spacer()
                Text("\(eval.corrections.count) Hinweise")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(.secondary)
            }
            
            if eval.corrections.isEmpty {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.green)
                    Text("Hervorragend! Dein Text enthält keine gravierenden Grammatik- oder Wortschatzfehler.")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.primary)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.green.opacity(0.1))
                .cornerRadius(12)
            } else {
                ForEach(eval.corrections) { item in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(item.category.uppercased())
                                .font(.system(size: 10, weight: .heavy, design: .rounded))
                                .foregroundColor(.purple)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.purple.opacity(0.12))
                                .cornerRadius(5)
                            Spacer()
                        }
                        
                        // Original sentence
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.red)
                                .padding(.top, 2)
                            Text(item.originalSentence)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.red)
                        }
                        
                        // Corrected sentence
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.green)
                                .padding(.top, 2)
                            Text(item.correctedSentence)
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.primary)
                        }
                        
                        // Explanation
                        Text(item.explanation)
                            .font(.system(size: 12, weight: .regular))
                            .foregroundColor(.secondary)
                            .padding(.top, 2)
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color(UIColor.tertiarySystemGroupedBackground))
                    )
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(UIColor.secondarySystemGroupedBackground))
        )
    }
    
    // MARK: - 6. Improved Model Solution (Musterlösung)
    private func modelSolutionCard(eval: SchreibenEvaluationResult) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Goethe-Musterlösung (\(submission.task.level.rawValue))", systemImage: "star.bubble.fill")
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundColor(Color(red: 0.10, green: 0.62, blue: 0.38))
                
                Spacer()
                
                Button(action: {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    AudioSpeaker.shared.speak(text: eval.improvedModelText)
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "speaker.wave.2.fill")
                            .font(.system(size: 11, weight: .bold))
                        Text("Vorlesen")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                    }
                    .foregroundColor(Color(red: 0.10, green: 0.62, blue: 0.38))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color(red: 0.10, green: 0.62, blue: 0.38).opacity(0.12))
                    .clipShape(Capsule())
                }
            }
            
            Text(eval.improvedModelText)
                .font(.system(size: 13.5, weight: .medium))
                .foregroundColor(.primary)
                .lineSpacing(4)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(red: 0.10, green: 0.62, blue: 0.38).opacity(0.08))
                )
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(UIColor.secondarySystemGroupedBackground))
        )
    }
    
    // MARK: - 7. Recommended Redemittel
    private func redemittelCard(eval: SchreibenEvaluationResult) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Starke Redemittel für dieses Thema", systemImage: "quote.bubble.fill")
                .font(.system(size: 15, weight: .black, design: .rounded))
                .foregroundColor(.orange)
            
            ForEach(eval.recommendedRedemittel, id: \.self) { phrase in
                Button(action: {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    AudioSpeaker.shared.speak(text: phrase)
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "speaker.wave.2.circle.fill")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.orange)
                        Text(phrase)
                            .font(.system(size: 12.5, weight: .semibold))
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.leading)
                        Spacer()
                    }
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color(UIColor.tertiarySystemGroupedBackground))
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(UIColor.secondarySystemGroupedBackground))
        )
    }
    
    // MARK: - 8. User's Original Submitted Text & Prompt
    private var userTextAndPromptCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            DisclosureGroup(isExpanded: $showSubmittedText) {
                Text(submission.userText)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(.primary)
                    .lineSpacing(3.5)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 8)
            } label: {
                Label("Dein eingereichter Text (\(submission.wordCount) Wörter)", systemImage: "doc.plaintext.fill")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
            }
            
            Divider().opacity(0.6)
            
            DisclosureGroup(isExpanded: $showOriginalPrompt) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(submission.task.situation)
                        .font(.system(size: 12.5, weight: .regular))
                        .foregroundColor(.secondary)
                    
                    ForEach(Array(submission.task.leitpunkte.enumerated()), id: \.offset) { idx, point in
                        HStack(alignment: .top, spacing: 6) {
                            Text("\(idx + 1).")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.blue)
                            Text(point)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.primary)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 8)
            } label: {
                Label("Aufgabenstellung anzeigen", systemImage: "questionmark.folder.fill")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(UIColor.secondarySystemGroupedBackground))
        )
    }
    
    private var pendingOfflineCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Offline gespeichert • Warte auf KI-Prüfung", systemImage: "icloud.and.arrow.up.fill")
                .font(.system(size: 15, weight: .black, design: .rounded))
                .foregroundColor(.orange)
            Text("Dieser Prüfungstext wurde lokal auf deinem iPhone gespeichert. Sobald du Internet hast, kannst du ihn im Verlauf mit einem Tipp von Gemini 3 Flash auswerten lassen.")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.secondary)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(UIColor.secondarySystemGroupedBackground))
        )
    }
}
