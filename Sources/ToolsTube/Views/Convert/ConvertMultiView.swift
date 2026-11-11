import SwiftUI

struct ConvertMultiView: View {
    @EnvironmentObject var app: AppState
    @ObservedObject var model: ConvertMultiModel

    var body: some View {
        PageScaffold(page: .cvMulti, subtitle: "Converta vários arquivos, cada um com suas opções") {
            Section("Arquivos") {
                FileDropZone(multiple: true) { model.add($0) }
            }

            if !model.files.isEmpty {
                Section {
                    MediaOptionsFields(options: $model.globalOptions, context: .convert)
                    HStack {
                        Spacer()
                        Button { model.applyToAll() } label: { Label("Aplicar a todos", systemImage: "square.stack.3d.up") }
                    }
                } header: {
                    Text("Opções para todos")
                } footer: {
                    Text("Ajuste aqui e aplique a todos, ou personalize cada arquivo abaixo.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }

            ForEach($model.files) { $file in
                Section {
                    FileHeaderRow(file: file)
                    DisclosureGroup(isExpanded: $file.expanded) {
                        MediaOptionsFields(options: $file.options, context: .convert)
                        Toggle("Cortar antes de converter", isOn: $file.range.enabled.animation())
                        if file.range.enabled {
                            TimeRangeFields(range: $file.range, duration: file.probe?.duration)
                        }
                    } label: {
                        HStack {
                            Text("Opções").foregroundStyle(.secondary)
                            Spacer()
                            Text(([file.options.summary(original: true)] + (file.range.isActive ? [file.range.summary] : []))
                                .joined(separator: " · "))
                                .font(.callout).foregroundStyle(.secondary)
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
            ActivitySection(queue: model.runner, title: "Conversões")
        } actions: {
            OpenFolderButton { model.save.resolve(source: model.files.first?.url) }
            if !model.files.isEmpty {
                Button("Limpar lista") { withAnimation { model.files.removeAll() } }
            }
            Spacer()
            AddToQueueButton(count: model.files.count) {
                guard let jobs = model.makeJobs() else { return }
                app.convertQueue.add(jobs)
                app.showToast("\(jobs.count) arquivo(s) adicionados à fila")
            }
            .disabled(model.files.isEmpty)
            PrimaryButton(title: model.files.count > 1 ? "Converter \(model.files.count)" : "Converter", icon: "arrow.triangle.2.circlepath") {
                guard let jobs = model.makeJobs() else { return }
                model.runner.run(jobs)
            }
            .disabled(model.files.isEmpty)
        }
    }
}
