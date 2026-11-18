import SwiftUI
import UIKit

// MARK: - Generated Grammar Multiple-Choice Question
public struct StrukturSprintQuestion: Identifiable, Equatable {
    public let id = UUID()
    public let topic: GrammarTopic
    public let exercise: GrammarExercise
    public let sentencePrefix: String
    public let correctOption: String
    public let sentenceSuffix: String
    public let options: [String]
    public let correctIndex: Int
}

// MARK: - Smart Grammar Masking & Distractor Engine
public enum GrammarSprintEngine {
    
    public static func makeQuestion(for challenge: SatzbauChallenge) -> StrukturSprintQuestion {
        let sentence = challenge.exercise.targetSentence
        let topicId = challenge.topic.id
        
        let (targetToken, distractors) = extractTargetAndDistractors(sentence: sentence, topicId: topicId)
        
        // Split sentence around first occurrence of targetToken
        let prefix: String
        let suffix: String
        if let range = sentence.range(of: targetToken) {
            prefix = String(sentence[..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
            suffix = String(sentence[range.upperBound...]).trimmingCharacters(in: .whitespaces)
        } else {
            let tokens = challenge.exercise.expectedTokens
            let fallbackTarget = tokens.last ?? sentence
            prefix = tokens.dropLast().joined(separator: " ")
            suffix = "."
            return finalizeQuestion(
                challenge: challenge,
                prefix: prefix,
                target: fallbackTarget,
                suffix: suffix,
                distractors: distractors
            )
        }
        
        return finalizeQuestion(
            challenge: challenge,
            prefix: prefix,
            target: targetToken,
            suffix: suffix,
            distractors: distractors
        )
    }
    
    private static func finalizeQuestion(
        challenge: SatzbauChallenge,
        prefix: String,
        target: String,
        suffix: String,
        distractors: [String]
    ) -> StrukturSprintQuestion {
        var uniqueDistractors: [String] = []
        for d in distractors {
            let cleaned = d.trimmingCharacters(in: .whitespacesAndNewlines)
            if !cleaned.isEmpty && cleaned.lowercased() != target.lowercased() && !uniqueDistractors.contains(cleaned) {
                uniqueDistractors.append(cleaned)
            }
        }
        
        let fallbackPool = ["obwohl", "trotzdem", "deshalb", "während", "dessen", "darauf", "würde", "hatte"]
        for fb in fallbackPool where uniqueDistractors.count < 3 {
            if fb.lowercased() != target.lowercased() && !uniqueDistractors.contains(fb) {
                uniqueDistractors.append(fb)
            }
        }
        
        var allOptions = Array(uniqueDistractors.prefix(3))
        allOptions.append(target)
        allOptions.shuffle()
        let correctIdx = allOptions.firstIndex(of: target) ?? 0
        
        return StrukturSprintQuestion(
            topic: challenge.topic,
            exercise: challenge.exercise,
            sentencePrefix: prefix,
            correctOption: target,
            sentenceSuffix: suffix,
            options: allOptions,
            correctIndex: correctIdx
        )
    }
    
    private static func extractTargetAndDistractors(sentence: String, topicId: String) -> (String, [String]) {
        switch topicId {
        case "b1_nebensaetze_kausal_konzessiv":
            let connectors = ["obwohl", "weil", "da", "dass", "wenn", "als"]
            if let found = firstWholeWord(in: sentence, candidates: connectors) {
                let pool = ["trotzdem", "deshalb", "wegen", "obwohl", "weil", "dennoch", "damit"]
                return (found, pool.filter { $0.lowercased() != found.lowercased() })
            }
            
        case "b1_nebensatz_vorfeld":
            // Mask the comma + inverted verb pair: e.g. "dauerten, einigten"
            if let commaRange = sentence.range(of: ", ") {
                let beforeWords = sentence[..<commaRange.lowerBound].components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                let afterWords = sentence[commaRange.upperBound...].components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                if let lastSubVerb = beforeWords.last, afterWords.count >= 2 {
                    let mainVerb = afterWords[0]
                    let mainSubj = afterWords[1]
                    let correct = "\(lastSubVerb), \(mainVerb) \(mainSubj)"
                    let d1 = "\(lastSubVerb), \(mainSubj) \(mainVerb)"
                    let d2 = "\(mainVerb), \(lastSubVerb) \(mainSubj)"
                    let d3 = "\(lastSubVerb), weil \(mainSubj) \(mainVerb)"
                    return (correct, [d1, d2, d3])
                }
            }
            
        case "b1_infinitivsaetze_zu":
            let markers = ["um", "ohne", "anstatt"]
            if let found = firstWholeWord(in: sentence, candidates: markers) {
                return (found, ["damit", "weil", "sodass", "trotz", "um", "ohne", "anstatt"])
            }
            // Otherwise mask the "zu + Infinitiv" or separable "-zu-" verb at the end
            let words = cleanTokens(sentence)
            if let last = words.last, last.contains("zu") {
                let base = last.replacingOccurrences(of: "zu", with: "")
                return (last, ["zu \(base)", base, "\(base) zu"])
            }
            
        case "b1_indirekte_fragen":
            let qWords = ["ob", "warum", "wann", "wie viel", "wer", "wohin", "wie"]
            for qw in qWords {
                if let r = sentence.range(of: ", \(qw) ", options: .caseInsensitive) {
                    let matched = String(sentence[r]).replacingOccurrences(of: ",", with: "").trimmingCharacters(in: .whitespaces)
                    return (matched, ["dass", "weil", "ob", "wann", "warum", "welcher"])
                }
            }
            
        case "b2_zweiteilige_konnektoren":
            let secondParts = ["desto", "umso", "sondern auch", "aber", "noch", "als auch"]
            for part in secondParts {
                if sentence.localizedCaseInsensitiveContains(part),
                   let r = sentence.range(of: part, options: .caseInsensitive) {
                    let exact = String(sentence[r])
                    return (exact, ["desto", "trotzdem", "sondern auch", "als auch", "oder", "deshalb"])
                }
            }
            
        case "b2_adverbiale_konnektoren":
            let advs = ["deshalb", "trotzdem", "dennoch", "folglich", "allerdings", "stattdessen"]
            for adv in advs {
                if let r = sentence.range(of: ", \(adv) ", options: .caseInsensitive) {
                    let after = sentence[r.upperBound...].components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                    if after.count >= 2 {
                        let verb = after[0]
                        let subj = after[1]
                        let matchedAdv = String(sentence[r]).replacingOccurrences(of: ",", with: "").trimmingCharacters(in: .whitespaces)
                        let correct = "\(matchedAdv) \(verb)"
                        return (correct, ["\(matchedAdv) \(subj)", "weil \(verb)", "obwohl \(subj)"])
                    }
                }
            }
            
        case "b2_doppelter_infinitiv":
            let words = cleanTokens(sentence)
            if words.count >= 3 {
                let tail3 = words.suffix(3).joined(separator: " ")
                let w1 = words[words.count - 3]
                let w2 = words[words.count - 2]
                let w3 = words[words.count - 1]
                return (tail3, [
                    "\(w2) \(w3) \(w1)",
                    "\(w3) \(w2) \(w1)",
                    "\(w1) zu \(w2) \(w3)"
                ])
            }
            
        case "b1_plusquamperfekt_nachdem":
            if let commaRange = sentence.range(of: ",") {
                let before = sentence[..<commaRange.lowerBound].components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                if before.count >= 2 {
                    let part = before[before.count - 2]
                    let aux = before[before.count - 1]
                    let correct = "\(part) \(aux)"
                    return (correct, ["\(aux) \(part)", "\(part) wird", "\(part) würde"])
                }
            }
            
        case "b1_vorgangspassiv":
            let passives = ["wird", "wurden", "wurde", "werden"]
            if let found = firstWholeWord(in: sentence, candidates: passives) {
                return (found, ["hat", "ist", "würde", "waren", "wird", "wurde"])
            }
            
        case "b1_konjunktiv2_gegenwart":
            let k2 = ["wäre,", "hätte,", "läge,", "würden,", "wären,", "hätten,", "würde,", "gäbe,", "wüsste,", "würdest,", "würden", "könnten", "würde"]
            for form in k2 {
                if let r = sentence.range(of: form) {
                    let exact = String(sentence[r]).replacingOccurrences(of: ",", with: "")
                    return (exact, ["ist", "hat", "wird", "kann", "war", "wurde"])
                }
            }
            
        case "b2_konjunktiv2_vergangenheit":
            let k2past = ["hätten,", "hätte,", "hättest,", "wäre,", "wären,", "hätten", "hättest"]
            for form in k2past {
                if let r = sentence.range(of: form) {
                    let exact = String(sentence[r]).replacingOccurrences(of: ",", with: "")
                    return (exact, ["hatten", "würden", "sind", "waren", "haben"])
                }
            }
            
        case "b2_passiv_modalverben_ersatz":
            let patterns = ["lässt sich", "lassen sich", "sind jederzeit unter Verschluss aufzubewahren", "ist bis Ende Mai beim Finanzamt einzureichen", "eingehalten werden", "eingereicht werden", "zu beachten"]
            for pat in patterns {
                if let r = sentence.range(of: pat) {
                    let exact = String(sentence[r])
                    return (exact, ["hat sich", "wird zu", "muss gemacht", "kann beheben", "ist beachtet"])
                }
            }
            
        case "b2_subjektive_modalverben":
            let modals = ["dürften", "soll", "muss", "will", "müsste"]
            if let found = firstWholeWord(in: sentence, candidates: modals) {
                return (found, ["soll", "will", "dürfte", "muss", "kann", "möchte"].filter { $0 != found })
            }
            
        case "b2_konjunktiv1_indirekte_rede":
            let k1 = ["gebe", "habe", "seien", "werde", "sei"]
            if let found = firstWholeWord(in: sentence, candidates: k1) {
                return (found, ["gibt", "hatte", "wäre", "wurde", "ist", "hat"])
            }
            
        case "b2_funktionsverbgefuege":
            let fvgs = ["Entscheidung über das Budget treffen", "Rücksicht nehmen", "in Frage", "zur Sprache bringen", "zur Verfügung", "Entscheidung treffen"]
            for fvg in fvgs {
                if let r = sentence.range(of: fvg) {
                    let exact = String(sentence[r])
                    return (exact, ["Entscheidung machen", "Rücksicht geben", "im Frage", "zur Verfügung haben", "zur Sprache nehmen"])
                }
            }
            
        case "b1_relativsaetze_kasus":
            let rels = ["mit dem", "mit der", "für das", "bei dem", "auf die", "über das", "von dem", "an das", "mit denen", "denen", "auf den", "über den", "die"]
            for rel in rels {
                if let r = sentence.range(of: ", \(rel) ") {
                    let exact = String(sentence[r]).replacingOccurrences(of: ",", with: "").trimmingCharacters(in: .whitespaces)
                    return (exact, ["mit den", "für dem", "über den", "auf dem", "dessen", "wo", "mit dem", "mit der"])
                }
            }
            
        case "b1_verben_praepositionen":
            let pronAdvs = ["darauf,", "damit,", "daran,", "dafür", "davon", "darauf", "von einer", "über die", "bei Ihnen für"]
            for pa in pronAdvs {
                if let r = sentence.range(of: pa) {
                    let exact = String(sentence[r]).replacingOccurrences(of: ",", with: "")
                    return (exact, ["darüber", "dazu", "worauf", "daran", "damit", "davon", "über den"])
                }
            }
            
        case "b1_n_deklination":
            let ndeks = ["den neuen Kunden", "dem internationalen Experten", "des kritischen Journalisten", "den jungen Praktikanten", "dem besten Doktoranden", "den berühmten Architekten", "des einzigen Zeugen", "dem nervösen Patienten", "meinen freundlichen Nachbarn", "den jungen Patienten", "unserem neuen Nachbarn"]
            for nd in ndeks {
                if let r = sentence.range(of: nd) {
                    let exact = String(sentence[r])
                    let wrongNoN = String(exact.dropLast(exact.hasSuffix("en") ? 2 : 1))
                    let wrongKasus = exact.replacingOccurrences(of: "den ", with: "dem ").replacingOccurrences(of: "dem ", with: "den ")
                    return (exact, [wrongNoN, wrongKasus, "der " + wrongNoN])
                }
            }
            
        case "b2_genitiv_praepositionen":
            let genPreps = ["Trotz der", "Aufgrund der", "Während der", "Infolge des", "Angesichts der", "Anstelle eines", "Außerhalb der", "Innerhalb des", "Wegen eines", "Trotz des", "Aufgrund einer"]
            for gp in genPreps {
                if let r = sentence.range(of: gp) {
                    let exact = String(sentence[r])
                    let prepOnly = exact.components(separatedBy: " ").first ?? "Trotz"
                    return (exact, ["\(prepOnly) den", "\(prepOnly) dem", "\(prepOnly) die", "Weil der"])
                }
            }
            
        case "b2_relativsaetze_genitiv_wo_was":
            let genRels = ["dessen", "deren", "was"]
            for gr in genRels {
                if let r = sentence.range(of: ", \(gr) ") {
                    let exact = String(sentence[r]).replacingOccurrences(of: ",", with: "").trimmingCharacters(in: .whitespaces)
                    return (exact, ["dem", "denen", "der", "welcher", "das", "dessen", "deren", "was"])
                }
            }
            
        case "b2_partizipialattribute":
            let parts = ["beschlossenen", "entwickelte", "unterzeichnete", "veröffentlichte", "gelieferten", "steigenden", "geltenden", "arbeitenden", "abgeschlossene", "ausgehandelte", "festgelegten", "zufriedenstellenden"]
            if let found = firstWholeWord(in: sentence, candidates: parts) {
                return (found, ["\(found)d", String(found.dropLast(2)), "zu \(found)", "\(found)er"])
            }
            
        case "b2_nominalisierung_verbalisierung":
            let noms = ["Vor der Unterzeichnung", "Durch die regelmäßige", "Bei der Ankunft", "Nach dem Abschluss", "Zur Senkung", "Ohne die vorherige", "Bei der Bearbeitung", "Durch den Einsatz", "Vor der Einführung", "Nach der Präsentation", "Vor dem Abschluss", "Durch regelmäßiges"]
            for nom in noms {
                if let r = sentence.range(of: nom) {
                    let exact = String(sentence[r])
                    return (exact, ["Bevor die Unterzeichnung", "Weil die regelmäßige", "Während dem Abschluss", "Damit die Senkung"])
                }
            }
            
        default:
            break
        }
        
        // General fallback: mask the final verb/token of the sentence
        let tokens = cleanTokens(sentence)
        let target = tokens.last ?? "ist"
        return (target, ["wäre", "hatte", "wurde", "könnte"])
    }
    
    private static func firstWholeWord(in sentence: String, candidates: [String]) -> String? {
        let tokens = cleanTokens(sentence)
        for cand in candidates {
            if let match = tokens.first(where: { $0.lowercased() == cand.lowercased() }) {
                return match
            }
        }
        return nil
    }
    
    private static func cleanTokens(_ sentence: String) -> [String] {
        sentence
            .replacingOccurrences(of: #"[.,;!?]"#, with: "", options: .regularExpression)
            .components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }
    }
}

// MARK: - Game #2 View: Struktur- & Kasus-Sprint
public struct StrukturSprintGameView: View {
    @ObservedObject var grammarStore: GrammarStore
    @ObservedObject var vocabStore: VocabularyStore
    let initialFocusTopic: GrammarTopic?
    let initialLevelFilter: String?
    
    @Environment(\.dismiss) private var dismiss
    
    @State private var questions: [StrukturSprintQuestion] = []
    @State private var currentIndex: Int = 0
    @State private var selectedOptionIndex: Int? = nil
    @State private var isAnswerLocked: Bool = false
    @State private var latestResult: GrammarAttemptResult? = nil
    @State private var showingRuleSheet: Bool = false
    @State private var isSessionComplete: Bool = false
    @State private var sessionCorrectCount: Int = 0
    @State private var startingUserElo: Double = 1200.0
    
    public init(
        grammarStore: GrammarStore,
        vocabStore: VocabularyStore,
        focusTopic: GrammarTopic? = nil,
        levelFilter: String? = nil
    ) {
        self.grammarStore = grammarStore
        self.vocabStore = vocabStore
        self.initialFocusTopic = focusTopic
        self.initialLevelFilter = levelFilter
    }
    
    private var currentQuestion: StrukturSprintQuestion? {
        guard currentIndex < questions.count else { return nil }
        return questions[currentIndex]
    }
    
    public var body: some View {
        NavigationView {
            ZStack {
                Color(UIColor.systemGroupedBackground)
                    .ignoresSafeArea()
                
                if isSessionComplete {
                    sessionCompleteView
                } else if let q = currentQuestion {
                    activeQuestionView(question: q)
                } else {
                    emptyStateView
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: {
                        AudioSpeaker.shared.stop()
                        dismiss()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.secondary)
                    }
                }
                
                ToolbarItem(placement: .principal) {
                    if !questions.isEmpty && !isSessionComplete {
                        VStack(spacing: 2) {
                            Text("Kasus- & Konnektoren-Sprint")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                            Text("\(currentIndex + 1) von \(questions.count)")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    if let q = currentQuestion {
                        let liveTopic = grammarStore.topics.first(where: { $0.id == q.topic.id }) ?? q.topic
                        LearnScoreBadge(
                            score: liveTopic.learnScore,
                            reviewsCount: liveTopic.reviewsCount,
                            showLabel: false,
                            compact: true
                        )
                    }
                }
            }
            .sheet(isPresented: $showingRuleSheet) {
                if let q = currentQuestion {
                    let liveTopic = grammarStore.topics.first(where: { $0.id == q.topic.id }) ?? q.topic
                    GrammarTopicDetailSheet(
                        topic: liveTopic,
                        onStartTopicPractice: nil
                    )
                }
            }
            .onAppear {
                startNewSession()
            }
            .onDisappear {
                AudioSpeaker.shared.stop()
            }
        }
    }
    
    @ViewBuilder
    private func activeQuestionView(question: StrukturSprintQuestion) -> some View {
        VStack(spacing: 0) {
            
            // Progress Bar
            GeometryReader { geo in
                let progress = CGFloat(currentIndex) / CGFloat(max(1, questions.count))
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.primary.opacity(0.08))
                        .frame(height: 4)
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [Color(red: 0.53, green: 0.28, blue: 0.92), .teal],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * progress, height: 4)
                        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: progress)
                }
            }
            .frame(height: 4)
            
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 12) {
                    
                    // 1. Topic Header & Spickzettel Button
                    HStack(spacing: 8) {
                        Text(question.topic.level)
                            .font(.system(size: 10, weight: .heavy, design: .rounded))
                            .foregroundColor(.white)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(question.topic.level == "B2" ? Color.purple : Color.blue)
                            .cornerRadius(6)
                        
                        Text(question.topic.title)
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        
                        Spacer()
                        
                        Button(action: {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            showingRuleSheet = true
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "book.pages.fill")
                                Text("Regel")
                            }
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(.purple)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 4)
                            .background(Color.purple.opacity(0.12))
                            .cornerRadius(8)
                        }
                        .buttonStyle(ScaleButtonStyle(scaleAmount: 0.95))
                    }
                    .padding(.top, 6)
                    
                    // 2. German Sentence Card with Highlighted Gap
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Label("Wähle die korrekte Struktur", systemImage: "scope")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.purple)
                            Spacer()
                            if isAnswerLocked {
                                Button(action: {
                                    AudioSpeaker.shared.speak(text: question.exercise.targetSentence)
                                }) {
                                    Image(systemName: "speaker.wave.2.fill")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundColor(.purple)
                                        .padding(6)
                                        .background(Color.purple.opacity(0.12))
                                        .clipShape(Circle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        
                        let gapText = isAnswerLocked ? question.correctOption : " ______ "
                        (Text(question.sentencePrefix.isEmpty ? "" : question.sentencePrefix + " ")
                            .font(.system(size: 17, weight: .semibold, design: .rounded))
                         + Text("[\(gapText)]")
                            .font(.system(size: 17, weight: .black, design: .rounded))
                            .foregroundColor(isAnswerLocked ? .green : .purple)
                         + Text(question.sentenceSuffix.isEmpty ? "" : " " + question.sentenceSuffix)
                            .font(.system(size: 17, weight: .semibold, design: .rounded)))
                            .lineSpacing(4)
                            .foregroundColor(.primary)
                        
                        Divider()
                            .opacity(0.6)
                        
                        // English Context Translation
                        HStack(alignment: .top, spacing: 6) {
                            Image(systemName: "translate")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                                .padding(.top, 2)
                            Text(question.exercise.englishPrompt)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color(UIColor.secondarySystemGroupedBackground))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
                    )
                    
                    // 3. 4 Multiple-Choice Options
                    VStack(spacing: 9) {
                        ForEach(0..<question.options.count, id: \.self) { idx in
                            optionButton(option: question.options[idx], index: idx, question: question)
                        }
                    }
                    
                    // 4. Post-Answer Rule Callout & Next Button
                    if isAnswerLocked {
                        feedbackSection(question: question)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 20)
            }
        }
    }
    
    @ViewBuilder
    private func optionButton(option: String, index: Int, question: StrukturSprintQuestion) -> some View {
        let isSelected = selectedOptionIndex == index
        let isCorrectTarget = index == question.correctIndex
        
        Button(action: {
            guard !isAnswerLocked else { return }
            selectOption(index: index, question: question)
        }) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(badgeBackground(isSelected: isSelected, isCorrect: isCorrectTarget))
                        .frame(width: 28, height: 28)
                    Text(["A", "B", "C", "D"][index])
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(badgeForeground(isSelected: isSelected, isCorrect: isCorrectTarget))
                }
                
                Text(option)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(textForeground(isSelected: isSelected, isCorrect: isCorrectTarget))
                    .multilineTextAlignment(.leading)
                
                Spacer()
                
                if isAnswerLocked {
                    if isCorrectTarget {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.green)
                    } else if isSelected {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.red)
                    }
                }
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 52)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(rowBackground(isSelected: isSelected, isCorrect: isCorrectTarget))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(rowBorder(isSelected: isSelected, isCorrect: isCorrectTarget), lineWidth: isAnswerLocked && (isSelected || isCorrectTarget) ? 2 : 1)
            )
            .shadow(color: Color.black.opacity(0.025), radius: 4, y: 2)
        }
        .buttonStyle(ScaleButtonStyle(scaleAmount: 0.97))
        .disabled(isAnswerLocked)
    }
    
    @ViewBuilder
    private func feedbackSection(question: StrukturSprintQuestion) -> some View {
        let wasCorrect = selectedOptionIndex == question.correctIndex
        
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: wasCorrect ? "checkmark.seal.fill" : "xmark.circle.fill")
                        .foregroundColor(wasCorrect ? .green : .red)
                    Text(wasCorrect ? "Richtig erkannt!" : "Nicht ganz!")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(wasCorrect ? .green : .red)
                }
                
                Spacer()
                
                if let res = latestResult {
                    Text(res.scoreDelta >= 0 ? "+\(res.scoreDelta)% ➔ \(res.newScore)%" : "\(res.scoreDelta)% ➔ \(res.newScore)%")
                        .font(.system(size: 12, weight: .heavy, design: .rounded))
                        .foregroundColor(res.scoreDelta >= 0 ? .green : .red)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background((res.scoreDelta >= 0 ? Color.green : Color.red).opacity(0.12))
                        .cornerRadius(6)
                }
            }
            
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(.orange)
                    .font(.system(size: 13))
                    .padding(.top, 2)
                Text(question.exercise.ruleCallout)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.primary)
                    .lineSpacing(2)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.orange.opacity(0.10))
            .cornerRadius(10)
            
            Button(action: advanceToNext) {
                HStack(spacing: 6) {
                    Text("Nächste Frage")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                    Image(systemName: "arrow.right")
                        .font(.system(size: 13, weight: .bold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 46)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(wasCorrect ? Color.green : Color.purple)
                )
            }
            .buttonStyle(ScaleButtonStyle(scaleAmount: 0.97))
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(UIColor.secondarySystemGroupedBackground))
        )
    }
    
    // MARK: - Actions & Styling
    private func selectOption(index: Int, question: StrukturSprintQuestion) {
        selectedOptionIndex = index
        isAnswerLocked = true
        let correct = (index == question.correctIndex)
        
        if correct {
            sessionCorrectCount += 1
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } else {
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
        
        latestResult = grammarStore.recordAttempt(
            topicId: question.topic.id,
            success: correct,
            vocabStore: vocabStore
        )
        
        AudioSpeaker.shared.speak(text: question.exercise.targetSentence, rate: 0.47)
    }
    
    private func advanceToNext() {
        AudioSpeaker.shared.stop()
        selectedOptionIndex = nil
        isAnswerLocked = false
        latestResult = nil
        
        if currentIndex + 1 < questions.count {
            currentIndex += 1
        } else {
            isSessionComplete = true
        }
    }
    
    private func startNewSession() {
        AudioSpeaker.shared.stop()
        startingUserElo = vocabStore.userElo
        sessionCorrectCount = 0
        currentIndex = 0
        selectedOptionIndex = nil
        isAnswerLocked = false
        isSessionComplete = false
        
        let rawChallenges = grammarStore.generateSatzbauSession(
            focusTopic: initialFocusTopic,
            levelFilter: initialLevelFilter,
            count: 10
        )
        questions = rawChallenges.map { GrammarSprintEngine.makeQuestion(for: $0) }
    }
    
    private func rowBackground(isSelected: Bool, isCorrect: Bool) -> Color {
        if !isAnswerLocked { return Color(UIColor.secondarySystemGroupedBackground) }
        if isCorrect { return Color.green.opacity(0.12) }
        if isSelected { return Color.red.opacity(0.12) }
        return Color(UIColor.secondarySystemGroupedBackground).opacity(0.6)
    }
    
    private func rowBorder(isSelected: Bool, isCorrect: Bool) -> Color {
        if !isAnswerLocked { return Color.primary.opacity(0.08) }
        if isCorrect { return .green }
        if isSelected { return .red }
        return .clear
    }
    
    private func badgeBackground(isSelected: Bool, isCorrect: Bool) -> Color {
        if !isAnswerLocked { return Color(UIColor.tertiarySystemFill) }
        if isCorrect { return .green }
        if isSelected { return .red }
        return Color(UIColor.tertiarySystemFill)
    }
    
    private func badgeForeground(isSelected: Bool, isCorrect: Bool) -> Color {
        if isAnswerLocked && (isCorrect || isSelected) { return .white }
        return .primary
    }
    
    private func textForeground(isSelected: Bool, isCorrect: Bool) -> Color {
        if isAnswerLocked && isCorrect { return .green }
        if isAnswerLocked && isSelected { return .red }
        return .primary
    }
    
    private var sessionCompleteView: some View {
        VStack(spacing: 20) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(Color.purple.opacity(0.14))
                    .frame(width: 84, height: 84)
                Image(systemName: "bolt.horizontal.circle.fill")
                    .font(.system(size: 42))
                    .foregroundColor(.purple)
            }
            
            VStack(spacing: 6) {
                Text("Struktur-Sprint Abgeschlossen!")
                    .font(.system(size: 22, weight: .black, design: .rounded))
                    .foregroundColor(.primary)
                
                Text("\(sessionCorrectCount) von \(questions.count) Strukturen richtig erkannt")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
            }
            
            VStack(spacing: 6) {
                let eloDelta = vocabStore.userElo - startingUserElo
                HStack(spacing: 6) {
                    Text("Neues Elo-Rating:")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.secondary)
                    Text("\(Int(round(vocabStore.userElo)))")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    Text(eloDelta >= 0 ? "(+\(Int(round(eloDelta))))" : "(\(Int(round(eloDelta))))")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(eloDelta >= 0 ? .green : .red)
                }
                Text("Grammatik Lern-Scores wurden aktualisiert.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            .padding(14)
            .frame(maxWidth: .infinity)
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .cornerRadius(14)
            .padding(.horizontal, 24)
            
            Spacer()
            
            VStack(spacing: 10) {
                Button(action: startNewSession) {
                    Text("Nächste 10 Fragen starten")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(Color.purple)
                        .cornerRadius(12)
                }
                .buttonStyle(ScaleButtonStyle(scaleAmount: 0.97))
                
                Button(action: {
                    AudioSpeaker.shared.stop()
                    dismiss()
                }) {
                    Text("Zurück zur Grammatik")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 14)
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "scope")
                .font(.system(size: 40))
                .foregroundColor(.purple)
            Text("Keine Fragen gefunden")
                .font(.system(size: 16, weight: .bold))
            Button("Neu laden", action: startNewSession)
        }
    }
}
