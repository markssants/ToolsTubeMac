import Foundation
import AppKit

/// `ToolsTube --selftest <pasta>`: executa download, conversão e corte reais e encerra.
@MainActor
enum SelfTest {
    static func runIfRequested() {
        let args = CommandLine.arguments
        guard let i = args.firstIndex(of: "--selftest") else { return }
        let dir = URL(fileURLWithPath: i + 1 < args.count ? args[i + 1] : NSTemporaryDirectory() + "tt-selftest")
        Task { @MainActor in
            var ok = true
            @MainActor func check(_ name: String, _ job: Job) {
                let pass = job.status == .done && job.outputURL.map { FileManager.default.fileExists(atPath: $0.path) } == true
                print("\(pass ? "PASS" : "FAIL") \(name): \(job.status) → \(job.outputURL?.lastPathComponent ?? "-") \(job.detail)")
                ok = ok && pass
            }
            let url = "https://www.youtube.com/watch?v=jNQXAC9IVRw"
            do {
                if case .video(let v) = try await YTDLP.fetch(url, playlist: false) {
                    print("PASS fetch: \(v.title) \(v.duration ?? 0)s")
                }
            } catch { print("FAIL fetch: \(error)"); ok = false }

            var opts = MediaOptions(); opts.quality = .p360
            let v = Job(title: "video", work: .download(DownloadSpec(url: url, options: opts, range: TimeRange(), filenamePrefix: "01 - ", outputDir: dir)))
            var aopts = MediaOptions(); aopts.kind = .audio; aopts.audioFormat = .mp3; aopts.audioBitrate = .k192
            let a = Job(title: "audio", work: .download(DownloadSpec(url: url, options: aopts, range: TimeRange(enabled: true, start: "3", end: "0:9"), outputDir: dir)))
            let q = JobQueue()
            q.run([v, a])
            while q.isRunning { try? await Task.sleep(for: .milliseconds(200)) }
            check("download vídeo", v)
            check("download áudio trecho", a)

            if let src = v.outputURL {
                var c = MediaOptions(); c.quality = .p360; c.container = .mov; c.preset = .small
                let cj = Job(title: "conv", work: .convert(ConvertSpec(input: src, options: c, range: TimeRange(enabled: true, start: "2", end: "8"), outputDir: dir)))
                var ca = MediaOptions(); ca.kind = .audio; ca.audioFormat = .m4a
                let caj = Job(title: "conv-a", work: .convert(ConvertSpec(input: src, options: ca, range: TimeRange(), outputDir: dir)))
                let fast = Job(title: "cut", work: .cut(CutSpec(input: src, range: TimeRange(enabled: true, start: "1", end: "5"), format: .original, precise: false, outputDir: dir)))
                let precise = Job(title: "cut2", work: .cut(CutSpec(input: src, range: TimeRange(enabled: true, start: "4.5", end: ""), format: .mkv, precise: true, outputDir: dir)))
                let wav = Job(title: "cut3", work: .cut(CutSpec(input: src, range: TimeRange(enabled: true, start: "", end: "3"), format: .wav, precise: false, outputDir: dir)))
                let q2 = JobQueue()
                q2.run([cj, caj, fast, precise, wav])
                while q2.isRunning { try? await Task.sleep(for: .milliseconds(200)) }
                check("converter mov 360p trecho", cj)
                check("converter m4a", caj)
                check("corte rápido", fast)
                check("corte preciso mkv", precise)
                check("corte wav", wav)
                for j in [cj, fast, precise] {
                    if let o = j.outputURL, let p = await FFmpeg.probe(o) {
                        print("   \(o.lastPathComponent): \(p.duration ?? 0)s \(p.width ?? 0)x\(p.height ?? 0) \(p.videoCodec ?? "")")
                    }
                }
            }

            // cancelamento
            let cjob = Job(title: "cancel", work: .download(DownloadSpec(url: url, options: MediaOptions(), range: TimeRange(), filenamePrefix: "cancel - ", outputDir: dir)))
            let q3 = JobQueue(); q3.run([cjob])
            try? await Task.sleep(for: .milliseconds(1500))
            cjob.cancel()
            while q3.isRunning { try? await Task.sleep(for: .milliseconds(100)) }
            print("\(cjob.status == .cancelled ? "PASS" : "FAIL") cancelamento: \(cjob.status)")

            print(ok ? "SELFTEST OK" : "SELFTEST FALHOU")
            exit(ok ? 0 : 1)
        }
    }
}
