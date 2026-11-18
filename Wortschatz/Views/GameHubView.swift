import SwiftUI
import UIKit

public struct GameHubView: View {
    @ObservedObject var store: VocabularyStore
    let onSelectCloze: () -> Void
    let onSelectReverseQuiz: () -> Void
    let onSelectFlashcards: () -> Void
    var onSelectDictation: (() -> Void)? = nil
    
    public init(
        store: VocabularyStore,
        onSelectCloze: @escaping () -> Void,
        onSelectReverseQuiz: @escaping () -> Void,
        onSelectFlashcards: @escaping () -> Void,
        onSelectDictation: (() -> Void)? = nil
    ) {
        self.store = store
        self.onSelectCloze = onSelectCloze
        self.onSelectReverseQuiz = onSelectReverseQuiz
        self.onSelectFlashcards = onSelectFlashcards
        self.onSelectDictation = onSelectDictation
    }
    
    public var body: some View {
        NavigationView {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    
                    // Header Banner
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Trainingsmodi")
                            .font(.system(size: 20, weight: .black, design: .rounded))
                            .foregroundColor(.primary)
                        Text("Wähle deinen Lernmodus • 80% Zu lernen / 20% Gelernt")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 4)
                    
                    GameHubCard(
                        title: "Karteikarten",
                        subtitle: "Lernen & Verinnerlichen",
                        badge: "Audio & 3D",
                        description: "Verinnerliche neue Vokabeln mit deutscher Sprachausgabe, taktilen 3D-Drehkarten und B1/B2-Beispielsätzen.",
                        footerLabel: "+20% Lern-Score • Swipe-System",
                        footerIcon: "hand.draw.fill",
                        icon: "rectangle.stack.fill",
                        color: Color(red: 0.94, green: 0.50, blue: 0.10),
                        buttonTitle: "Lernen",
                        action: onSelectFlashcards
                    )
                    
                    GameHubCard(
                        title: "Lückentext-Arena",
                        subtitle: "Progressive B1 ➔ B2 Cloze",
                        badge: "Aktiv Schreiben",
                        description: "Neue Wörter starten mit dem B1-Beispielsatz. Ab 50% Lern-Score schaltet die Arena dynamisch auf den B2-Satz um.",
                        footerLabel: "+30% Lern-Score • \(store.b2UnlockedWords.count) B2 aktiv",
                        footerIcon: "sparkles",
                        icon: "character.cursor.ibeam",
                        color: Color(red: 0.14, green: 0.46, blue: 0.96),
                        buttonTitle: "Starten",
                        action: onSelectCloze
                    )
                    
                    GameHubCard(
                        title: "Rückwärts-Quiz",
                        subtitle: "100% Zielsprachen-Deduktion",
                        badge: "Multiple Choice",
                        description: "Versteckt die englische Übersetzung! Leite das gesuchte Zielwort anhand der deutschen Definition aus 4 Optionen derselben Wortart ab.",
                        footerLabel: "+25% Lern-Score • Kein Englisch",
                        footerIcon: "eye.slash.fill",
                        icon: "arrow.triangle.turn.up.right.diamond.fill",
                        color: Color(red: 0.55, green: 0.27, blue: 0.93),
                        buttonTitle: "Starten",
                        action: onSelectReverseQuiz
                    )
                    
                    if let onSelectDictation = onSelectDictation {
                        GameHubCard(
                            title: "Hör-Diktat",
                            subtitle: "Hörverständnis & Rechtschreibung",
                            badge: "Normal & 0.7x",
                            description: "Das Zielwort ist ausgeblendet – höre dir das Wort (normal oder langsam) sowie den Beispielsatz an und schreibe die Vokabel auf.",
                            footerLabel: "+10% Lern-Score • Audio-Training",
                            footerIcon: "ear.and.waveform",
                            icon: "headphones",
                            color: Color(red: 0.06, green: 0.62, blue: 0.66),
                            buttonTitle: "Starten",
                            action: onSelectDictation
                        )
                    }
                }
                .padding(14)
            }
            .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Trainieren")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

private struct GameHubCard: View {
    let title: String
    let subtitle: String
    let badge: String
    let description: String
    let footerLabel: String
    let footerIcon: String
    let icon: String
    let color: Color
    let buttonTitle: String
    let action: () -> Void
    
    var body: some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        }) {
            VStack(alignment: .leading, spacing: 11) {
                HStack(alignment: .center, spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(color.opacity(0.14))
                            .frame(width: 46, height: 46)
                        Image(systemName: icon)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(color)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                        Text(subtitle)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(color)
                    }
                    
                    Spacer()
                    
                    Text(badge)
                        .font(.system(size: 10, weight: .heavy, design: .rounded))
                        .foregroundColor(color)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(color.opacity(0.12))
                        .cornerRadius(6)
                }
                
                Text(description)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(.secondary)
                    .lineSpacing(2.5)
                    .multilineTextAlignment(.leading)
                
                Divider()
                    .opacity(0.6)
                
                HStack {
                    Label(footerLabel, systemImage: footerIcon)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(color)
                    
                    Spacer()
                    
                    HStack(spacing: 5) {
                        Text(buttonTitle)
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                        Image(systemName: "play.fill")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(
                        Capsule()
                            .fill(color)
                    )
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color(UIColor.secondarySystemGroupedBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.035), radius: 8, y: 3)
        }
        .buttonStyle(ScaleButtonStyle(scaleAmount: 0.97))
    }
}
