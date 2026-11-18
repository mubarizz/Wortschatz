import SwiftUI
import UIKit

public struct WordDetailSheet: View {
    @State private var word: VocabularyWord
    var store: VocabularyStore?
    @Environment(\.dismiss) private var dismiss
    @State private var showingEditor = false
    
    public init(word: VocabularyWord, store: VocabularyStore? = nil) {
        self._word = State(initialValue: word)
        self.store = store
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
                            
                            if let cefr = word.cefrLevel, !cefr.isEmpty {
                                Text(cefr)
                                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                                    .foregroundColor(.indigo)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.indigo.opacity(0.14))
                                    .cornerRadius(6)
                            }
                            
                            Spacer()
                            
                            Button(action: {
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                AudioSpeaker.shared.speak(text: word.displayTitle)
                            }) {
                                Image(systemName: "speaker.wave.2.fill")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(.blue)
                                    .padding(8)
                                    .background(Color.blue.opacity(0.12))
                                    .clipShape(Circle())
                            }
                            .buttonStyle(.plain)
                            
                            LearnScoreBadge(word: word, showLabel: true)
                        }
                        
                        Text(word.cleanTargetWord)
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                        
                        Text(word.englishDefinition)
                            .font(.system(size: 15, weight: .regular))
                            .foregroundColor(.secondary)
                        
                        // Learn Score Progress Bar (Ziel: 75% Gelernt)
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Lernfortschritt (\(word.masteryLabel))")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(word.learnScoreColor)
                                Spacer()
                                Text("\(word.learnScore)% (Gelernt ab 75%)")
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                                    .foregroundColor(.secondary)
                            }
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Capsule()
                                        .fill(Color(UIColor.tertiarySystemFill))
                                        .frame(height: 6)
                                    Capsule()
                                        .fill(word.learnScoreColor)
                                        .frame(width: geo.size.width * CGFloat(word.learnScore) / 100.0, height: 6)
                                }
                            }
                            .frame(height: 6)
                        }
                        .padding(.top, 4)
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
                                
                                Spacer()
                                
                                Button(action: {
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    AudioSpeaker.shared.speak(text: word.b1Example)
                                }) {
                                    Image(systemName: "speaker.wave.2.fill")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(.blue)
                                        .padding(5)
                                        .background(Color.blue.opacity(0.12))
                                        .clipShape(Circle())
                                }
                                .buttonStyle(.plain)
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
                                
                                Spacer()
                                
                                Button(action: {
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    AudioSpeaker.shared.speak(text: word.b2Example)
                                }) {
                                    Image(systemName: "speaker.wave.2.fill")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(.purple)
                                        .padding(5)
                                        .background(Color.purple.opacity(0.12))
                                        .clipShape(Circle())
                                }
                                .buttonStyle(.plain)
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
                if store != nil {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Anpassen") {
                            showingEditor = true
                        }
                        .font(.system(size: 14, weight: .medium))
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") {
                        AudioSpeaker.shared.stop()
                        dismiss()
                    }
                    .font(.system(size: 15, weight: .semibold))
                }
            }
            .sheet(isPresented: $showingEditor) {
                CandidateEditorSheet(
                    candidate: GeminiWordCandidate(
                        id: word.id,
                        articleOrType: word.articleOrType,
                        word: word.cleanTargetWord,
                        cefrLevel: word.cefrLevel ?? "B1",
                        englishDefinition: word.englishDefinition,
                        germanDefinition: word.germanDefinition,
                        b1Example: word.b1Example,
                        b2Example: word.b2Example
                    ),
                    onSaveAndAdd: { edited in
                        word.articleOrType = edited.articleOrType
                        word.word = edited.word
                        word.cefrLevel = edited.cefrLevel
                        word.englishDefinition = edited.englishDefinition
                        word.germanDefinition = edited.germanDefinition
                        word.b1Example = edited.b1Example
                        word.b2Example = edited.b2Example
                        store?.updateWord(word)
                    }
                )
            }
            .onDisappear {
                AudioSpeaker.shared.stop()
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
