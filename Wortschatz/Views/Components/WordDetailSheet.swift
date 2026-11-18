import SwiftUI

public struct WordDetailSheet: View {
    let word: VocabularyWord
    @Environment(\.dismiss) private var dismiss
    
    public init(word: VocabularyWord) {
        self.word = word
    }
    
    public var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    
                    // Header Card
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .center) {
                            Text(word.articleOrType)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(word.category.badgeColor)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(word.category.badgeColor.opacity(0.15))
                                .cornerRadius(8)
                            
                            Spacer()
                            
                            EloBadge(elo: word.elo, showLabel: true)
                        }
                        
                        Text(word.cleanTargetWord)
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                        
                        Text(word.englishDefinition)
                            .font(.system(size: 15, weight: .regular))
                            .foregroundColor(.secondary)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(12)
                    
                    // German Definition Card
                    VStack(alignment: .leading, spacing: 6) {
                        Label("Deutsche Definition", systemImage: "character.book.closed.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.indigo)
                        
                        Text(word.germanDefinition)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.primary)
                            .lineSpacing(3)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.indigo.opacity(0.08))
                    .cornerRadius(12)
                    
                    // Examples Section (B1 & B2)
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Kontext-Beispiele")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.primary)
                        
                        // B1 Example Box
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("B1 Basis")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.blue)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.blue.opacity(0.12))
                                    .cornerRadius(4)
                                
                                if !word.isB2MasteryReached {
                                    Text("Aktiver Cloze-Modus")
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundColor(.secondary)
                                }
                            }
                            Text(word.b1Example)
                                .font(.system(size: 13, weight: .regular))
                                .foregroundColor(.primary)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(10)
                        
                        // B2 Example Box
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("B2 Fortgeschritten")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.purple)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.purple.opacity(0.12))
                                    .cornerRadius(4)
                                
                                if word.isB2MasteryReached {
                                    Text("Freigeschaltet ✓")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(.green)
                                } else {
                                    Text("Gesperrt (ab 2x Folgeerfolg)")
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundColor(.secondary)
                                }
                            }
                            Text(word.b2Example)
                                .font(.system(size: 13, weight: .regular))
                                .foregroundColor(.primary)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(10)
                    }
                    
                    // Mastery & Review Stats
                    HStack(spacing: 12) {
                        StatTile(title: "Wiederholungen", value: "\(word.reviewsCount)")
                        StatTile(title: "Erfolgsquote", value: "\(Int(word.correctRate * 100))%")
                        StatTile(title: "Folgeerfolge", value: "\(word.consecutiveCorrect)")
                    }
                }
                .padding(14)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") {
                        dismiss()
                    }
                    .font(.system(size: 15, weight: .semibold))
                }
            }
        }
    }
}

private struct StatTile: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(10)
    }
}
