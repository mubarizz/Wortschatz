import SwiftUI

public struct SettingsView: View {
    @ObservedObject var store: VocabularyStore
    @ObservedObject private var gemini = GeminiService.shared
    @State private var showingResetAlert = false
    @State private var showAPIKey = false
    
    public init(store: VocabularyStore) {
        self.store = store
    }
    
    public var body: some View {
        NavigationView {
            Form {
                Section(
                    header: Text("Gemini AI (Wortsuche A1–C2)"),
                    footer: Text("Wird verwendet, um im Wortschatz-Tab beliebige Wörter zu suchen und 3 passende Vokabel-Vorschläge samt B1/B2-Beispielsätzen zu generieren.")
                ) {
                    HStack {
                        Image(systemName: "key.fill")
                            .foregroundColor(gemini.hasValidKey ? .green : .orange)
                        if showAPIKey {
                            TextField("Gemini API Key (AIzaSy...)", text: $gemini.apiKey)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled(true)
                                .font(.system(size: 13, design: .monospaced))
                        } else {
                            SecureField("Gemini API Key (AIzaSy...)", text: $gemini.apiKey)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled(true)
                                .font(.system(size: 13))
                        }
                        Button(action: { showAPIKey.toggle() }) {
                            Image(systemName: showAPIKey ? "eye.slash" : "eye")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    
                    HStack {
                        Text("Status")
                        Spacer()
                        HStack(spacing: 4) {
                            Circle()
                                .fill(gemini.hasValidKey ? Color.green : Color.orange)
                                .frame(width: 8, height: 8)
                            Text(gemini.hasValidKey ? "API-Schlüssel aktiv" : "Nicht konfiguriert")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(gemini.hasValidKey ? .green : .orange)
                        }
                    }
                }
                
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
