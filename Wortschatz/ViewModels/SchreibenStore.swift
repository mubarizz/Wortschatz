import Foundation
import Combine

public final class SchreibenStore: ObservableObject {
    @Published public private(set) var builtInTasks: [SchreibenTask] = []
    @Published public private(set) var customTasks: [SchreibenTask] = []
    @Published public private(set) var submissions: [SchreibenSubmission] = []
    @Published public private(set) var activeDrafts: [String: String] = [:]
    @Published public private(set) var activeDraftDurations: [String: Int] = [:]
    
    private let submissionsKey = "wortschatz_schreiben_submissions_v1"
    private let customTasksKey = "wortschatz_schreiben_custom_tasks_v1"
    private let draftsKey = "wortschatz_schreiben_drafts_v1"
    private let draftDurationsKey = "wortschatz_schreiben_draft_durations_v1"
    
    public init() {
        self.builtInTasks = Self.makeBuiltInGoetheTasks()
        loadPersistedData()
    }
    
    // MARK: - Task Queries
    public var allTasks: [SchreibenTask] {
        customTasks + builtInTasks
    }
    
    public func tasks(for teil: SchreibenExamTeil) -> [SchreibenTask] {
        allTasks.filter { $0.teil == teil }
    }
    
    public func tasks(for level: SchreibenExamLevel) -> [SchreibenTask] {
        allTasks.filter { $0.level == level }
    }
    
    // MARK: - Draft & Timer Management (100% Offline Safe)
    public func draft(for taskId: String) -> String {
        activeDrafts[taskId] ?? ""
    }
    
    public func draftDuration(for taskId: String) -> Int {
        activeDraftDurations[taskId] ?? 0
    }
    
    public func updateDraft(_ text: String, durationSeconds: Int? = nil, for taskId: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            activeDrafts.removeValue(forKey: taskId)
            activeDraftDurations.removeValue(forKey: taskId)
        } else {
            activeDrafts[taskId] = text
            if let dur = durationSeconds {
                activeDraftDurations[taskId] = dur
            }
        }
        saveDrafts()
    }
    
    public func clearDraft(for taskId: String) {
        activeDrafts.removeValue(forKey: taskId)
        activeDraftDurations.removeValue(forKey: taskId)
        saveDrafts()
    }
    
    // MARK: - Submissions & Offline Queue
    public var pendingOfflineSubmissions: [SchreibenSubmission] {
        submissions
            .filter { $0.status == .pendingOfflineEvaluation }
            .sorted { $0.submittedAt > $1.submittedAt }
    }
    
    public var evaluatedSubmissions: [SchreibenSubmission] {
        submissions
            .filter { $0.status == .evaluated && $0.evaluation != nil }
            .sorted { $0.submittedAt > $1.submittedAt }
    }
    
    public func submissions(for taskId: String) -> [SchreibenSubmission] {
        submissions
            .filter { $0.task.id == taskId }
            .sorted { $0.submittedAt > $1.submittedAt }
    }
    
    public func bestScore(for taskId: String) -> Int? {
        submissions(for: taskId)
            .compactMap { $0.evaluation?.totalScore }
            .max()
    }
    
    /// Saves a completed exam locally while offline so it can be evaluated later when internet is available.
    @discardableResult
    public func saveOfflineSubmission(
        task: SchreibenTask,
        userText: String,
        durationSeconds: Int
    ) -> SchreibenSubmission {
        let trimmed = userText.trimmingCharacters(in: .whitespacesAndNewlines)
        let wordCount = trimmed.split { $0.isWhitespace || $0.isNewline }.count
        let submission = SchreibenSubmission(
            task: task,
            userText: trimmed,
            wordCount: wordCount,
            submittedAt: Date(),
            durationSeconds: durationSeconds,
            status: .pendingOfflineEvaluation,
            evaluation: nil,
            evaluatedModel: nil
        )
        submissions.insert(submission, at: 0)
        clearDraft(for: task.id)
        saveSubmissions()
        return submission
    }
    
    /// Evaluates a new exam text live with Gemini 3 Flash, calculates Elo change, and records the score.
    @MainActor
    public func submitAndEvaluate(
        task: SchreibenTask,
        userText: String,
        durationSeconds: Int,
        vocabStore: VocabularyStore? = nil,
        existingSubmissionId: UUID? = nil
    ) async throws -> SchreibenSubmission {
        let trimmed = userText.trimmingCharacters(in: .whitespacesAndNewlines)
        let wordCount = trimmed.split { $0.isWhitespace || $0.isNewline }.count
        let evaluation = try await GeminiService.shared.evaluateSchreiben(task: task, userText: trimmed)
        let modelUsed = GeminiService.shared.lastUsedModel
        
        // Calculate Elo rating change based on Goethe exam score, level (B1/B2), and time limit
        let eloResult = SchreibenEloCalculator.calculateEloDelta(
            task: task,
            evaluation: evaluation,
            durationSeconds: durationSeconds
        )
        
        var updatedUserElo: Double? = nil
        if let store = vocabStore {
            let nextElo = max(1000.0, store.userElo + eloResult.delta)
            store.userElo = nextElo
            store.totalReviews += 1
            store.lastStudyDate = Date()
            store.saveWordsToDisk()
            updatedUserElo = nextElo
        }
        
        if let existingId = existingSubmissionId,
           let index = submissions.firstIndex(where: { $0.id == existingId }) {
            submissions[index].userText = trimmed
            submissions[index].wordCount = wordCount
            submissions[index].status = .evaluated
            submissions[index].evaluation = evaluation
            submissions[index].evaluatedModel = modelUsed
            submissions[index].eloDelta = eloResult.delta
            submissions[index].newUserElo = updatedUserElo
            submissions[index].timeBonusAwarded = eloResult.timeBonus
            clearDraft(for: task.id)
            saveSubmissions()
            return submissions[index]
        } else {
            let submission = SchreibenSubmission(
                task: task,
                userText: trimmed,
                wordCount: wordCount,
                submittedAt: Date(),
                durationSeconds: durationSeconds,
                status: .evaluated,
                evaluation: evaluation,
                evaluatedModel: modelUsed,
                eloDelta: eloResult.delta,
                newUserElo: updatedUserElo,
                timeBonusAwarded: eloResult.timeBonus
            )
            submissions.insert(submission, at: 0)
            clearDraft(for: task.id)
            saveSubmissions()
            return submission
        }
    }
    
    /// Evaluates a previously saved offline submission when the user is back online.
    @MainActor
    public func evaluatePendingSubmission(
        _ submission: SchreibenSubmission,
        vocabStore: VocabularyStore? = nil
    ) async throws -> SchreibenSubmission {
        return try await submitAndEvaluate(
            task: submission.task,
            userText: submission.userText,
            durationSeconds: submission.durationSeconds,
            vocabStore: vocabStore,
            existingSubmissionId: submission.id
        )
    }
    
    public func deleteSubmission(id: UUID) {
        submissions.removeAll { $0.id == id }
        saveSubmissions()
    }
    
    // MARK: - AI Task Generation (Persisted Locally After Generation)
    @MainActor
    public func generateNewTask(for teil: SchreibenExamTeil) async throws -> SchreibenTask {
        let existingTitles = tasks(for: teil).map { $0.title }
        let newTask = try await GeminiService.shared.generateSchreibenTask(
            teil: teil,
            existingTitles: existingTitles
        )
        customTasks.insert(newTask, at: 0)
        saveCustomTasks()
        return newTask
    }
    
    // MARK: - Analytics & Weak-Point Engine
    public var overallAverageScore: Int {
        let scores = evaluatedSubmissions.compactMap { $0.evaluation?.totalScore }
        guard !scores.isEmpty else { return 0 }
        let sum = scores.reduce(0, +)
        return Int((Double(sum) / Double(scores.count)).rounded())
    }
    
    public var overallBestScore: Int {
        evaluatedSubmissions.compactMap { $0.evaluation?.totalScore }.max() ?? 0
    }
    
    public var overallPassRatePercentage: Int {
        let evaluated = evaluatedSubmissions
        guard !evaluated.isEmpty else { return 0 }
        let passedCount = evaluated.filter { $0.evaluation?.passed == true }.count
        return Int((Double(passedCount) / Double(evaluated.count) * 100.0).rounded())
    }
    
    public func statistics(for teil: SchreibenExamTeil) -> SchreibenTeilStatistics {
        let teilSubs = evaluatedSubmissions.filter { $0.task.teil == teil }
        let evals = teilSubs.compactMap { $0.evaluation }
        guard !evals.isEmpty else {
            return SchreibenTeilStatistics(
                teil: teil,
                attemptCount: 0,
                averageScore: 0,
                bestScore: 0,
                passCount: 0,
                avgErfuellung: 0,
                avgKohaerenz: 0,
                avgWortschatz: 0,
                avgStrukturen: 0
            )
        }
        let count = Double(evals.count)
        let totalSum = evals.map { $0.totalScore }.reduce(0, +)
        let best = evals.map { $0.totalScore }.max() ?? 0
        let passed = evals.filter { $0.passed }.count
        
        let erfuellung = Double(evals.map { $0.erfuellungScore }.reduce(0, +)) / count
        let kohaerenz = Double(evals.map { $0.kohaerenzScore }.reduce(0, +)) / count
        let wortschatz = Double(evals.map { $0.wortschatzScore }.reduce(0, +)) / count
        let strukturen = Double(evals.map { $0.strukturenScore }.reduce(0, +)) / count
        
        return SchreibenTeilStatistics(
            teil: teil,
            attemptCount: evals.count,
            averageScore: Int((Double(totalSum) / count).rounded()),
            bestScore: best,
            passCount: passed,
            avgErfuellung: erfuellung,
            avgKohaerenz: kohaerenz,
            avgWortschatz: wortschatz,
            avgStrukturen: strukturen
        )
    }
    
    public var allTeilStatistics: [SchreibenTeilStatistics] {
        SchreibenExamTeil.allCases.map { statistics(for: $0) }
    }
    
    /// Returns the weakest exam Teil among those attempted at least once.
    public var weakestTeil: SchreibenTeilStatistics? {
        allTeilStatistics
            .filter { $0.attemptCount > 0 }
            .min(by: { $0.averageScore < $1.averageScore })
    }
    
    /// Returns the strongest exam Teil among those attempted at least once.
    public var strongestTeil: SchreibenTeilStatistics? {
        allTeilStatistics
            .filter { $0.attemptCount > 0 }
            .max(by: { $0.averageScore < $1.averageScore })
    }
    
    public var criterionWeaknesses: [SchreibenCriterionWeakness] {
        let evals = evaluatedSubmissions.compactMap { $0.evaluation }
        guard !evals.isEmpty else { return [] }
        let count = Double(evals.count)
        
        let avgErf = Double(evals.map { $0.erfuellungScore }.reduce(0, +)) / count
        let avgKoh = Double(evals.map { $0.kohaerenzScore }.reduce(0, +)) / count
        let avgWor = Double(evals.map { $0.wortschatzScore }.reduce(0, +)) / count
        let avgStr = Double(evals.map { $0.strukturenScore }.reduce(0, +)) / count
        
        return [
            SchreibenCriterionWeakness(
                id: "erfuellung",
                title: "Erfüllung & Leitpunkte",
                averageOutOf25: avgErf,
                advice: "Achte darauf, zu jedem der 3–4 Leitpunkte mindestens 2 konkrete Sätze zu schreiben und das geforderte Register (Du vs. Sie) einzuhalten."
            ),
            SchreibenCriterionWeakness(
                id: "kohaerenz",
                title: "Kohärenz & Textaufbau",
                averageOutOf25: avgKoh,
                advice: "Verbinde deine Sätze aktiv mit B1/B2-Konnektoren (obwohl, infolgedessen, einerseits... andererseits) und gliedere den Text in klare Absätze."
            ),
            SchreibenCriterionWeakness(
                id: "wortschatz",
                title: "Wortschatz & Ausdruck",
                averageOutOf25: avgWor,
                advice: "Vermeide Wortwiederholungen (wie 'machen', 'gut', 'sagen') und nutze präzise Verben sowie Nomen-Verb-Verbindungen (z.B. 'eine Entscheidung treffen')."
            ),
            SchreibenCriterionWeakness(
                id: "strukturen",
                title: "Grammatik & Strukturen",
                averageOutOf25: avgStr,
                advice: "Prüfe am Ende besonders die Verbposition im Nebensatz (Verb am Ende!) sowie Kasus nach Präpositionen und den Konjunktiv II für höfliche Bitten."
            )
        ]
    }
    
    public var weakestCriterion: SchreibenCriterionWeakness? {
        criterionWeaknesses.min(by: { $0.averageOutOf25 < $1.averageOutOf25 })
    }
    
    // MARK: - Persistence
    private func loadPersistedData() {
        if let data = UserDefaults.standard.data(forKey: submissionsKey),
           let decoded = try? JSONDecoder().decode([SchreibenSubmission].self, from: data) {
            self.submissions = decoded
        }
        if let data = UserDefaults.standard.data(forKey: customTasksKey),
           let decoded = try? JSONDecoder().decode([SchreibenTask].self, from: data) {
            self.customTasks = decoded
        }
        if let data = UserDefaults.standard.data(forKey: draftsKey),
           let decoded = try? JSONDecoder().decode([String: String].self, from: data) {
            self.activeDrafts = decoded
        }
        if let data = UserDefaults.standard.data(forKey: draftDurationsKey),
           let decoded = try? JSONDecoder().decode([String: Int].self, from: data) {
            self.activeDraftDurations = decoded
        }
    }
    
    private func saveSubmissions() {
        if let data = try? JSONEncoder().encode(submissions) {
            UserDefaults.standard.set(data, forKey: submissionsKey)
        }
    }
    
    private func saveCustomTasks() {
        if let data = try? JSONEncoder().encode(customTasks) {
            UserDefaults.standard.set(data, forKey: customTasksKey)
        }
    }
    
    private func saveDrafts() {
        if let data = try? JSONEncoder().encode(activeDrafts) {
            UserDefaults.standard.set(data, forKey: draftsKey)
        }
        if let data = try? JSONEncoder().encode(activeDraftDurations) {
            UserDefaults.standard.set(data, forKey: draftDurationsKey)
        }
    }
    
    // MARK: - Built-in Authentic Goethe-Institut B1 & B2 Exam Tasks (29 Tasks across all 5 Teile)
    private static func makeBuiltInGoetheTasks() -> [SchreibenTask] {
        let officialPDFTasks: [SchreibenTask] = OfficialGoetheSamplesBank.goethePDFSamples.map { sample in
            let combinedSituation: String
            if let quote = sample.impulseQuote {
                combinedSituation = "\(sample.officialPromptText)\n\n\(quote)"
            } else {
                combinedSituation = sample.officialPromptText
            }
            return SchreibenTask(
                id: sample.id,
                level: sample.level,
                teil: sample.teil,
                title: "\(sample.title) (Offizieller Modellsatz)",
                situation: combinedSituation,
                leitpunkte: sample.officialLeitpunkte,
                targetWords: sample.targetWords,
                registerHint: sample.teil.defaultRegisterHint,
                recommendedTimeMinutes: sample.workingTimeMinutes,
                isAIGenerated: false
            )
        }
        
        let additionalTasks: [SchreibenTask] = [
            // =====================================================
            // GOETHE-ZERTIFIKAT B1 • TEIL 1 (Persönliche E-Mail ~80 Wörter)
            // =====================================================
            SchreibenTask(
                id: "goethe_b1_t1_umzug",
                level: .b1,
                teil: .b1Teil1,
                title: "Einladung zur neuen Wohnung",
                situation: "Sie sind vor kurzem in eine neue Wohnung umgezogen und möchten am kommenden Wochenende eine kleine Einweihungsparty feiern. Schreiben Sie eine E-Mail an Ihren Freund / Ihre Freundin Lukas.",
                leitpunkte: [
                    "Beschreiben Sie Ihre neue Wohnung und die Nachbarschaft.",
                    "Begründen Sie, warum Sie erst jetzt umgezogen sind.",
                    "Laden Sie Lukas zur Feier ein und schlagen Sie vor, was er mitbringen könnte."
                ]
            ),
            SchreibenTask(
                id: "goethe_b1_t1_sprachkurs",
                level: .b1,
                teil: .b1Teil1,
                title: "Neuer Deutsch-Intensivkurs",
                situation: "Sie besuchen seit zwei Wochen einen neuen Deutsch-Intensivkurs in Ihrer Stadt. Eine gute Freundin, Sofia, interessiert sich ebenfalls für den Kurs. Schreiben Sie ihr eine E-Mail.",
                leitpunkte: [
                    "Erzählen Sie, wie Ihnen der Unterricht, die Lehrkraft und die Gruppe gefallen.",
                    "Beschreiben Sie, was Ihnen im Kurs noch schwerfällt und warum.",
                    "Machen Sie einen Vorschlag für ein gemeinsames Treffen in dieser Woche."
                ]
            ),
            SchreibenTask(
                id: "goethe_b1_t1_wochenendausflug",
                level: .b1,
                teil: .b1Teil1,
                title: "Ausflug in die Berge",
                situation: "Sie haben am letzten Wochenende einen Ausflug in die Berge gemacht, bei dem Ihr Freund Jonas leider krank war und nicht mitkommen konnte. Schreiben Sie Jonas eine E-Mail.",
                leitpunkte: [
                    "Fragen Sie, wie es Jonas geht, und berichten Sie, wie der Ausflug war.",
                    "Erzählen Sie von einem besonderen Erlebnis oder einer Überraschung unterwegs.",
                    "Schlagen Sie ein baldiges Treffen vor, um ihm die Fotos zu zeigen."
                ]
            ),
            
            // =====================================================
            // GOETHE-ZERTIFIKAT B1 • TEIL 2 (Diskussionsbeitrag ~80 Wörter)
            // =====================================================
            SchreibenTask(
                id: "goethe_b1_t2_einkaufen",
                level: .b1,
                teil: .b1Teil2,
                title: "Online-Shopping oder Geschäfte vor Ort?",
                situation: "Im Internet lesen Sie in einem Forum eine Diskussion zum Thema „Online einkaufen oder im Geschäft vor Ort kaufen?“. Schreiben Sie einen Diskussionsbeitrag für das Gästebuch der Sendung.",
                leitpunkte: [
                    "Äußern Sie Ihre persönliche Meinung zum Thema Online-Shopping.",
                    "Berichten Sie von Ihren eigenen Gewohnheiten und Erfahrungen beim Einkaufen.",
                    "Nennen Sie Vor- und Nachteile für die Geschäfte in der Innenstadt."
                ]
            ),
            SchreibenTask(
                id: "goethe_b1_t2_autofrei",
                level: .b1,
                teil: .b1Teil2,
                title: "Autofreie Innenstädte",
                situation: "In einer Fernsehsendung haben Sie eine Diskussion zum Thema „Sollten Innenstädte komplett autofrei sein?“ gesehen. Im Online-Gästebuch der Sendung finden Sie viele Kommentare. Schreiben Sie nun Ihre Meinung.",
                leitpunkte: [
                    "Sagen Sie, was Sie von autofreien Innenstädten halten.",
                    "Beschreiben Sie, wie Sie selbst im Alltag zur Arbeit oder zum Unterricht fahren.",
                    "Erklären Sie, welche Folgen ein Autoverbot für ältere Menschen oder Familien hätte."
                ]
            ),
            SchreibenTask(
                id: "goethe_b1_t2_soziale_medien",
                level: .b1,
                teil: .b1Teil2,
                title: "Kinder und Smartphones",
                situation: "In einem Eltern-Forum wird darüber diskutiert, ab welchem Alter Kinder ein eigenes Smartphone besitzen sollten. Schreiben Sie einen Forumsbeitrag dazu.",
                leitpunkte: [
                    "Äußern Sie Ihre Meinung dazu, ab wann ein eigenes Smartphone sinnvoll ist.",
                    "Begründen Sie, warum Smartphones für Kinder nützlich, aber auch problematisch sein können.",
                    "Geben Sie einen Tipp, welche Regeln Eltern mit ihren Kindern vereinbaren sollten."
                ]
            ),
            
            // =====================================================
            // GOETHE-ZERTIFIKAT B1 • TEIL 3 (Formelle Kurzmitteilung ~40 Wörter)
            // =====================================================
            SchreibenTask(
                id: "goethe_b1_t3_terminabsage",
                level: .b1,
                teil: .b1Teil3,
                title: "Absage eines Beratungstermins",
                situation: "Sie haben am Donnerstag um 10:00 Uhr einen Beratungstermin bei Ihrer Studienberaterin, Frau Dr. Weber. Sie müssen den Termin wegen eines dringenden Arztbesuchs absagen.",
                leitpunkte: [
                    "Entschuldigen Sie sich höflich für die Absage.",
                    "Erklären Sie kurz, warum Sie am Donnerstag nicht kommen können.",
                    "Bitten Sie um einen neuen Termin in der nächsten Woche."
                ]
            ),
            SchreibenTask(
                id: "goethe_b1_t3_hausverwaltung",
                level: .b1,
                teil: .b1Teil3,
                title: "Defekte Heizung in der Wohnung",
                situation: "Seit gestern funktioniert die Heizung in Ihrer Wohnung nicht mehr und es ist sehr kalt. Schreiben Sie eine kurze formelle Nachricht an Ihren Vermieter, Herrn Schneider.",
                leitpunkte: [
                    "Beschreiben Sie kurz das Problem in Ihrer Wohnung.",
                    "Bitten Sie um eine schnelle Reparatur durch einen Handwerker.",
                    "Teilen Sie mit, zu welchen Uhrzeiten Sie zu Hause erreichbar sind."
                ]
            ),
            SchreibenTask(
                id: "goethe_b1_t3_elternabend",
                level: .b1,
                teil: .b1Teil3,
                title: "Entschuldigung für das Kursfehlen",
                situation: "Sie können morgen nicht an Ihrem Berufssprachkurs teilnehmen, weil Sie einen wichtigen Termin beim Ausländeramt haben. Schreiben Sie Ihrem Kursleiter, Herrn Becker.",
                leitpunkte: [
                    "Entschuldigen Sie sich höflich dafür, dass Sie morgen fehlen.",
                    "Nennen Sie den Grund für Ihre Abwesenheit.",
                    "Fragen Sie nach den Hausaufgaben für die nächste Stunde."
                ]
            ),
            
            // =====================================================
            // GOETHE-ZERTIFIKAT B2 • TEIL 1 (Forumsbeitrag ~150 Wörter)
            // =====================================================
            SchreibenTask(
                id: "goethe_b2_t1_homeoffice",
                level: .b2,
                teil: .b2Teil1,
                title: "Recht auf dauerhaftes Homeoffice",
                situation: "Sie schreiben einen Forumsbeitrag zum Thema „Sollten Arbeitnehmerinnen und Arbeitnehmer ein gesetzliches Recht auf Homeoffice erhalten?“. Gehen Sie dabei auf alle vier Punkte ein.",
                leitpunkte: [
                    "Äußern Sie Ihre Meinung zu einem gesetzlichen Anspruch auf Homeoffice.",
                    "Nennen Sie Gründe, warum mobiles Arbeiten heute immer beliebter wird.",
                    "Erläutern Sie mögliche Nachteile für die Zusammenarbeit im Team und für Unternehmen.",
                    "Schlagen Sie vor, wie ein ausgewogenes Arbeitsmodell der Zukunft aussehen könnte."
                ]
            ),
            SchreibenTask(
                id: "goethe_b2_t1_fleischkonsum",
                level: .b2,
                teil: .b2Teil1,
                title: "Umweltbewusste Ernährung und Fleischsteuer",
                situation: "In einem Online-Magazin wird über eine höhere Besteuerung von Fleischprodukten zum Schutz des Klimas diskutiert. Verfassen Sie einen strukturierten Diskussionsbeitrag.",
                leitpunkte: [
                    "Nehmen Sie Stellung zu dem Vorschlag, Fleischprodukte höher zu besteuern.",
                    "Begründen Sie, welchen Einfluss unsere Ernährung auf Umwelt und Klima hat.",
                    "Diskutieren Sie Vor- und Nachteile einer solchen Steuer für Verbraucher.",
                    "Nennen Sie andere Möglichkeiten, um eine nachhaltige Ernährung zu fördern."
                ]
            ),
            SchreibenTask(
                id: "goethe_b2_t1_ki_bildung",
                level: .b2,
                teil: .b2Teil1,
                title: "Künstliche Intelligenz an Schulen und Universitäten",
                situation: "Immer mehr Studierende und Schüler nutzen KI-Programme für Hausarbeiten und Referate. Schreiben Sie einen Forumsbeitrag zur Frage, wie Bildungseinrichtungen damit umgehen sollten.",
                leitpunkte: [
                    "Äußern Sie Ihre Meinung zum Einsatz von Künstlicher Intelligenz im Bildungsbereich.",
                    "Erläutern Sie, welche Chancen KI-Werkzeuge beim individuellen Lernen bieten.",
                    "Benennen Sie Risiken für die Selbstständigkeit und faire Leistungsbewertung.",
                    "Schlagen Sie vor, wie Prüfungen und Unterricht sinnvoll angepasst werden könnten."
                ]
            ),
            
            // =====================================================
            // GOETHE-ZERTIFIKAT B2 • TEIL 2 (Formelle Nachricht ~100 Wörter)
            // =====================================================
            SchreibenTask(
                id: "goethe_b2_t2_praktikum",
                level: .b2,
                teil: .b2Teil2,
                title: "Verlängerung eines Praktikums",
                situation: "Sie absolvieren derzeit ein dreimonatiges Praktikum in einem deutschen Unternehmen. Da Sie gerne auch an einem neuen Projekt mitarbeiten möchten, würden Sie Ihr Praktikum gerne um zwei Monate verlängern. Schreiben Sie eine Nachricht an Ihre Abteilungsleiterin, Frau Sandra Lehmann.",
                leitpunkte: [
                    "Bedanken Sie sich für die bisherigen Erfahrungen in der Abteilung.",
                    "Erklären Sie Ihren Wunsch, das Praktikum um zwei Monate zu verlängern.",
                    "Begründen Sie, welchen Mehrwert Ihre Mitarbeit am neuen Projekt für das Team bietet.",
                    "Bitten Sie höflich um ein kurzes persönliches Gespräch in dieser Woche."
                ]
            ),
            SchreibenTask(
                id: "goethe_b2_t2_seminarraum",
                level: .b2,
                teil: .b2Teil2,
                title: "Beschwerde über Ausstattung im Weiterbildungskurs",
                situation: "Sie haben an einem kostenpflichtigen Wochenend-Seminar zur beruflichen Weiterbildung teilgenommen. Leider entsprachen weder die technische Ausstattung noch die Gruppengröße der Beschreibung im Programm. Schreiben Sie an den Veranstalter, Herrn Dr. Kellermann.",
                leitpunkte: [
                    "Erklären Sie, an welchem Seminar Sie teilgenommen haben und warum Sie es gebucht hatten.",
                    "Schildern Sie konkret, welche Mängel es bei Technik und Gruppengröße gab.",
                    "Erläutern Sie, welche Auswirkungen dies auf Ihren Lernerfolg hatte.",
                    "Fordern Sie eine angemessene Entschädigung (z.B. Teilrückerstattung oder Gutschein)."
                ]
            ),
            SchreibenTask(
                id: "goethe_b2_t2_projektfrist",
                level: .b2,
                teil: .b2Teil2,
                title: "Bitte um Fristverlängerung im Studium",
                situation: "Sie schreiben an Ihrer Universität eine Seminararbeit bei Herrn Professor Lindner. Wegen eines unerwarteten technischen Defekts Ihres Laptops und fehlender Literatur aus der Bibliothek schaffen Sie den Abgabetermin am Freitag nicht. Schreiben Sie eine formelle Nachricht.",
                leitpunkte: [
                    "Erinnern Sie kurz an das Thema Ihrer Seminararbeit und den geplanten Abgabetermin.",
                    "Schildern Sie nachvollziehbar die Gründe für die Verzögerung.",
                    "Beschreiben Sie, wie weit Ihre Arbeit bereits fortgeschritten ist.",
                    "Bitten Sie höflich um eine Fristverlängerung von einer Woche."
                ]
            )
        ]
        return officialPDFTasks + additionalTasks
    }
}
