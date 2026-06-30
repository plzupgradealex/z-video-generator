import SwiftUI
import AppKit

/// The Generate screen. The gallery is a list of independent jobs — add up to N,
/// each with its own prompt + settings, then "Generate all" fires them
/// concurrently (throttled to `AppLimits.maxConcurrent`). Click a card to open
/// `JobDetailView`, the focused single-job workspace (status, settings, and the
/// video panel) — the "old nice interface" lives there.
struct GenerationView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.colorScheme) private var scheme
    @State private var playingJob: GenerationJob?
    @State private var openedJob: GenerationJob?
    /// Opens the API-key sheet from the "Add key" banner. Passed in by
    /// `ContentView`, which owns the sheet state.
    var onAddKey: () -> Void = {}

    private let columns = [GridItem(.flexible(), spacing: Spacing.s5),
                           GridItem(.flexible(), spacing: Spacing.s5)]

    private var runnableCount: Int { model.jobs.filter { $0.canGenerate }.count }

    var body: some View {
        if let job = openedJob {
            JobDetailView(job: job, onBack: { openedJob = nil }, onAddKey: onAddKey)
        } else if model.jobs.isEmpty {
            emptyState
        } else {
            gallery
        }
    }

    /// Create a fresh job and focus into its detail workspace.
    private func startNewJob() {
        if let job = model.addJob() { openedJob = job }
    }

    private var emptyState: some View {
        let set = AppTheme.resolve(scheme)
        return VStack(spacing: Spacing.s6) {
            Spacer(minLength: 0)
            VStack(spacing: Spacing.s5) {
                ZStack {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(set.interactiveSoft)
                    Image(systemName: "wand.and.stars")
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundStyle(set.interactive)
                }
                .frame(width: 72, height: 72)

                VStack(spacing: Spacing.s2) {
                    Text("No videos yet").font(.app(AppType.heading01)).foregroundStyle(.primary)
                    Text("Generate a video — write a prompt, pick settings, and render. Come back here to run several at once.")
                        .font(.app(AppType.body)).foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: 420)

                if model.isDemoMode && !model.isAuthenticated {
                    Label("Demo mode — results are sample videos. Add a Z.AI key to generate for real.", systemImage: "sparkles")
                        .font(.app(AppType.caption)).foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 420)
                        .fixedSize(horizontal: false, vertical: true)
                } else if !model.canUse {
                    APIKeyBanner(onAddKey: onAddKey)
                        .frame(maxWidth: 420)
                }

                Button { startNewJob() } label: {
                    Label("Generate Video", systemImage: "plus")
                        .font(.app(AppType.body)).fontWeight(.semibold)
                        .padding(.horizontal, Spacing.s6)
                        .frame(minHeight: 44)
                        .contentShape(.rect)
                }
                .buttonStyle(.glassProminent)
                .controlSize(.large)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(Spacing.s7)
        .background(SmokeBackground())
    }

    private var gallery: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.s6) {
                if !model.canUse { APIKeyBanner(onAddKey: onAddKey) }
                header
                LazyVGrid(columns: columns, alignment: .leading, spacing: Spacing.s5) {
                    ForEach(model.jobs) { job in
                        JobCard(job: job,
                                onOpen: { openedJob = job },
                                onPlay: { playingJob = job },
                                onAddKey: onAddKey)
                    }
                    if model.jobs.count < AppLimits.maxJobs {
                        addCard
                    }
                }
            }
            .padding(Spacing.s6)
            .frame(maxWidth: 1000)
            .frame(maxWidth: .infinity)
        }
        .background(SmokeBackground())
        .sheet(item: $playingJob) { job in
            if let url = job.resultVideoURL { VideoPlayerView(url: url) }
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: Spacing.s1) {
                Text("Generate").font(.app(AppType.heading02)).foregroundStyle(.primary)
                Text(summary)
                    .font(.app(AppType.caption)).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            actions
        }
    }

    private var summary: String {
        if model.hasActive {
            return "\(model.activeCount) rendering · \(model.queuedCount) queued · \(model.successCount) done"
        } else if model.successCount > 0 || model.failedCount > 0 {
            return "\(model.successCount) ready · \(model.failedCount) failed"
        } else {
            return "Add prompts and run them in parallel — up to \(AppLimits.maxConcurrent) at once."
        }
    }

    private var actions: some View {
        HStack(spacing: Spacing.s3) {
            Button { startNewJob() } label: {
                Label("Generate Video", systemImage: "plus").font(.app(AppType.body))
            }
            .buttonStyle(.glass)
            if model.hasActive {
                Button(role: .cancel) { model.cancelAll() } label: {
                    Label("Stop all", systemImage: "stop.fill").font(.app(AppType.body))
                }
                .buttonStyle(.glass)
            }
            if model.successCount > 0 || model.failedCount > 0 {
                Button { model.clearFinished() } label: {
                    Label("Clear done", systemImage: "checkmark.circle").font(.app(AppType.body))
                }
                .buttonStyle(.glass)
            }
            Button { model.generateAll() } label: {
                Label(runnableCount > 0 ? "Generate all (\(runnableCount))" : "Generate all",
                      systemImage: "wand.and.stars")
                    .font(.app(AppType.body)).fontWeight(.semibold)
            }
            .buttonStyle(.glassProminent)
            .disabled(!model.canGenerateAll)
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    private var addCard: some View {
        Button { startNewJob() } label: {
            VStack(spacing: Spacing.s2) {
                Image(systemName: "plus").font(.title3)
                Text("Generate Video").font(.app(AppType.caption))
            }
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, minHeight: 150)
            .background(
                RoundedRectangle(cornerRadius: Radius.medium, style: .continuous)
                    .strokeBorder(Color.secondary.opacity(0.3), style: StrokeStyle(lineWidth: 1.5, dash: [6, 5]))
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Job card (gallery item)

private struct JobCard: View {
    @Bindable var job: GenerationJob
    let onOpen: () -> Void
    let onPlay: () -> Void
    let onAddKey: () -> Void
    @Environment(AppModel.self) private var model
    @Environment(\.colorScheme) private var scheme
    @State private var chevronHovered = false

    var body: some View {
        Surface {
            VStack(alignment: .leading, spacing: Spacing.s3) {
                topRow
                promptEditor
                chipsRow
                statusArea
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(count: 2) { onOpen() }
    }

    private var topRow: some View {
        HStack(spacing: Spacing.s2) {
            Circle().fill(statusColor).frame(width: 8, height: 8)
            Text("Video \(number)")
                .font(.app(AppType.body)).fontWeight(.medium).foregroundStyle(.primary)
            Spacer()
            // Open the focused detail view for this job.
            Button(action: onOpen) {
                Image(systemName: "chevron.right").font(.body)
                    .frame(width: 18, height: 16)
                    .foregroundStyle(.secondary)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.carbonGhost(hovered: chevronHovered))
            .onHover { chevronHovered = $0 }
            .help("Open job")
            Menu {
                Button("Open") { onOpen() }
                Button("Save to library") { model.savePrompt(from: job) }
                Button("Duplicate") { model.duplicate(job) }
                Divider()
                Button("Remove", role: .destructive) { model.remove(job) }
            } label: {
                Image(systemName: "ellipsis").font(.body)
                    .frame(width: 24, height: 16)
                    .contentShape(Rectangle())
            }
            .fixedSize()
        }
    }

    private var promptEditor: some View {
        let set = AppTheme.resolve(scheme)
        return VStack(alignment: .trailing, spacing: 2) {
            TextEditor(text: $job.prompt)
                .font(.app(AppType.body))
                .scrollContentBackground(.hidden)
                .frame(minHeight: 64, maxHeight: 120)
                .padding(Spacing.s2)
                .fieldBackground()
                .onChange(of: job.prompt) { _, newValue in
                    if newValue.count > AppLimits.prompt {
                        job.prompt = String(newValue.prefix(AppLimits.prompt))
                    }
                }
            Text("\(job.prompt.count) / \(AppLimits.prompt)")
                .font(.app(AppType.tag))
                .foregroundStyle(job.prompt.count >= AppLimits.prompt ? set.danger : set.textSecondary)
                .monospacedDigit()
        }
    }

    private var chipsRow: some View {
        HStack(spacing: Spacing.s2) {
            Chip(text: job.model)
            Chip(text: aspectLabel)
            Chip(text: "\(job.duration)s")
            Chip(text: "\(job.fps)fps")
        }
    }

    @ViewBuilder
    private var statusArea: some View {
        let set = AppTheme.resolve(scheme)
        switch job.status {
        case .idle:
            HStack(spacing: Spacing.s2) {
                Image(systemName: job.canGenerate ? "circle.dashed" : "text.bubble")
                    .foregroundStyle(.tertiary)
                Text(job.canGenerate ? "Ready" : "Add a prompt to generate")
                    .font(.app(AppType.caption)).foregroundStyle(.tertiary)
                Spacer()
                if job.canGenerate {
                    Button { model.generate(job) } label: {
                        Label("Generate", systemImage: "wand.and.stars")
                            .font(.app(AppType.caption))
                            .padding(.horizontal, Spacing.s3)
                            .padding(.vertical, Spacing.s2)
                            .frame(minHeight: 32)
                            .contentShape(.rect)
                    }
                    .buttonStyle(.glassProminent)
                    .controlSize(.regular)
                    .disabled(!model.canUse)
                }
            }
        case .processing:
            ZStack(alignment: .bottomLeading) {
                LoadingArt()
                HStack(spacing: Spacing.s3) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Rendering")
                            .font(.app(AppType.caption)).foregroundStyle(.white).fontWeight(.semibold)
                        Text(job.statusMessage.isEmpty ? "Working…" : job.statusMessage)
                            .font(.app(AppType.tag)).foregroundStyle(.white.opacity(0.85)).lineLimit(1)
                    }
                    Spacer()
                    ProgressView().controlSize(.small).tint(.white)
                }
                .padding(.horizontal, Spacing.s3).padding(.vertical, Spacing.s2)
                .background(Color.black.opacity(0.4), in: .rect(cornerRadius: Radius.small))
                .padding(Spacing.s2)
            }
            .frame(height: 144)
            .clipShape(RoundedRectangle(cornerRadius: Radius.small, style: .continuous))
            .overlay(alignment: .topTrailing) {
                Button("Cancel") { model.cancel(job) }
                    .font(.app(AppType.caption))
                    .buttonStyle(.glass)
                    .controlSize(.small)
                    .padding(Spacing.s2)
            }
        case .success:
            playPreview
        case .failed:
            HStack(alignment: .top, spacing: Spacing.s2) {
                Image(systemName: job.showsOutOfCredit ? "dollarsign.circle.fill" : "exclamationmark.triangle.fill")
                    .foregroundStyle(job.showsOutOfCredit ? set.warning : set.danger)
                Text(job.errorMessage ?? "Generation failed")
                    .font(.app(AppType.caption))
                    .foregroundStyle(job.showsOutOfCredit ? set.warning : set.danger)
                    .lineLimit(3)
                Spacer()
                // Retry won't help when the key is out of credit or rejected —
                // nudge to reload the key instead.
                if job.showsOutOfCredit || job.showsKeyError {
                    Button("Update key") { onAddKey() }
                        .font(.app(AppType.caption)).buttonStyle(.borderless)
                } else {
                    Button("Retry") { model.regenerate(job) }
                        .font(.app(AppType.caption)).buttonStyle(.borderless)
                        .disabled(!model.canUse)
                }
            }
        }
    }

    private var playPreview: some View {
        Button(action: onPlay) {
            ZStack {
                RoundedRectangle(cornerRadius: Radius.small, style: .continuous).fill(Color.black)
                if let cover = job.resultCoverURL {
                    AsyncImage(url: cover) { phase in
                        switch phase {
                        case .success(let image): image.resizable().scaledToFill()
                        default: Color.black
                        }
                    }
                }
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 46, height: 46)
                    .overlay(Image(systemName: "play.fill").foregroundStyle(.white).font(.system(size: 16, weight: .bold)))
            }
            .frame(height: 144)
            .clipShape(RoundedRectangle(cornerRadius: Radius.small, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: Helpers

    private var statusColor: Color {
        let set = AppTheme.resolve(scheme)
        switch job.status {
        case .idle:       return set.textSecondary
        case .processing: return set.interactive
        case .success:    return set.success
        case .failed:     return set.danger
        }
    }

    private var number: Int {
        (model.jobs.firstIndex { $0.id == job.id }).map { $0 + 1 } ?? 0
    }

    private var aspectLabel: String {
        model.aspectOptions.first(where: { $0.value == job.aspect })?.label ?? "Default"
    }
}

// MARK: - Job detail (the focused single-job workspace)

/// The "old nice interface": a roomy, focused view for one job with the full
/// prompt + settings editor on the left and the status/video panel on the right.
/// Reached by opening a card from the gallery; `onBack` returns to the list.
struct JobDetailView: View {
    @Bindable var job: GenerationJob
    let onBack: () -> Void
    let onAddKey: () -> Void
    @Environment(AppModel.self) private var model
    @Environment(\.colorScheme) private var scheme
    @State private var saving = false
    @State private var savedMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.s5) {
                detailHeader
                HStack(alignment: .top, spacing: Spacing.s6) {
                    editorColumn
                        .frame(maxWidth: 440)
                    panelColumn
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(Spacing.s6)
            .frame(maxWidth: 1120)
            .frame(maxWidth: .infinity)
        }
        .background(SmokeBackground())
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button(action: onBack) {
                    Label("Videos", systemImage: "chevron.left")
                }
                .help("Back to videos")
            }
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button("Save to library") { model.savePrompt(from: job) }
                    Button("Copy prompt") { copyPrompt() }
                    Button("Duplicate") { model.duplicate(job) }
                    Divider()
                    Button("Remove", role: .destructive) {
                        model.remove(job)
                        onBack()
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
    }

    private var detailHeader: some View {
        HStack(spacing: Spacing.s3) {
            Text("Video \(number)")
                .font(.app(AppType.heading01)).foregroundStyle(.primary)
            Chip(text: statusLabel, tone: statusTone)
            Spacer()
        }
    }

    // MARK: Editor column

    private var editorColumn: some View {
        let set = AppTheme.resolve(scheme)
        return Surface {
            VStack(alignment: .leading, spacing: Spacing.s5) {
                VStack(alignment: .leading, spacing: Spacing.s2) {
                    Eyebrow(text: "Prompt")
                    TextEditor(text: $job.prompt)
                        .font(.app(AppType.body))
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 140, maxHeight: 260)
                        .padding(Spacing.s2)
                        .fieldBackground()
                        .onChange(of: job.prompt) { _, v in
                            if v.count > AppLimits.prompt { job.prompt = String(v.prefix(AppLimits.prompt)) }
                        }
                    Text("\(job.prompt.count) / \(AppLimits.prompt)")
                        .font(.app(AppType.tag))
                        .foregroundStyle(job.prompt.count >= AppLimits.prompt ? set.danger : set.textSecondary)
                        .monospacedDigit()
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }

                parameterGrid
                imageRef
            }
        }
    }

    private var parameterGrid: some View {
        VStack(alignment: .leading, spacing: Spacing.s5) {
            Eyebrow(text: "Parameters")
            VStack(spacing: Spacing.s4) {
                paramRow("Model") {
                    Picker("", selection: $job.model) {
                        ForEach(model.models, id: \.self) { Text($0).tag($0) }
                    }
                    .pickerStyle(.menu).labelsHidden()
                }
                paramRow("Aspect") {
                    Picker("", selection: $job.aspect) {
                        ForEach(model.aspectOptions) { Text($0.label).tag($0.value) }
                    }
                    .pickerStyle(.menu).labelsHidden()
                }
                paramRow("Resolution") {
                    Picker("", selection: $job.size) {
                        ForEach(model.sizes, id: \.self) { Text($0).tag($0) }
                    }
                    .pickerStyle(.menu).labelsHidden()
                }
                paramRow("Duration") {
                    Picker("", selection: $job.duration) {
                        ForEach(model.durations, id: \.self) { Text("\($0)s").tag($0) }
                    }
                    .pickerStyle(.segmented)
                }
                paramRow("FPS") {
                    Picker("", selection: $job.fps) {
                        ForEach(model.fpsOptions, id: \.self) { Text("\($0)").tag($0) }
                    }
                    .pickerStyle(.segmented)
                }
                paramRow("Quality") {
                    Picker("", selection: $job.quality) {
                        ForEach(model.qualities, id: \.self) { Text($0.capitalized).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .disabled(job.model != "cogvideox-3")
                }
                paramRow("Motion") {
                    Picker("", selection: $job.movement) {
                        ForEach(model.movements, id: \.self) { Text($0.capitalized).tag($0) }
                    }
                    .pickerStyle(.menu).labelsHidden()
                }
            }
            Toggle("Include audio", isOn: $job.withAudio)
                .font(.app(AppType.body))
        }
    }

    /// One aligned settings row: label on the left, control pinned to a
    /// consistent trailing width so every row lines up.
    private func paramRow<C: View>(_ title: String, @ViewBuilder control: () -> C) -> some View {
        HStack(spacing: Spacing.s4) {
            Text(title)
                .font(.app(AppType.body))
                .foregroundStyle(.secondary)
            Spacer(minLength: Spacing.s4)
            control()
                .frame(maxWidth: .infinity)
                .frame(width: 240)
        }
    }

    private var imageRef: some View {
        VStack(alignment: .leading, spacing: Spacing.s2) {
            Eyebrow(text: "Image reference (optional)")
            TextField("Image URL or data:image base64", text: $job.imageURL, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .font(.app(AppType.body))
                .lineLimit(2...5)
        }
    }

    // MARK: Panel column

    private var panelColumn: some View {
        VStack(alignment: .leading, spacing: Spacing.s3) {
            HStack(spacing: Spacing.s3) {
                Chip(text: statusLabel, tone: statusTone)
                Spacer()
                primaryAction
            }
            stage
        }
    }

    private var statusLabel: String {
        switch job.status {
        case .idle:       return "Ready"
        case .processing: return job.statusMessage.isEmpty ? "Rendering" : job.statusMessage
        case .success:    return "Ready"
        case .failed:     return "Failed"
        }
    }

    private var statusTone: Chip.Tone {
        switch job.status {
        case .idle:       return .neutral
        case .processing: return .accent
        case .success:    return .success
        case .failed:     return .danger
        }
    }

    @ViewBuilder
    private var primaryAction: some View {
        switch job.status {
        case .idle:
            Button { model.generate(job) } label: {
                Label("Generate", systemImage: "wand.and.stars").font(.app(AppType.body)).fontWeight(.semibold)
            }
            .buttonStyle(.glassProminent)
            .controlSize(.large)
            .disabled(!job.canGenerate || !model.canUse)
        case .processing:
            Button(role: .cancel) { model.cancel(job) } label: {
                Text("Cancel").font(.app(AppType.body))
            }
            .buttonStyle(.glass)
            .controlSize(.large)
        case .success:
            Button { model.regenerate(job) } label: {
                Label("Regenerate", systemImage: "arrow.triangle.2.circlepath").font(.app(AppType.body))
            }
            .buttonStyle(.glass)
            .controlSize(.large)
            .disabled(!model.isAuthenticated)
        case .failed:
            if job.showsOutOfCredit || job.showsKeyError {
                Button { onAddKey() } label: {
                    Label(job.showsKeyError ? "Update API key" : "Reload API key", systemImage: "key.fill")
                        .font(.app(AppType.body)).fontWeight(.semibold)
                }
                .buttonStyle(.glassProminent)
                .controlSize(.large)
            } else {
                Button { model.regenerate(job) } label: {
                    Label("Retry", systemImage: "arrow.triangle.2.circlepath").font(.app(AppType.body)).fontWeight(.semibold)
                }
                .buttonStyle(.glassProminent)
                .controlSize(.large)
                .disabled(!model.isAuthenticated)
            }
        }
    }

    @ViewBuilder
    private var stage: some View {
        switch job.status {
        case .idle:
            placeholderStage
        case .processing:
            LoadingArtPanel(job: job)
        case .success:
            successStage
        case .failed:
            failedStage
        }
    }

    private var placeholderStage: some View {
        let set = AppTheme.resolve(scheme)
        return ZStack {
            RoundedRectangle(cornerRadius: Radius.medium, style: .continuous)
                .fill(set.surfaceAlt)
            VStack(spacing: Spacing.s3) {
                Image(systemName: "film.stack")
                    .font(.system(size: 30))
                    .foregroundStyle(.secondary)
                Text(job.canGenerate ? "Ready to render" : "Add a prompt to generate")
                    .font(.app(AppType.caption)).foregroundStyle(.secondary)
            }
        }
        .frame(height: 320)
        .clipShape(RoundedRectangle(cornerRadius: Radius.medium, style: .continuous))
    }

    private var successStage: some View {
        let set = AppTheme.resolve(scheme)
        return VStack(alignment: .leading, spacing: Spacing.s3) {
            if let url = job.resultVideoURL {
                AVPlayerRepresentable(url: url)
                    .aspectRatio(16.0 / 9.0, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.medium, style: .continuous))
                HStack(spacing: Spacing.s3) {
                    if let savedMessage {
                        Label(savedMessage, systemImage: "checkmark.circle.fill")
                            .font(.app(AppType.caption)).foregroundStyle(set.success)
                    }
                    Spacer()
                    Button {
                        model.savePrompt(from: job)
                        savedMessage = "Prompt saved to library"
                    } label: {
                        Label("Save prompt", systemImage: "bookmark").font(.app(AppType.body))
                    }
                    .buttonStyle(.glass)
                    if !url.isFileURL {
                        Button { ZVUtil.openExternal(url) } label: {
                            Label("Open", systemImage: "safari").font(.app(AppType.body))
                        }
                        .buttonStyle(.glass)
                    }
                    Button { saveToDownloads(url) } label: {
                        Label("Save to Downloads", systemImage: "square.and.arrow.down").font(.app(AppType.body))
                    }
                    .buttonStyle(.glassProminent)
                    .disabled(saving)
                }
            } else {
                placeholderStage
            }
        }
    }

    private var failedStage: some View {
        let set = AppTheme.resolve(scheme)
        let ooc = job.showsOutOfCredit
        let keyErr = job.showsKeyError
        let tint = (ooc || keyErr) ? set.warning : set.danger
        return VStack(alignment: .leading, spacing: Spacing.s3) {
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: Radius.medium, style: .continuous)
                    .fill(tint.opacity(0.10))
                VStack(alignment: .leading, spacing: Spacing.s2) {
                    HStack(spacing: Spacing.s2) {
                        Image(systemName: ooc ? "dollarsign.circle.fill" : "exclamationmark.triangle.fill")
                            .foregroundStyle(tint)
                        Text(ooc ? "Out of credit" : (keyErr ? "API key rejected" : "Generation failed"))
                            .font(.app(AppType.body)).fontWeight(.semibold).foregroundStyle(tint)
                    }
                    Text(job.errorMessage ?? "Something went wrong.")
                        .font(.app(AppType.caption)).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(Spacing.s4)
            }
            .frame(minHeight: 160)

            // Tailored recovery: reload the key (and top up at Z.AI) when the
            // failure is about credit or auth — a bare Retry would just fail the
            // same way again.
            if ooc || keyErr {
                HStack(spacing: Spacing.s3) {
                    Button { onAddKey() } label: {
                        Label(keyErr ? "Update API key" : "Reload API key", systemImage: "key.fill")
                            .font(.app(AppType.body)).fontWeight(.semibold)
                    }
                    .buttonStyle(.glassProminent)
                    .controlSize(.large)
                    if ooc, let url = URL(string: "https://z.ai") {
                        Link(destination: url) {
                            Label("Top up at Z.AI", systemImage: "arrow.up.right.square")
                                .font(.app(AppType.body))
                        }
                        .buttonStyle(.glass)
                        .controlSize(.large)
                    }
                    Spacer()
                }
            }
        }
    }

    private func saveToDownloads(_ url: URL) {
        saving = true
        savedMessage = nil
        Task {
            let result = await ZVUtil.saveVideo(from: url)
            await MainActor.run {
                saving = false
                if let result { savedMessage = result ? "Saved" : "Save failed" }
            }
        }
    }

    private var number: Int {
        (model.jobs.firstIndex { $0.id == job.id }).map { $0 + 1 } ?? 0
    }

    private func copyPrompt() {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(job.prompt, forType: .string)
    }
}

// MARK: - Loading art panel (detail)

/// Tall, full-bleed fire art with a legible status overlay and a Cancel control.
private struct LoadingArtPanel: View {
    @Bindable var job: GenerationJob
    @Environment(AppModel.self) private var model

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            LoadingArt()
            LinearGradient(colors: [.clear, .black.opacity(0.55)],
                           startPoint: .center, endPoint: .bottom)
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Rendering").font(.app(AppType.heading02)).foregroundStyle(.white)
                    Text(job.statusMessage.isEmpty ? "Working…" : job.statusMessage)
                        .font(.app(AppType.caption)).foregroundStyle(.white.opacity(0.85)).lineLimit(2)
                }
                Spacer()
                ProgressView().controlSize(.regular).tint(.white)
            }
            .padding(Spacing.s4)
        }
        .frame(height: 320)
        .clipShape(RoundedRectangle(cornerRadius: Radius.medium, style: .continuous))
    }
}

// MARK: - API key banner

/// Shown across the Generate screen whenever no API key is set, so a missing
/// key never reads as a reset: it calls out the one thing you can't do (render)
/// while reassuring that library, history, and saved videos are still right
/// here. The "Add key" button opens the key sheet.
struct APIKeyBanner: View {
    let onAddKey: () -> Void
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let set = AppTheme.resolve(scheme)
        HStack(spacing: Spacing.s3) {
            Image(systemName: "key.fill")
                .font(.app(AppType.body))
                .foregroundStyle(set.warning)
            VStack(alignment: .leading, spacing: 1) {
                Text("Add your Z.AI API key to generate")
                    .font(.app(AppType.body)).fontWeight(.medium).foregroundStyle(.primary)
                Text("Your library, history, and saved videos are still here.")
                    .font(.app(AppType.caption)).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: Spacing.s4)
            Button("Add key", action: onAddKey)
                .buttonStyle(.glassProminent)
                .controlSize(.small)
        }
        .padding(Spacing.s4)
        .background(
            RoundedRectangle(cornerRadius: Radius.medium, style: .continuous)
                .fill(set.warning.opacity(scheme == .dark ? 0.12 : 0.14))
        )
        .overlay(
            RoundedRectangle(cornerRadius: Radius.medium, style: .continuous)
                .strokeBorder(set.warning.opacity(0.45), lineWidth: 1)
        )
    }
}
