import SwiftUI

struct PasteButton2: View {
    var onPaste: (String) -> Void
    var body: some View {
        Button {
            if let s = NSPasteboard.general.string(forType: .string) { onPaste(s) }
        } label: { Label("Colar", systemImage: "doc.on.clipboard") }
        .buttonStyle(LiquidButtonStyle(kind: .secondary, compact: true))
    }
}

struct MultiVideoView: View {
    @EnvironmentObject var app: AppState
    @ObservedObject var model: MultiDownloadModel

    var body: some View {
        PageView(page: .dlMulti, subtitle: "Cole vários links de uma vez e escolha quais baixar") {
            GlassCard("Links", icon: "link") {
                LinksEditor(text: $model.linksText, placeholder: "Cole um link por linha…")
                HStack {
                    PasteButton2 { s in model.linksText += (model.linksText.isEmpty ? "" : "\n") + s }
                    Spacer()
                    let n = extractURLs(model.linksText).count
                    if n > 0 { MetaChip(icon: "link", text: "\(n) link\(n == 1 ? "" : "s")") }
                    Button { withAnimation { model.addLinks() } } label: { Label("Adicionar à lista", systemImage: "plus") }
                        .buttonStyle(LiquidButtonStyle(kind: .primary, compact: true))
                        .disabled(n == 0)
                }
            }

            if !model.items.isEmpty {
                GlassCard("Vídeos", icon: "rectangle.stack.fill", accessory: {
                    HStack(spacing: 8) {
                        if model.loadingCount > 0 { ProgressView().controlSize(.mini) }
                        Text("\(model.selectedCount) de \(model.items.count)")
                            .font(.system(size: 12, weight: .semibold).monospacedDigit()).foregroundStyle(.secondary)
                        Button(model.allSelected ? "Desmarcar todos" : "Marcar todos") { model.toggleAll() }
                            .buttonStyle(LiquidButtonStyle(kind: .secondary, compact: true))
                        Button("Limpar") { withAnimation { model.items.removeAll() } }
                            .buttonStyle(LiquidButtonStyle(kind: .secondary, compact: true))
                    }
                }) {
                    VStack(spacing: 2) {
                        ForEach($model.items) { $item in
                            VideoEntryRow(entry: $item) {
                                withAnimation { model.items.removeAll { $0.id == item.id } }
                            }
                        }
                    }
                }
            }

            MediaOptionsCard(options: $model.options)
            NamingCard(naming: $model.naming)
            SaveLocationCard(location: $model.save)
            ActivityCard(queue: model.runner, title: "Downloads")
        } actions: {
            OpenFolderButton { model.save.resolve() }
            AddToQueueButton(count: model.selectedCount) {
                guard let jobs = model.makeJobs() else { return }
                app.downloadQueue.add(jobs)
                app.showToast("\(jobs.count) vídeo(s) adicionados à fila")
            }
            .disabled(model.selectedCount == 0)
            PrimaryButton(title: model.selectedCount > 1 ? "Baixar \(model.selectedCount)" : "Baixar", icon: "arrow.down.circle.fill") {
                guard let jobs = model.makeJobs() else { return }
                withAnimation { model.runner.run(jobs) }
            }
            .disabled(model.selectedCount == 0)
        }
    }
}
