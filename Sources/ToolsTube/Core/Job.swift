import Foundation
import Combine
import AppKit

struct DownloadSpec {
    var url: String
    var options: MediaOptions
    var range: TimeRange
    var filenamePrefix: String = ""
    var outputDir: URL
}

struct ConvertSpec {
    var input: URL
    var options: MediaOptions
    var range: TimeRange
    var outputDir: URL
}

struct CutSpec {
    var input: URL
    var range: TimeRange
    var format: CutFormat
    var precise: Bool
    var outputDir: URL
}

@MainActor
final class Job: ObservableObject, Identifiable {
    enum Status: Equatable {
        case pending, running, finishing, done, failed(String), cancelled
        var isFinished: Bool {
            switch self { case .done, .failed, .cancelled: return true; default: return false }
        }
        var isActive: Bool { self == .running || self == .finishing }
    }

    enum Work {
        case download(DownloadSpec)
        case convert(ConvertSpec)
        case cut(CutSpec)
    }

    let id = UUID()
    let work: Work
    @Published var title: String
    @Published var status: Status = .pending
    @Published var progress: Double?
    @Published var detail = ""
    @Published var outputURL: URL?
    private(set) var handle = ProcessHandle()

    init(title: String, work: Work) {
        self.title = title
        self.work = work
    }

    var outputDir: URL {
        switch work {
        case .download(let s): return s.outputDir
        case .convert(let s): return s.outputDir
        case .cut(let s): return s.outputDir
        }
    }

    var icon: String {
        switch work {
        case .download(let s): return s.options.kind == .audio ? "music.note" : "film"
        case .convert(let s): return s.options.kind == .audio ? "waveform" : "arrow.triangle.2.circlepath"
        case .cut: return "scissors"
        }
    }

    var subtitle: String {
        var parts: [String] = []
        switch work {
        case .download(let s):
            parts.append(s.options.summary())
            if s.range.isActive { parts.append(s.range.summary) }
        case .convert(let s):
            parts.append(s.options.summary(original: true))
            if s.range.isActive { parts.append(s.range.summary) }
        case .cut(let s):
            parts.append(s.format.label)
            parts.append(s.range.summary)
            parts.append(s.precise ? "Preciso" : "Rápido")
        }
        return parts.filter { !$0.isEmpty }.joined(separator: " · ")
    }

    func cancel() {
        switch status {
        case .pending: status = .cancelled
        case .running, .finishing: handle.cancel()
        default: break
        }
    }

    func retry() {
        guard status.isFinished else { return }
        handle = ProcessHandle()
        progress = nil
        detail = ""
        status = .pending
    }
}

/// Fila de execução com N trabalhos simultâneos.
@MainActor
final class JobQueue: ObservableObject {
    @Published private(set) var jobs: [Job] = []
    @Published private(set) var activeWorkers = 0
    private var subs: [UUID: AnyCancellable] = [:]

    var isRunning: Bool { activeWorkers > 0 }
    var pendingCount: Int { jobs.filter { $0.status == .pending }.count }
    var activeCount: Int { jobs.filter { $0.status.isActive }.count }
    var doneCount: Int { jobs.filter { $0.status == .done }.count }
    var hasFinished: Bool { jobs.contains { $0.status.isFinished } }

    var overallProgress: Double {
        let relevant = jobs.filter { $0.status != .cancelled }
        guard !relevant.isEmpty else { return 0 }
        let sum = relevant.reduce(0.0) { acc, j in
            acc + (j.status.isFinished ? 1 : (j.progress ?? 0))
        }
        return sum / Double(relevant.count)
    }

    func add(_ newJobs: [Job]) {
        for job in newJobs {
            subs[job.id] = job.objectWillChange.sink { [weak self] _ in
                self?.objectWillChange.send()
            }
        }
        jobs.append(contentsOf: newJobs)
    }

    func remove(_ job: Job) {
        job.cancel()
        subs[job.id] = nil
        jobs.removeAll { $0.id == job.id }
    }

    func removeAll() {
        for j in jobs { j.cancel() }
        jobs.removeAll()
        subs.removeAll()
    }

    func clearFinished() {
        for j in jobs where j.status.isFinished { subs[j.id] = nil }
        jobs.removeAll { $0.status.isFinished }
    }

    func cancelAll() {
        for j in jobs { j.cancel() }
    }

    func retryFailed() {
        for j in jobs {
            if case .failed = j.status { j.retry() }
            if j.status == .cancelled { j.retry() }
        }
        start()
    }

    func move(from: IndexSet, to: Int) {
        jobs.move(fromOffsets: from, toOffset: to)
    }

    /// Adiciona e inicia imediatamente.
    func run(_ newJobs: [Job]) {
        add(newJobs)
        start()
    }

    func start() {
        let limit = max(1, AppSettings.shared.maxConcurrent)
        let needed = min(limit - activeWorkers, pendingCount)
        guard needed > 0 else { return }
        for _ in 0..<needed {
            activeWorkers += 1
            Task { @MainActor in
                while let job = self.jobs.first(where: { $0.status == .pending }) {
                    await JobExecutor.run(job)
                }
                self.activeWorkers -= 1
                if self.activeWorkers == 0 { self.didFinishAll() }
            }
        }
    }

    private func didFinishAll() {
        guard AppSettings.shared.playSound, jobs.contains(where: { $0.status == .done }) else { return }
        let failed = jobs.contains { if case .failed = $0.status { return true }; return false }
        NSSound(named: failed ? "Basso" : "Glass")?.play()
    }
}

@MainActor
enum JobExecutor {
    static func run(_ job: Job) async {
        job.status = .running
        job.progress = nil
        job.detail = "Iniciando…"
        do {
            try FileManager.default.createDirectory(at: job.outputDir, withIntermediateDirectories: true)
            switch job.work {
            case .download(let s): try await YTDLP.download(s, job: job)
            case .convert(let s): try await FFmpeg.convert(s, job: job)
            case .cut(let s): try await FFmpeg.cut(s, job: job)
            }
            job.status = .done
            job.progress = 1
            job.detail = job.outputURL?.lastPathComponent ?? "Concluído"
            AppSettings.shared.lastFolder = job.outputDir
        } catch ToolError.cancelled {
            job.status = .cancelled
            job.detail = "Cancelado"
        } catch {
            job.status = .failed(error.localizedDescription)
            job.detail = error.localizedDescription
        }
    }
}
