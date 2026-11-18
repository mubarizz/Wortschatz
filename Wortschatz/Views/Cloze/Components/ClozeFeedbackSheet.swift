import SwiftUI
import UIKit

public struct ClozeFeedbackSheet: View {
    let word: VocabularyWord
    let isCorrect: Bool
    let eloResult: EloResult?
    let userAnswer: String
    let maskedToken: String
    let onNext: () -> Void
    
    public init(
        word: VocabularyWord,
        isCorrect: Bool,
        eloResult: EloResult?,
        userAnswer: String,
        maskedToken: String,
        onNext: @escaping () -> Void
    ) {
        self.word = word
        self.isCorrect = isCorrect
        self.eloResult = eloResult
        self.userAnswer = userAnswer
        self.maskedToken = maskedToken
        self.onNext = onNext
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            
            // Header: Status & Elo Delta Pill
            HStack(alignment: .center, spacing: 10) {
                ZStack {
                    Circle()
                        .fill(isCorrect ? Color.green.opacity(0.18) : Color.red.opacity(0.18))
                        .frame(width: 42, height: 42)
                    Image(systemName: isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(isCorrect ? .green : .red)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(isCorrect ? "Ausgezeichnet!" : "Fast richtig!")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    
                    if let result = eloResult {
                        HStack(spacing: 6) {
                            Text(result.userDelta >= 0 ? "+\(Int(round(result.userDelta))) Elo" : "\(Int(round(result.userDelta))) Elo")
                                .font(.system(size: 12, weight: .heavy, design: .rounded))
                                .foregroundColor(result.userDelta >= 0 ? .green : .red)
                            
                            Text("• Dein Rating: \(Int(round(result.newUserElo)))")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Spacer()
                
                // Active Level Indicator
                Text(word.activeExampleLevelTag)
                    .font(.system(size: 11, weight: .black))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(word.isB2MasteryReached ? Color.purple : Color.blue)
                    .cornerRadius(6)
            }
            
            // Milestone alert if B2 was just unlocked
            if isCorrect && word.isB2MasteryReached && word.consecutiveCorrect == 2 {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .foregroundColor(.purple)
                    Text("B2-Niveau freigeschaltet! Nächste Runde nutzt den B2-Satz.")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.purple)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.purple.opacity(0.12))
                .cornerRadius(10)
            }
            
            // Revealed Target Word
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(word.articleOrType)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(word.category.badgeColor)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(word.category.badgeColor.opacity(0.15))
                        .cornerRadius(6)
                    
                    Text(word.cleanTargetWord)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    
                    if !isCorrect && !userAnswer.isEmpty {
                        Text("(Deine Eingabe: \(userAnswer))")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }
                
                Text(word.englishDefinition)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(.secondary)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(12)
            
            // Complete Example Sentence Revealed
            VStack(alignment: .leading, spacing: 4) {
                Text("Vollständiger Satz (\(word.activeExampleLevelTag)):")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.secondary)
                
                Text(word.activeExample)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.primary)
                    .lineSpacing(3)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(12)
            
            // Next Button
            Button(action: {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                onNext()
            }) {
                HStack {
                    Text("Nächste Vokabel")
                        .font(.system(size: 15, weight: .bold))
                    Image(systemName: "arrow.right")
                        .font(.system(size: 13, weight: .bold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(isCorrect ? Color.green : Color.blue)
                .cornerRadius(12)
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
        .padding(16)
        .background(Color(UIColor.systemBackground))
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.15), radius: 15, y: -4)
    }
}
