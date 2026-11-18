import SwiftUI

public enum AppTab: Int, Hashable {
    case dashboard = 0
    case games = 1
    case library = 2
    case settings = 3
}

public struct ContentView: View {
    @StateObject private var store = VocabularyStore()
    @State private var selectedTab: AppTab = .dashboard
    
    // Mini-game activation triggers (ready for the upcoming mini-game views)
    @State private var showingClozeGame: Bool = false
    @State private var showingReverseQuiz: Bool = false
    
    public init() {}
    
    public var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView(
                store: store,
                onStartCloze: { showingClozeGame = true },
                onStartReverseQuiz: { showingReverseQuiz = true }
            )
            .tabItem {
                Label("Arena", systemImage: "bolt.shield.fill")
            }
            .tag(AppTab.dashboard)
            
            GameHubView(
                store: store,
                onSelectCloze: { showingClozeGame = true },
                onSelectReverseQuiz: { showingReverseQuiz = true }
            )
            .tabItem {
                Label("Spiele", systemImage: "gamecontroller.fill")
            }
            .tag(AppTab.games)
            
            LibraryView(store: store)
                .tabItem {
                    Label("Wortschatz", systemImage: "books.vertical.fill")
                }
                .tag(AppTab.library)
            
            SettingsView(store: store)
                .tabItem {
                    Label("Profil", systemImage: "gearshape.fill")
                }
                .tag(AppTab.settings)
        }
        // Tint color optimized for readability and dark/light mode contrast
        .accentColor(.blue)
        // Mini-Game Preparation Sheets
        .sheet(isPresented: $showingClozeGame) {
            MiniGamePlaceholderView(
                title: "Lückentext-Arena",
                subtitle: "Progressive Context Cloze Deletions",
                icon: "character.cursor.ibeam",
                accentColor: .blue,
                description: "Bereit für Mini-Game Schritt: Filtert nach der Spaced Repetition Queue, nutzt für neue Wörter das B1-Beispiel und schaltet nach 2x Folgeerfolg dynamisch auf den B2-Beispielsatz um."
            )
        }
        .sheet(isPresented: $showingReverseQuiz) {
            MiniGamePlaceholderView(
                title: "Rückwärts-Quiz",
                subtitle: "Reverse-Engineering Target Deduction",
                icon: "arrow.triangle.turn.up.right.diamond.fill",
                accentColor: .purple,
                description: "Bereit für Mini-Game Schritt: Versteckt die englische Definition vollständig, zeigt nur die deutsche Definition und fordert die Wahl des richtigen Zielworts aus 4 Optionen."
            )
        }
    }
}

// MARK: - Mini-Game Preparation Placeholder
struct MiniGamePlaceholderView: View {
    let title: String
    let subtitle: String
    let icon: String
    let accentColor: Color
    let description: String
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Spacer()
                
                ZStack {
                    Circle()
                        .fill(accentColor.opacity(0.12))
                        .frame(width: 80, height: 80)
                    Image(systemName: icon)
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(accentColor)
                }
                
                VStack(spacing: 6) {
                    Text(title)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    
                    Text(subtitle)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(accentColor)
                }
                
                Text(description)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
                    .lineSpacing(3)
                
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Datenmodell & SRS-Engine bereit")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.primary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(20)
                
                Spacer()
                
                Button(action: { dismiss() }) {
                    Text("Schließen")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(accentColor)
                        .cornerRadius(12)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 12)
            }
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
