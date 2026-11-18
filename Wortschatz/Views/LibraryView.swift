import SwiftUI
import UIKit

public struct LibraryView: View {
    @ObservedObject var store: VocabularyStore
    @State private var searchText: String = ""
    @State private var selectedFilter: String = "Alle"
    @State private var selectedWordForDetail: VocabularyWord?
    
    let filterOptions = ["Alle", "der", "die", "das", "Verb", "Adjektiv", "B2"]
    
    public init(store: VocabularyStore) {
        self.store = store
    }
    
    private var filteredWords: [VocabularyWord] {
        store.words.filter { word in
            let matchesSearch = searchText.isEmpty ||
                word.word.localizedCaseInsensitiveContains(searchText) ||
                word.englishDefinition.localizedCaseInsensitiveContains(searchText) ||
                word.germanDefinition.localizedCaseInsensitiveContains(searchText)
            
            if !matchesSearch { return false }
            
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
    }
    
    public var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                
                // Filter Chips (Compact horizontal scroll)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(filterOptions, id: \.self) { filter in
                            Button(action: { selectedFilter = filter }) {
                                Text(filter)
                                    .font(.system(size: 12, weight: selectedFilter == filter ? .bold : .medium))
                                    .foregroundColor(selectedFilter == filter ? .white : .primary)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(
                                        selectedFilter == filter ?
                                        Color.blue : Color(UIColor.secondarySystemBackground)
                                    )
                                    .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                }
                
                // Word Count & Queue Info
                HStack {
                    Text("\(filteredWords.count) Wörter")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("Nach Elo sortiert")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 4)
                
                // Words List
                List {
                    ForEach(filteredWords) { word in
                        WordRowView(word: word) {
                            selectedWordForDetail = word
                        }
                        .listRowInsets(EdgeInsets(top: 0, leading: 4, bottom: 0, trailing: 4))
                    }
                }
                .listStyle(.plain)
            }
            .navigationTitle("Wortschatz")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Wort oder Definition suchen...")
            .sheet(item: $selectedWordForDetail) { word in
                WordDetailSheet(word: word)
            }
        }
    }
}
