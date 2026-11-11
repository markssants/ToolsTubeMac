import Foundation
import SwiftUI

enum MainTab: String, CaseIterable, Identifiable {
    case download, convert, cut
    var id: String { rawValue }
    var label: String {
        switch self {
        case .download: return "Baixar"
        case .convert: return "Conversor"
        case .cut: return "Corte"
        }
    }
    var icon: String {
        switch self {
        case .download: return "arrow.down.circle"
        case .convert: return "arrow.triangle.2.circlepath"
        case .cut: return "scissors"
        }
    }
    var pages: [Page] {
        switch self {
        case .download: return [.dlSingle, .dlMulti, .dlPlaylist, .dlQueue]
        case .convert: return [.cvSingle, .cvMulti, .cvQueue]
        case .cut: return [.ctSingle, .ctMulti, .ctQueue]
        }
    }
}

enum Page: String, Hashable, Identifiable {
    case dlSingle, dlMulti, dlPlaylist, dlQueue
    case cvSingle, cvMulti, cvQueue
    case ctSingle, ctMulti, ctQueue
    var id: String { rawValue }

    var label: String {
        switch self {
        case .dlSingle: return "Vídeo Único"
        case .dlMulti: return "Vários Vídeos"
        case .dlPlaylist: return "Playlist"
        case .cvSingle: return "Converter Único"
        case .cvMulti: return "Converter Vários"
        case .ctSingle: return "Cortar Único"
        case .ctMulti: return "Cortar Vários"
        case .dlQueue, .cvQueue, .ctQueue: return "Fila"
        }
    }

    var icon: String {
        switch self {
        case .dlSingle: return "play.rectangle"
        case .dlMulti: return "rectangle.stack"
        case .dlPlaylist: return "music.note.list"
        case .cvSingle: return "doc.badge.arrow.up"
        case .cvMulti: return "doc.on.doc"
        case .ctSingle: return "scissors"
        case .ctMulti: return "square.stack.3d.down.right"
        case .dlQueue, .cvQueue, .ctQueue: return "list.bullet.rectangle.portrait"
        }
    }

    var color: Color {
        switch self {
        case .dlSingle, .dlMulti, .dlPlaylist, .dlQueue: return .red
        case .cvSingle, .cvMulti, .cvQueue: return .blue
        case .ctSingle, .ctMulti, .ctQueue: return .orange
        }
    }
}

@MainActor
final class AppState: ObservableObject {
    @Published var tab: MainTab = .download
    @Published var page: Page? = .dlSingle
    private var lastPage: [MainTab: Page] = [:]

    @Published var toast: String?
    private var toastTask: Task<Void, Never>?

    let downloadQueue = JobQueue()
    let convertQueue = JobQueue()
    let cutQueue = JobQueue()

    let single = SingleDownloadModel()
    let multi = MultiDownloadModel()
    let playlist = PlaylistModel()
    let convertSingle = ConvertSingleModel()
    let convertMulti = ConvertMultiModel()
    let cutSingle = CutSingleModel()
    let cutMulti = CutMultiModel()

    func switchTab(_ t: MainTab) {
        if let p = page { lastPage[tabOf(p)] = p }
        tab = t
        page = lastPage[t] ?? t.pages.first
    }

    func tabOf(_ p: Page) -> MainTab {
        MainTab.allCases.first { $0.pages.contains(p) } ?? .download
    }

    func showToast(_ text: String) {
        toastTask?.cancel()
        withAnimation(.spring(duration: 0.35)) { toast = text }
        toastTask = Task {
            try? await Task.sleep(for: .seconds(2.4))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.3)) { toast = nil }
        }
    }
}

extension SaveLocation {
    /// Resolve a pasta; se o modo for "escolher" e ainda não houver pasta, pergunta.
    @MainActor
    mutating func resolveOrAsk(source: URL? = nil) -> URL? {
        if customize && mode == .choose && chosenFolder == nil {
            chosenFolder = Finder.chooseFolder()
        }
        return resolve(source: source)
    }
}

func extractURLs(_ text: String) -> [String] {
    let separators = CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: ",;"))
    var seen = Set<String>()
    return text.components(separatedBy: separators)
        .map { $0.trimmingCharacters(in: CharacterSet(charactersIn: "<>\"'()")) }
        .filter { $0.hasPrefix("http://") || $0.hasPrefix("https://") }
        .filter { seen.insert($0).inserted }
}

func sanitizeFilename(_ s: String) -> String {
    let bad = CharacterSet(charactersIn: "/:\\?%*|\"<>")
    return s.components(separatedBy: bad).joined(separator: "-").trimmingCharacters(in: .whitespacesAndNewlines)
}

func numberPrefix(_ n: Int, total: Int) -> String {
    let width = max(2, String(total).count)
    return String(format: "%0\(width)d - ", n)
}

// MARK: - Baixar

@MainActor
final class SingleDownloadModel: ObservableObject {
    @Published var url = ""
    @Published var info: VideoEntry?
    @Published var loading = false
    @Published var error: String?
    @Published var options = MediaOptions()
    @Published var save = SaveLocation()
    @Published var range = TimeRange()
    let runner = JobQueue()
    private var analyzedURL = ""

    var trimmedURL: String { url.trimmingCharacters(in: .whitespacesAndNewlines) }
    var isValidURL: Bool { trimmedURL.hasPrefix("http") }

    func analyze() async {
        let u = trimmedURL
        guard u.hasPrefix("http"), u != analyzedURL else { return }
        analyzedURL = u
        loading = true; error = nil; info = nil
        do {
            switch try await YTDLP.fetch(u, playlist: false) {
            case .video(let v): if u == trimmedURL { info = v }
            case .playlist(let p): if let first = p.entries.first { info = first }
            }
        } catch {
            if u == trimmedURL { self.error = error.localizedDescription }
        }
        if u == trimmedURL { loading = false }
    }

    func makeJobs() -> [Job]? {
        guard isValidURL, range.validationError == nil, let dir = save.resolveOrAsk() else { return nil }
        let spec = DownloadSpec(url: trimmedURL, options: options, range: range, outputDir: dir)
        return [Job(title: info?.title ?? trimmedURL, work: .download(spec))]
    }
}

@MainActor
final class MultiDownloadModel: ObservableObject {
    @Published var linksText = ""
    @Published var items: [VideoEntry] = []
    @Published var options = MediaOptions()
    @Published var save = SaveLocation()
    @Published var naming: NamingMode = .enumerated
    let runner = JobQueue()

    var selectedCount: Int { items.filter(\.selected).count }
    var allSelected: Bool { !items.isEmpty && items.allSatisfy(\.selected) }
    var loadingCount: Int { items.filter { $0.state == .loading }.count }

    func addLinks() {
        let urls = extractURLs(linksText).filter { u in !items.contains { $0.url == u } }
        guard !urls.isEmpty else { return }
        linksText = ""
        let newItems = urls.map { VideoEntry(url: $0, title: $0, state: .loading) }
        items.append(contentsOf: newItems)
        Task {
            await withTaskGroup(of: Void.self) { group in
                var running = 0
                for item in newItems {
                    if running >= 4 { await group.next(); running -= 1 }
                    running += 1
                    group.addTask { @MainActor in await self.load(item.id, url: item.url) }
                }
            }
        }
    }

    private func load(_ id: UUID, url: String) async {
        do {
            let result = try await YTDLP.fetch(url, playlist: false)
            guard let idx = items.firstIndex(where: { $0.id == id }) else { return }
            if case .video(let v) = result {
                items[idx].title = v.title
                items[idx].duration = v.duration
                items[idx].thumbnail = v.thumbnail
                items[idx].uploader = v.uploader
                items[idx].url = v.url.hasPrefix("http") ? v.url : url
            }
            items[idx].state = .ready
        } catch {
            guard let idx = items.firstIndex(where: { $0.id == id }) else { return }
            items[idx].state = .failed(error.localizedDescription)
            items[idx].selected = false
        }
    }

    func toggleAll() {
        let target = !allSelected
        for i in items.indices where items[i].state != .loading { items[i].selected = target }
    }

    func makeJobs() -> [Job]? {
        let selected = items.filter(\.selected)
        guard !selected.isEmpty, let dir = save.resolveOrAsk() else { return nil }
        return selected.enumerated().map { i, item in
            let prefix = naming == .enumerated ? numberPrefix(i + 1, total: selected.count) : ""
            let spec = DownloadSpec(url: item.url, options: options, range: TimeRange(), filenamePrefix: prefix, outputDir: dir)
            return Job(title: item.title, work: .download(spec))
        }
    }
}

@MainActor
final class PlaylistModel: ObservableObject {
    enum Mode: String, CaseIterable, Identifiable {
        case single, multiple
        var id: String { rawValue }
        var label: String { self == .single ? "Uma Playlist" : "Várias Playlists" }
    }
    @Published var mode: Mode = .single
    @Published var singleURL = ""
    @Published var single: PlaylistInfo?
    @Published var loadingSingle = false
    @Published var errorSingle: String?
    @Published var multiText = ""
    @Published var playlists: [PlaylistInfo] = []
    @Published var options = MediaOptions()
    @Published var save = SaveLocation()
    @Published var naming: NamingMode = .enumerated
    @Published var subfolder = true
    let runner = JobQueue()

    func loadSingle() async {
        let u = singleURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard u.hasPrefix("http") else { return }
        loadingSingle = true; errorSingle = nil; single = nil
        do {
            switch try await YTDLP.fetch(u, playlist: true) {
            case .playlist(let p): single = p
            case .video: errorSingle = "Este link é de um vídeo, não de uma playlist."
            }
        } catch { errorSingle = error.localizedDescription }
        loadingSingle = false
    }

    func addPlaylists() {
        let urls = extractURLs(multiText).filter { u in !playlists.contains { $0.url == u } }
        guard !urls.isEmpty else { return }
        multiText = ""
        let placeholders = urls.map { PlaylistInfo(url: $0, title: $0, entries: [], state: .loading) }
        playlists.append(contentsOf: placeholders)
        for p in placeholders {
            Task {
                do {
                    let r = try await YTDLP.fetch(p.url, playlist: true)
                    guard let i = playlists.firstIndex(where: { $0.id == p.id }) else { return }
                    switch r {
                    case .playlist(let info):
                        playlists[i].title = info.title
                        playlists[i].uploader = info.uploader
                        playlists[i].entries = info.entries
                        playlists[i].state = .ready
                    case .video(let v):
                        var e = v; e.index = 1
                        playlists[i].title = v.title
                        playlists[i].entries = [e]
                        playlists[i].state = .ready
                    }
                } catch {
                    guard let i = playlists.firstIndex(where: { $0.id == p.id }) else { return }
                    playlists[i].state = .failed(error.localizedDescription)
                }
            }
        }
    }

    var totalSelected: Int {
        mode == .single ? (single?.selectedCount ?? 0) : playlists.reduce(0) { $0 + $1.selectedCount }
    }

    func makeJobs() -> [Job]? {
        let lists = mode == .single ? [single].compactMap { $0 } : playlists.filter { $0.state == .ready }
        guard totalSelected > 0, let dir = save.resolveOrAsk() else { return nil }
        var jobs: [Job] = []
        for list in lists {
            let folder = subfolder ? dir.appendingPathComponent(sanitizeFilename(list.title)) : dir
            let total = list.entries.count
            for e in list.entries where e.selected {
                let prefix = naming == .enumerated ? numberPrefix(e.index ?? 1, total: total) : ""
                let spec = DownloadSpec(url: e.url, options: options, range: TimeRange(), filenamePrefix: prefix, outputDir: folder)
                jobs.append(Job(title: e.title, work: .download(spec)))
            }
        }
        return jobs
    }
}

// MARK: - Conversor

struct MediaFile: Identifiable, Equatable {
    let id = UUID()
    var url: URL
    var probe: ProbeInfo?
    var options = MediaOptions()
    var range = TimeRange()
    var cutFormat: CutFormat = .original
    var precise = false
    var expanded = false

    var name: String { url.lastPathComponent }
    var sizeText: String {
        let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        return ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)
    }
    var infoText: String {
        var parts = [sizeText]
        if let d = probe?.duration { parts.append(TimeUtils.format(d)) }
        if let w = probe?.width, let h = probe?.height { parts.append("\(w)×\(h)") }
        if probe?.hasVideo == false { parts.append("somente áudio") }
        return parts.joined(separator: " · ")
    }
}

@MainActor
final class ConvertSingleModel: ObservableObject {
    @Published var file: MediaFile?
    @Published var options = MediaOptions()
    @Published var range = TimeRange()
    @Published var save = SaveLocation()
    let runner = JobQueue()

    func setFile(_ url: URL) {
        file = MediaFile(url: url)
        range = TimeRange()
        Task {
            let p = await FFmpeg.probe(url)
            if file?.url == url { file?.probe = p }
            if p?.hasVideo == false { options.kind = .audio }
        }
    }

    func makeJobs() -> [Job]? {
        guard let f = file, range.validationError == nil, let dir = save.resolveOrAsk(source: f.url) else { return nil }
        let spec = ConvertSpec(input: f.url, options: options, range: range, outputDir: dir)
        return [Job(title: f.name, work: .convert(spec))]
    }
}

@MainActor
final class ConvertMultiModel: ObservableObject {
    @Published var files: [MediaFile] = []
    @Published var globalOptions = MediaOptions()
    @Published var save = SaveLocation()
    let runner = JobQueue()

    func add(_ urls: [URL]) {
        let new = urls.filter { u in !files.contains { $0.url == u } }.map { u -> MediaFile in
            var f = MediaFile(url: u); f.options = globalOptions; return f
        }
        files.append(contentsOf: new)
        for f in new {
            Task {
                let p = await FFmpeg.probe(f.url)
                if let i = files.firstIndex(where: { $0.id == f.id }) {
                    files[i].probe = p
                    if p?.hasVideo == false { files[i].options.kind = .audio }
                }
            }
        }
    }

    func applyToAll() {
        for i in files.indices {
            files[i].options = globalOptions
            if files[i].probe?.hasVideo == false { files[i].options.kind = .audio }
        }
    }

    func makeJobs() -> [Job]? {
        guard !files.isEmpty, files.allSatisfy({ $0.range.validationError == nil }) else { return nil }
        if save.customize && save.mode == .choose && save.chosenFolder == nil {
            save.chosenFolder = Finder.chooseFolder()
            if save.chosenFolder == nil { return nil }
        }
        return files.compactMap { f in
            guard let dir = save.resolve(source: f.url) else { return nil }
            return Job(title: f.name, work: .convert(ConvertSpec(input: f.url, options: f.options, range: f.range, outputDir: dir)))
        }
    }
}

// MARK: - Corte

@MainActor
final class CutSingleModel: ObservableObject {
    @Published var file: MediaFile?
    @Published var range = TimeRange(enabled: true)
    @Published var format: CutFormat = .original
    @Published var precise = false
    @Published var save = SaveLocation()
    let runner = JobQueue()

    func setFile(_ url: URL) {
        file = MediaFile(url: url)
        range = TimeRange(enabled: true)
        Task {
            let p = await FFmpeg.probe(url)
            if file?.url == url { file?.probe = p }
        }
    }

    var canCut: Bool { file != nil && range.isActive && range.validationError == nil }

    func makeJobs() -> [Job]? {
        guard let f = file, canCut, let dir = save.resolveOrAsk(source: f.url) else { return nil }
        let spec = CutSpec(input: f.url, range: range, format: format, precise: precise, outputDir: dir)
        return [Job(title: f.name, work: .cut(spec))]
    }
}

@MainActor
final class CutMultiModel: ObservableObject {
    @Published var files: [MediaFile] = []
    @Published var save = SaveLocation()
    let runner = JobQueue()

    func add(_ urls: [URL]) {
        let new = urls.filter { u in !files.contains { $0.url == u } }.map { u -> MediaFile in
            var f = MediaFile(url: u); f.range = TimeRange(enabled: true); f.expanded = true; return f
        }
        files.append(contentsOf: new)
        for f in new {
            Task {
                let p = await FFmpeg.probe(f.url)
                if let i = files.firstIndex(where: { $0.id == f.id }) { files[i].probe = p }
            }
        }
    }

    var readyCount: Int { files.filter { $0.range.isActive && $0.range.validationError == nil }.count }

    func makeJobs() -> [Job]? {
        let ready = files.filter { $0.range.isActive && $0.range.validationError == nil }
        guard !ready.isEmpty else { return nil }
        if save.customize && save.mode == .choose && save.chosenFolder == nil {
            save.chosenFolder = Finder.chooseFolder()
            if save.chosenFolder == nil { return nil }
        }
        return ready.compactMap { f in
            guard let dir = save.resolve(source: f.url) else { return nil }
            let spec = CutSpec(input: f.url, range: f.range, format: f.cutFormat, precise: f.precise, outputDir: dir)
            return Job(title: f.name, work: .cut(spec))
        }
    }
}
