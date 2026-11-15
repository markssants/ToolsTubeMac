import SwiftUI

struct CutOutputFields: View {
    @Binding var format: CutFormat
    @Binding var precise: Bool

    var body: some View {
        VStack(spacing: 12) {
            OptionRow(title: "Formato de saída") {
                ChipMenu(selection: $format, options: CutFormat.allCases) { $0.label }
            }
            RowDivider()
            HStack(spacing: 10) {
                ChoiceTile(title: "Rápido", subtitle: "Sem recodificar · instantâneo", icon: "hare.fill", selected: !precise) { precise = false }
                ChoiceTile(title: "Preciso", subtitle: "Quadro exato · recodifica", icon: "scope", selected: precise) { precise = true }
            }
        }
    }
}

struct CutSingleView: View {
    @EnvironmentObject var app: AppState
    @ObservedObject var model: CutSingleModel

    var body: some View {
        PageView(page: .ctSingle, subtitle: "Marque o início e o fim no player e corte o trecho") {
            GlassCard("Arquivo", icon: "film.fill") {
                if let f = model.file {
                    FileHeaderRow(file: f) {
                        Button("Trocar…") {
                            if let u = Finder.chooseMediaFiles(multiple: false).first { model.setFile(u) }
                        }
                        .buttonStyle(LiquidButtonStyle(kind: .secondary, compact: true))
                    }
                } else {
                    FileDropZone(multiple: false) { urls in if let u = urls.first { withAnimation { model.setFile(u) } } }
                }
            }

            if let f = model.file {
                GlassCard("Trecho", icon: "timeline.selection") {
                    TrimEditor(url: f.url, range: $model.range, fallbackDuration: f.probe?.duration,
                               hasVideo: f.probe?.hasVideo ?? true)
                        .id(f.url)
                    TimeRangeFields(range: $model.range, duration: f.probe?.duration)
                }
                GlassCard("Saída", icon: "square.and.arrow.up.fill") {
                    CutOutputFields(format: $model.format, precise: $model.precise)
                }
            }

            SaveLocationCard(location: $model.save, allowSource: true)
            ActivityCard(queue: model.runner, title: "Cortes")
        } actions: {
            OpenFolderButton { model.save.resolve(source: model.file?.url) }
            AddToQueueButton {
                guard let jobs = model.makeJobs() else { return }
                app.cutQueue.add(jobs)
                app.showToast("Adicionado à fila de cortes")
            }
            .disabled(!model.canCut)
            PrimaryButton(title: "Cortar", icon: "scissors") {
                guard let jobs = model.makeJobs() else { return }
                withAnimation { model.runner.run(jobs) }
            }
            .disabled(!model.canCut)
        }
    }
}
