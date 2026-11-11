import Foundation

enum FetchResult {
    case video(VideoEntry)
    case playlist(PlaylistInfo)
}

@MainActor
enum YTDLP {
    private static func commonArgs() throws -> [String] {
        var args: [String] = ["--no-warnings", "--ignore-config"]
        if let ff = Binaries.ffmpeg {
            args += ["--ffmpeg-location", ff.deletingLastPathComponent().path]
        }
        let browser = AppSettings.shared.cookieBrowser
        if browser != .none { args += ["--cookies-from-browser", browser.rawValue] }
        return args
    }

    private static func exe() throws -> URL {
        guard let y = Binaries.ytdlp else { throw ToolError.missingBinary("yt-dlp") }
        return y
    }

    // MARK: - Metadados

    static func fetch(_ url: String, playlist: Bool) async throws -> FetchResult {
        let args = try commonArgs() + [
            "-J", "--flat-playlist", "--skip-download",
            playlist ? "--yes-playlist" : "--no-playlist",
            url,
        ]
        let r = try await ProcessRunner.capture(try exe(), args)
        guard r.status == 0,
              let obj = try? JSONSerialization.jsonObject(with: r.stdout) as? [String: Any]
        else {
            let lines = r.stderr.split(separator: "\n").map(String.init)
            throw ToolError.failed(ProcessRunner.errorMessage(from: lines, fallback: "Não foi possível ler o link"))
        }

        if (obj["_type"] as? String) == "playlist" {
            let rawEntries = obj["entries"] as? [[String: Any]] ?? []
            var entries: [VideoEntry] = []
            for (i, e) in rawEntries.enumerated() {
                guard var entry = parseEntry(e) else { continue }
                entry.index = i + 1
                entries.append(entry)
            }
            return .playlist(PlaylistInfo(
                url: url,
                title: obj["title"] as? String ?? "Playlist",
                uploader: (obj["uploader"] ?? obj["channel"]) as? String,
                entries: entries
            ))
        }
        guard let entry = parseEntry(obj, fallbackURL: url) else {
            throw ToolError.failed("Resposta inesperada do yt-dlp")
        }
        return .video(entry)
    }

    private static func parseEntry(_ e: [String: Any], fallbackURL: String? = nil) -> VideoEntry? {
        let id = e["id"] as? String
        var url = (e["webpage_url"] as? String) ?? (e["url"] as? String) ?? fallbackURL
        if url == nil || !(url!.hasPrefix("http")), let id {
            url = "https://www.youtube.com/watch?v=\(id)"
        }
        guard let finalURL = url else { return nil }
        var thumb = (e["thumbnail"] as? String).flatMap(URL.init(string:))
        if thumb == nil, let thumbs = e["thumbnails"] as? [[String: Any]] {
            // prefere uma miniatura média
            let sorted = thumbs.compactMap { t -> (Int, String)? in
                guard let u = t["url"] as? String else { return nil }
                return ((t["width"] as? Int) ?? 0, u)
            }
            let pick = sorted.first(where: { $0.0 >= 320 }) ?? sorted.last
            thumb = pick.flatMap { URL(string: $0.1) }
        }
        if thumb == nil, let id, finalURL.contains("youtu") {
            thumb = URL(string: "https://i.ytimg.com/vi/\(id)/mqdefault.jpg")
        }
        return VideoEntry(
            url: finalURL,
            title: (e["title"] as? String) ?? finalURL,
            duration: (e["duration"] as? NSNumber)?.doubleValue,
            thumbnail: thumb,
            uploader: (e["uploader"] ?? e["channel"]) as? String
        )
    }

    // MARK: - Download

    static func downloadArgs(_ s: DownloadSpec) throws -> [String] {
        let settings = AppSettings.shared
        var a = try commonArgs()
        a += [
            "--newline", "--progress", "--no-playlist", "--no-mtime",
            "--progress-template", "download:TTP %(progress._percent_str)s|%(progress._speed_str)s|%(progress._eta_str)s",
            "--print", "before_dl:TTT %(title)s",
            "--print", "after_move:TTF %(filepath)s",
            "-P", s.outputDir.path,
            "-o", "\(s.filenamePrefix)%(title)s.%(ext)s",
        ]

        let o = s.options
        switch o.kind {
        case .video:
            let res = o.quality.height.map { "res:\($0)" } ?? "res"
            switch o.container {
            case .webm:
                a += ["-f", "bv*[ext=webm]+ba[ext=webm]/bv*+ba/b", "-S", "\(res),vcodec:vp9,acodec:opus",
                      "--merge-output-format", "webm"]
            case .mkv:
                a += ["-f", "bv*+ba/b", "-S", res, "--merge-output-format", "mkv"]
            default:
                let sort = settings.preferH264 ? "\(res),vcodec:h264,acodec:m4a" : "\(res),acodec:m4a"
                a += ["-f", "bv*+ba/b", "-S", sort, "--merge-output-format", "mp4"]
            }
            if settings.embedMetadata {
                a += ["--embed-metadata"]
                if o.container != .webm { a += ["--embed-thumbnail"] }
            }
        case .audio:
            a += ["-f", "ba/b", "-x", "--audio-format", o.audioFormat.rawValue]
            if !o.audioFormat.isLossless { a += ["--audio-quality", "\(o.audioBitrate.rawValue)K"] }
            if settings.embedMetadata {
                a += ["--embed-metadata"]
                if [.mp3, .m4a, .flac].contains(o.audioFormat) { a += ["--embed-thumbnail"] }
            }
        }

        if s.range.isActive {
            let start = s.range.startSeconds ?? 0
            let end = s.range.endSeconds.map { TimeUtils.ffmpegString($0) } ?? "inf"
            a += ["--download-sections", "*\(TimeUtils.ffmpegString(start))-\(end)", "--force-keyframes-at-cuts"]
        }
        a.append(s.url)
        return a
    }

    static func download(_ s: DownloadSpec, job: Job) async throws {
        let args = try downloadArgs(s)
        var streams = 0
        var lastPct = 0.0
        let result = try await ProcessRunner.stream(try exe(), args, handle: job.handle) { line, isErr in
            if line.hasPrefix("TTT ") {
                job.title = String(line.dropFirst(4))
            } else if line.hasPrefix("TTF ") {
                job.outputURL = URL(fileURLWithPath: String(line.dropFirst(4)))
            } else if line.hasPrefix("TTP ") {
                let parts = line.dropFirst(4).split(separator: "|", omittingEmptySubsequences: false)
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                if let pctStr = parts.first?.replacingOccurrences(of: "%", with: ""),
                   let pct = Double(pctStr) {
                    if pct < lastPct - 50 { streams += 1 } // começou o 2º fluxo (áudio)
                    lastPct = pct
                    job.progress = min(pct / 100, 1)
                    if pct >= 100 { job.status = .finishing }
                    else if job.status == .finishing { job.status = .running }
                }
                var d: [String] = []
                if parts.count > 1, !parts[1].contains("Unknown"), parts[1] != "NA" { d.append(parts[1]) }
                if parts.count > 2, parts[2] != "NA", parts[2] != "Unknown" { d.append("restam \(parts[2])") }
                if streams > 0 { d.insert("áudio", at: 0) }
                job.detail = d.isEmpty ? "Baixando…" : d.joined(separator: " · ")
                if job.status == .finishing { job.detail = "Processando…" }
            } else if !isErr, job.status == .finishing {
                job.detail = "Processando…"
            }
        }
        if result.status != 0 {
            throw ToolError.failed(ProcessRunner.errorMessage(from: result.stderrTail, fallback: "Falha no download (código \(result.status))"))
        }
    }
}
