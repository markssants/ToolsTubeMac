import SwiftUI

struct MultiVideoView: View {
    @EnvironmentObject var app: AppState
    @ObservedObject var model: MultiDownloadModel

    var body: some View {
        PageScaffold(page: .dlMulti, subtitle: "Cole vários links e escolha quais baixar") {
            Section {
                LinksEditor(text: $model.linksText, placeholder: "Cole um link por linha…")
                HStack {
                    Button {
                        if let s = NSPasteboard.general.string(forType: .string) {
                            model.linksText += (model.linksText.isEmpty ? "" : "\n") + s
                        }
                    } label: { Label("Colar", systemImage: "doc.on.clipboard") }
                    Spacer()
                    let n = extractURLs(model.linksText).count
                    if n > 0 { Text("\(n) link\(n == 1 ? "" : "s") encontrado\(n == 1 ? "" : "s")").foregroundStyle(.secondary).font(.callout) }
                    Button { model.addLinks() } label: { Label("Adicionar à lista", systemImage: "plus") }
                        .disabled(n == 0)
                }
            } header: { Text("Links") }

            if !model.items.isEmpty {
                Section {
                    ForEach($model.items) { $item in
                        VideoEntryRow(entry: $item) {
                            model.items.removeAll { $0.id == item.id }
                        }
                    }
                } header: {
                    HStack {
                        Text("Vídeos")
                        Spacer()
                        if model.loadingCount > 0 { ProgressView().controlSize(.mini) }
                        Text("\(model.selectedCount) de \(model.items.count) selecionados").monospacedDigit()
                        Button(model.allSelected ? "Desmarcar todos" : "Marcar todos") { model.toggleAll() }
                            .buttonStyle(.link).font(.caption)
                        Button("Limpar") { model.items.removeAll() }
                            .buttonStyle(.link).font(.caption)
                    }
                }
            }

            MediaOptionsSection(options: $model.options)
            NamingSection(naming: $model.naming)
            SaveLocationSection(location: $model.save)
            ActivitySection(queue: model.runner, title: "Downloads")
        } actions: {
            OpenFolderButton { model.save.resolve() }
            Spacer()
            AddToQueueButton(count: model.selectedCount) {
                guard let jobs = model.makeJobs() else { return }
                app.downloadQueue.add(jobs)
                app.showToast("\(jobs.count) vídeo(s) adicionados à fila")
            }
            .disabled(model.selectedCount == 0)
            PrimaryButton(title: model.selectedCount > 1 ? "Baixar \(model.selectedCount)" : "Baixar", icon: "arrow.down.circle.fill") {
                guard let jobs = model.makeJobs() else { return }
                model.runner.run(jobs)
            }
            .disabled(model.selectedCount == 0)
        }
    }
}
