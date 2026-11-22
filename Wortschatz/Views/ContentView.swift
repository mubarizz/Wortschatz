import SwiftUI
import UIKit

public enum AppTab: Int, Hashable {
    case dashboard = 0
    case games = 1
    case grammar = 2
    case library = 3
    case settings = 4
}

private struct QuickLookupSheetItem: Identifiable {
    let id = UUID()
    let rawText: String
}

public struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var store = VocabularyStore()
    @StateObject private var grammarStore = GrammarStore()
    @StateObject private var schreibenStore = SchreibenStore()
    @State private var selectedTab: AppTab = .dashboard
    
    @State private var showingClozeGame: Bool = false
    @State private var showingReverseQuiz: Bool = false
    @State private var showingFlashcards: Bool = false
    @State private var showingDictationGame: Bool = false
    @State private var showingPrepositionSprint: Bool = false
    @State private var quickLookupItem: QuickLookupSheetItem? = nil
    @State private var importedWordsBannerText: String? = nil
    
    public init() {}
    
    public var body: some View {
        ZStack(alignment: .top) {
            TabView(selection: $selectedTab) {
                DashboardView(
                    store: store,
                    onStartCloze: { showingClozeGame = true },
                    onStartReverseQuiz: { showingReverseQuiz = true },
                    onStartFlashcards: { showingFlashcards = true },
                    onStartDictation: { showingDictationGame = true },
                    onStartPrepositionSprint: { showingPrepositionSprint = true },
                    onStartQuickLookup: { text in
                        quickLookupItem = QuickLookupSheetItem(rawText: text)
                    }
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
                    onSelectDictation: { showingDictationGame = true },
                    onSelectPrepositionSprint: { showingPrepositionSprint = true }
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
            .accentColor(.blue)
            
            // Floating Banner when words saved from Podcasts Share Extension are imported
            if let bannerText = importedWordsBannerText {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundColor(.white)
                    Text(bannerText)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Spacer()
                    Button(action: {
                        withAnimation { importedWordsBannerText = nil }
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .fill(Color.indigo)
                        .shadow(color: Color.black.opacity(0.18), radius: 8, y: 4)
                )
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .transition(.move(edge: .top).combined(with: .opacity))
                .zIndex(10)
            }
        }
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
        .fullScreenCover(isPresented: $showingPrepositionSprint) {
            PrepositionSprintGameView(vocabStore: store)
        }
        .sheet(item: $quickLookupItem) { item in
            QuickLookupView(
                rawText: item.rawText,
                store: store,
                isExtensionMode: false,
                onClose: {
                    quickLookupItem = nil
                }
            )
        }
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .active {
                checkAndImportSharedWords()
                checkPendingShortcutClipboardLookup()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .wortschatzOpenClipboardLookup)) { notification in
            checkAndImportSharedWords()
            let text = (notification.object as? String) ?? UIPasteboard.general.string ?? ""
            UserDefaults.standard.set(false, forKey: "wortschatz_trigger_clipboard_lookup")
            quickLookupItem = QuickLookupSheetItem(rawText: text)
        }
        .onOpenURL { url in
            handleIncomingDeepLink(url)
        }
    }
    
    private func checkPendingShortcutClipboardLookup() {
        if UserDefaults.standard.bool(forKey: "wortschatz_trigger_clipboard_lookup") {
            UserDefaults.standard.set(false, forKey: "wortschatz_trigger_clipboard_lookup")
            let savedText = UserDefaults.standard.string(forKey: "wortschatz_trigger_clipboard_text") ?? UIPasteboard.general.string ?? ""
            quickLookupItem = QuickLookupSheetItem(rawText: savedText)
        }
    }
    
    private func checkAndImportSharedWords() {
        let newlyImported = store.importPendingWordsFromExtension()
        guard !newlyImported.isEmpty else { return }
        let names = newlyImported.prefix(2).map { "„\($0.cleanTargetWord)“" }.joined(separator: ", ")
        let suffix = newlyImported.count > 2 ? " (+\(newlyImported.count - 2))" : ""
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            importedWordsBannerText = "Aus Schnellsuche: \(names)\(suffix) (+\(newlyImported.count * 5) Elo)"
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.5) {
            withAnimation {
                importedWordsBannerText = nil
            }
        }
    }
    
    private func handleIncomingDeepLink(_ url: URL) {
        checkAndImportSharedWords()
        guard url.scheme?.lowercased() == "wortschatz" else { return }
        if let components = URLComponents(url: url, resolvingAgainstBaseURL: false) {
            let queryValue = components.queryItems?.first(where: { $0.name == "q" || $0.name == "word" })?.value ?? ""
            quickLookupItem = QuickLookupSheetItem(rawText: queryValue)
        }
    }
}
