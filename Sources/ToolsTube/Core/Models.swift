import Foundation

enum MediaKind: String, CaseIterable, Identifiable, Codable {
    case video, audio
    var id: String { rawValue }
    var label: String { self == .video ? "Vídeo" : "Áudio" }
    var icon: String { self == .video ? "film" : "waveform" }
}

enum VideoQuality: String, CaseIterable, Identifiable, Codable {
    case best, p2160, p1440, p1080, p720, p480, p360
    var id: String { rawValue }
    var height: Int? {
        switch self {
        case .best: return nil
        case .p2160: return 2160
        case .p1440: return 1440
        case .p1080: return 1080
        case .p720: return 720
        case .p480: return 480
        case .p360: return 360
        }
    }
    func label(original: Bool) -> String {
        switch self {
        case .best: return original ? "Original" : "Melhor disponível"
        case .p2160: return "4K (2160p)"
        case .p1440: return "2K (1440p)"
        default: return "\(height!)p"
        }
    }
}

enum VideoContainer: String, CaseIterable, Identifiable, Codable {
    case mp4, mov, mkv, webm
    var id: String { rawValue }
    var label: String { rawValue.uppercased() }
    static let downloadable: [VideoContainer] = [.mp4, .mkv, .webm]
}

enum AudioFormat: String, CaseIterable, Identifiable, Codable {
    case mp3, m4a, wav, flac, opus
    var id: String { rawValue }
    var label: String { rawValue.uppercased() }
    var isLossless: Bool { self == .wav || self == .flac }
}

enum AudioBitrate: Int, CaseIterable, Identifiable, Codable {
    case k320 = 320, k256 = 256, k192 = 192, k128 = 128, k96 = 96
    var id: Int { rawValue }
    var label: String { "\(rawValue) kbps" }
}

enum EncodePreset: String, CaseIterable, Identifiable, Codable {
    case high, medium, small
    var id: String { rawValue }
    var label: String {
        switch self {
        case .high: return "Alta"
        case .medium: return "Equilibrada"
        case .small: return "Arquivo menor"
        }
    }
    var crf: Int { self == .high ? 18 : self == .medium ? 23 : 28 }
    var vp9crf: Int { self == .high ? 24 : self == .medium ? 32 : 40 }
    var vtQuality: Int { self == .high ? 75 : self == .medium ? 60 : 45 }
}

/// Opções de formato/qualidade usadas em download e conversão.
struct MediaOptions: Equatable, Codable {
    var kind: MediaKind = .video
    var quality: VideoQuality = .best
    var container: VideoContainer = .mp4
    var audioFormat: AudioFormat = .mp3
    var audioBitrate: AudioBitrate = .k320
    var preset: EncodePreset = .medium

    var outputExtension: String { kind == .video ? container.rawValue : audioFormat.rawValue }

    func summary(original: Bool = false) -> String {
        switch kind {
        case .video: return "\(container.label) · \(quality.label(original: original))"
        case .audio:
            return audioFormat.isLossless ? audioFormat.label : "\(audioFormat.label) · \(audioBitrate.rawValue)k"
        }
    }
}

enum NamingMode: String, CaseIterable, Identifiable, Codable {
    case enumerated, original
    var id: String { rawValue }
    var label: String { self == .enumerated ? "Enumerado" : "Título original" }
    var example: String { self == .enumerated ? "01 - Título do Vídeo" : "Título do Vídeo" }
}

enum SaveMode: String, CaseIterable, Identifiable, Codable {
    case lastUsed, choose, defaultFolder, sourceFolder
    var id: String { rawValue }
    var label: String {
        switch self {
        case .lastUsed: return "Mesma pasta da última vez"
        case .choose: return "Escolher pasta"
        case .defaultFolder: return "Pasta padrão"
        case .sourceFolder: return "Pasta do arquivo original"
        }
    }
    var icon: String {
        switch self {
        case .lastUsed: return "clock.arrow.circlepath"
        case .choose: return "folder.badge.plus"
        case .defaultFolder: return "house"
        case .sourceFolder: return "doc.on.doc"
        }
    }
}

struct SaveLocation: Equatable {
    var customize = false
    var mode: SaveMode = .lastUsed
    var chosenFolder: URL?

    /// Pasta de destino. `source` é o arquivo de origem (conversor/corte).
    @MainActor
    func resolve(source: URL? = nil) -> URL? {
        let settings = AppSettings.shared
        guard customize else { return settings.defaultFolder }
        switch mode {
        case .lastUsed: return settings.lastFolder ?? settings.defaultFolder
        case .choose: return chosenFolder
        case .defaultFolder: return settings.defaultFolder
        case .sourceFolder: return source?.deletingLastPathComponent() ?? settings.defaultFolder
        }
    }
}

/// Formato de saída para cortes.
enum CutFormat: String, CaseIterable, Identifiable, Codable {
    case original, mp4, mov, mkv, webm, mp3, m4a, wav
    var id: String { rawValue }
    var label: String { self == .original ? "Manter original" : rawValue.uppercased() }
    var isAudio: Bool { [.mp3, .m4a, .wav].contains(self) }
}

/// Item de vídeo listado (playlist / vários links).
struct VideoEntry: Identifiable, Equatable {
    enum LoadState: Equatable { case loading, ready, failed(String) }
    let id = UUID()
    var url: String
    var title: String
    var duration: Double?
    var thumbnail: URL?
    var uploader: String?
    var index: Int?
    var selected = true
    var state: LoadState = .ready
}

struct PlaylistInfo: Identifiable, Equatable {
    let id = UUID()
    var url: String
    var title: String
    var uploader: String?
    var entries: [VideoEntry]
    var state: VideoEntry.LoadState = .ready
    var expanded = true

    var selectedCount: Int { entries.filter(\.selected).count }
}
