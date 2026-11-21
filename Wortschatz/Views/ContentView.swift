import SwiftUI
import UIKit

public enum AppTab: Int, Hashable {
    case dashboard = 0
    case games = 1
    case grammar = 2
    case library = 3
    case settings = 4
}

public struct ContentView: View {
    @StateObject private var store = VocabularyStore()
    @StateObject private var grammarStore = GrammarStore()
    @StateObject private var schreibenStore = SchreibenStore()
    @State private var selectedTab: AppTab = .dashboard
    
    @State private var showingClozeGame: Bool = false
    @State private var showingReverseQuiz: Bool = false
    @State private var showingFlashcards: Bool = false
    @State private var showingDictationGame: Bool = false
    
    public init() {}
    
    public var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView(
                store: store,
                onStartCloze: { showingClozeGame = true },
                onStartReverseQuiz: { showingReverseQuiz = true },
                onStartFlashcards: { showingFlashcards = true },
                onStartDictation: { showingDictationGame = true }
            )
            .tabItem {
                Label("Arena", systemImage: "bolt.shield.fill")
            }
            .tag(AppTab.dashboard)
            
            GameHubView(
                store: store,
                grammarStore: grammarStore,
                schreibenStore: schreibenStore,
                onSelectCloze: { showingClozeGame = true },
                onSelectReverseQuiz: { showingReverseQuiz = true },
                onSelectFlashcards: { showingFlashcards = true },
                onSelectDictation: { showingDictationGame = true }
            )
            .tabItem {
                Label("Spiele", systemImage: "gamecontroller.fill")
            }
            .tag(AppTab.games)
            
            GrammarHubView(grammarStore: grammarStore, vocabStore: store)
                .tabItem {
                    Label("Lernen", systemImage: "graduationcap.fill")
                }
                .tag(AppTab.grammar)
            
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
        // Interactive Study Modes
        .fullScreenCover(isPresented: $showingFlashcards) {
            FlashcardDeckView(store: store)
        }
        .fullScreenCover(isPresented: $showingClozeGame) {
            ClozeArenaView(store: store)
        }
        .fullScreenCover(isPresented: $showingReverseQuiz) {
            ReverseQuizView(store: store)
        }
        .fullScreenCover(isPresented: $showingDictationGame) {
            AudioDictationView(store: store)
        }
    }
}


