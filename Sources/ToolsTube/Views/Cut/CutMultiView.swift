import SwiftUI

struct CutMultiView: View {
    @EnvironmentObject var app: AppState
    @ObservedObject var model: CutMultiModel
    @State private var editing: UUID?

    var body: some View {
        PageView(page: .ctMulti, subtitle: "Corte vários arquivos, cada um com seu próprio trecho") {
            GlassCard("Arquivos", icon: "film.stack.fill") {
                FileDropZone(multiple: true, compact: !model.files.isEmpty) { urls in withAnimation { model.add(urls) } }
            }

            ForEach($model.files) { $file in
                GlassCard {
                    FileHeaderRow(file: file) {
                        Button { editing = file.id } label: { Label("Editor", systemImage: "play.rectangle.fill") }
                            .buttonStyle(LiquidButtonStyle(kind: .secondary, compact: true))
                        IconButton(icon: "xmark", help: "Remover") {
                            withAnimation { model.files.removeAll { $0.id == file.id } }
                        }
                    }
                    if !file.range.isActive {
                        Label("Defina o início e/ou o fim do trecho", systemImage: "exclamationmark.circle.fill")
                            .font(.system(size: 12, weight: .medium)).foregroundStyle(.orange)
                    }
                    TimeRangeFields(range: $file.range, duration: file.probe?.duration)
                    RowDivider()
                    CutOutputFields(format: $file.cutFormat, precise: $file.precise)
                }
            }

            SaveLocationCard(location: $model.save, allowSource: true)
            ActivityCard(queue: model.runner, title: "Cortes")
        } actions: {
            OpenFolderButton { model.save.resolve(source: model.files.first?.url) }
            AddToQueueButton(count: model.readyCount) {
                guard let jobs = model.makeJobs() else { return }
                app.cutQueue.add(jobs)
                app.showToast("\(jobs.count) corte(s) adicionados à fila")
            }
            .disabled(model.readyCount == 0)
            PrimaryButton(title: model.readyCount > 1 ? "Cortar \(model.readyCount)" : "Cortar", icon: "scissors") {
                guard let jobs = model.makeJobs() else { return }
                withAnimation { model.runner.run(jobs) }
            }
            .disabled(model.readyCount == 0)
        }
        .sheet(isPresented: Binding(get: { editing != nil }, set: { if !$0 { editing = nil } })) {
            if let id = editing, let i = model.files.firstIndex(where: { $0.id == id }) {
                TrimSheet(file: $model.files[i])
                    .environment(\.pageColors, app.tab.colors)
                    .tint(app.tab.tint)
            }
        }
    }
}

struct TrimSheet: View {
    @Binding var file: MediaFile
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            FileHeaderRow(file: file)
            TrimEditor(url: file.url, range: $file.range, fallbackDuration: file.probe?.duration,
                       hasVideo: file.probe?.hasVideo ?? true)
            TimeRangeFields(range: $file.range, duration: file.probe?.duration)
            HStack {
                Spacer()
                Button { dismiss() } label: { Label("Concluído", systemImage: "checkmark") }
                    .buttonStyle(LiquidButtonStyle(kind: .primary))
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(minWidth: 720, minHeight: 620)
    }
}
