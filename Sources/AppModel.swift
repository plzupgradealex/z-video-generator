import Foundation
import Observation

enum JobStatus: String, Equatable {
    case idle
    case processing
    case success
    case failed
}

/// Why a job failed, so the UI can offer a tailored recovery instead of a bare
/// "Retry". Out-of-credit and bad-key are common, recoverable, and worth their
/// own affordance; everything else is generic. Persisted as the raw value, so a
/// new kind decodes as `nil` on older snapshots (safe additive change).
enum FailureKind: String, Codable, Sendable {
    case generic
    case outOfCredit     // 402 / "insufficient balance" — key works but has no funds
    case unauthorized    // 401/403 — key rejected
    case network         // transport error — can't reach Z.AI
}

/// One independently-configured generation in the gallery. `@Observable` so each
/// `JobCard` updates live as its status flips and its result arrives.
@MainActor
@Observable
final class GenerationJob: Identifiable {
    let id: UUID
    let createdAt: Date

    // Editable settings (per job — the gallery is N independent requests).
    var prompt: String
    var model: String
    var quality: String
    var size: String
    var fps: Int
    var duration: Int
    var withAudio: Bool
    var aspect: String          // "", "16:9", "9:16", "1:1"
    var movement: String
    var imageURL: String

    // Runtime state.
    var status: JobStatus = .idle
    var statusMessage: String = ""
    var taskID: String?
    var resultVideoURL: URL?
    var resultCoverURL: URL?
    var errorMessage: String?
    /// Tailored recovery hint for a failed job (nil on success/idle). See
    /// `FailureKind`.
    var failureKind: FailureKind?

    init(prompt: String = "",
         model: String = "cogvideox-3",
         quality: String = "quality",
         size: String = "1920x1080",
         fps: Int = 30,
         duration: Int = 5,
         withAudio: Bool = true,
         aspect: String = "",
         movement: String = "auto",
         imageURL: String = "") {
        self.id = UUID()
        self.createdAt = Date()
        self.prompt = prompt
        self.model = model
        self.quality = quality
        self.size = size
        self.fps = fps
        self.duration = duration
        self.withAudio = withAudio
        self.aspect = aspect
        self.movement = movement
        self.imageURL = imageURL
    }

    /// Restore a job from disk, preserving its stable `id`/`createdAt` so the
    /// gallery order and any in-flight server task can be reattached on relaunch.
    init(restoring persisted: PersistedJob) {
        self.id = persisted.id
        self.createdAt = persisted.createdAt
        self.prompt = persisted.prompt
        self.model = persisted.model
        self.quality = persisted.quality
        self.size = persisted.size
        self.fps = persisted.fps
        self.duration = persisted.duration
        self.withAudio = persisted.withAudio
        self.aspect = persisted.aspect
        self.movement = persisted.movement
        self.imageURL = persisted.imageURL
        self.status = JobStatus(rawValue: persisted.status) ?? .idle
        self.statusMessage = persisted.statusMessage
        self.taskID = persisted.taskID
        self.resultVideoURL = persisted.resultVideoURL
        self.resultCoverURL = persisted.resultCoverURL
        self.errorMessage = persisted.errorMessage
        self.failureKind = persisted.failureKind
    }

    var isTerminal: Bool { status == .success || status == .failed }
    var canGenerate: Bool {
        (status == .idle) && (!prompt.containsOnlyWhitespace || !imageURL.containsOnlyWhitespace)
    }

    /// Whether a failed job should show the reload/out-of-credit affordance
    /// instead of a plain Retry. True on a real `outOfCredit` classification,
    /// or when the debug preview flag is on (so the UI can be eyeballed without
    /// burning a real 402): `defaults write com.alex.ZVideoGenerator
    /// zvg.outofcredit.preview -bool true`.
    var showsOutOfCredit: Bool {
        failureKind == .outOfCredit
        || (status == .failed && UserDefaults.standard.bool(forKey: "zvg.outofcredit.preview"))
    }

    /// Whether a failed job should nudge the user to fix their key.
    var showsKeyError: Bool { failureKind == .unauthorized }
}

/// On-disk snapshot of a `GenerationJob`. Kept separate from the `@Observable`
/// class so the JSON keys stay clean and the macro's backing storage never leaks
/// into the file. Round-trips through `GenerationJob.init(restoring:)`.
struct PersistedJob: Codable {
    let id: UUID
    let createdAt: Date
    let prompt: String
    let model: String
    let quality: String
    let size: String
    let fps: Int
    let duration: Int
    let withAudio: Bool
    let aspect: String
    let movement: String
    let imageURL: String
    let status: String
    let statusMessage: String
    let taskID: String?
    let resultVideoURL: URL?
    let resultCoverURL: URL?
    let errorMessage: String?
    let failureKind: FailureKind?

    /// Reads the live `GenerationJob`'s `@MainActor`-isolated fields, so the init
    /// itself is main-actor-isolated (only ever called from `saveJobs`, on main).
    @MainActor
    init(_ job: GenerationJob) {
        id = job.id
        createdAt = job.createdAt
        prompt = job.prompt
        model = job.model
        quality = job.quality
        size = job.size
        fps = job.fps
        duration = job.duration
        withAudio = job.withAudio
        aspect = job.aspect
        movement = job.movement
        imageURL = job.imageURL
        status = job.status.rawValue
        statusMessage = job.statusMessage
        taskID = job.taskID
        resultVideoURL = job.resultVideoURL
        resultCoverURL = job.resultCoverURL
        errorMessage = job.errorMessage
        failureKind = job.failureKind
    }
}

/// A prompt the user chose to keep — usually from a finished job that made
/// something great — so it can be reused to start a new job. Snapshots the
/// job's full settings alongside the prompt text.
struct SavedPrompt: Codable, Identifiable, Hashable, Sendable {
    var id: UUID
    var title: String
    var prompt: String
    var note: String
    var model: String
    var quality: String
    var size: String
    var fps: Int
    var duration: Int
    var withAudio: Bool
    var aspect: String
    var movement: String
    var imageURL: String
    var createdAt: Date

    init(id: UUID = UUID(), title: String = "", prompt: String = "", note: String = "",
         model: String = "cogvideox-3", quality: String = "quality", size: String = "1920x1080",
         fps: Int = 30, duration: Int = 5, withAudio: Bool = true, aspect: String = "",
         movement: String = "auto", imageURL: String = "", createdAt: Date = Date()) {
        self.id = id; self.title = title; self.prompt = prompt; self.note = note
        self.model = model; self.quality = quality; self.size = size; self.fps = fps
        self.duration = duration; self.withAudio = withAudio; self.aspect = aspect
        self.movement = movement; self.imageURL = imageURL; self.createdAt = createdAt
    }

    /// A human label: an explicit title, else the first line of the prompt,
    /// else a fallback.
    var displayTitle: String {
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !t.isEmpty { return t }
        let firstLine = (prompt.split(separator: "\n").first.map(String.init) ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return firstLine.isEmpty ? "Untitled prompt" : firstLine
    }
}

/// A user-facing aspect-ratio choice; `value` is what the Z.AI API expects.
struct AspectOption: Identifiable, Hashable {
    let value: String
    let label: String
    var id: String { value }
}

/// Live state of the connection to Z.AI, mirrored as a colored light in the
/// sidebar footer. `checking` and `error` both read yellow (connecting vs.
/// can't-reach / key-rejected) — the footer's text disambiguates; only `noKey`
/// is red.
enum ConnectionStatus: Equatable {
    case noKey        // red    — no API key stored
    case checking     // yellow — a verification request is in flight
    case connected    // green  — key accepted, server reachable
    case error        // yellow — can't reach Z.AI, or the key was rejected
    case demo         // blue   — demo mode active, no key needed
}

/// Central, observable state. `@MainActor` so all mutations (including those
/// inside the per-job polling `Task`s, which inherit the actor) are main-thread
/// safe. Drives the jobs gallery, history, and API-key onboarding.
@MainActor
@Observable
final class AppModel {
    // MARK: Credentials
    var apiKey: String = KeychainStore.get() ?? "" {
        didSet {
            KeychainStore.set(apiKey)
            // Adding a real key turns demo mode off — real generation resumes.
            if !apiKey.containsOnlyWhitespace { isDemoMode = false }
            // Re-light the status indicator whenever the key changes (entered,
            // replaced, or removed) so it never goes stale.
            verifyKey()
        }
    }

    var isAuthenticated: Bool { !apiKey.containsOnlyWhitespace }

    /// Demo mode lets the app be exercised with **no API key** — generation runs
    /// a short simulated flow and returns a bundled sample video, so reviewers
    /// (and curious users) can try the full UI without a key or spending credit.
    /// This is the fix for the v1.0 rejection ("no demo mode / no key to test
    /// with"). Persists across launches; turns off the moment a real key is added.
    var isDemoMode: Bool = UserDefaults.standard.bool(forKey: "zvg.demomode") {
        didSet {
            UserDefaults.standard.set(isDemoMode, forKey: "zvg.demomode")
            verifyKey()
        }
    }

    /// Whether the app can generate at all: a real key OR demo mode.
    var canUse: Bool { isAuthenticated || isDemoMode }

    /// Live Z.AI connection state for the sidebar footer light. Green when the
    /// key works, yellow while checking / unreachable, red when there's no key.
    var connectionStatus: ConnectionStatus = .noKey

    /// True when there's anything worth keeping the full UI around for even
    /// without a key — queued/finished jobs, saved prompts, or past history.
    /// Lets a returning user keep browsing their videos if their key drops,
    /// instead of being thrown into the first-run screen.
    var hasExistingContent: Bool {
        !jobs.isEmpty || !savedPrompts.isEmpty || !history.isEmpty
    }

    // MARK: Defaults (seed new jobs; persisted to UserDefaults)
    //
    // Edited from the Settings window (⌘,). Stored on AppModel so @Observable
    // drives live bindings; each setter writes through to UserDefaults. New jobs
    // are seeded from these — existing jobs always keep their own settings.
    var defaultModel: String = UserDefaults.standard.string(forKey: "defaultModel") ?? "cogvideox-3" {
        didSet { UserDefaults.standard.set(defaultModel, forKey: "defaultModel") }
    }
    var defaultQuality: String = UserDefaults.standard.string(forKey: "defaultQuality") ?? "quality" {
        didSet { UserDefaults.standard.set(defaultQuality, forKey: "defaultQuality") }
    }
    var defaultSize: String = UserDefaults.standard.string(forKey: "defaultSize") ?? "1920x1080" {
        didSet { UserDefaults.standard.set(defaultSize, forKey: "defaultSize") }
    }
    var defaultFPS: Int = (UserDefaults.standard.object(forKey: "defaultFPS") as? Int) ?? 30 {
        didSet { UserDefaults.standard.set(defaultFPS, forKey: "defaultFPS") }
    }
    var defaultDuration: Int = (UserDefaults.standard.object(forKey: "defaultDuration") as? Int) ?? 5 {
        didSet { UserDefaults.standard.set(defaultDuration, forKey: "defaultDuration") }
    }
    var defaultAudio: Bool = (UserDefaults.standard.object(forKey: "defaultAudio") as? Bool) ?? true {
        didSet { UserDefaults.standard.set(defaultAudio, forKey: "defaultAudio") }
    }
    var defaultAspect: String = UserDefaults.standard.string(forKey: "defaultAspect") ?? "" {
        didSet { UserDefaults.standard.set(defaultAspect, forKey: "defaultAspect") }
    }
    var defaultMovement: String = UserDefaults.standard.string(forKey: "defaultMovement") ?? "auto" {
        didSet { UserDefaults.standard.set(defaultMovement, forKey: "defaultMovement") }
    }

    // MARK: Jobs (the gallery)
    var jobs: [GenerationJob] = []
    /// Concurrent in-flight generations. The API is the limit, not the Mac.
    let maxConcurrent = AppLimits.maxConcurrent
    /// Live count for the header; bumped as jobs start/finish.
    var activeCount = 0

    // MARK: Prompt library
    var savedPrompts: [SavedPrompt] = []

    // MARK: History
    var history: [HistoryItem] = []

    // MARK: Option lists
    let models = ["cogvideox-3", "vidu2-image", "vidu2-reference", "vidu2-start-end", "viduq1-image"]
    let sizes = ["1920x1080", "1280x720", "1024x1024", "720x1280", "3840x2160"]
    let qualities = ["quality", "speed"]
    let fpsOptions = [30, 60]
    let durations = [5, 10]
    let styles = ["Default", "general", "anime"]
    /// Friendly aspect choices; values match the web app's supported ratios.
    let aspectOptions: [AspectOption] = [
        AspectOption(value: "",     label: "Default"),
        AspectOption(value: "16:9", label: "Landscape"),
        AspectOption(value: "9:16", label: "Portrait"),
        AspectOption(value: "1:1",  label: "Square"),
    ]
    let movements = ["Auto", "auto", "small", "medium", "large"]

    private var jobTasks: [UUID: Task<Void, Never>] = [:]
    private var autosaveTask: Task<Void, Never>?
    /// Backing task for the connection-status probe; cancelled/replaced on each
    /// `verifyKey()` call so only the most recent probe sets the status.
    private var verifyTask: Task<Void, Never>?

    init() {
        loadHistory()
        loadJobs()
        loadLibrary()
        resumeInProgressJobs()
        startAutosave()
        // Light the status indicator on launch — no-op (red) when there's no key.
        verifyKey()
    }

    // MARK: Connection status

    /// Probe Z.AI with the current key and update `connectionStatus`. Cheap and
    /// idempotent — safe to call on launch, on key change, and when the app
    /// regains focus. Real generate/retrieve calls also correct the status as a
    /// side effect (see `noteConnectionSuccess` / `noteConnectionFailure`).
    func verifyKey() {
        verifyTask?.cancel()
        // Demo mode with no key: show a neutral "Demo" status, not "No key".
        if isDemoMode && apiKey.containsOnlyWhitespace { connectionStatus = .demo; return }
        guard isAuthenticated else { connectionStatus = .noKey; return }
        connectionStatus = .checking
        // Capture the key the probe runs under so a late probe result can't
        // light the indicator for a key the user has since replaced.
        let key = apiKey
        let client = ZAIClient(apiKey: key)
        verifyTask = Task { [weak self] in
            let result = await client.verify()
            if Task.isCancelled { return }
            self?.applyVerifyResult(result, forKey: key)
        }
    }

    private func applyVerifyResult(_ result: VerifyResult, forKey key: String) {
        switch result {
        case .connected:    applyStatus(.connected, forKey: key)
        case .unauthorized: applyStatus(.error, forKey: key)
        case .unreachable:  applyStatus(.error, forKey: key)
        }
    }

    /// The single chokepoint for setting the status: only honor a signal that
    /// reflects the *current* key (and is non-empty). This keeps both a late
    /// probe and a real job that started under a previous key from lighting the
    /// indicator for a key the user has since changed or removed.
    private func applyStatus(_ status: ConnectionStatus, forKey key: String) {
        guard !key.isEmpty, key == apiKey else { return }
        connectionStatus = status
    }

    /// A real API call just succeeded — the key it ran under works and Z.AI is
    /// reachable. `key` is the key the call used (captured when the job started),
    /// so a stale signal from a replaced key is ignored.
    fileprivate func noteConnectionSuccess(forKey key: String) {
        applyStatus(.connected, forKey: key)
    }

    /// Fold a failed request into the status: an auth failure (401/403) or a
    /// transport failure dims the light to yellow; other server-side errors
    /// leave it alone (the key is fine, the request just didn't succeed).
    fileprivate func noteConnectionFailure(_ error: Error, forKey key: String) {
        if let zai = error as? ZAIError, case .http(let status, _) = zai {
            if status == 401 || status == 403 { applyStatus(.error, forKey: key) }
            return
        }
        if error is URLError { applyStatus(.error, forKey: key) }
    }

    /// Map a thrown error to a `FailureKind` for tailored recovery UI. Mirrors
    /// `noteConnectionFailure`'s logic but returns a category instead of dimming
    /// the light — a 402 leaves the light green (the key is valid) yet still
    /// classifies as out-of-credit for the job's reload affordance.
    fileprivate func classify(_ error: Error) -> FailureKind {
        if let zai = error as? ZAIError { return zai.failureKind }
        if error is URLError { return .network }
        return .generic
    }

    /// A short, action-oriented message for a failed job. Known kinds get a plain
    /// explanation + the next step; anything unknown falls back to the raw error.
    fileprivate func friendlyMessage(for kind: FailureKind, fallback error: Error) -> String {
        switch kind {
        case .outOfCredit:
            return "Your Z.AI key is out of credit. Top up at z.ai, then update your key here."
        case .unauthorized:
            return "Your Z.AI key was rejected. Update it and try again."
        case .network:
            return "Can't reach Z.AI. Check your connection and try again."
        case .generic:
            return error.localizedDescription
        }
    }

    // MARK: Aggregate state

    var queuedCount: Int { jobs.filter { $0.status == .idle }.count }
    var successCount: Int { jobs.filter { $0.status == .success }.count }
    var failedCount: Int { jobs.filter { $0.status == .failed }.count }
    var hasActive: Bool { activeCount > 0 }
    var canGenerateAll: Bool {
        canUse && jobs.contains { $0.canGenerate }
    }

    // MARK: Job lifecycle

    @discardableResult
    func addJob() -> GenerationJob? {
        guard jobs.count < AppLimits.maxJobs else { return nil }
        // Seed a new job from the user's saved defaults (Settings window).
        let job = GenerationJob(
            prompt: "",
            model: defaultModel,
            quality: defaultQuality,
            size: defaultSize,
            fps: defaultFPS,
            duration: defaultDuration,
            withAudio: defaultAudio,
            aspect: defaultAspect,
            movement: defaultMovement,
            imageURL: "")
        jobs.append(job)
        saveJobs()
        return job
    }

    func duplicate(_ job: GenerationJob) {
        guard jobs.count < AppLimits.maxJobs else { return }
        let copy = GenerationJob(
            prompt: job.prompt, model: job.model, quality: job.quality, size: job.size,
            fps: job.fps, duration: job.duration, withAudio: job.withAudio,
            aspect: job.aspect, movement: job.movement, imageURL: job.imageURL)
        if let index = jobs.firstIndex(where: { $0.id == job.id }) {
            jobs.insert(copy, at: index + 1)
        } else {
            jobs.append(copy)
        }
        saveJobs()
    }

    func remove(_ job: GenerationJob) {
        cancel(job)
        jobs.removeAll { $0.id == job.id }
        saveJobs()
    }

    func clearFinished() {
        let terminal = jobs.filter { $0.isTerminal }
        for job in terminal { jobTasks[job.id]?.cancel(); jobTasks.removeValue(forKey: job.id) }
        jobs.removeAll { $0.isTerminal }
        saveJobs()
        // Allow the list to become empty (shows the empty state) rather than
        // forcing a blank job back in.
    }

    // MARK: Dispatch (concurrency-throttled)

    /// Start every ready, idle job, up to `maxConcurrent` at once. Running jobs
    /// are left alone; queued jobs are started as slots free up (`scheduleNext`).
    func generateAll() {
        guard canUse else { return }
        scheduleNext()
    }

    func generate(_ job: GenerationJob) {
        guard canUse, job.canGenerate else { return }
        scheduleNext(forceStart: job)
    }

    /// Re-run a finished job by resetting it to idle and dispatching it. Backs
    /// "Retry" (failed) and "Regenerate" (success); an already-idle job just
    /// dispatches. `generate(_:)` only accepts idle jobs, so finished jobs must
    /// be reset first.
    func regenerate(_ job: GenerationJob) {
        guard canUse else { return }
        if job.status == .success || job.status == .failed {
            job.status = .idle
            job.statusMessage = ""
            job.errorMessage = nil
            job.resultVideoURL = nil
            job.resultCoverURL = nil
            saveJobs()
        }
        guard job.canGenerate else { return }
        scheduleNext(forceStart: job)
    }

    private func scheduleNext(forceStart: GenerationJob? = nil) {
        if let forced = forceStart, forced.status == .idle {
            startJob(forced)
        }
        while activeCount < maxConcurrent {
            guard let next = jobs.first(where: { $0.status == .idle && $0.canGenerate }) else { break }
            startJob(next)
        }
    }

    private func startJob(_ job: GenerationJob) {
        guard job.status == .idle else { return }
        job.status = .processing
        job.statusMessage = "Submitting…"
        job.errorMessage = nil
        job.resultVideoURL = nil
        job.resultCoverURL = nil
        activeCount += 1

        let id = job.id

        // Demo mode (no real key): run the simulated sample-video flow so the
        // whole UI is exercisable without spending Z.AI credit.
        if isDemoMode && !isAuthenticated {
            jobTasks[id] = Task { [weak self, weak job] in
                await self?.runDemoJob(job)
            }
            return
        }

        let key = apiKey
        let client = ZAIClient(apiKey: key)
        let request = buildRequest(for: job)
        jobTasks[id] = Task { [weak self, weak job] in
            await self?.runJob(job, client: client, request: request, key: key)
        }
    }

    /// Demo-mode generation: step through a short simulated render and resolve
    /// with the bundled sample video (Resources/Art/fire.mp4, the same clip the
    /// loading art uses). No Z.AI call, no key, no credit spent — the point is to
    /// let reviewers and users exercise the full generate → process → play → save
    /// flow. Mirrors `runJob`'s cancellation/success/finish shape so the rest of
    /// the pipeline (gallery, history, concurrency throttle) works unchanged.
    private func runDemoJob(_ job: GenerationJob?) async {
        guard let job else { return }
        let steps = ["Preparing demo render…", "Compositing demo frames…", "Encoding demo video…"]
        for msg in steps {
            if Task.isCancelled { break }
            job.statusMessage = msg
            saveJobs()
            try? await Task.sleep(for: .seconds(1.2))
        }
        if Task.isCancelled {
            job.status = .idle
            job.statusMessage = ""
            saveJobs()
            finish(job)
            return
        }
        let url = Bundle.main.url(forResource: "fire", withExtension: "mp4")
            ?? Bundle.main.url(forResource: "fire", withExtension: "mp4", subdirectory: "Art")
            ?? Bundle.main.url(forResource: "fire", withExtension: "mp4", subdirectory: "Resources/Art")
        job.resultVideoURL = url
        job.resultCoverURL = nil
        job.status = .success
        job.statusMessage = "Demo render"
        if let url { recordHistory(prompt: job.prompt, model: job.model, url: url, cover: nil) }
        saveJobs()
        finish(job)
    }

    /// Submit a fresh request, then poll its server task to completion. Split
    /// from `pollJob` so a relaunch can resume a known task id without resubmitting.
    private func runJob(_ job: GenerationJob?, client: ZAIClient, request: GenerationRequest, key: String) async {
        guard let job else { return }
        do {
            let initial = try await client.generate(request)
            guard let taskID = initial.id else { throw ZAIError.invalidResponse }
            job.taskID = taskID
            noteConnectionSuccess(forKey: key)   // the submit authenticated fine
            job.statusMessage = "Processing on Z.AI servers…"
            saveJobs()
            await pollJob(job, client: client, taskID: taskID, key: key)
        } catch is CancellationError {
            job.status = .idle
            job.statusMessage = ""
            saveJobs()
            finish(job)
        } catch {
            noteConnectionFailure(error, forKey: key)
            let kind = classify(error)
            job.status = .failed
            job.failureKind = kind
            job.errorMessage = friendlyMessage(for: kind, fallback: error)
            saveJobs()
            finish(job)
        }
    }

    /// Poll a known server task until it resolves. Shared by fresh runs (after
    /// the submit returns a task id) and by `resumeInProgressJobs` on launch, so
    /// an in-progress render survives app restarts instead of being orphaned.
    private func pollJob(_ job: GenerationJob?, client: ZAIClient, taskID: String, key: String) async {
        guard let job else { return }
        do {
            while !Task.isCancelled {
                try await Task.sleep(for: .seconds(5))
                if Task.isCancelled { break }
                let result = try await client.retrieve(id: taskID)
                let state = result.task_status ?? "PROCESSING"
                job.statusMessage = "Status: \(state)"

                if state == "SUCCESS" {
                    noteConnectionSuccess(forKey: key)   // the retrieve calls authenticated fine
                    if let urlString = result.video_result?.first?.url,
                       let url = URL(string: urlString) {
                        job.resultVideoURL = url
                        job.resultCoverURL = result.video_result?.first?.cover_image_url.flatMap(URL.init(string:))
                        job.status = .success
                        job.statusMessage = "Ready"
                        recordHistory(prompt: job.prompt, model: job.model, url: url,
                                      cover: result.video_result?.first?.cover_image_url)
                    } else {
                        job.status = .failed
                        job.errorMessage = "Generation succeeded but no video URL was returned."
                    }
                    saveJobs()
                    finish(job)
                    return
                } else if state == "FAIL" {
                    job.status = .failed
                    job.errorMessage = "Generation failed on the server."
                    saveJobs()
                    finish(job)
                    return
                }
            }
            // Cancelled mid-flight → back to idle so it can be retried.
            job.status = .idle
            job.statusMessage = ""
            saveJobs()
            finish(job)
        } catch is CancellationError {
            job.status = .idle
            job.statusMessage = ""
            saveJobs()
            finish(job)
        } catch {
            noteConnectionFailure(error, forKey: key)
            let kind = classify(error)
            job.status = .failed
            job.failureKind = kind
            job.errorMessage = friendlyMessage(for: kind, fallback: error)
            saveJobs()
            finish(job)
        }
    }

    private func finish(_ job: GenerationJob) {
        if activeCount > 0 { activeCount -= 1 }
        jobTasks.removeValue(forKey: job.id)
        scheduleNext()
    }

    func cancel(_ job: GenerationJob) {
        jobTasks[job.id]?.cancel()
        jobTasks.removeValue(forKey: job.id)
        if job.status == .processing {
            job.status = .idle
            job.statusMessage = ""
            job.taskID = nil
            if activeCount > 0 { activeCount -= 1 }
            scheduleNext()
            saveJobs()
        }
    }

    func cancelAll() {
        for job in jobs where job.status == .processing { cancel(job) }
    }

    // MARK: Resume in-flight jobs after relaunch

    /// On launch, any job that was mid-render when the app quit is still alive on
    /// Z.AI's servers under its task id. Re-attach a polling loop so the result
    /// (or failure) is recovered instead of lost to the restart. A render that
    /// already finished server-side while the app was closed resolves on the
    /// first poll; one still in progress just keeps polling.
    private func resumeInProgressJobs() {
        let inFlight = jobs.filter { $0.status == .processing }
        guard !inFlight.isEmpty else { return }
        // Can't re-attach a server poll without a key. Drop in-flight jobs back
        // to idle so the user can retry once they (re-)add a key, rather than
        // firing authenticated requests with an empty/missing key.
        guard isAuthenticated else {
            for job in inFlight {
                job.status = .idle
                job.statusMessage = ""
            }
            saveJobs()
            return
        }
        let key = apiKey
        for job in inFlight {
            guard let taskID = job.taskID, !taskID.isEmpty else {
                // The submit request hadn't returned a task id yet when the app
                // died — there's nothing server-side to reattach. Drop it back to
                // idle so the user can just hit Generate again.
                job.status = .idle
                job.statusMessage = ""
                continue
            }
            activeCount += 1
            job.statusMessage = "Resuming…"
            let client = ZAIClient(apiKey: key)
            let id = job.id
            jobTasks[id] = Task { [weak self, weak job] in
                await self?.pollJob(job, client: client, taskID: taskID, key: key)
            }
        }
        saveJobs()
    }

    // MARK: Request building

    private func buildRequest(for job: GenerationJob) -> GenerationRequest {
        var req = GenerationRequest(model: job.model)
        req.prompt = job.prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        if job.model == "cogvideox-3" { req.quality = job.quality }
        req.size = job.size
        req.fps = job.fps
        req.duration = job.duration
        if !job.aspect.isEmpty { req.aspect_ratio = job.aspect }
        if !job.movement.isEmpty && job.movement != "Auto" { req.movement_amplitude = job.movement }
        if job.model != "viduq1-text" { req.with_audio = job.withAudio }
        let trimmedImage = job.imageURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedImage.isEmpty { req.image_url = trimmedImage }
        return req
    }

    // MARK: Job persistence
    //
    // The gallery is persisted (not just history) so an in-progress render can
    // be resumed and a finished job reopened across app restarts. Every state
    // transition flushes immediately, and a 3s autosave catches prompt/setting
    // edits that don't flow through a mutating method.

    private var jobsFileURL: URL? {
        guard let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        let folder = dir.appendingPathComponent("ZVideoGenerator", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder.appendingPathComponent("jobs.json")
    }

    private func loadJobs() {
        guard let url = jobsFileURL, let data = try? Data(contentsOf: url) else { return }
        let decoded = (try? JSONDecoder().decode([PersistedJob].self, from: data)) ?? []
        jobs = decoded.map(GenerationJob.init(restoring:))
    }

    func saveJobs() {
        guard let url = jobsFileURL else { return }
        let snapshot = jobs.map(PersistedJob.init)
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        try? data.write(to: url, options: .atomic)
    }

    private func startAutosave() {
        autosaveTask?.cancel()
        autosaveTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(3))
                if Task.isCancelled { break }
                self?.saveJobs()
            }
        }
    }

    // MARK: Prompt library
    //
    // Saved prompts persist to disk (like jobs + history) so they survive
    // restarts. "Use" seeds a brand-new job from one.

    /// Save a job's prompt (+ its full settings) to the library. Re-saving the
    /// same prompt bumps it to the top instead of duplicating.
    func savePrompt(from job: GenerationJob, title: String = "", note: String = "") {
        let entry = SavedPrompt(
            title: title, prompt: job.prompt, note: note,
            model: job.model, quality: job.quality, size: job.size,
            fps: job.fps, duration: job.duration, withAudio: job.withAudio,
            aspect: job.aspect, movement: job.movement, imageURL: job.imageURL)
        savedPrompts.removeAll { matches($0, entry) }
        savedPrompts.insert(entry, at: 0)
        if savedPrompts.count > 200 { savedPrompts = Array(savedPrompts.prefix(200)) }
        saveLibrary()
    }

    private func matches(_ a: SavedPrompt, _ b: SavedPrompt) -> Bool {
        a.prompt == b.prompt && a.model == b.model && a.aspect == b.aspect
            && a.size == b.size && a.duration == b.duration && a.fps == b.fps
    }

    func removeSavedPrompt(_ entry: SavedPrompt) {
        savedPrompts.removeAll { $0.id == entry.id }
        saveLibrary()
    }

    /// Create a new idle job seeded from a saved prompt, ready to generate.
    @discardableResult
    func addJob(from saved: SavedPrompt) -> GenerationJob? {
        guard let job = addJob() else { return nil }
        job.prompt = saved.prompt
        job.model = saved.model
        job.quality = saved.quality
        job.size = saved.size
        job.fps = saved.fps
        job.duration = saved.duration
        job.withAudio = saved.withAudio
        job.aspect = saved.aspect
        job.movement = saved.movement
        job.imageURL = saved.imageURL
        saveJobs()
        return job
    }

    private var libraryFileURL: URL? {
        guard let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        let folder = dir.appendingPathComponent("ZVideoGenerator", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder.appendingPathComponent("library.json")
    }

    private func loadLibrary() {
        guard let url = libraryFileURL, let data = try? Data(contentsOf: url) else { return }
        savedPrompts = (try? JSONDecoder().decode([SavedPrompt].self, from: data)) ?? []
    }

    private func saveLibrary() {
        guard let url = libraryFileURL,
              let data = try? JSONEncoder().encode(savedPrompts) else { return }
        try? data.write(to: url, options: .atomic)
    }

    // MARK: History persistence

    private func recordHistory(prompt: String, model: String, url: URL, cover: String?) {
        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        let item = HistoryItem(
            id: UUID(),
            prompt: trimmed.isEmpty ? "(image prompt)" : trimmed,
            videoURL: url.absoluteString,
            coverURL: cover,
            model: model,
            date: Date()
        )
        history.insert(item, at: 0)
        if history.count > 100 { history = Array(history.prefix(100)) }
        saveHistory()
    }

    func clearHistory() {
        history.removeAll()
        saveHistory()
    }

    private var historyFileURL: URL? {
        guard let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        let folder = dir.appendingPathComponent("ZVideoGenerator", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder.appendingPathComponent("history.json")
    }

    private func loadHistory() {
        guard let url = historyFileURL, let data = try? Data(contentsOf: url) else { return }
        let decoded = (try? JSONDecoder().decode([HistoryItem].self, from: data)) ?? []
        history = decoded
    }

    private func saveHistory() {
        guard let url = historyFileURL,
              let data = try? JSONEncoder().encode(history) else { return }
        try? data.write(to: url, options: .atomic)
    }
}

private extension String {
    var containsOnlyWhitespace: Bool { trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
}
