import SwiftUI
import UIKit

public enum LibraryMasteryFilter: String, CaseIterable {
    case all = "Alle"
    case unlearned = "Zu lernen"
    case learned = "Gelernt ✓"
}

public enum LibrarySortOrder: String, CaseIterable {
    case lowestScoreFirst = "Schwierigste (0% ➔ 100%)"
    case highestScoreFirst = "Gelernte (100% ➔ 0%)"
    case alphabetical = "Alphabetisch (A–Z)"
    case recentlyReviewed = "Zuletzt geübt"
}

private struct GeminiSearchSheetRequest: Identifiable {
    let id = UUID()
    let query: String
}

public struct LibraryView: View {
    @ObservedObject var store: VocabularyStore
    @State private var searchText: String = ""
    @State private var masteryFilter: LibraryMasteryFilter = .all
    @State private var sortOrder: LibrarySortOrder = .lowestScoreFirst
    @State private var selectedFilter: String = "Alle"
    @State private var selectedWordForDetail: VocabularyWord?
    @State private var geminiSearchRequest: GeminiSearchSheetRequest? = nil
    
    let filterOptions = ["Alle", "der", "die", "das", "Verb", "Adjektiv", "B2"]
    
    public init(store: VocabularyStore) {
        self.store = store
    }
    
    private var trimmedSearchText: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private var filteredWords: [VocabularyWord] {
        let query = trimmedSearchText
        let filtered = store.words.filter { word in
            // 1. Mastery segment filter
            switch masteryFilter {
            case .all:
                break
            case .unlearned:
                if word.isLearned { return false }
            case .learned:
                if !word.isLearned { return false }
            }
            
            // 2. Search text filter (handles articles, trailing keyboard spaces, and diacritics)
            let matchesSearch = query.isEmpty ||
                word.word.localizedStandardContains(query) ||
                word.displayTitle.localizedStandardContains(query) ||
                word.cleanTargetWord.localizedStandardContains(query) ||
                word.englishDefinition.localizedStandardContains(query) ||
                word.germanDefinition.localizedStandardContains(query)
            
            if !matchesSearch { return false }
            
            // 3. Category chip filter
            switch selectedFilter {
            case "Alle":
                return true
            case "der", "die", "das":
                return word.articleOrType.lowercased().contains(selectedFilter)
            case "Verb":
                return word.category == .verb
            case "Adjektiv":
                return word.category == .adjective
            case "B2":
                return word.isB2MasteryReached
            default:
                return true
            }
        }
        
        // 4. Sort order
        switch sortOrder {
        case .lowestScoreFirst:
            return filtered.sorted {
                if $0.learnScore != $1.learnScore {
                    return $0.learnScore < $1.learnScore
                }
                return $0.cleanTargetWord.localizedCompare($1.cleanTargetWord) == .orderedAscending
            }
        case .highestScoreFirst:
            return filtered.sorted {
                if $0.learnScore != $1.learnScore {
                    return $0.learnScore > $1.learnScore
                }
                return $0.cleanTargetWord.localizedCompare($1.cleanTargetWord) == .orderedAscending
            }
        case .alphabetical:
            return filtered.sorted {
                $0.cleanTargetWord.localizedCompare($1.cleanTargetWord) == .orderedAscending
            }
        case .recentlyReviewed:
            return filtered.sorted {
                ($0.lastReviewedAt ?? .distantPast) > ($1.lastReviewedAt ?? .distantPast)
            }
        }
    }
    
    public var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                
                // Mastery Status Segmented Control (Alle / Zu lernen / Gelernt)
                Picker("Lernstatus", selection: $masteryFilter) {
                    Text("Alle (\(store.words.count))").tag(LibraryMasteryFilter.all)
                    Text("Zu lernen (\(store.unlearnedWords.count))").tag(LibraryMasteryFilter.unlearned)
                    Text("Gelernt (\(store.learnedWords.count))").tag(LibraryMasteryFilter.learned)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 12)
                .padding(.top, 6)
                .padding(.bottom, 2)
                
                // Filter Chips (Compact horizontal scroll)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(filterOptions, id: \.self) { filter in
                            Button(action: {
                                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                    selectedFilter = filter
                                }
                            }) {
                                Text(filter)
                                    .font(.system(size: 12, weight: selectedFilter == filter ? .bold : .semibold, design: .rounded))
                                    .foregroundColor(selectedFilter == filter ? .white : .primary)
                                    .padding(.horizontal, 11)
                                    .padding(.vertical, 6)
                                    .background(
                                        Capsule()
                                            .fill(selectedFilter == filter ? Color(red: 0.14, green: 0.46, blue: 0.96) : Color(UIColor.secondarySystemGroupedBackground))
                                    )
                                    .overlay(
                                        Capsule()
                                            .strokeBorder(selectedFilter == filter ? Color.clear : Color.primary.opacity(0.08), lineWidth: 1)
                                    )
                            }
                            .buttonStyle(ScaleButtonStyle(scaleAmount: 0.95))
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                }
                
                // Word Count & Sort Picker Menu
                HStack {
                    Text("\(filteredWords.count) Wörter")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Menu {
                        ForEach(LibrarySortOrder.allCases, id: \.self) { order in
                            Button(action: { sortOrder = order }) {
                                HStack {
                                    Text(order.rawValue)
                                    if sortOrder == order {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.up.arrow.down")
                                .font(.system(size: 10, weight: .bold))
                            Text(sortOrder.rawValue)
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .foregroundColor(.blue)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 4)
                
                // Words List
                List {
                    if !trimmedSearchText.isEmpty {
                        Button(action: {
                            geminiSearchRequest = GeminiSearchSheetRequest(query: trimmedSearchText)
                        }) {
                            HStack(spacing: 10) {
                                ZStack {
                                    Circle()
                                        .fill(Color.indigo.opacity(0.15))
                                        .frame(width: 34, height: 34)
                                    Image(systemName: "sparkles")
                                        .font(.system(size: 15, weight: .bold))
                                        .foregroundColor(.indigo)
                                }
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("„\(trimmedSearchText)“ mit Gemini AI suchen")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(.indigo)
                                    Text("3 verwandte Vorschläge (A1–C2) generieren & hinzufügen")
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 18))
                                    .foregroundColor(.indigo)
                            }
                            .padding(.vertical, 6)
                        }
                    }
                    
                    ForEach(filteredWords) { word in
                        WordRowView(word: word) {
                            selectedWordForDetail = word
                        }
                        .listRowInsets(EdgeInsets(top: 1, leading: 6, bottom: 1, trailing: 6))
                        .alignmentGuide(.listRowSeparatorLeading) { _ in 72 }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                store.deleteWord(id: word.id)
                            } label: {
                                Label("Löschen", systemImage: "trash")
                            }
                        }
                    }
                }
                .listStyle(.plain)
            }
            .navigationTitle("Wortschatz")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        geminiSearchRequest = GeminiSearchSheetRequest(query: trimmedSearchText)
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "sparkles")
                            Text("Wort +")
                        }
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.indigo)
                        .cornerRadius(14)
                    }
                }
            }
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Wort suchen oder mit AI neu anlegen...")
            .onSubmit(of: .search) {
                if filteredWords.isEmpty && !trimmedSearchText.isEmpty {
                    geminiSearchRequest = GeminiSearchSheetRequest(query: trimmedSearchText)
                }
            }
            .sheet(item: $selectedWordForDetail) { word in
                WordDetailSheet(word: word, store: store)
            }
            .sheet(item: $geminiSearchRequest) { request in
                GeminiWordSearchSheet(store: store, initialQuery: request.query)
            }
        }
    }
}
