import SwiftUI
import UniformTypeIdentifiers

// MARK: - Cabeçalho

struct PageHeader: View {
    let page: Page
    let subtitle: String

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(page.color.gradient)
                    .frame(width: 44, height: 44)
                    .shadow(color: page.color.opacity(0.35), radius: 6, y: 3)
                Image(systemName: page.icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(page == .dlQueue || page == .cvQueue || page == .ctQueue ? queueTitle : page.label)
                    .font(.title2.weight(.semibold))
                Text(subtitle).font(.callout).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 4)
        .padding(.top, 6)
        .padding(.bottom, 18)
        .listRowInsets(EdgeInsets())
        .listRowBackground(Color.clear)
    }

    private var queueTitle: String {
        switch page {
        case .dlQueue: return "Fila de Downloads"
        case .cvQueue: return "Fila de Conversão"
        default: return "Fila de Cortes"
        }
    }
}

/// Layout padrão das páginas: formulário agrupado + barra de ações inferior.
struct PageScaffold<Content: View, Actions: View>: View {
    let page: Page
    let subtitle: String
    @ViewBuilder var content: Content
    @ViewBuilder var actions: Actions

    var body: some View {
        Form {
            Section { } header: { PageHeader(page: page, subtitle: subtitle) }
            content
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .background(Color(nsColor: .windowBackgroundColor))
        .safeAreaInset(edge: .bottom, spacing: 0) {
            HStack(spacing: 10) { actions }
                .controlSize(.large)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
                .background(.bar)
                .overlay(alignment: .top) { Divider() }
        }
    }
}

// MARK: - Campo de link

struct LinkField: View {
    let placeholder: String
    @Binding var text: String
    var onSubmit: () -> Void = {}

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "link").foregroundStyle(.secondary)
            TextField("", text: $text, prompt: Text(placeholder))
                .textFieldStyle(.plain)
                .labelsHidden()
                .onSubmit(onSubmit)
            if !text.isEmpty {
                Button { text = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .help("Limpar")
            }
            Button {
                if let s = NSPasteboard.general.string(forType: .string) {
                    text = s.trimmingCharacters(in: .whitespacesAndNewlines)
                    onSubmit()
                }
            } label: {
                Label("Colar", systemImage: "doc.on.clipboard")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(.vertical, 4)
    }
}

struct LinksEditor: View {
    @Binding var text: String
    let placeholder: String

    var body: some View {
        ZStack(alignment: .topLeading) {
            TextEditor(text: $text)
                .font(.system(.body, design: .monospaced))
                .scrollContentBackground(.hidden)
                .frame(minHeight: 90, maxHeight: 140)
            if text.isEmpty {
                Text(placeholder)
                    .foregroundStyle(.tertiary)
                    .padding(.leading, 5)
                    .allowsHitTesting(false)
            }
        }
        .padding(6)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color(nsColor: .textBackgroundColor).opacity(0.6)))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.quaternary))
    }
}

// MARK: - Miniatura e itens de vídeo

struct Thumbnail: View {
    let url: URL?
    var width: CGFloat = 96

    var body: some View {
        AsyncImage(url: url) { phase in
            if let img = phase.image {
                img.resizable().aspectRatio(contentMode: .fill)
            } else {
                ZStack {
                    Rectangle().fill(.quaternary)
                    Image(systemName: "play.rectangle").foregroundStyle(.tertiary)
                }
            }
        }
        .frame(width: width, height: width * 9 / 16)
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).strokeBorder(.black.opacity(0.08)))
    }
}

struct VideoCard: View {
    let entry: VideoEntry

    var body: some View {
        HStack(spacing: 14) {
            Thumbnail(url: entry.thumbnail, width: 160)
            VStack(alignment: .leading, spacing: 6) {
                Text(entry.title).font(.headline).lineLimit(2)
                if let u = entry.uploader {
                    Label(u, systemImage: "person.crop.circle").font(.callout).foregroundStyle(.secondary)
                }
                if let d = entry.duration {
                    Label(TimeUtils.format(d), systemImage: "clock").font(.callout).foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

struct VideoEntryRow: View {
    @Binding var entry: VideoEntry
    var showIndex = false
    var onRemove: (() -> Void)?

    var body: some View {
        HStack(spacing: 12) {
            Toggle("", isOn: $entry.selected)
                .toggleStyle(.checkbox)
                .labelsHidden()
                .disabled(entry.state != .ready)
            if showIndex, let i = entry.index {
                Text("\(i)").font(.caption.monospacedDigit()).foregroundStyle(.secondary).frame(width: 26, alignment: .trailing)
            }
            Thumbnail(url: entry.thumbnail, width: 72)
            VStack(alignment: .leading, spacing: 3) {
                Text(entry.title).lineLimit(1)
                switch entry.state {
                case .loading:
                    HStack(spacing: 6) { ProgressView().controlSize(.mini); Text("Carregando…") }
                        .font(.caption).foregroundStyle(.secondary)
                case .failed(let msg):
                    Label(msg, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption).foregroundStyle(.red).lineLimit(1)
                case .ready:
                    Text([entry.uploader, entry.duration.map { TimeUtils.format($0) }].compactMap { $0 }.joined(separator: " · "))
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            if let onRemove {
                Button(action: onRemove) { Image(systemName: "minus.circle.fill").foregroundStyle(.secondary) }
                    .buttonStyle(.plain).help("Remover")
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { if entry.state == .ready { entry.selected.toggle() } }
    }
}

// MARK: - Seções de opções

enum OptionsContext { case download, convert }

struct MediaOptionsSection: View {
    @Binding var options: MediaOptions
    var context: OptionsContext = .download
    var title = "Formato e qualidade"

    var body: some View {
        Section(title) {
            MediaOptionsFields(options: $options, context: context)
        }
    }
}

struct MediaOptionsFields: View {
    @Binding var options: MediaOptions
    var context: OptionsContext = .download

    var body: some View {
        Picker("Baixar como", selection: $options.kind) {
            ForEach(MediaKind.allCases) { k in Label(k.label, systemImage: k.icon).tag(k) }
        }
        .pickerStyle(.segmented)
        .labelsHidden()

        if options.kind == .video {
            Picker("Qualidade", selection: $options.quality) {
                ForEach(VideoQuality.allCases) { q in Text(q.label(original: context == .convert)).tag(q) }
            }
            Picker("Formato", selection: $options.container) {
                ForEach(context == .download ? VideoContainer.downloadable : VideoContainer.allCases) { c in
                    Text(c.label).tag(c)
                }
            }
            if context == .convert {
                Picker("Compressão", selection: $options.preset) {
                    ForEach(EncodePreset.allCases) { p in Text(p.label).tag(p) }
                }
            }
        } else {
            Picker("Formato", selection: $options.audioFormat) {
                ForEach(AudioFormat.allCases) { f in Text(f.label).tag(f) }
            }
            if !options.audioFormat.isLossless {
                Picker("Qualidade", selection: $options.audioBitrate) {
                    ForEach(AudioBitrate.allCases) { b in Text(b.label).tag(b) }
                }
            }
        }
    }
}

struct NamingSection: View {
    @Binding var naming: NamingMode

    var body: some View {
        Section("Nomear arquivos") {
            Picker("Nomes", selection: $naming) {
                ForEach(NamingMode.allCases) { n in
                    VStack(alignment: .leading) {
                        Text(n.label)
                        Text(n.example).font(.caption).foregroundStyle(.secondary)
                    }.tag(n)
                }
            }
            .pickerStyle(.radioGroup)
            .labelsHidden()
        }
    }
}

struct SaveLocationSection: View {
    @Binding var location: SaveLocation
    var allowSource = false
    @ObservedObject private var settings = AppSettings.shared

    private var modes: [SaveMode] {
        allowSource ? SaveMode.allCases : [.lastUsed, .choose, .defaultFolder]
    }

    var body: some View {
        Section {
            Toggle(isOn: $location.customize.animation()) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Escolher onde salvar")
                    if !location.customize {
                        Text("Salvando na pasta padrão").font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            if location.customize {
                Picker("Destino", selection: $location.mode) {
                    ForEach(modes) { m in Label(m.label, systemImage: m.icon).tag(m) }
                }
                if location.mode == .choose {
                    HStack {
                        Text("Pasta")
                        Spacer()
                        Text(location.chosenFolder?.path(percentEncoded: false).abbreviatingHome ?? "Nenhuma selecionada")
                            .foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
                        Button("Escolher…") {
                            if let u = Finder.chooseFolder() { location.chosenFolder = u }
                        }
                    }
                }
            }
            HStack {
                Image(systemName: "folder.fill").foregroundStyle(.blue)
                Text(destinationText)
                    .font(.callout).foregroundStyle(.secondary)
                    .lineLimit(1).truncationMode(.middle)
            }
        } header: {
            Text("Salvar em")
        }
    }

    private var destinationText: String {
        if location.customize && location.mode == .sourceFolder { return "Mesma pasta de cada arquivo" }
        if let u = location.resolve() { return u.path(percentEncoded: false).abbreviatingHome }
        return "Será perguntado ao iniciar"
    }
}

extension String {
    var abbreviatingHome: String { (self as NSString).abbreviatingWithTildeInPath }
}

struct TimeField: View {
    let label: String
    @Binding var text: String
    var placeholder = "00:00"

    var body: some View {
        LabeledContent(label) {
            TextField("", text: $text, prompt: Text(placeholder))
                .textFieldStyle(.roundedBorder)
                .multilineTextAlignment(.trailing)
                .font(.body.monospacedDigit())
                .frame(width: 110)
        }
    }
}

struct TimeRangeFields: View {
    @Binding var range: TimeRange
    var duration: Double?

    var body: some View {
        TimeField(label: "Início", text: $range.start, placeholder: "00:00")
        TimeField(label: "Fim", text: $range.end, placeholder: duration.map { TimeUtils.format($0) } ?? "fim")
        if let err = range.validationError {
            Label(err, systemImage: "exclamationmark.triangle.fill").foregroundStyle(.orange).font(.callout)
        } else if range.isActive {
            let s = range.startSeconds ?? 0
            let e = range.endSeconds ?? duration
            Label("Duração do trecho: \(e.map { TimeUtils.format($0 - s) } ?? "até o fim")", systemImage: "timer")
                .font(.callout).foregroundStyle(.secondary)
        }
    }
}

struct TimeRangeSection: View {
    @Binding var range: TimeRange
    var toggleLabel = "Baixar apenas um trecho"
    var duration: Double?

    var body: some View {
        Section {
            Toggle(toggleLabel, isOn: $range.enabled.animation())
            if range.enabled {
                TimeRangeFields(range: $range, duration: duration)
            }
        } header: {
            Text("Trecho")
        } footer: {
            if range.enabled {
                Text("Use o formato hh:mm:ss, mm:ss ou segundos. Deixe em branco para começar do início ou ir até o fim.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Seleção de arquivos

struct FileDropZone: View {
    var multiple: Bool
    var onFiles: ([URL]) -> Void
    @State private var targeted = false

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: multiple ? "square.and.arrow.down.on.square" : "square.and.arrow.down")
                .font(.system(size: 30, weight: .light))
                .foregroundStyle(targeted ? Color.accentColor : .secondary)
            Text(multiple ? "Arraste arquivos aqui" : "Arraste um arquivo aqui")
                .font(.headline)
            Text("ou").font(.caption).foregroundStyle(.secondary)
            Button(multiple ? "Selecionar arquivos…" : "Selecionar arquivo…") {
                let urls = Finder.chooseMediaFiles(multiple: multiple)
                if !urls.isEmpty { onFiles(urls) }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 26)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                .foregroundStyle(targeted ? Color.accentColor : Color.secondary.opacity(0.4))
                .background(RoundedRectangle(cornerRadius: 12).fill(targeted ? Color.accentColor.opacity(0.08) : .clear))
        )
        .onDrop(of: [.fileURL], isTargeted: $targeted) { providers in
            loadURLs(providers) { urls in onFiles(multiple ? urls : Array(urls.prefix(1))) }
            return true
        }
    }
}

func loadURLs(_ providers: [NSItemProvider], completion: @escaping @MainActor ([URL]) -> Void) {
    let group = DispatchGroup()
    let lock = NSLock()
    var urls: [URL] = []
    for p in providers {
        group.enter()
        _ = p.loadObject(ofClass: URL.self) { url, _ in
            if let url { lock.lock(); urls.append(url); lock.unlock() }
            group.leave()
        }
    }
    group.notify(queue: .main) {
        MainActor.assumeIsolated { completion(urls.sorted { $0.lastPathComponent < $1.lastPathComponent }) }
    }
}

struct FileHeaderRow: View {
    let file: MediaFile
    var onChange: (() -> Void)?

    var body: some View {
        HStack(spacing: 12) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: file.url.path))
                .resizable().frame(width: 36, height: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(file.name).font(.headline).lineLimit(1).truncationMode(.middle)
                Text(file.infoText).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if let onChange {
                Button("Trocar…", action: onChange)
            }
        }
    }
}

// MARK: - Progresso de trabalhos

struct JobRow: View {
    @ObservedObject var job: Job
    var onRemove: (() -> Void)?

    var body: some View {
        HStack(spacing: 12) {
            statusIcon.frame(width: 26)
            VStack(alignment: .leading, spacing: 4) {
                Text(job.title).lineLimit(1).truncationMode(.middle)
                if job.status.isActive || (job.status == .pending && job.progress != nil) {
                    if let p = job.progress, job.status != .finishing {
                        ProgressView(value: p).progressViewStyle(.linear)
                    } else {
                        ProgressView().progressViewStyle(.linear)
                    }
                }
                HStack(spacing: 6) {
                    Text(job.subtitle)
                    if !statusText.isEmpty { Text("·"); Text(statusText).foregroundStyle(statusColor) }
                }
                .font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer(minLength: 8)
            actions
        }
        .padding(.vertical, 3)
        .contextMenu {
            if let u = job.outputURL { Button("Mostrar no Finder") { Finder.reveal(u) } }
            Button("Abrir pasta de destino") { Finder.open(job.outputDir) }
            if case .download(let s) = job.work {
                Button("Copiar link") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(s.url, forType: .string)
                }
            }
        }
    }

    private var statusText: String {
        switch job.status {
        case .pending: return "Aguardando"
        case .running, .finishing: return job.detail
        case .done: return "Concluído"
        case .failed(let m): return m
        case .cancelled: return "Cancelado"
        }
    }

    private var statusColor: Color {
        switch job.status {
        case .done: return .green
        case .failed: return .red
        default: return .secondary
        }
    }

    @ViewBuilder private var statusIcon: some View {
        switch job.status {
        case .pending: Image(systemName: job.icon).foregroundStyle(.secondary)
        case .running, .finishing:
            if let p = job.progress, job.status == .running {
                ZStack {
                    Circle().stroke(.quaternary, lineWidth: 3)
                    Circle().trim(from: 0, to: p).stroke(Color.accentColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                }.frame(width: 20, height: 20)
            } else {
                ProgressView().controlSize(.small)
            }
        case .done: Image(systemName: "checkmark.circle.fill").foregroundStyle(.green).font(.title3)
        case .failed: Image(systemName: "exclamationmark.circle.fill").foregroundStyle(.red).font(.title3)
        case .cancelled: Image(systemName: "xmark.circle").foregroundStyle(.secondary).font(.title3)
        }
    }

    @ViewBuilder private var actions: some View {
        HStack(spacing: 6) {
            if job.status.isActive || job.status == .pending {
                iconButton("xmark", help: "Cancelar") { job.cancel() }
            }
            if case .failed = job.status { iconButton("arrow.clockwise", help: "Tentar novamente") { job.retry() } }
            if job.status == .cancelled { iconButton("arrow.clockwise", help: "Tentar novamente") { job.retry() } }
            if let u = job.outputURL, job.status == .done {
                iconButton("magnifyingglass", help: "Mostrar no Finder") { Finder.reveal(u) }
            }
            if let onRemove, !job.status.isActive {
                iconButton("trash", help: "Remover") { onRemove() }
            }
        }
    }

    private func iconButton(_ icon: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { Image(systemName: icon) }
            .buttonStyle(.borderless)
            .help(help)
    }
}

/// Seção com os trabalhos em andamento de uma página.
struct ActivitySection: View {
    @ObservedObject var queue: JobQueue
    var title = "Atividade"

    var body: some View {
        if !queue.jobs.isEmpty {
            Section {
                ForEach(queue.jobs) { job in
                    JobRow(job: job) {
                        queue.remove(job)
                    }
                }
            } header: {
                HStack {
                    Text(title)
                    Spacer()
                    if queue.jobs.count > 1 {
                        Text("\(queue.doneCount) de \(queue.jobs.count)").monospacedDigit()
                    }
                    if queue.hasFinished {
                        Button("Limpar concluídos") { withAnimation { queue.clearFinished() } }
                            .buttonStyle(.link).font(.caption)
                    }
                }
            }
            .onChange(of: queue.jobs.contains { $0.status == .pending }) { _, hasPending in
                // reinicia trabalhos reenviados (tentar novamente)
                if hasPending && !queue.isRunning { queue.start() }
            }
        }
    }
}

// MARK: - Botões padrão da barra inferior

struct OpenFolderButton: View {
    var folder: () -> URL?
    var body: some View {
        Button { Finder.open(folder()) } label: { Label("Abrir pasta", systemImage: "folder") }
    }
}

struct AddToQueueButton: View {
    var count: Int = 1
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            Label(count > 1 ? "Enviar \(count) para a fila" : "Enviar para a fila", systemImage: "text.badge.plus")
        }
    }
}

struct PrimaryButton: View {
    let title: String
    let icon: String
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            Label(title, systemImage: icon).frame(minWidth: 90)
        }
        .buttonStyle(.borderedProminent)
        .keyboardShortcut(.defaultAction)
    }
}
