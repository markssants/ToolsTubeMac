import Foundation

enum ToolError: LocalizedError {
    case missingBinary(String)
    case failed(String)
    case cancelled

    var errorDescription: String? {
        switch self {
        case .missingBinary(let n): return "\(n) não encontrado. Instale com: brew install yt-dlp ffmpeg"
        case .failed(let m): return m
        case .cancelled: return "Cancelado"
        }
    }
}

/// Referência a um processo em execução, usada para cancelar.
final class ProcessHandle: @unchecked Sendable {
    private let lock = NSLock()
    private var process: Process?
    private(set) var wasCancelled = false

    func attach(_ p: Process) {
        lock.lock(); process = p; let c = wasCancelled; lock.unlock()
        if c { p.terminate() }
    }

    func cancel() {
        lock.lock(); wasCancelled = true; let p = process; lock.unlock()
        if let p, p.isRunning {
            // encerra filhos (ex.: ffmpeg iniciado pelo yt-dlp) e depois o processo
            let pk = Process()
            pk.executableURL = URL(fileURLWithPath: "/usr/bin/pkill")
            pk.arguments = ["-TERM", "-P", String(p.processIdentifier)]
            try? pk.run()
            pk.waitUntilExit()
            p.terminate()
        }
    }
}

/// Divide um fluxo de bytes em linhas (\n ou \r).
private final class LineBuffer: @unchecked Sendable {
    private var data = Data()
    func append(_ chunk: Data) -> [String] {
        data.append(chunk)
        var lines: [String] = []
        while let idx = data.firstIndex(where: { $0 == 0x0A || $0 == 0x0D }) {
            let lineData = data[data.startIndex..<idx]
            data.removeSubrange(data.startIndex...idx)
            if let s = String(data: lineData, encoding: .utf8), !s.isEmpty { lines.append(s) }
        }
        return lines
    }
    func flush() -> [String] {
        defer { data.removeAll() }
        if let s = String(data: data, encoding: .utf8), !s.isEmpty { return [s] }
        return []
    }
}

private final class TailBuffer: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [String] = []
    func append(_ new: [String]) {
        lock.lock(); defer { lock.unlock() }
        storage.append(contentsOf: new)
        if storage.count > 30 { storage.removeFirst(storage.count - 30) }
    }
    var lines: [String] { lock.lock(); defer { lock.unlock() }; return storage }
}

enum ProcessRunner {
    struct Result {
        var status: Int32
        var stderrTail: [String]
    }

    /// Executa um processo transmitindo linhas (no main thread) conforme chegam.
    static func stream(
        _ exe: URL,
        _ args: [String],
        handle: ProcessHandle? = nil,
        onLine: @escaping @MainActor (String, Bool) -> Void
    ) async throws -> Result {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Result, Error>) in
            let p = Process()
            p.executableURL = exe
            p.arguments = args
            p.environment = Binaries.environment
            p.standardInput = FileHandle.nullDevice
            let out = Pipe(), err = Pipe()
            p.standardOutput = out
            p.standardError = err

            let group = DispatchGroup()
            let tail = TailBuffer()

            func wire(_ pipe: Pipe, isErr: Bool) {
                let buf = LineBuffer()
                group.enter()
                pipe.fileHandleForReading.readabilityHandler = { fh in
                    let chunk = fh.availableData
                    let lines = chunk.isEmpty ? buf.flush() : buf.append(chunk)
                    if isErr && !lines.isEmpty { tail.append(lines) }
                    if !lines.isEmpty {
                        DispatchQueue.main.async {
                            MainActor.assumeIsolated { for l in lines { onLine(l, isErr) } }
                        }
                    }
                    if chunk.isEmpty {
                        fh.readabilityHandler = nil
                        group.leave()
                    }
                }
            }
            wire(out, isErr: false)
            wire(err, isErr: true)

            group.enter()
            p.terminationHandler = { _ in group.leave() }

            do {
                try p.run()
            } catch {
                out.fileHandleForReading.readabilityHandler = nil
                err.fileHandleForReading.readabilityHandler = nil
                cont.resume(throwing: error)
                return
            }
            handle?.attach(p)

            group.notify(queue: .main) {
                // garante que as linhas despachadas antes sejam processadas primeiro
                DispatchQueue.main.async {
                    let t = tail.lines
                    if handle?.wasCancelled == true {
                        cont.resume(throwing: ToolError.cancelled)
                    } else {
                        cont.resume(returning: Result(status: p.terminationStatus, stderrTail: t))
                    }
                }
            }
        }
    }

    /// Executa e captura toda a saída padrão.
    static func capture(_ exe: URL, _ args: [String], handle: ProcessHandle? = nil) async throws -> (status: Int32, stdout: Data, stderr: String) {
        try await withCheckedThrowingContinuation { cont in
            DispatchQueue.global(qos: .userInitiated).async {
                let p = Process()
                p.executableURL = exe
                p.arguments = args
                p.environment = Binaries.environment
                p.standardInput = FileHandle.nullDevice
                let out = Pipe(), err = Pipe()
                p.standardOutput = out
                p.standardError = err
                do { try p.run() } catch { cont.resume(throwing: error); return }
                handle?.attach(p)
                var errData = Data()
                let g = DispatchGroup()
                g.enter()
                DispatchQueue.global().async {
                    errData = err.fileHandleForReading.readDataToEndOfFile()
                    g.leave()
                }
                let outData = out.fileHandleForReading.readDataToEndOfFile()
                g.wait()
                p.waitUntilExit()
                if handle?.wasCancelled == true { cont.resume(throwing: ToolError.cancelled); return }
                cont.resume(returning: (p.terminationStatus, outData, String(decoding: errData, as: UTF8.self)))
            }
        }
    }

    /// Extrai a mensagem de erro mais útil do stderr.
    static func errorMessage(from tail: [String], fallback: String) -> String {
        if let e = tail.last(where: { $0.contains("ERROR") || $0.lowercased().contains("error") }) {
            return e.replacingOccurrences(of: "ERROR: ", with: "")
        }
        return tail.last ?? fallback
    }
}
