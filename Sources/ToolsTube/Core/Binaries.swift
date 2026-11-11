import Foundation

/// Localiza os executáveis externos (yt-dlp, ffmpeg, ffprobe).
enum Binaries {
    static let searchDirs: [String] = [
        "/opt/homebrew/bin",
        "/usr/local/bin",
        "/usr/bin",
        NSHomeDirectory() + "/.local/bin",
        "/opt/local/bin",
    ]

    static func find(_ name: String) -> URL? {
        let fm = FileManager.default
        var dirs = searchDirs
        if let path = ProcessInfo.processInfo.environment["PATH"] {
            dirs += path.split(separator: ":").map(String.init)
        }
        for dir in dirs {
            let p = (dir as NSString).appendingPathComponent(name)
            if fm.isExecutableFile(atPath: p) { return URL(fileURLWithPath: p) }
        }
        return nil
    }

    static var ytdlp: URL? { find("yt-dlp") }
    static var ffmpeg: URL? { find("ffmpeg") }
    static var ffprobe: URL? { find("ffprobe") }

    static var missing: [String] {
        var m: [String] = []
        if ytdlp == nil { m.append("yt-dlp") }
        if ffmpeg == nil { m.append("ffmpeg") }
        if ffprobe == nil { m.append("ffprobe") }
        return m
    }

    /// Ambiente para processos filhos: apps abertos pelo Finder não herdam o PATH do Homebrew.
    static var environment: [String: String] {
        var env = ProcessInfo.processInfo.environment
        let extra = searchDirs.joined(separator: ":")
        env["PATH"] = extra + ":" + (env["PATH"] ?? "/usr/bin:/bin:/usr/sbin:/sbin")
        env["PYTHONUNBUFFERED"] = "1"
        env["PYTHONIOENCODING"] = "utf-8"
        env["LANG"] = env["LANG"] ?? "en_US.UTF-8"
        env["LC_ALL"] = "en_US.UTF-8"
        return env
    }
}
