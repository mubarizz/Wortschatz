import SwiftUI
import UIKit

public struct WordRowView: View {
    let word: VocabularyWord
    let onTap: () -> Void
    
    public init(word: VocabularyWord, onTap: @escaping () -> Void) {
        self.word = word
        self.onTap = onTap
    }
    
    public var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                // Category Chip / Article
                Text(word.articleOrType)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(word.category.badgeColor)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(word.category.badgeColor.opacity(0.12))
                    .cornerRadius(6)
                    .frame(minWidth: 42)
                
                // Target Word & English translation
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(word.cleanTargetWord)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        
                        if word.isB2MasteryReached {
                            Text("B2")
                                .font(.system(size: 9, weight: .heavy))
                                .foregroundColor(.white)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                                .background(Color.indigo)
                                .cornerRadius(4)
                        }
                    }
                    
                    Text(word.englishDefinition)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Spacer(minLength: 4)
                
                // Elo Pill
                EloBadge(elo: word.elo, showLabel: false, compact: true)
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Color(UIColor.tertiaryLabel))
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .frame(minHeight: 48) // Safe iOS touch target >= 44pt
    }
}
