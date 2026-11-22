import SwiftUI
import UIKit

public struct DashboardView: View {
    @ObservedObject var store: VocabularyStore
    let onStartCloze: () -> Void
    let onStartReverseQuiz: () -> Void
    let onStartFlashcards: () -> Void
    var onStartDictation: (() -> Void)? = nil
    var onStartPrepositionSprint: (() -> Void)? = nil
    var onStartQuickLookup: ((String) -> Void)? = nil
    
    @State private var selectedWordForDetail: VocabularyWord?
    
    public init(
        store: VocabularyStore,
        onStartCloze: @escaping () -> Void,
        onStartReverseQuiz: @escaping () -> Void,
        onStartFlashcards: @escaping () -> Void,
        onStartDictation: (() -> Void)? = nil,
        onStartPrepositionSprint: (() -> Void)? = nil,
        onStartQuickLookup: ((String) -> Void)? = nil
    ) {
        self.store = store
        self.onStartCloze = onStartCloze
        self.onStartReverseQuiz = onStartReverseQuiz
        self.onStartFlashcards = onStartFlashcards
        self.onStartDictation = onStartDictation
        self.onStartPrepositionSprint = onStartPrepositionSprint
        self.onStartQuickLookup = onStartQuickLookup
    }
    
    public var body: some View {
        NavigationView {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    
                    // MARK: - 1. Hero Elo & Mastery Banner
                    VStack(spacing: 12) {
                        HStack(alignment: .center) {
                            VStack(alignment: .leading, spacing: 3) {
                                HStack(spacing: 5) {
                                    Image(systemName: "crown.fill")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(store.userRankColor)
                                    Text(store.userRankTitle.uppercased())
                                        .font(.system(size: 11, weight: .heavy, design: .rounded))
                                        .tracking(0.6)
                                        .foregroundColor(store.userRankColor)
                                }
                                
                                HStack(alignment: .firstTextBaseline, spacing: 5) {
                                    Text("\(Int(round(store.userElo)))")
                                        .font(.system(size: 34, weight: .black, design: .rounded))
                                        .monospacedDigit()
                                        .foregroundColor(.primary)
                                    
                                    Text("Elo")
                                        .font(.system(size: 14, weight: .bold, design: .rounded))
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            Spacer()
                            
                            // Daily Streak & Reviews Pill
                            HStack(spacing: 12) {
                                VStack(spacing: 2) {
                                    HStack(spacing: 3) {
                                        Image(systemName: "flame.fill")
                                            .foregroundColor(.orange)
                                            .font(.system(size: 13, weight: .bold))
                                        Text("\(store.dailyStreak)")
                                            .font(.system(size: 15, weight: .heavy, design: .rounded))
                                            .monospacedDigit()
                                    }
                                    Text("Tage")
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundColor(.secondary)
                                }
                                
                                Divider()
                                    .frame(height: 26)
                                
                                VStack(spacing: 2) {
                                    Text("\(store.totalReviews)")
                                        .font(.system(size: 15, weight: .heavy, design: .rounded))
                                        .monospacedDigit()
                                    Text("Reviews")
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color(UIColor.secondarySystemGroupedBackground))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
                            )
                        }
                        
                        // Progress bar towards B2 Elo Goal (Target 5.000)
                        VStack(alignment: .leading, spacing: 5) {
                            HStack {
                                Text("Weg zum B2 Niveau (Ziel: 5.000 Elo)")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(.secondary)
                                Spacer()
                                let percent = min(100, max(0, Int((store.userElo - 1000.0) / (5000.0 - 1000.0) * 100.0)))
                                Text("\(percent)%")
                                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                                    .monospacedDigit()
                                    .foregroundColor(.primary)
                            }
                            
                            GeometryReader { geo in
                                let progress = min(1.0, max(0.03, (store.userElo - 1000.0) / 4000.0))
                                ZStack(alignment: .leading) {
                                    Capsule()
                                        .fill(Color.primary.opacity(0.08))
                                        .frame(height: 7)
                                    Capsule()
                                        .fill(
                                            LinearGradient(
                                                colors: [Color(red: 0.18, green: 0.48, blue: 0.98), Color(red: 0.56, green: 0.26, blue: 0.96)],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                        .frame(width: geo.size.width * progress, height: 7)
                                        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: progress)
                                }
                            }
                            .frame(height: 7)
                        }
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.indigo.opacity(0.10),
                                        Color.blue.opacity(0.04),
                                        Color(UIColor.secondarySystemGroupedBackground)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(Color.indigo.opacity(0.18), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.04), radius: 10, y: 4)
                    
                    // MARK: - 1B. Podcast & Text Schnell-Nachschlagen Bar
                    if let onStartQuickLookup = onStartQuickLookup {
                        HStack(spacing: 10) {
                            Button(action: {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                onStartQuickLookup("")
                            }) {
                                HStack(spacing: 8) {
                                    ZStack {
                                        Circle()
                                            .fill(Color.indigo.opacity(0.14))
                                            .frame(width: 34, height: 34)
                                        Image(systemName: "text.magnifyingglass")
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundColor(.indigo)
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text("Podcast & Text Lookup")
                                            .font(.system(size: 13, weight: .bold, design: .rounded))
                                            .foregroundColor(.primary)
                                        Text("Auch über iOS „Teilen ➔ Wortschatz“ in Podcasts")
                                            .font(.system(size: 10, weight: .medium))
                                            .foregroundColor(.secondary)
                                            .lineLimit(1)
                                    }
                                    
                                    Spacer(minLength: 4)
                                }
                                .padding(.horizontal, 11)
                                .padding(.vertical, 9)
                                .background(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(Color(UIColor.secondarySystemGroupedBackground))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .strokeBorder(Color.indigo.opacity(0.22), lineWidth: 1)
                                )
                            }
                            .buttonStyle(ScaleButtonStyle(scaleAmount: 0.98))
                            
                            Button(action: {
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                let pasted = UIPasteboard.general.string ?? ""
                                onStartQuickLookup(pasted)
                            }) {
                                HStack(spacing: 5) {
                                    Image(systemName: "doc.on.clipboard.fill")
                                        .font(.system(size: 12, weight: .bold))
                                    Text("Paste")
                                        .font(.system(size: 12, weight: .bold, design: .rounded))
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 12)
                                .frame(height: 52)
                                .background(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(Color.indigo)
                                )
                            }
                            .buttonStyle(ScaleButtonStyle(scaleAmount: 0.96))
                        }
                    }
                    
                    // MARK: - 2. Quick Game Mode Launchers
                    VStack(spacing: 9) {
                        if let onStartPrepositionSprint = onStartPrepositionSprint {
                            DashboardModeRow(
                                title: "Präpositionen-Sprint",
                                badge: "B1–C1 Neu",
                                subtitle: "Verben mit festen Präpositionen & Kasus trainieren",
                                icon: "bolt.horizontal.fill",
                                color: Color.orange,
                                action: onStartPrepositionSprint
                            )
                        }
                        
                        DashboardModeRow(
                            title: "Karteikarten",
                            badge: "Audio & 3D",
                            subtitle: "Neue Wörter mit Aussprache verinnerlichen",
                            icon: "rectangle.stack.fill",
                            color: Color(red: 0.94, green: 0.50, blue: 0.10),
                            action: onStartFlashcards
                        )
                        
                        DashboardModeRow(
                            title: "Lückentext-Arena",
                            badge: "B1 ➔ B2",
                            subtitle: "Progressive Kontext-Lücken aktiv schreiben",
                            icon: "character.cursor.ibeam",
                            color: Color(red: 0.14, green: 0.46, blue: 0.96),
                            action: onStartCloze
                        )
                        
                        DashboardModeRow(
                            title: "Rückwärts-Quiz",
                            badge: "100% Deutsch",
                            subtitle: "Wort anhand deutscher Definition ableiten",
                            icon: "arrow.triangle.turn.up.right.diamond.fill",
                            color: Color(red: 0.55, green: 0.27, blue: 0.93),
                            action: onStartReverseQuiz
                        )
                        
                        if let onStartDictation = onStartDictation {
                            DashboardModeRow(
                                title: "Hör-Diktat",
                                badge: "Normal & 0.7x",
                                subtitle: "Wort & Beispielsatz anhören und buchstabieren",
                                icon: "headphones",
                                color: Color(red: 0.06, green: 0.62, blue: 0.66),
                                action: onStartDictation
                            )
                        }
                    }
                    
                    // MARK: - 3. Spaced Repetition SRS Summary Chips
                    HStack(spacing: 9) {
                        MetricCard(
                            title: "Wortschatz",
                            value: "\(store.words.count)",
                            systemImage: "books.vertical.fill",
                            accentColor: Color(red: 0.14, green: 0.46, blue: 0.96)
                        )
                        MetricCard(
                            title: "Zu lernen (<75%)",
                            value: "\(store.unlearnedWords.count)",
                            systemImage: "flame.circle.fill",
                            accentColor: Color(red: 0.94, green: 0.50, blue: 0.10)
                        )
                        MetricCard(
                            title: "Gelernt (≥75%)",
                            value: "\(store.learnedWords.count)",
                            systemImage: "checkmark.seal.fill",
                            accentColor: Color(red: 0.10, green: 0.66, blue: 0.44)
                        )
                    }
                    
                    // MARK: - 4. "Im Fokus" (Highest Urgency Words)
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .firstTextBaseline) {
                            Text("Heute im Fokus")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundColor(.primary)
                            Spacer()
                            Text("Niedrigster Lern-Score zuerst")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 2)
                        
                        let topQueue = Array(store.spacedRepetitionQueue.prefix(4))
                        VStack(spacing: 0) {
                            ForEach(topQueue) { word in
                                WordRowView(word: word) {
                                    selectedWordForDetail = word
                                }
                                if word.id != topQueue.last?.id {
                                    Divider()
                                        .padding(.leading, 78)
                                }
                            }
                        }
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color(UIColor.secondarySystemGroupedBackground))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
                        )
                        .shadow(color: Color.black.opacity(0.03), radius: 8, y: 3)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
            }
            .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Wortschatz Arena")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(item: $selectedWordForDetail) { word in
                WordDetailSheet(word: word, store: store)
            }
        }
    }
}

private struct DashboardModeRow: View {
    let title: String
    let badge: String
    let subtitle: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        }) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(color.opacity(0.14))
                        .frame(width: 44, height: 44)
                    Image(systemName: icon)
                        .font(.system(size: 19, weight: .bold))
                        .foregroundColor(color)
                }
                
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(title)
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                        
                        Text(badge)
                            .font(.system(size: 9, weight: .heavy, design: .rounded))
                            .foregroundColor(color)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(color.opacity(0.13))
                            .cornerRadius(5)
                    }
                    Text(subtitle)
                        .font(.system(size: 11, weight: .regular))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Spacer(minLength: 4)
                
                Image(systemName: "chevron.right.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(color.opacity(0.85))
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
            .shadow(color: Color.black.opacity(0.03), radius: 6, y: 2)
        }
        .buttonStyle(ScaleButtonStyle(scaleAmount: 0.97))
    }
}

private struct MetricCard: View {
    let title: String
    let value: String
    let systemImage: String
    let accentColor: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Image(systemName: systemImage)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(accentColor)
                Spacer()
            }
            Text(value)
                .font(.system(size: 19, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .foregroundColor(.primary)
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(11)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(UIColor.secondarySystemGroupedBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.025), radius: 5, y: 2)
    }
}
