import SwiftUI

public struct DashboardView: View {
    @ObservedObject var store: VocabularyStore
    let onStartCloze: () -> Void
    let onStartReverseQuiz: () -> Void
    
    @State private var selectedWordForDetail: VocabularyWord?
    
    public init(
        store: VocabularyStore,
        onStartCloze: @escaping () -> Void,
        onStartReverseQuiz: @escaping () -> Void
    ) {
        self.store = store
        self.onStartCloze = onStartCloze
        self.onStartReverseQuiz = onStartReverseQuiz
    }
    
    public var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 12) {
                    
                    // MARK: - 1. User Elo & Tier Banner (Compact for iPhone 13 mini)
                    VStack(spacing: 8) {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(store.userRankTitle)
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(store.userRankColor)
                                
                                HStack(alignment: .firstTextBaseline, spacing: 4) {
                                    Text("\(Int(round(store.userElo)))")
                                        .font(.system(size: 32, weight: .black, design: .rounded))
                                        .foregroundColor(.primary)
                                    
                                    Text("Elo")
                                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            Spacer()
                            
                            // Daily Streak & Reviews Pill
                            HStack(spacing: 10) {
                                VStack(spacing: 1) {
                                    HStack(spacing: 3) {
                                        Image(systemName: "flame.fill")
                                            .foregroundColor(.orange)
                                            .font(.system(size: 13))
                                        Text("\(store.dailyStreak)")
                                            .font(.system(size: 14, weight: .bold, design: .rounded))
                                    }
                                    Text("Tage")
                                        .font(.system(size: 9, weight: .medium))
                                        .foregroundColor(.secondary)
                                }
                                
                                Divider()
                                    .frame(height: 24)
                                
                                VStack(spacing: 1) {
                                    Text("\(store.totalReviews)")
                                        .font(.system(size: 14, weight: .bold, design: .rounded))
                                    Text("Reviews")
                                        .font(.system(size: 9, weight: .medium))
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color(UIColor.tertiarySystemBackground))
                            .cornerRadius(10)
                        }
                        
                        // Progress bar towards B2 Elo Goal (Target 1500)
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Weg zum B2 Niveau (Ziel: 1500 Elo)")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundColor(.secondary)
                                Spacer()
                                let percent = min(100, max(0, Int((store.userElo - 1000.0) / (1500.0 - 1000.0) * 100.0)))
                                Text("\(percent)%")
                                    .font(.system(size: 10, weight: .bold, design: .rounded))
                                    .foregroundColor(.primary)
                            }
                            
                            GeometryReader { geo in
                                let progress = min(1.0, max(0.0, (store.userElo - 1000.0) / 500.0))
                                ZStack(alignment: .leading) {
                                    Capsule()
                                        .fill(Color(UIColor.tertiarySystemFill))
                                        .frame(height: 6)
                                    Capsule()
                                        .fill(
                                            LinearGradient(
                                                colors: [.blue, .purple],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                        .frame(width: geo.size.width * progress, height: 6)
                                }
                            }
                            .frame(height: 6)
                        }
                    }
                    .padding(14)
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(14)
                    
                    // MARK: - 2. Quick Game Mode Launchers (Touch target >= 44pt)
                    VStack(spacing: 8) {
                        // Cloze Mode Launcher Button
                        Button(action: onStartCloze) {
                            HStack(spacing: 12) {
                                ZStack {
                                    Circle()
                                        .fill(Color.blue.opacity(0.15))
                                        .frame(width: 44, height: 44)
                                    Image(systemName: "character.cursor.ibeam")
                                        .font(.system(size: 20, weight: .bold))
                                        .foregroundColor(.blue)
                                }
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack {
                                        Text("Lückentext-Arena")
                                            .font(.system(size: 15, weight: .bold))
                                            .foregroundColor(.primary)
                                        
                                        Text("B1 ➔ B2")
                                            .font(.system(size: 9, weight: .heavy))
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 5)
                                            .padding(.vertical, 2)
                                            .background(Color.blue)
                                            .cornerRadius(4)
                                    }
                                    Text("Progressive Kontext-Lücken mit B1/B2 Sätzen")
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                }
                                
                                Spacer()
                                
                                Image(systemName: "arrow.right.circle.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(.blue)
                            }
                            .padding(12)
                            .background(Color(UIColor.secondarySystemBackground))
                            .cornerRadius(12)
                        }
                        .buttonStyle(.plain)
                        
                        // Reverse-Engineering Quiz Launcher Button
                        Button(action: onStartReverseQuiz) {
                            HStack(spacing: 12) {
                                ZStack {
                                    Circle()
                                        .fill(Color.purple.opacity(0.15))
                                        .frame(width: 44, height: 44)
                                    Image(systemName: "arrow.triangle.turn.up.right.diamond.fill")
                                        .font(.system(size: 20, weight: .bold))
                                        .foregroundColor(.purple)
                                }
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack {
                                        Text("Rückwärts-Quiz")
                                            .font(.system(size: 15, weight: .bold))
                                            .foregroundColor(.primary)
                                        
                                        Text("100% Deutsch")
                                            .font(.system(size: 9, weight: .heavy))
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 5)
                                            .padding(.vertical, 2)
                                            .background(Color.purple)
                                            .cornerRadius(4)
                                    }
                                    Text("Wort anhand deutscher Definition deduzieren")
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                }
                                
                                Spacer()
                                
                                Image(systemName: "arrow.right.circle.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(.purple)
                            }
                            .padding(12)
                            .background(Color(UIColor.secondarySystemBackground))
                            .cornerRadius(12)
                        }
                        .buttonStyle(.plain)
                    }
                    
                    // MARK: - 3. Spaced Repetition SRS Summary Chips
                    HStack(spacing: 8) {
                        MetricCard(
                            title: "Gesamtwortschatz",
                            value: "\(store.words.count)",
                            systemImage: "book.fill",
                            accentColor: .blue
                        )
                        MetricCard(
                            title: "B2 Freigeschaltet",
                            value: "\(store.b2UnlockedWords.count)",
                            systemImage: "checkmark.seal.fill",
                            accentColor: .indigo
                        )
                        MetricCard(
                            title: "SRS Warteschlange",
                            value: "\(min(store.words.count, 10))",
                            systemImage: "clock.arrow.2.circlepath",
                            accentColor: .orange
                        )
                    }
                    
                    // MARK: - 4. "Im Fokus" (Highest Urgency Words)
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Heute im Fokus (SRS Queue)")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.primary)
                            Spacer()
                            Text("Höchste Priorität")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        
                        let topQueue = Array(store.spacedRepetitionQueue.prefix(4))
                        VStack(spacing: 1) {
                            ForEach(topQueue) { word in
                                WordRowView(word: word) {
                                    selectedWordForDetail = word
                                }
                                if word.id != topQueue.last?.id {
                                    Divider()
                                        .padding(.leading, 56)
                                }
                            }
                        }
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(12)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
            }
            .navigationTitle("Wortschatz Arena")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(item: $selectedWordForDetail) { word in
                WordDetailSheet(word: word)
            }
        }
    }
}

private struct MetricCard: View {
    let title: String
    let value: String
    let systemImage: String
    let accentColor: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(accentColor)
            Text(value)
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
            Text(title)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(10)
    }
}
