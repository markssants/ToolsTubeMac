import SwiftUI

struct CutOutputFields: View {
    @Binding var format: CutFormat
    @Binding var precise: Bool

    var body: some View {
        Picker("Formato", selection: $format) {
            ForEach(CutFormat.allCases) { f in Text(f.label).tag(f) }
        }
        Toggle(isOn: $precise) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Corte preciso")
                Text(precise ? "Recodifica: corta no quadro exato, mais lento."
                             : "Rápido: sem recodificar, corta no quadro-chave mais próximo.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

struct CutSingleView: View {
    @EnvironmentObject var app: AppState
    @ObservedObject var model: CutSingleModel

    var body: some View {
        PageScaffold(page: .ctSingle, subtitle: "Marque o início e o fim e corte o trecho") {
            Section("Arquivo") {
                if let f = model.file {
                    FileHeaderRow(file: f) {
                        if let u = Finder.chooseMediaFiles(multiple: false).first { model.setFile(u) }
                    }
                } else {
                    FileDropZone(multiple: false) { urls in if let u = urls.first { model.setFile(u) } }
                }
            }

            if let f = model.file {
                Section("Trecho") {
                    TrimEditor(url: f.url, range: $model.range, fallbackDuration: f.probe?.duration,
                               hasVideo: f.probe?.hasVideo ?? true)
                        .id(f.url)
                    TimeRangeFields(range: $model.range, duration: f.probe?.duration)
                }
                Section("Saída") {
                    CutOutputFields(format: $model.format, precise: $model.precise)
                }
            }

            SaveLocationSection(location: $model.save, allowSource: true)
            ActivitySection(queue: model.runner, title: "Cortes")
        } actions: {
            OpenFolderButton { model.save.resolve(source: model.file?.url) }
            Spacer()
            AddToQueueButton {
                guard let jobs = model.makeJobs() else { return }
                app.cutQueue.add(jobs)
                app.showToast("Adicionado à fila de cortes")
            }
            .disabled(!model.canCut)
            PrimaryButton(title: "Cortar", icon: "scissors") {
                guard let jobs = model.makeJobs() else { return }
                model.runner.run(jobs)
            }
            .disabled(!model.canCut)
        }
    }
}
