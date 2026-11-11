import Foundation

enum TimeUtils {
    /// Aceita "83", "1:23", "01:02:03", "1:23.5", "1m23s".
    static func parse(_ text: String) -> Double? {
        let t = text.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")
        if t.isEmpty { return nil }
        if t.contains("h") || t.contains("m") || t.contains("s") {
            var total = 0.0, num = ""
            for ch in t {
                if ch.isNumber || ch == "." { num.append(ch); continue }
                guard let v = Double(num) else { return nil }
                switch ch {
                case "h": total += v * 3600
                case "m": total += v * 60
                case "s": total += v
                case " ": continue
                default: return nil
                }
                num = ""
            }
            if !num.isEmpty, let v = Double(num) { total += v }
            return total
        }
        let parts = t.split(separator: ":", omittingEmptySubsequences: false).map(String.init)
        guard parts.count <= 3 else { return nil }
        var total = 0.0
        for part in parts {
            guard let v = Double(part.isEmpty ? "0" : part), v >= 0 else { return nil }
            total = total * 60 + v
        }
        return total
    }

    static func format(_ seconds: Double?, showMillis: Bool = false) -> String {
        guard let seconds, seconds.isFinite, seconds >= 0 else { return "--:--" }
        let total = Int(seconds)
        let h = total / 3600, m = (total % 3600) / 60, s = total % 60
        var str = h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%02d:%02d", m, s)
        if showMillis {
            let ms = Int(((seconds - Double(total)) * 10).rounded(.down))
            str += ".\(ms)"
        }
        return str
    }

    static func ffmpegString(_ s: Double) -> String { String(format: "%.3f", s) }
}

struct TimeRange: Equatable, Codable {
    var enabled = false
    var start = ""
    var end = ""

    var startSeconds: Double? { enabled ? TimeUtils.parse(start) : nil }
    var endSeconds: Double? { enabled ? TimeUtils.parse(end) : nil }

    var isActive: Bool { enabled && (startSeconds != nil || endSeconds != nil) }

    var validationError: String? {
        guard enabled else { return nil }
        if !start.isEmpty && TimeUtils.parse(start) == nil { return "Início inválido" }
        if !end.isEmpty && TimeUtils.parse(end) == nil { return "Fim inválido" }
        if let s = startSeconds, let e = endSeconds, e <= s { return "O fim deve ser depois do início" }
        return nil
    }

    var summary: String {
        guard isActive else { return "" }
        return "\(TimeUtils.format(startSeconds ?? 0)) → \(endSeconds.map { TimeUtils.format($0) } ?? "fim")"
    }
}
