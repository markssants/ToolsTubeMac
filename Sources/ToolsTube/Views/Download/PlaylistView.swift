import SwiftUI

struct PlaylistView: View {
    @EnvironmentObject var app: AppState
    @ObservedObject var model: PlaylistModel

    var body: some View {
        PageScaffold(page: .dlPlaylist, subtitle: "Baixe playlists inteiras ou só os vídeos que escolher") {
            Section {
                Picker("Modo", selection: $model.mode.animation()) {
                    ForEach(PlaylistModel.Mode.allCases) { m in Text(m.label).tag(m) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }

            if model.mode == .single { singleContent } else { multipleContent }

            MediaOptionsSection(options: $model.options)
            NamingSection(naming: $model.naming)
            Section {
                Toggle("Criar uma subpasta com o nome da playlist", isOn: $model.subfolder)
            }
            SaveLocationSection(location: $model.save)
            ActivitySection(queue: model.runner, title: "Downloads")
        } actions: {
            OpenFolderButton { model.save.resolve() }
            Spacer()
            AddToQueueButton(count: model.totalSelected) {
                guard let jobs = model.makeJobs() else { return }
                app.downloadQueue.add(jobs)
                app.showToast("\(jobs.count) vídeo(s) adicionados à fila")
            }
            .disabled(model.totalSelected == 0)
            PrimaryButton(title: model.totalSelected > 1 ? "Baixar \(model.totalSelected)" : "Baixar", icon: "arrow.down.circle.fill") {
                guard let jobs = model.makeJobs() else { return }
                model.runner.run(jobs)
            }
            .disabled(model.totalSelected == 0)
        }
    }

    // MARK: Uma playlist

    @ViewBuilder private var singleContent: some View {
        Section("Link da playlist") {
            HStack {
                LinkField(placeholder: "https://www.youtube.com/playlist?list=…", text: $model.singleURL) {
                    Task { await model.loadSingle() }
                }
                Button("Carregar") { Task { await model.loadSingle() } }
                    .disabled(!model.singleURL.hasPrefix("http") || model.loadingSingle)
            }
            if model.loadingSingle {
                HStack(spacing: 10) {
                    ProgressView().controlSize(.small)
                    Text("Carregando playlist…").foregroundStyle(.secondary)
                }
            } else if let err = model.errorSingle {
                Label(err, systemImage: "exclamationmark.triangle.fill").foregroundStyle(.orange).font(.callout)
            }
        }

        if let binding = Binding($model.single) {
            PlaylistEntriesSection(playlist: binding)
        }
    }

    // MARK: Várias playlists

    @ViewBuilder private var multipleContent: some View {
        Section("Links das playlists") {
            LinksEditor(text: $model.multiText, placeholder: "Cole o link de uma playlist por linha…")
            HStack {
                Button {
                    if let s = NSPasteboard.general.string(forType: .string) {
                        model.multiText += (model.multiText.isEmpty ? "" : "\n") + s
                    }
                } label: { Label("Colar", systemImage: "doc.on.clipboard") }
                Spacer()
                Button { model.addPlaylists() } label: { Label("Carregar playlists", systemImage: "plus") }
                    .disabled(extractURLs(model.multiText).isEmpty)
            }
        }

        ForEach($model.playlists) { $pl in
            PlaylistEntriesSection(playlist: $pl, collapsible: true) {
                model.playlists.removeAll { $0.id == pl.id }
            }
        }
    }
}

struct PlaylistEntriesSection: View {
    @Binding var playlist: PlaylistInfo
    var collapsible = false
    var onRemove: (() -> Void)?

    private var allSelected: Bool { !playlist.entries.isEmpty && playlist.entries.allSatisfy(\.selected) }

    var body: some View {
        Section {
            switch playlist.state {
            case .loading:
                HStack(spacing: 10) {
                    ProgressView().controlSize(.small)
                    Text("Carregando \(playlist.url)…").foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
                }
            case .failed(let msg):
                Label(msg, systemImage: "exclamationmark.triangle.fill").foregroundStyle(.orange).font(.callout)
            case .ready:
                if !collapsible || playlist.expanded {
                    ForEach($playlist.entries) { $e in
                        VideoEntryRow(entry: $e, showIndex: true)
                    }
                }
            }
        } header: {
            HStack(spacing: 8) {
                if collapsible {
                    Button {
                        withAnimation { playlist.expanded.toggle() }
                    } label: {
                        Image(systemName: "chevron.right")
                            .rotationEffect(.degrees(playlist.expanded ? 90 : 0))
                    }
                    .buttonStyle(.plain)
                }
                Image(systemName: "music.note.list")
                Text(playlist.title).lineLimit(1)
                if let u = playlist.uploader { Text("· \(u)").foregroundStyle(.tertiary).lineLimit(1) }
                Spacer()
                if playlist.state == .ready {
                    Text("\(playlist.selectedCount)/\(playlist.entries.count)").monospacedDigit()
                    Button(allSelected ? "Desmarcar todos" : "Marcar todos") {
                        let t = !allSelected
                        for i in playlist.entries.indices { playlist.entries[i].selected = t }
                    }
                    .buttonStyle(.link).font(.caption)
                }
                if let onRemove {
                    Button(action: onRemove) { Image(systemName: "xmark.circle.fill") }
                        .buttonStyle(.plain).foregroundStyle(.secondary).help("Remover playlist")
                }
            }
        }
    }
}
