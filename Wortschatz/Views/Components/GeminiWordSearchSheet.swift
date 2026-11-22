import SwiftUI
import UIKit

public struct GeminiWordSearchSheet: View {
    @ObservedObject var store: VocabularyStore
    @ObservedObject private var gemini = GeminiService.shared
    @Environment(\.dismiss) private var dismiss
    
    private let initialQuery: String
    @State private var query: String
    @State private var candidates: [GeminiWordCandidate] = []
    @State private var isLoading: Bool = false
    @State private var errorMessage: String? = nil
    @State private var apiKeyInput: String = ""
    @State private var editingCandidate: GeminiWordCandidate? = nil
    @State private var addedWordsCount: Int = 0
    
    public init(store: VocabularyStore, initialQuery: String = "") {
        self.store = store
        self.initialQuery = initialQuery
        self._query = State(initialValue: initialQuery)
    }
    
    public var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    
                    // 1. API Key Prompt if not configured yet
                    if !gemini.hasValidKey {
                        apiKeySetupCard
                    }
                    
                    // 2. Search Bar Card
                    searchBarSection
                    
                    // 3. Loading / Error / Results
                    if isLoading {
                        loadingSection
                    } else if let error = errorMessage {
                        errorSection(error)
                    } else if !candidates.isEmpty {
                        resultsSection
                    } else {
                        emptyPromptSection
                    }
                }
                .padding(14)
            }
            .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Wort hinzufügen (AI)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Schließen") {
                        AudioSpeaker.shared.stop()
                        dismiss()
                    }
                    .font(.system(size: 14, weight: .medium))
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: openBlankEditor) {
                        Label("Manuell", systemImage: "square.and.pencil")
                            .font(.system(size: 13, weight: .semibold))
                    }
                }
            }
            .sheet(item: $editingCandidate) { candidate in
                CandidateEditorSheet(
                    candidate: candidate,
                    onSaveAndAdd: { updatedCandidate in
                        if let idx = candidates.firstIndex(where: { $0.id == updatedCandidate.id }) {
                            candidates[idx] = updatedCandidate
                        } else {
                            candidates.insert(updatedCandidate, at: 0)
                        }
                        let vocabWord = updatedCandidate.toVocabularyWord()
                        if store.addWord(vocabWord) {
                            addedWordsCount += 1
                            UINotificationFeedbackGenerator().notificationOccurred(.success)
                        }
                    }
                )
            }
            .onAppear {
                apiKeyInput = gemini.apiKey
                if !initialQuery.isEmpty && (query.isEmpty || query != initialQuery) {
                    query = initialQuery
                }
                let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty && candidates.isEmpty {
                    triggerSearch()
                }
            }
            .onDisappear {
                AudioSpeaker.shared.stop()
            }
        }
    }
    
    // MARK: - API Key Inline Setup Card
    private var apiKeySetupCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "key.fill")
                    .foregroundColor(.orange)
                Text("Gemini API-Schlüssel erforderlich")
                    .font(.system(size: 13, weight: .bold))
            }
            
            Text("Hinterlege deinen kostenlosen Google Gemini API-Schlüssel, um Wörter (A1–C2) automatisch samt Definitionen und B1/B2-Sätzen zu generieren.")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            
            HStack(spacing: 8) {
                SecureField("AIzaSy...", text: $apiKeyInput)
                    .font(.system(size: 13))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                    .padding(9)
                    .background(Color(UIColor.systemBackground))
                    .cornerRadius(8)
                
                Button("Speichern") {
                    gemini.apiKey = apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    if !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        triggerSearch()
                    }
                }
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.gray : Color.blue)
                .cornerRadius(8)
                .disabled(apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(12)
        .background(Color.orange.opacity(0.1))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
        )
    }
    
    // MARK: - Search Input Bar
    private var searchBarSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .foregroundColor(.indigo)
                        .font(.system(size: 14, weight: .semibold))
                    
                    TextField("Deutsch oder Englisch (z.B. 'sustainable', 'Eindruck')...", text: $query)
                        .font(.system(size: 14, weight: .medium))
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                        .submitLabel(.search)
                        .onSubmit {
                            triggerSearch()
                        }
                    
                    if !query.isEmpty {
                        Button(action: { query = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                                .font(.system(size: 14))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 10)
                .frame(height: 44)
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(10)
                
                Button(action: triggerSearch) {
                    Text("Suchen")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .frame(height: 44)
                        .background(
                            query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading
                            ? Color.indigo.opacity(0.4)
                            : Color.indigo
                        )
                        .cornerRadius(10)
                }
                .disabled(query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)
            }
            
            Text("Findet 3 passende Vokabel-Vorschläge über alle Niveaustufen (A1–C2) mit deutschen & englischen Definitionen sowie B1/B2-Kontextsätzen.")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Loading View
    private var loadingSection: some View {
        VStack(spacing: 12) {
            ProgressView()
                .scaleEffect(1.2)
            Text("Gemini analysiert '\(query)' und erstellt 3 Vorschläge (A1–C2)...")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(14)
    }
    
    // MARK: - Error View
    private func errorSection(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.red)
                Text("Hinweis")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.red)
            }
            Text(message)
                .font(.system(size: 12))
                .foregroundColor(.primary)
            
            Button("Erneut versuchen") {
                triggerSearch()
            }
            .font(.system(size: 12, weight: .bold))
            .foregroundColor(.blue)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.red.opacity(0.08))
        .cornerRadius(12)
    }
    
    // MARK: - Empty State Prompt
    private var emptyPromptSection: some View {
        VStack(spacing: 10) {
            Image(systemName: "text.magnifyingglass")
                .font(.system(size: 32))
                .foregroundColor(.indigo.opacity(0.7))
            
            Text("Suche nach jedem Wort oder Begriff")
                .font(.system(size: 15, weight: .bold))
            
            Text("Gib ein deutsches Wort (auch konjugiert), ein englisches Wort oder ein Thema ein. Du kannst jeden der 3 Vorschläge vor dem Speichern anpassen.")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(14)
    }
    
    // MARK: - 3 Candidates List
    private var resultsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("\(candidates.count) Vorschläge (A1–C2)")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.secondary)
                Spacer()
                if addedWordsCount > 0 {
                    Text("\(addedWordsCount) neu hinzugefügt ✓")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.green)
                }
            }
            
            ForEach(candidates) { candidate in
                candidateCard(candidate)
            }
        }
    }
    
    private func candidateCard(_ candidate: GeminiWordCandidate) -> some View {
        let vocabWord = candidate.toVocabularyWord()
        let alreadyAdded = store.hasWord(vocabWord.cleanTargetWord)
        
        return VStack(alignment: .leading, spacing: 10) {
            // Top bar: Article/POS + CEFR Badge + Audio + Edit button
            HStack(spacing: 6) {
                Text(vocabWord.articleOrType)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(vocabWord.category.badgeColor)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(vocabWord.category.badgeColor.opacity(0.14))
                    .cornerRadius(6)
                
                Text(candidate.cefrLevel.uppercased())
                    .font(.system(size: 10, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(cefrColor(for: candidate.cefrLevel))
                    .cornerRadius(5)
                
                Spacer()
                
                // Speak Word Button
                Button(action: {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    AudioSpeaker.shared.speak(text: vocabWord.displayTitle)
                }) {
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.blue)
                        .padding(6)
                        .background(Color.blue.opacity(0.12))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                
                // Edit Candidate Button
                Button(action: {
                    editingCandidate = candidate
                }) {
                    HStack(spacing: 3) {
                        Image(systemName: "pencil")
                        Text("Anpassen")
                    }
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.indigo)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Color.indigo.opacity(0.12))
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }
            
            // Word & English Definition
            VStack(alignment: .leading, spacing: 2) {
                Text(vocabWord.cleanTargetWord)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                
                Text(vocabWord.englishDefinition)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.blue)
            }
            
            // German Definition
            VStack(alignment: .leading, spacing: 2) {
                Text("Deutsche Definition (Quiz):")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary)
                Text(vocabWord.germanDefinition)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.primary)
            }
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(UIColor.tertiarySystemBackground))
            .cornerRadius(8)
            
            // B1 & B2 Examples
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .top, spacing: 6) {
                    Text("B1")
                        .font(.system(size: 9, weight: .heavy))
                        .foregroundColor(.blue)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.12))
                        .cornerRadius(4)
                    
                    Text(vocabWord.b1Example)
                        .font(.system(size: 11))
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Button(action: {
                        AudioSpeaker.shared.speak(text: vocabWord.b1Example)
                    }) {
                        Image(systemName: "speaker.wave.2")
                            .font(.system(size: 11))
                            .foregroundColor(.blue)
                    }
                    .buttonStyle(.plain)
                }
                
                HStack(alignment: .top, spacing: 6) {
                    Text("B2")
                        .font(.system(size: 9, weight: .heavy))
                        .foregroundColor(.purple)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.purple.opacity(0.12))
                        .cornerRadius(4)
                    
                    Text(vocabWord.b2Example)
                        .font(.system(size: 11))
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Button(action: {
                        AudioSpeaker.shared.speak(text: vocabWord.b2Example)
                    }) {
                        Image(systemName: "speaker.wave.2")
                            .font(.system(size: 11))
                            .foregroundColor(.purple)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
            .background(Color(UIColor.tertiarySystemBackground).opacity(0.6))
            .cornerRadius(8)
            
            // Add to Vocabulary Button
            Button(action: {
                guard !alreadyAdded else { return }
                if store.addWord(vocabWord) {
                    addedWordsCount += 1
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                }
            }) {
                HStack(spacing: 6) {
                    Image(systemName: alreadyAdded ? "checkmark.circle.fill" : "plus.circle.fill")
                    Text(alreadyAdded ? "Im Wortschatz gespeichert" : "Zum Wortschatz hinzufügen")
                }
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(alreadyAdded ? .green : .white)
                .frame(maxWidth: .infinity)
                .frame(height: 40)
                .background(alreadyAdded ? Color.green.opacity(0.15) : Color.blue)
                .cornerRadius(10)
            }
            .buttonStyle(.plain)
            .disabled(alreadyAdded)
        }
        .padding(12)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(alreadyAdded ? Color.green.opacity(0.4) : Color(UIColor.separator).opacity(0.25), lineWidth: 1)
        )
    }
    
    // MARK: - Actions & Helpers
    private func triggerSearch() {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        AudioSpeaker.shared.stop()
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let results = try await gemini.searchWords(query: trimmed)
                await MainActor.run {
                    self.candidates = results
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }
    
    private func openBlankEditor() {
        editingCandidate = GeminiWordCandidate(
            articleOrType: "der",
            word: query.trimmingCharacters(in: .whitespacesAndNewlines),
            cefrLevel: "B1",
            englishDefinition: "",
            germanDefinition: "",
            b1Example: "",
            b2Example: ""
        )
    }
    
    private func cefrColor(for level: String) -> Color {
        switch level.uppercased() {
        case "A1", "A2": return .teal
        case "B1": return .blue
        case "B2": return .indigo
        case "C1", "C2": return .purple
        default: return .gray
        }
    }
}

// MARK: - Editable Candidate Sheet
public struct CandidateEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State var candidate: GeminiWordCandidate
    let onSaveAndAdd: (GeminiWordCandidate) -> Void
    
    private let articleOptions = ["der", "die", "das", "Verb", "Adjektiv", "Adverb", "Ausdruck"]
    private let cefrOptions = ["A1", "A2", "B1", "B2", "C1", "C2"]
    
    public var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Wort & Grammatik")) {
                    Picker("Artikel / Wortart", selection: $candidate.articleOrType) {
                        ForEach(articleOptions, id: \.self) { opt in
                            Text(opt).tag(opt)
                        }
                    }
                    
                    Picker("CEFR Niveau", selection: $candidate.cefrLevel) {
                        ForEach(cefrOptions, id: \.self) { lvl in
                            Text(lvl).tag(lvl)
                        }
                    }
                    
                    TextField("Deutsches Zielwort (ohne Artikel)", text: $candidate.word)
                        .font(.system(size: 16, weight: .bold))
                }
                
                Section(header: Text("Definitionen")) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Englische Übersetzung")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.secondary)
                        TextField("English meaning...", text: $candidate.englishDefinition)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Deutsche Definition (für Rückwärts-Quiz)")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.secondary)
                        TextEditor(text: $candidate.germanDefinition)
                            .frame(minHeight: 64)
                    }
                }
                
                Section(header: Text("Kontext-Beispiele (für Lückentext-Arena)")) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("B1 Beispielsatz (sollte das Zielwort enthalten)")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.blue)
                        TextEditor(text: $candidate.b1Example)
                            .frame(minHeight: 56)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("B2 Beispielsatz (Fortgeschritten)")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.purple)
                        TextEditor(text: $candidate.b2Example)
                            .frame(minHeight: 56)
                    }
                }
            }
            .navigationTitle("Vokabel anpassen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern & Hinzufügen") {
                        onSaveAndAdd(candidate)
                        dismiss()
                    }
                    .font(.system(size: 14, weight: .bold))
                    .disabled(candidate.word.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}
