import SwiftUI

struct RootView: View {
    @EnvironmentObject var app: AppState
    @State private var missing = Binaries.missing

    var body: some View {
        NavigationSplitView {
            Sidebar()
                .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 280)
        } detail: {
            VStack(spacing: 0) {
                if !missing.isEmpty { MissingToolsBanner(missing: missing) { missing = Binaries.missing } }
                detail
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .overlay(alignment: .top) { ToastView() }
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                Picker("Seção", selection: Binding(get: { app.tab }, set: { app.switchTab($0) })) {
                    ForEach(MainTab.allCases) { t in
                        Label(t.label, systemImage: t.icon).tag(t)
                    }
                }
                .pickerStyle(.segmented)
                .labelStyle(.titleAndIcon)
                .frame(width: 380)
            }
        }
        .navigationTitle("")
    }

    @ViewBuilder private var detail: some View {
        switch app.page ?? app.tab.pages[0] {
        case .dlSingle: SingleVideoView(model: app.single)
        case .dlMulti: MultiVideoView(model: app.multi)
        case .dlPlaylist: PlaylistView(model: app.playlist)
        case .dlQueue: QueueView(page: .dlQueue, queue: app.downloadQueue)
        case .cvSingle: ConvertSingleView(model: app.convertSingle)
        case .cvMulti: ConvertMultiView(model: app.convertMulti)
        case .cvQueue: QueueView(page: .cvQueue, queue: app.convertQueue)
        case .ctSingle: CutSingleView(model: app.cutSingle)
        case .ctMulti: CutMultiView(model: app.cutMulti)
        case .ctQueue: QueueView(page: .ctQueue, queue: app.cutQueue)
        }
    }
}

struct Sidebar: View {
    @EnvironmentObject var app: AppState

    var body: some View {
        List(selection: $app.page) {
            Section(app.tab.label) {
                ForEach(app.tab.pages.filter { !isQueue($0) }) { p in
                    SidebarRow(page: p).tag(p)
                }
            }
            Section("Fila") {
                ForEach(app.tab.pages.filter(isQueue)) { p in
                    QueueSidebarRow(page: p, queue: queue(for: p)).tag(p)
                }
            }
        }
        .listStyle(.sidebar)
    }

    private func isQueue(_ p: Page) -> Bool { [.dlQueue, .cvQueue, .ctQueue].contains(p) }

    private func queue(for p: Page) -> JobQueue {
        switch p {
        case .cvQueue: return app.convertQueue
        case .ctQueue: return app.cutQueue
        default: return app.downloadQueue
        }
    }
}

struct SidebarRow: View {
    let page: Page
    var body: some View {
        Label {
            Text(page.label)
        } icon: {
            Image(systemName: page.icon).foregroundStyle(page.color)
        }
    }
}

struct QueueSidebarRow: View {
    let page: Page
    @ObservedObject var queue: JobQueue
    var body: some View {
        HStack {
            Label {
                Text("Criar Fila")
            } icon: {
                Image(systemName: page.icon).foregroundStyle(page.color)
            }
            Spacer()
            if queue.isRunning {
                ProgressView(value: queue.overallProgress).progressViewStyle(.circular).controlSize(.mini)
            }
        }
        .badge(queue.jobs.filter { !$0.status.isFinished }.count)
    }
}

struct ToastView: View {
    @EnvironmentObject var app: AppState
    var body: some View {
        if let t = app.toast {
            Label(t, systemImage: "checkmark.circle.fill")
                .font(.callout.weight(.medium))
                .padding(.horizontal, 16).padding(.vertical, 10)
                .background(.regularMaterial, in: Capsule())
                .overlay(Capsule().strokeBorder(.quaternary))
                .shadow(color: .black.opacity(0.15), radius: 10, y: 4)
                .padding(.top, 14)
                .transition(.move(edge: .top).combined(with: .opacity))
        }
    }
}

struct MissingToolsBanner: View {
    let missing: [String]
    var recheck: () -> Void
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.yellow)
            VStack(alignment: .leading, spacing: 2) {
                Text("Ferramentas ausentes: \(missing.joined(separator: ", "))").font(.callout.weight(.semibold))
                Text("Instale pelo Terminal com:  brew install yt-dlp ffmpeg").font(.caption).foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
            Spacer()
            Button("Verificar novamente", action: recheck)
        }
        .padding(12)
        .background(.yellow.opacity(0.12))
    }
}
