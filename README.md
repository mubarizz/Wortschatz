# Wortschatz 🇩🇪 ➔ 🎯 B2

Gamified German vocabulary learning app built natively in **SwiftUI**, engineered to bridge the gap between B1 and B2 fluency through Elo-driven spaced repetition and progressive context immersion.

## Core Features

- **Chess Elo Spaced Repetition (SRS):** Mathematically authentic FIDE Elo rating engine. The user and each vocabulary word maintain individual Elo ratings. Conquering difficult words raises your rank and reduces word challenge, pushing it back in the review queue.
- **Progressive Context Cloze Deletions:** Fill-in-the-blank challenges that adapt to mastery. New words present the standard **B1 Example** sentence; once mastery is demonstrated ($\ge 2$ consecutive wins or low Elo), the engine dynamically shifts to the richer **B2 Example** sentence.
- **Reverse-Engineering Quizzes:** 100% German immersion. The English definition is hidden, challenging you to deduce target vocabulary directly from nuanced German definitions.
- **Optimized for iPhone 13 mini:** High-density, compact layout designed specifically for 5.4-inch screens with $\ge 44\text{ pt}$ ergonomic touch targets and tab-based navigation.

## Architecture

```text
Wortschatz/
├── Models/
│   └── VocabularyWord.swift          # Core data model with Elo & B1/B2 state
├── Services/
│   ├── CSVParser.swift               # RFC 4180 CSV parser
│   └── EloEngine.swift               # FIDE-based Elo SRS calculation engine
├── ViewModels/
│   └── VocabularyStore.swift         # ObservableObject state manager & persistence
├── Views/
│   ├── ContentView.swift             # Root TabView navigation
│   ├── DashboardView.swift           # Elo progress banner & priority queue
│   ├── LibraryView.swift             # Searchable dictionary with article chips
│   ├── GameHubView.swift             # Game mode selector
│   ├── SettingsView.swift            # Profile, reset & CSV re-sync
│   └── Components/
│       ├── EloBadge.swift            # Rating indicator badge
│       ├── WordRowView.swift         # Compact list item
│       └── WordDetailSheet.swift     # Modal definitions & sentence inspector
└── Resources/
    └── wortschatz.csv                # Vocabulary dataset
```

## Dataset Format (`wortschatz.csv`)

| Column | Description |
|---|---|
| `Article/Type` | Grammatical gender (`der`, `die`, `das`) or part of speech (`Verb`, `Adjektiv`, etc.) |
| `Word` | Target German vocabulary |
| `English Definition` | Concise English translation |
| `German Definition` | Comprehensive German definition |
| `B1 Example` | Introductory context sentence |
| `B2 Example` | Advanced context sentence |
