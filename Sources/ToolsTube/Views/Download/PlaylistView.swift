import SwiftUI

struct PlaylistView: View {
    @EnvironmentObject var app: AppState
    @ObservedObject var model: PlaylistModel

    var body: some View {
        PageView(page: .dlPlaylist, subtitle: "Baixe playlists inteiras ou só os vídeos que escolher") {
            GlassSegmented(selection: $model.mode.animation(.spring(response: 0.4)), options: PlaylistModel.Mode.allCases,
                           label: { $0.label }, icon: { $0 == .single ? "music.note.list" : "square.stack.fill" })
                .padding(4)
                .glass(Capsule())

            if model.mode == .single { singleContent } else { multipleContent }

            MediaOptionsCard(options: $model.options)
            NamingCard(naming: $model.naming)
            GlassCard {
                OptionRow(title: "Criar subpasta com o nome da playlist", subtitle: "Organiza cada playlist em sua própria pasta") {
                    Toggle("", isOn: $model.subfolder).toggleStyle(.switch).labelsHidden()
                }
            }
            SaveLocationCard(location: $model.save)
            ActivityCard(queue: model.runner, title: "Downloads")
        } actions: {
            OpenFolderButton { model.save.resolve() }
            AddToQueueButton(count: model.totalSelected) {
                guard let jobs = model.makeJobs() else { return }
                app.downloadQueue.add(jobs)
                app.showToast("\(jobs.count) vídeo(s) adicionados à fila")
            }
            .disabled(model.totalSelected == 0)
            PrimaryButton(title: model.totalSelected > 1 ? "Baixar \(model.totalSelected)" : "Baixar", icon: "arrow.down.circle.fill") {
                guard let jobs = model.makeJobs() else { return }
                withAnimation { model.runner.run(jobs) }
            }
            .disabled(model.totalSelected == 0)
        }
    }

    @ViewBuilder private var singleContent: some View {
        GlassCard("Link da playlist", icon: "link") {
            HStack(spacing: 10) {
                LinkField(placeholder: "https://www.youtube.com/playlist?list=…", text: $model.singleURL) {
                    Task { await model.loadSingle() }
                }
                Button("Carregar") { Task { await model.loadSingle() } }
                    .buttonStyle(LiquidButtonStyle(kind: .primary, compact: true))
                    .disabled(!model.singleURL.hasPrefix("http") || model.loadingSingle)
            }
            if model.loadingSingle {
                HStack(spacing: 10) {
                    ProgressView().controlSize(.small)
                    Text("Carregando playlist…").font(.system(size: 12)).foregroundStyle(.secondary)
                }
            } else if let err = model.errorSingle {
                Label(err, systemImage: "exclamationmark.triangle.fill").foregroundStyle(.orange).font(.system(size: 12))
            }
        }
        if let binding = Binding($model.single) {
            PlaylistEntriesCard(playlist: binding)
        }
    }

    @ViewBuilder private var multipleContent: some View {
        GlassCard("Links das playlists", icon: "link") {
            LinksEditor(text: $model.multiText, placeholder: "Cole o link de uma playlist por linha…")
            HStack {
                PasteButton2 { s in model.multiText += (model.multiText.isEmpty ? "" : "\n") + s }
                Spacer()
                Button { withAnimation { model.addPlaylists() } } label: { Label("Carregar playlists", systemImage: "plus") }
                    .buttonStyle(LiquidButtonStyle(kind: .primary, compact: true))
                    .disabled(extractURLs(model.multiText).isEmpty)
            }
        }
        ForEach($model.playlists) { $pl in
            PlaylistEntriesCard(playlist: $pl, collapsible: true) {
                withAnimation { model.playlists.removeAll { $0.id == pl.id } }
            }
        }
    }
}

struct PlaylistEntriesCard: View {
    @Binding var playlist: PlaylistInfo
    var collapsible = false
    var onRemove: (() -> Void)?

    private var allSelected: Bool { !playlist.entries.isEmpty && playlist.entries.allSatisfy(\.selected) }

    var body: some View {
        GlassCard {
            HStack(spacing: 10) {
                if collapsible {
                    Button {
                        withAnimation(.spring(response: 0.35)) { playlist.expanded.toggle() }
                    } label: {
                        Image(systemName: "chevron.right").font(.system(size: 11, weight: .bold))
                            .rotationEffect(.degrees(playlist.expanded ? 90 : 0))
                            .frame(width: 22, height: 22)
                    }
                    .buttonStyle(.plain)
                }
                Thumbnail(url: playlist.entries.first?.thumbnail, width: 64)
                VStack(alignment: .leading, spacing: 2) {
                    Text(playlist.title).font(.system(size: 14, weight: .semibold)).lineLimit(1)
                    Text([playlist.uploader, playlist.state == .ready ? "\(playlist.entries.count) vídeos" : nil]
                        .compactMap { $0 }.joined(separator: " · "))
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                }
                Spacer()
                if playlist.state == .ready {
                    Text("\(playlist.selectedCount)/\(playlist.entries.count)")
                        .font(.system(size: 12, weight: .semibold).monospacedDigit()).foregroundStyle(.secondary)
                    Button(allSelected ? "Desmarcar todos" : "Marcar todos") {
                        let t = !allSelected
                        for i in playlist.entries.indices { playlist.entries[i].selected = t }
                    }
                    .buttonStyle(LiquidButtonStyle(kind: .secondary, compact: true))
                }
                if let onRemove { IconButton(icon: "xmark", help: "Remover playlist", action: onRemove) }
            }

            switch playlist.state {
            case .loading:
                HStack(spacing: 10) {
                    ProgressView().controlSize(.small)
                    Text("Carregando…").font(.system(size: 12)).foregroundStyle(.secondary)
                }
            case .failed(let msg):
                Label(msg, systemImage: "exclamationmark.triangle.fill").foregroundStyle(.orange).font(.system(size: 12))
            case .ready:
                if !collapsible || playlist.expanded {
                    LazyVStack(spacing: 2) {
                        ForEach($playlist.entries) { $e in VideoEntryRow(entry: $e, showIndex: true) }
                    }
                }
            }
        }
    }
}
