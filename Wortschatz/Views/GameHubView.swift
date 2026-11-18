import SwiftUI
import UIKit

public struct GameHubView: View {
    @ObservedObject var store: VocabularyStore
    let onSelectCloze: () -> Void
    let onSelectReverseQuiz: () -> Void
    let onSelectFlashcards: () -> Void
    
    public init(
        store: VocabularyStore,
        onSelectCloze: @escaping () -> Void,
        onSelectReverseQuiz: @escaping () -> Void,
        onSelectFlashcards: @escaping () -> Void
    ) {
        self.store = store
        self.onSelectCloze = onSelectCloze
        self.onSelectReverseQuiz = onSelectReverseQuiz
        self.onSelectFlashcards = onSelectFlashcards
    }
    
    public var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 14) {
                    
                    // Header Banner
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Trainingsmodi")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.primary)
                        Text("Wähle deinen Lernmodus für die heutige B2-Einheit.")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 4)
                    
                    // Card 1: Flashcards (Learn First)
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(alignment: .top) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.orange.opacity(0.15))
                                    .frame(width: 44, height: 44)
                                Image(systemName: "rectangle.stack.fill")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(.orange)
                            }
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Karteikarten")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.primary)
                                Text("Lernen & Verinnerlichen")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.orange)
                            }
                            
                            Spacer()
                            
                            Text("Audio & 3D")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.orange)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(Color.orange.opacity(0.12))
                                .cornerRadius(4)
                        }
                        
                        Text("Verinnerliche neue Vokabeln mit nativer deutscher Sprachausgabe, taktilen 3D-Drehkarten und Beispielsätzen vor dem Testen.")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .lineSpacing(2)
                        
                        HStack {
                            Label("Leitner & Swipe-System", systemImage: "hand.draw.fill")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.orange)
                            
                            Spacer()
                            
                            Button(action: onSelectFlashcards) {
                                HStack(spacing: 4) {
                                    Text("Lernen")
                                        .font(.system(size: 13, weight: .bold))
                                    Image(systemName: "play.fill")
                                        .font(.system(size: 10))
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 7)
                                .background(Color.orange)
                                .cornerRadius(8)
                            }
                        }
                    }
                    .padding(14)
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(14)
                    
                    // Card 2: Progressive Context Cloze
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(alignment: .top) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.blue.opacity(0.15))
                                    .frame(width: 44, height: 44)
                                Image(systemName: "character.cursor.ibeam")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(.blue)
                            }
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Lückentext-Arena")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.primary)
                                Text("Progressive B1 ➔ B2 Cloze")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.blue)
                            }
                            
                            Spacer()
                            
                            EloBadge(elo: store.userElo, showLabel: false, compact: true)
                        }
                        
                        Text("Neue Wörter starten mit dem einfacheren B1-Beispielsatz. Sobald du das Wort 2x hintereinander beherrschst, schaltet die Arena dynamisch auf den anspruchsvollen B2-Satz um.")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .lineSpacing(2)
                        
                        HStack {
                            Label("\(store.b2UnlockedWords.count) B2 Freigeschaltet", systemImage: "sparkles")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.indigo)
                            
                            Spacer()
                            
                            Button(action: onSelectCloze) {
                                HStack(spacing: 4) {
                                    Text("Starten")
                                        .font(.system(size: 13, weight: .bold))
                                    Image(systemName: "play.fill")
                                        .font(.system(size: 10))
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 7)
                                .background(Color.blue)
                                .cornerRadius(8)
                            }
                        }
                    }
                    .padding(14)
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(14)
                    
                    // Card 2: Reverse-Engineering Quiz
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(alignment: .top) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.purple.opacity(0.15))
                                    .frame(width: 44, height: 44)
                                Image(systemName: "arrow.triangle.turn.up.right.diamond.fill")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(.purple)
                            }
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Rückwärts-Quiz")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.primary)
                                Text("100% Zielsprachen-Deduktion")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.purple)
                            }
                            
                            Spacer()
                            
                            Text("Multiple Choice")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.purple)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(Color.purple.opacity(0.12))
                                .cornerRadius(4)
                        }
                        
                        Text("Versteckt die englische Übersetzung vollständig! Du siehst ausschließlich die präzise deutsche Definition und musst das gesuchte Zielwort aus 4 Optionen ableiten.")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .lineSpacing(2)
                        
                        HStack {
                            Label("Kein Englisch erlaubt", systemImage: "eye.slash.fill")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.purple)
                            
                            Spacer()
                            
                            Button(action: onSelectReverseQuiz) {
                                HStack(spacing: 4) {
                                    Text("Starten")
                                        .font(.system(size: 13, weight: .bold))
                                    Image(systemName: "play.fill")
                                        .font(.system(size: 10))
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 7)
                                .background(Color.purple)
                                .cornerRadius(8)
                            }
                        }
                    }
                    .padding(14)
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(14)
                }
                .padding(14)
            }
            .navigationTitle("Trainieren")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
