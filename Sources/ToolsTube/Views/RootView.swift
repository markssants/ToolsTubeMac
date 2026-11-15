import SwiftUI

struct RootView: View {
    @EnvironmentObject var app: AppState
    @State private var missing = Binaries.missing

    var body: some View {
        ZStack {
            AuroraBackground(colors: app.tab.colors)

            HStack(spacing: 0) {
                Sidebar()
                    .frame(width: 232)
                    .padding(10)

                ZStack(alignment: .top) {
                    detail
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .id(app.page)
                        .transition(.opacity.combined(with: .offset(y: 8)))

                    WindowDragArea().frame(height: 64)

                    VStack(spacing: 10) {
                        TabSwitcher()
                        if !missing.isEmpty {
                            MissingToolsBanner(missing: missing) { missing = Binaries.missing }
                        }
                        ToastView()
                    }
                    .padding(.top, 14)
                }
            }
        }
        .environment(\.pageColors, app.tab.colors)
        .tint(app.tab.tint)
        .ignoresSafeArea()
        .background(WindowConfigurator())
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: app.page)
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

// MARK: - Abas no topo

struct TabSwitcher: View {
    @EnvironmentObject var app: AppState
    @Namespace private var ns

    var body: some View {
        HStack(spacing: 2) {
            ForEach(MainTab.allCases) { t in
                let selected = app.tab == t
                Button {
                    withAnimation(.spring(response: 0.38, dampingFraction: 0.8)) { app.switchTab(t) }
                } label: {
                    Label(t.label, systemImage: t.icon)
                        .labelStyle(TightLabelStyle())
                        .font(.system(size: 13, weight: selected ? .semibold : .medium))
                        .foregroundStyle(selected ? AnyShapeStyle(.white) : AnyShapeStyle(.primary.opacity(0.8)))
                        .padding(.horizontal, 18)
                        .padding(.vertical, 9)
                        .background {
                            if selected {
                                Capsule()
                                    .fill(LinearGradient(colors: [t.colors[0], t.colors[1]], startPoint: .topLeading, endPoint: .bottomTrailing))
                                    .overlay(Capsule().fill(LinearGradient(colors: [.white.opacity(0.4), .clear], startPoint: .top, endPoint: .center)))
                                    .overlay(Capsule().stroke(.white.opacity(0.45), lineWidth: 1))
                                    .shadow(color: t.colors[0].opacity(0.5), radius: 8, y: 3)
                                    .matchedGeometryEffect(id: "tab", in: ns)
                            }
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .glass(Capsule())
    }
}

// MARK: - Barra lateral

struct Sidebar: View {
    @EnvironmentObject var app: AppState
    @Namespace private var ns

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            WindowDragArea().frame(height: 34)

            HStack(spacing: 10) {
                IconOrb(icon: "play.rectangle.fill", colors: MainTab.download.colors, size: 30)
                VStack(alignment: .leading, spacing: 0) {
                    Text("ToolsTube").font(.system(size: 15, weight: .bold, design: .rounded))
                    Text("Baixe · Converta · Corte").font(.system(size: 10)).foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 10)
            .padding(.bottom, 16)

            sectionTitle(app.tab.label)
            ForEach(app.tab.pages.filter { !isQueue($0) }) { p in
                SidebarItem(page: p, selected: app.page == p, ns: ns) { select(p) }
            }

            sectionTitle("Fila").padding(.top, 14)
            ForEach(app.tab.pages.filter(isQueue)) { p in
                QueueSidebarItem(page: p, queue: queue(for: p), selected: app.page == p, ns: ns) { select(p) }
            }

            Spacer()

            HStack(spacing: 8) {
                if #available(macOS 14.0, *) {
                    SettingsLink {
                        Label("Ajustes", systemImage: "gearshape")
                    }
                    .buttonStyle(LiquidButtonStyle(kind: .secondary, compact: true))
                }
                Spacer()
            }
            .padding(6)
        }
        .padding(10)
        .frame(maxHeight: .infinity, alignment: .top)
        .glass(RoundedRectangle(cornerRadius: 26, style: .continuous))
    }

    private func select(_ p: Page) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) { app.page = p }
    }

    private func sectionTitle(_ s: String) -> some View {
        Text(s.uppercased())
            .font(.system(size: 10, weight: .bold))
            .tracking(0.8)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12)
            .padding(.bottom, 4)
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

struct SidebarItem<Trailing: View>: View {
    let page: Page
    var title: String?
    let selected: Bool
    let ns: Namespace.ID
    @ViewBuilder var trailing: Trailing
    let action: () -> Void
    @Environment(\.pageColors) private var colors
    @State private var hover = false

    init(page: Page, title: String? = nil, selected: Bool, ns: Namespace.ID,
         @ViewBuilder trailing: () -> Trailing = { EmptyView() }, action: @escaping () -> Void) {
        self.page = page
        self.title = title
        self.selected = selected
        self.ns = ns
        self.trailing = trailing()
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: page.icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(selected ? .white : colors[0])
                    .frame(width: 26, height: 26)
                    .background {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(selected
                                  ? AnyShapeStyle(LinearGradient(colors: [colors[0], colors[1]], startPoint: .topLeading, endPoint: .bottomTrailing))
                                  : AnyShapeStyle(colors[0].opacity(0.13)))
                    }
                Text(title ?? page.label)
                    .font(.system(size: 13, weight: selected ? .semibold : .medium))
                    .foregroundStyle(.primary)
                Spacer()
                trailing
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background {
                if selected {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(.primary.opacity(0.08))
                        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(.white.opacity(0.18), lineWidth: 1))
                        .matchedGeometryEffect(id: "sel", in: ns)
                } else if hover {
                    RoundedRectangle(cornerRadius: 12, style: .continuous).fill(.primary.opacity(0.04))
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
    }
}

struct QueueSidebarItem: View {
    let page: Page
    @ObservedObject var queue: JobQueue
    let selected: Bool
    let ns: Namespace.ID
    let action: () -> Void
    @Environment(\.pageColors) private var colors

    var body: some View {
        SidebarItem(page: page, title: "Criar Fila", selected: selected, ns: ns, trailing: {
            let n = queue.jobs.filter { !$0.status.isFinished }.count
            if queue.isRunning {
                ProgressView(value: queue.overallProgress).progressViewStyle(.circular).controlSize(.mini)
            }
            if n > 0 {
                Text("\(n)")
                    .font(.system(size: 11, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 7).padding(.vertical, 2)
                    .background(Capsule().fill(colors[0].gradient))
            }
        }, action: action)
    }
}

// MARK: - Avisos

struct ToastView: View {
    @EnvironmentObject var app: AppState
    var body: some View {
        if let t = app.toast {
            Label(t, systemImage: "checkmark.circle.fill")
                .labelStyle(TightLabelStyle())
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.primary)
                .padding(.horizontal, 18).padding(.vertical, 10)
                .glass(Capsule())
                .transition(.move(edge: .top).combined(with: .opacity).combined(with: .scale(scale: 0.9)))
        }
    }
}

struct MissingToolsBanner: View {
    let missing: [String]
    var recheck: () -> Void
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.yellow)
            VStack(alignment: .leading, spacing: 2) {
                Text("Ferramentas ausentes: \(missing.joined(separator: ", "))").font(.system(size: 13, weight: .semibold))
                Text("No Terminal: brew install yt-dlp ffmpeg").font(.system(size: 11)).foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
            Button("Verificar", action: recheck).buttonStyle(LiquidButtonStyle(kind: .secondary, compact: true))
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
        .glass(RoundedRectangle(cornerRadius: 18, style: .continuous), tint: .yellow)
    }
}
