import AppIntents
import SwiftUI
import UIKit

public extension Notification.Name {
    static let wortschatzOpenClipboardLookup = Notification.Name("wortschatzOpenClipboardLookup")
}

// MARK: - 1. In-Place Popup Intent (Stays inside Podcasts & shows a rich banner at top of screen!)
public struct LookUpCopiedWordPopupIntent: AppIntent {
    public static var title: LocalizedStringResource = "Kopiertes Wort nachschlagen (Popup)"
    public static var description = IntentDescription(
        "Schlägt das aktuell kopierte Wort aus der Zwischenablage (z.B. aus Podcasts) nach, zeigt Artikel, Bedeutung und Beispielsatz direkt als Banner an und speichert es im Wortschatz."
    )
    public static var openAppWhenRun: Bool = false
    
    public init() {}
    
    @MainActor
    public func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        let rawClipboard = UIPasteboard.general.string?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !rawClipboard.isEmpty else {
            return .result(
                dialog: IntentDialog("Keine Vokabel in der Zwischenablage gefunden. Bitte kopiere zuerst ein Wort."),
                view: EmptyClipboardSnippetView()
            )
        }
        
        let context = SharedLookupBridge.shared.extractLookupContext(from: rawClipboard)
        let targetQuery = context.primaryQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !targetQuery.isEmpty else {
            return .result(
                dialog: IntentDialog("Kein gültiges Wort in der Zwischenablage erkannt."),
                view: EmptyClipboardSnippetView()
            )
        }
        
        // 1. Check Verb + Preposition match
        let prepMatch = SharedLookupBridge.shared.findPrepositionMatches(for: targetQuery).first
        
        // 2. Check local vocabulary deck first
        let snapshot = SharedLookupBridge.shared.loadVocabularySnapshot()
        if let localMatch = SharedLookupBridge.shared.findLocalVocabularyMatches(for: targetQuery, in: snapshot).first,
           localMatch.cleanTargetWord.lowercased() == targetQuery.lowercased() {
            return .result(
                dialog: IntentDialog("\(localMatch.displayTitle): \(localMatch.englishDefinition)"),
                view: LookupResultSnippetView(
                    word: localMatch,
                    prepositionEntry: prepMatch,
                    wasNewlySaved: false
                )
            )
        }
        
        // 3. Live Gemini AI / Wiktionary DE+EN Lookup
        var resolvedWord: VocabularyWord? = nil
        if let candidates = try? await GeminiService.shared.searchWords(query: targetQuery),
           let first = candidates.first {
            resolvedWord = first.toVocabularyWord()
        } else if let wikiCandidates = await SharedLookupBridge.shared.lookupViaWiktionary(query: targetQuery).first {
            resolvedWord = wikiCandidates.toVocabularyWord()
        }
        
        let finalWord = resolvedWord ?? VocabularyWord(
            articleOrType: targetQuery.first?.isUppercase == true ? "die" : "Verb",
            word: targetQuery,
            englishDefinition: "Saved from podcast clipboard",
            germanDefinition: "Aus Zwischenablage gespeichertes Wort („\(targetQuery)“).",
            b1Example: "Ich habe das Wort \(targetQuery) heute im Podcast gehört.",
            b2Example: "Im Kontext der Sendung wurde der Begriff \(targetQuery) verwendet.",
            cefrLevel: "B2"
        )
        
        // 4. Automatically save to Wortschatz (+5 Elo when main app opens)
        SharedLookupBridge.shared.enqueueSavedWordFromExtension(finalWord)
        
        return .result(
            dialog: IntentDialog("\(finalWord.displayTitle) — \(finalWord.englishDefinition)"),
            view: LookupResultSnippetView(
                word: finalWord,
                prepositionEntry: prepMatch,
                wasNewlySaved: true
            )
        )
    }
}

// MARK: - 2. Open Full Lookup Card in Wortschatz App Intent
public struct OpenCopiedWordInAppIntent: AppIntent {
    public static var title: LocalizedStringResource = "Kopiertes Wort in Wortschatz öffnen"
    public static var description = IntentDescription(
        "Öffnet Wortschatz direkt mit der Detail- und Audio-Ansicht für das aktuell kopierte Wort."
    )
    public static var openAppWhenRun: Bool = true
    
    public init() {}
    
    @MainActor
    public func perform() async throws -> some IntentResult {
        let rawClipboard = UIPasteboard.general.string?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        UserDefaults.standard.set(true, forKey: "wortschatz_trigger_clipboard_lookup")
        UserDefaults.standard.set(rawClipboard, forKey: "wortschatz_trigger_clipboard_text")
        NotificationCenter.default.post(name: .wortschatzOpenClipboardLookup, object: rawClipboard)
        return .result()
    }
}

// MARK: - 3. App Shortcuts Provider (Automatically registers in iOS Shortcuts & Control Center)
public struct WortschatzShortcutsProvider: AppShortcutsProvider {
    public static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: LookUpCopiedWordPopupIntent(),
            phrases: [
                "Kopiertes Wort in \(.applicationName) nachschlagen",
                "Wort aus Zwischenablage in \(.applicationName)",
                "\(.applicationName) Popup"
            ],
            shortTitle: "Wort-Popup (Copy)",
            systemImageName: "text.magnifyingglass"
        )
        AppShortcut(
            intent: OpenCopiedWordInAppIntent(),
            phrases: [
                "Kopiertes Wort in \(.applicationName) öffnen",
                "\(.applicationName) Zwischenablage öffnen"
            ],
            shortTitle: "In Wortschatz öffnen",
            systemImageName: "book.fill"
        )
    }
}

// MARK: - SwiftUI Snippet Views Rendered Directly Over Podcasts in the Banner!

private struct EmptyClipboardSnippetView: View {
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "doc.on.clipboard")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.orange)
            VStack(alignment: .leading, spacing: 2) {
                Text("Zwischenablage ist leer")
                    .font(.system(size: 14, weight: .bold))
                Text("Markiere zuerst ein Wort im Podcast und tippe auf „Kopieren“.")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
        }
        .padding(12)
    }
}

private struct LookupResultSnippetView: View {
    let word: VocabularyWord
    let prepositionEntry: PrepositionEntry?
    let wasNewlySaved: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Top Row: Article + Word + CEFR + Saved Badge
            HStack(spacing: 6) {
                Text(word.articleOrType)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(word.category.badgeColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(word.category.badgeColor.opacity(0.15))
                    .cornerRadius(6)
                
                if let cefr = word.cefrLevel, !cefr.isEmpty {
                    Text(cefr)
                        .font(.system(size: 11, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.indigo)
                        .cornerRadius(5)
                }
                
                Spacer()
                
                HStack(spacing: 3) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 11))
                    Text(wasNewlySaved ? "Gespeichert (+5 Elo)" : "Im Wortschatz (\(word.learnScore)%)")
                        .font(.system(size: 11, weight: .bold))
                }
                .foregroundColor(.green)
            }
            
            // Main Word & English Translation
            VStack(alignment: .leading, spacing: 2) {
                Text(word.displayTitle)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                
                Text(word.englishDefinition)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.blue)
            }
            
            // German Definition
            Text(word.germanDefinition)
                .font(.system(size: 12))
                .foregroundColor(.primary)
                .lineLimit(2)
            
            // Optional Verb + Preposition Highlight
            if let prep = prepositionEntry {
                HStack(spacing: 5) {
                    Text("Präposition:")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.purple)
                    Text("\(prep.verb) \(prep.preposition) + \(prep.targetCase.fullName)")
                        .font(.system(size: 11, weight: .heavy))
                        .foregroundColor(.primary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.purple.opacity(0.12))
                .cornerRadius(6)
            }
            
            // Example Sentence
            Text("„\(word.b2Example.isEmpty ? word.b1Example : word.b2Example)“")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)
                .lineLimit(2)
        }
        .padding(14)
    }
}
