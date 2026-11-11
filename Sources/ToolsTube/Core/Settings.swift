import Foundation
import AppKit

enum CookieBrowser: String, CaseIterable, Identifiable {
    case none, safari, chrome, firefox, brave, edge
    var id: String { rawValue }
    var label: String {
        switch self {
        case .none: return "Nenhum"
        case .safari: return "Safari"
        case .chrome: return "Google Chrome"
        case .firefox: return "Firefox"
        case .brave: return "Brave"
        case .edge: return "Microsoft Edge"
        }
    }
}

@MainActor
final class AppSettings: ObservableObject {
    static let shared = AppSettings()
    private let d = UserDefaults.standard

    @Published var defaultFolder: URL { didSet { d.set(defaultFolder.path, forKey: "defaultFolder") } }
    @Published var lastFolder: URL? { didSet { d.set(lastFolder?.path, forKey: "lastFolder") } }
    @Published var cookieBrowser: CookieBrowser { didSet { d.set(cookieBrowser.rawValue, forKey: "cookieBrowser") } }
    @Published var maxConcurrent: Int { didSet { d.set(maxConcurrent, forKey: "maxConcurrent") } }
    @Published var hardwareEncoding: Bool { didSet { d.set(hardwareEncoding, forKey: "hardwareEncoding") } }
    @Published var embedMetadata: Bool { didSet { d.set(embedMetadata, forKey: "embedMetadata") } }
    @Published var preferH264: Bool { didSet { d.set(preferH264, forKey: "preferH264") } }
    @Published var playSound: Bool { didSet { d.set(playSound, forKey: "playSound") } }

    private init() {
        let downloads = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
        defaultFolder = (d.string(forKey: "defaultFolder")).map { URL(fileURLWithPath: $0) }
            ?? downloads.appendingPathComponent("ToolsTube")
        lastFolder = d.string(forKey: "lastFolder").map { URL(fileURLWithPath: $0) }
        cookieBrowser = CookieBrowser(rawValue: d.string(forKey: "cookieBrowser") ?? "") ?? .none
        maxConcurrent = d.object(forKey: "maxConcurrent") as? Int ?? 2
        hardwareEncoding = d.object(forKey: "hardwareEncoding") as? Bool ?? false
        embedMetadata = d.object(forKey: "embedMetadata") as? Bool ?? true
        preferH264 = d.object(forKey: "preferH264") as? Bool ?? true
        playSound = d.object(forKey: "playSound") as? Bool ?? true
    }
}

@MainActor
enum Finder {
    static func open(_ folder: URL?) {
        let url = folder ?? AppSettings.shared.defaultFolder
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        NSWorkspace.shared.open(url)
    }

    static func reveal(_ file: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([file])
    }

    static func chooseFolder(message: String = "Escolha a pasta de destino") -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Escolher"
        panel.message = message
        return panel.runModal() == .OK ? panel.url : nil
    }

    static func chooseMediaFiles(multiple: Bool) -> [URL] {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = multiple
        panel.allowedContentTypes = [.movie, .audio, .video, .mpeg4Movie, .quickTimeMovie, .mp3, .wav, .aiff]
        panel.allowsOtherFileTypes = true
        panel.prompt = "Selecionar"
        return panel.runModal() == .OK ? panel.urls : []
    }

    /// Evita sobrescrever: "nome.ext" → "nome 2.ext".
    nonisolated static func uniqueURL(_ url: URL) -> URL {
        let fm = FileManager.default
        guard fm.fileExists(atPath: url.path) else { return url }
        let base = url.deletingPathExtension().lastPathComponent
        let ext = url.pathExtension
        let dir = url.deletingLastPathComponent()
        var n = 2
        while true {
            let candidate = dir.appendingPathComponent("\(base) \(n)").appendingPathExtension(ext)
            if !fm.fileExists(atPath: candidate.path) { return candidate }
            n += 1
        }
    }
}
