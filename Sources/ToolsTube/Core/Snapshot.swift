import SwiftUI
import AppKit

/// `ToolsTube --snapshot <pasta>`: renderiza cada página em PNG (para revisão visual) e encerra.
@MainActor
enum Snapshot {
    static var windows: [NSWindow] = []

    static func runIfRequested() {
        let args = CommandLine.arguments
        guard let i = args.firstIndex(of: "--snapshot") else { return }
        let dir = URL(fileURLWithPath: i + 1 < args.count ? args[i + 1] : NSTemporaryDirectory())
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let dark = args.contains("--dark")
        func makeState() -> AppState {
        let state = AppState()
        // dados de exemplo
        state.single.url = "https://www.youtube.com/watch?v=jNQXAC9IVRw"
        state.multi.items = [
            VideoEntry(url: "a", title: "Me at the zoo", duration: 19, thumbnail: URL(string: "https://i.ytimg.com/vi/jNQXAC9IVRw/mqdefault.jpg"), uploader: "jawed"),
            VideoEntry(url: "b", title: "Carregando…", state: .loading),
        ]
        let q = Job(title: "Me at the zoo", work: .download(DownloadSpec(url: "x", options: MediaOptions(), range: TimeRange(), outputDir: URL(fileURLWithPath: "/tmp"))))
        q.status = .running; q.progress = 0.42; q.detail = "2.1MiB/s · restam 00:12"
        state.downloadQueue.add([q, Job(title: "Outro vídeo", work: .download(DownloadSpec(url: "y", options: MediaOptions(kind: .audio), range: TimeRange(), outputDir: URL(fileURLWithPath: "/tmp"))))])
        return state
        }

        let pages: [Page] = [.dlSingle, .dlMulti, .dlPlaylist, .dlQueue, .cvSingle, .cvMulti, .ctSingle, .ctMulti]
        Task {
            for p in pages {
                let state = makeState()
                state.tab = state.tabOf(p)
                state.page = p
                let host = NSHostingView(rootView: RootView().environmentObject(state))
                let win = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1080, height: 760),
                                   styleMask: [.titled, .fullSizeContentView, .closable], backing: .buffered, defer: false)
                win.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
                win.contentView = host
                win.setFrameOrigin(NSPoint(x: -3000, y: 0))
                win.orderFront(nil)
                windows.append(win)
                try? await Task.sleep(for: .seconds(p == .dlSingle ? 5 : 1.5))
                host.layoutSubtreeIfNeeded()
                if let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) {
                    host.cacheDisplay(in: host.bounds, to: rep)
                    let f = dir.appendingPathComponent("\(p.rawValue)\(dark ? "-dark" : "").png")
                    try? rep.representation(using: .png, properties: [:])?.write(to: f)
                    print("snapshot \(f.path)")
                }
                win.orderOut(nil); win.contentView = nil
            }
            exit(0)
        }
    }
}
