import SwiftUI

public struct SettingsView: View {
    @ObservedObject var store: VocabularyStore
    @State private var showingResetAlert = false
    
    public init(store: VocabularyStore) {
        self.store = store
    }
    
    public var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Elo & Spaced Repetition (SRS)")) {
                    HStack {
                        Text("Dein Elo-Rating")
                        Spacer()
                        EloBadge(elo: store.userElo, showLabel: false)
                    }
                    HStack {
                        Text("Rang")
                        Spacer()
                        Text(store.userRankTitle)
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Abgeschlossene Reviews")
                        Spacer()
                        Text("\(store.totalReviews)")
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Tägliche Serie")
                        Spacer()
                        Text("\(store.dailyStreak) Tage")
                            .foregroundColor(.secondary)
                    }
                }
                
                Section(header: Text("Datensatz (wortschatz.csv)")) {
                    HStack {
                        Text("Geladene Vokabeln")
                        Spacer()
                        Text("\(store.words.count)")
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("B2-Niveau freigeschaltet")
                        Spacer()
                        Text("\(store.b2UnlockedWords.count)")
                            .foregroundColor(.indigo)
                    }
                    Button(action: {
                        store.loadFromBundledCSV()
                    }) {
                        Label("CSV neu synchronisieren", systemImage: "arrow.clockwise")
                    }
                }
                
                Section(header: Text("Fortschritt verwalten")) {
                    Button(role: .destructive, action: {
                        showingResetAlert = true
                    }) {
                        Label("Fortschritt & Elo zurücksetzen", systemImage: "trash")
                            .foregroundColor(.red)
                    }
                }
                
                Section(footer: Text("Wortschatz v1.0 — Entwickelt für B1 zu B2 Deutschlerner. Optimiert für kompakte iOS-Geräte wie iPhone 13 mini.")) {
                    EmptyView()
                }
            }
            .navigationTitle("Einstellungen")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Fortschritt zurücksetzen?", isPresented: $showingResetAlert) {
                Button("Abbrechen", role: .cancel) {}
                Button("Zurücksetzen", role: .destructive) {
                    store.resetProgress()
                }
            } message: {
                Text("Dein Elo-Rating wird auf 1200 zurückgesetzt und alle bisherigen Antworten werden gelöscht.")
            }
        }
    }
}
