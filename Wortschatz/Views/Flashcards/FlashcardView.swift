import SwiftUI
import UIKit

public struct FlashcardView: View {
    let word: VocabularyWord
    @Binding var isFlipped: Bool
    
    public init(word: VocabularyWord, isFlipped: Binding<Bool>) {
        self.word = word
        self._isFlipped = isFlipped
    }
    
    public var body: some View {
        ZStack {
            cardBack
                .opacity(isFlipped ? 1.0 : 0.0)
                .rotation3DEffect(.degrees(isFlipped ? 0 : -180), axis: (x: 0, y: 1, z: 0))
                .allowsHitTesting(isFlipped)
            
            cardFront
                .opacity(isFlipped ? 0.0 : 1.0)
                .rotation3DEffect(.degrees(isFlipped ? 180 : 0), axis: (x: 0, y: 1, z: 0))
                .allowsHitTesting(!isFlipped)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                isFlipped.toggle()
            }
        }
    }
    
    // MARK: - Front of Flashcard (German Word + Audio)
    private var cardFront: some View {
        VStack(spacing: 16) {
            
            // Top Bar
            HStack {
                Text(word.articleOrType)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(word.category.badgeColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(word.category.badgeColor.opacity(0.15))
                    .cornerRadius(6)
                
                Spacer()
                
                // Audio Speak Button
                Button(action: {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    AudioSpeaker.shared.speak(text: word.displayTitle)
                }) {
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.blue)
                        .padding(8)
                        .background(Color.blue.opacity(0.12))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                
                LearnScoreBadge(word: word, showLabel: false, compact: true)
            }
            
            Spacer()
            
            // German Target Word
            VStack(spacing: 6) {
                Text(word.cleanTargetWord)
                    .font(.system(size: 32, weight: .black, design: .rounded))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                
                Text("Wortart: \(word.partOfSpeech.rawValue)")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 10)
            
            // Mastery / Level Badge
            HStack(spacing: 6) {
                Circle()
                    .fill(word.learnScoreColor)
                    .frame(width: 8, height: 8)
                
                Text("\(word.masteryLabel) • \(word.learnScore)%")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Color(UIColor.tertiarySystemBackground))
            .cornerRadius(12)
            
            Spacer()
            
            // Tap hint
            HStack(spacing: 4) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 11))
                Text("Tippen zum Umdrehen")
                    .font(.system(size: 11, weight: .medium))
            }
            .foregroundColor(Color(UIColor.tertiaryLabel))
            .padding(.bottom, 4)
        }
        .padding(18)
        .frame(maxWidth: .infinity)
        .frame(height: 380)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color(UIColor.separator).opacity(0.3), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.08), radius: 10, y: 4)
    }
    
    // MARK: - Back of Flashcard (Definitions & Sentences)
    private var cardBack: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                
                // Header with translation & audio
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(word.cleanTargetWord)
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                        Text(word.englishDefinition)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.blue)
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        AudioSpeaker.shared.speak(text: word.activeExample)
                    }) {
                        Image(systemName: "speaker.wave.2.fill")
                            .font(.system(size: 15))
                            .foregroundColor(.purple)
                            .padding(7)
                            .background(Color.purple.opacity(0.12))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
                
                // German Definition
                VStack(alignment: .leading, spacing: 4) {
                    Text("Deutsche Definition:")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.secondary)
                    Text(word.germanDefinition)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.primary)
                        .lineSpacing(2.5)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(UIColor.tertiarySystemBackground))
                .cornerRadius(10)
                
                // B1 Example Sentence
                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text("B1 Beispiel")
                            .font(.system(size: 9, weight: .heavy))
                            .foregroundColor(.blue)
                        Spacer()
                        Button(action: {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            AudioSpeaker.shared.speak(text: word.b1Example)
                        }) {
                            Image(systemName: "speaker.wave.2.fill")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.blue)
                                .padding(4)
                                .background(Color.blue.opacity(0.12))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                    }
                    Text(word.b1Example)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(.primary)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.blue.opacity(0.06))
                .cornerRadius(10)
                
                // B2 Example Sentence
                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text("B2 Fortgeschritten")
                            .font(.system(size: 9, weight: .heavy))
                            .foregroundColor(.purple)
                        Spacer()
                        if word.isB2MasteryReached {
                            Text("Freigeschaltet ✓")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.green)
                        }
                        Button(action: {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            AudioSpeaker.shared.speak(text: word.b2Example)
                        }) {
                            Image(systemName: "speaker.wave.2.fill")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.purple)
                                .padding(4)
                                .background(Color.purple.opacity(0.12))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                    }
                    Text(word.b2Example)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(.primary)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.purple.opacity(0.06))
                .cornerRadius(10)
            }
            .padding(16)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 380)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.purple.opacity(0.3), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.08), radius: 10, y: 4)
    }
}
