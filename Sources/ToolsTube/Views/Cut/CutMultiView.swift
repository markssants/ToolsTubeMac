import SwiftUI

struct CutMultiView: View {
    @EnvironmentObject var app: AppState
    @ObservedObject var model: CutMultiModel
    @State private var editing: UUID?

    var body: some View {
        PageScaffold(page: .ctMulti, subtitle: "Corte vários arquivos, cada um com seu trecho") {
            Section("Arquivos") {
                FileDropZone(multiple: true) { model.add($0) }
            }

            ForEach($model.files) { $file in
                Section {
                    HStack {
                        FileHeaderRow(file: file)
                        Button { editing = file.id } label: { Label("Abrir no editor", systemImage: "play.rectangle") }
                    }
                    DisclosureGroup(isExpanded: $file.expanded) {
                        TimeRangeFields(range: $file.range, duration: file.probe?.duration)
                        CutOutputFields(format: $file.cutFormat, precise: $file.precise)
                    } label: {
                        HStack {
                            Text("Opções").foregroundStyle(.secondary)
                            Spacer()
                            if file.range.isActive {
                                Text("\(file.range.summary) · \(file.cutFormat.label)").font(.callout).foregroundStyle(.secondary)
                            } else {
                                Label("Defina o trecho", systemImage: "exclamationmark.circle")
                                    .font(.callout).foregroundStyle(.orange)
                            }
                        }
                    }
                } header: {
                    HStack {
                        Spacer()
                        Button {
                            withAnimation { model.files.removeAll { $0.id == file.id } }
                        } label: { Label("Remover", systemImage: "xmark") }
                            .buttonStyle(.link).font(.caption)
                    }
                }
            }

            SaveLocationSection(location: $model.save, allowSource: true)
            ActivitySection(queue: model.runner, title: "Cortes")
        } actions: {
            OpenFolderButton { model.save.resolve(source: model.files.first?.url) }
            if !model.files.isEmpty {
                Button("Limpar lista") { withAnimation { model.files.removeAll() } }
            }
            Spacer()
            AddToQueueButton(count: model.readyCount) {
                guard let jobs = model.makeJobs() else { return }
                app.cutQueue.add(jobs)
                app.showToast("\(jobs.count) corte(s) adicionados à fila")
            }
            .disabled(model.readyCount == 0)
            PrimaryButton(title: model.readyCount > 1 ? "Cortar \(model.readyCount)" : "Cortar", icon: "scissors") {
                guard let jobs = model.makeJobs() else { return }
                model.runner.run(jobs)
            }
            .disabled(model.readyCount == 0)
        }
        .sheet(isPresented: Binding(get: { editing != nil }, set: { if !$0 { editing = nil } })) {
            if let id = editing, let i = model.files.firstIndex(where: { $0.id == id }) {
                TrimSheet(file: $model.files[i])
            }
        }
    }
}

struct TrimSheet: View {
    @Binding var file: MediaFile
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(file.name).font(.headline).lineLimit(1).truncationMode(.middle)
            TrimEditor(url: file.url, range: $file.range, fallbackDuration: file.probe?.duration,
                       hasVideo: file.probe?.hasVideo ?? true)
            Form { TimeRangeFields(range: $file.range, duration: file.probe?.duration) }
                .formStyle(.grouped)
                .frame(height: 150)
            HStack {
                Spacer()
                Button("Concluído") { dismiss() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(minWidth: 680, minHeight: 600)
    }
}
