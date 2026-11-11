import Foundation

struct ProbeInfo: Equatable {
    var duration: Double?
    var hasVideo: Bool
    var hasAudio: Bool
    var width: Int?
    var height: Int?
    var videoCodec: String?
}

@MainActor
enum FFmpeg {
    private static func ffmpeg() throws -> URL {
        guard let f = Binaries.ffmpeg else { throw ToolError.missingBinary("ffmpeg") }
        return f
    }

    static func probe(_ url: URL) async -> ProbeInfo? {
        guard let fp = Binaries.ffprobe else { return nil }
        let args = ["-v", "error", "-show_entries", "format=duration:stream=codec_type,codec_name,width,height,disposition",
                    "-of", "json", url.path]
        guard let r = try? await ProcessRunner.capture(fp, args), r.status == 0,
              let obj = try? JSONSerialization.jsonObject(with: r.stdout) as? [String: Any] else { return nil }
        let streams = obj["streams"] as? [[String: Any]] ?? []
        let video = streams.first {
            ($0["codec_type"] as? String) == "video"
                && (($0["disposition"] as? [String: Any])?["attached_pic"] as? Int ?? 0) == 0
        }
        let dur = ((obj["format"] as? [String: Any])?["duration"] as? String).flatMap(Double.init)
        return ProbeInfo(
            duration: dur,
            hasVideo: video != nil,
            hasAudio: streams.contains { ($0["codec_type"] as? String) == "audio" },
            width: video?["width"] as? Int,
            height: video?["height"] as? Int,
            videoCodec: video?["codec_name"] as? String
        )
    }

    // MARK: - Codecs

    private static func videoCodec(container: String, preset: EncodePreset) -> [String] {
        if container == "webm" {
            return ["-c:v", "libvpx-vp9", "-crf", "\(preset.vp9crf)", "-b:v", "0",
                    "-row-mt", "1", "-deadline", "good", "-cpu-used", "4"]
        }
        if AppSettings.shared.hardwareEncoding {
            return ["-c:v", "h264_videotoolbox", "-q:v", "\(preset.vtQuality)", "-pix_fmt", "yuv420p"]
        }
        return ["-c:v", "libx264", "-crf", "\(preset.crf)", "-preset", "medium", "-pix_fmt", "yuv420p"]
    }

    private static func audioCodec(ext: String, bitrate: Int) -> [String] {
        switch ext {
        case "mp3": return ["-c:a", "libmp3lame", "-b:a", "\(bitrate)k"]
        case "wav": return ["-c:a", "pcm_s16le"]
        case "flac": return ["-c:a", "flac"]
        case "aiff", "aif": return ["-c:a", "pcm_s16be"]
        case "opus", "ogg", "webm": return ["-c:a", "libopus", "-b:a", "\(min(bitrate, 256))k"]
        default: return ["-c:a", "aac", "-b:a", "\(bitrate)k"]
        }
    }

    private static func containerFlags(_ ext: String) -> [String] {
        ["mp4", "mov", "m4a", "m4v"].contains(ext) ? ["-movflags", "+faststart"] : []
    }

    private static func rangeArgs(_ range: TimeRange, total: Double?) -> (pre: [String], post: [String], duration: Double?) {
        guard range.isActive else { return ([], [], total) }
        let start = range.startSeconds ?? 0
        var pre: [String] = []
        var post: [String] = []
        if start > 0 { pre = ["-ss", TimeUtils.ffmpegString(start)] }
        var dur: Double? = total.map { $0 - start }
        if let end = range.endSeconds {
            dur = end - start
            post = ["-t", TimeUtils.ffmpegString(end - start)]
        }
        return (pre, post, dur)
    }

    // MARK: - Conversão

    static func convert(_ s: ConvertSpec, job: Job) async throws {
        let info = await probe(s.input)
        let o = s.options
        let ext = o.outputExtension
        let base = s.input.deletingPathExtension().lastPathComponent
        var out = s.outputDir.appendingPathComponent(base).appendingPathExtension(ext)
        if out.standardizedFileURL == s.input.standardizedFileURL {
            out = s.outputDir.appendingPathComponent("\(base) (convertido)").appendingPathExtension(ext)
        }
        out = Finder.uniqueURL(out)

        let r = rangeArgs(s.range, total: info?.duration)
        var args = ["-hide_banner", "-nostdin", "-y"] + r.pre + ["-i", s.input.path] + r.post
        switch o.kind {
        case .video:
            if info?.hasVideo == false { throw ToolError.failed("O arquivo não possui faixa de vídeo") }
            args += ["-map", "0:v:0", "-map", "0:a:0?"]
            if let h = o.quality.height {
                args += ["-vf", "scale=-2:'min(\(h),ih)'"]
            }
            args += videoCodec(container: ext, preset: o.preset)
            args += audioCodec(ext: ext, bitrate: o.audioBitrate.rawValue)
        case .audio:
            if info?.hasAudio == false { throw ToolError.failed("O arquivo não possui faixa de áudio") }
            args += ["-vn", "-map", "0:a:0"] + audioCodec(ext: ext, bitrate: o.audioBitrate.rawValue)
        }
        args += ["-map_metadata", "0"] + containerFlags(ext)
        args += ["-progress", "pipe:1", "-nostats", "-loglevel", "error", out.path]
        try await runFFmpeg(args, duration: r.duration, output: out, job: job)
    }

    // MARK: - Corte

    static func cut(_ s: CutSpec, job: Job) async throws {
        guard s.range.isActive else { throw ToolError.failed("Defina o início e/ou o fim do corte") }
        let info = await probe(s.input)
        let hasVideo = info?.hasVideo ?? true
        let inExt = s.input.pathExtension.lowercased()
        let ext = s.format == .original ? (inExt.isEmpty ? "mp4" : inExt) : s.format.rawValue
        let base = s.input.deletingPathExtension().lastPathComponent
        let out = Finder.uniqueURL(s.outputDir.appendingPathComponent("\(base) (corte)").appendingPathExtension(ext))

        let r = rangeArgs(s.range, total: info?.duration)
        var args = ["-hide_banner", "-nostdin", "-y"] + r.pre + ["-i", s.input.path] + r.post
        let audioOnlyOut = s.format.isAudio || !hasVideo

        if audioOnlyOut {
            args += ["-vn", "-map", "0:a:0"]
            if !s.precise && s.format == .original {
                args += ["-c", "copy"]
            } else {
                args += audioCodec(ext: ext, bitrate: 256)
            }
        } else {
            args += ["-map", "0:v:0", "-map", "0:a?"]
            let canCopy = s.format == .original || (ext != "webm" && inExt != "webm")
            if !s.precise && canCopy {
                args += ["-c", "copy", "-avoid_negative_ts", "make_zero"]
            } else {
                args += videoCodec(container: ext, preset: .high) + audioCodec(ext: ext, bitrate: 192)
            }
        }
        args += ["-map_metadata", "0"] + containerFlags(ext)
        args += ["-progress", "pipe:1", "-nostats", "-loglevel", "error", out.path]
        try await runFFmpeg(args, duration: r.duration, output: out, job: job)
    }

    // MARK: - Execução

    private static func runFFmpeg(_ args: [String], duration: Double?, output: URL, job: Job) async throws {
        job.detail = "Processando…"
        var speed = ""
        let result = try await ProcessRunner.stream(try ffmpeg(), args, handle: job.handle) { line, isErr in
            guard !isErr, let eq = line.firstIndex(of: "=") else { return }
            let key = line[..<eq], value = line[line.index(after: eq)...].trimmingCharacters(in: .whitespaces)
            switch key {
            case "out_time_us", "out_time_ms":
                if let us = Double(value), let d = duration, d > 0 {
                    job.progress = min(max(us / 1_000_000 / d, 0), 1)
                    let remaining = speedValue(speed).map { (d - us / 1_000_000) / $0 }
                    var parts = ["\(Int((job.progress ?? 0) * 100))%"]
                    if !speed.isEmpty { parts.append(speed) }
                    if let rem = remaining, rem.isFinite, rem > 0 { parts.append("restam \(TimeUtils.format(rem))") }
                    job.detail = parts.joined(separator: " · ")
                }
            case "speed":
                speed = value == "N/A" ? "" : value
            case "progress":
                if value == "end" { job.status = .finishing; job.detail = "Finalizando…" }
            default: break
            }
        }
        if result.status != 0 {
            try? FileManager.default.removeItem(at: output)
            throw ToolError.failed(ProcessRunner.errorMessage(from: result.stderrTail, fallback: "Falha no ffmpeg (código \(result.status))"))
        }
        job.outputURL = output
    }

    private static func speedValue(_ s: String) -> Double? {
        Double(s.replacingOccurrences(of: "x", with: ""))
    }
}
