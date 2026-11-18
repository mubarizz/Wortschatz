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
            HStack(spacing: 12) {
                // Fixed-width Category Chip so all German words align on a razor-sharp vertical axis
                Text(word.compactCategoryTag)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(word.category.badgeColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .frame(width: 54, height: 24)
                    .background(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(word.category.badgeColor.opacity(0.12))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .strokeBorder(word.category.badgeColor.opacity(0.25), lineWidth: 1)
                    )
                
                // Target Word & English translation
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(word.cleanTargetWord)
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        
                        if let cefr = word.cefrLevel, !cefr.isEmpty {
                            Text(cefr)
                                .font(.system(size: 9, weight: .heavy, design: .rounded))
                                .foregroundColor(.indigo)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1.5)
                                .background(Color.indigo.opacity(0.14))
                                .cornerRadius(4)
                        }
                        
                        if word.isB2MasteryReached {
                            Text("B2")
                                .font(.system(size: 9, weight: .heavy, design: .rounded))
                                .foregroundColor(.white)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1.5)
                                .background(Color.purple)
                                .cornerRadius(4)
                        }
                    }
                    
                    Text(word.englishDefinition)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Spacer(minLength: 4)
                
                // Learn Score Badge (0% – 100%)
                LearnScoreBadge(word: word, showLabel: false, compact: true)
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(Color(UIColor.tertiaryLabel))
            }
            .padding(.vertical, 9)
            .padding(.horizontal, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(ScaleButtonStyle(scaleAmount: 0.98))
        .frame(minHeight: 50)
    }
}
