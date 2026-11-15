import SwiftUI

struct ConvertSingleView: View {
    @EnvironmentObject var app: AppState
    @ObservedObject var model: ConvertSingleModel

    var body: some View {
        PageView(page: .cvSingle, subtitle: "Converta um arquivo de vídeo ou áudio para outro formato") {
            GlassCard("Arquivo", icon: "doc.fill") {
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
            MediaOptionsCard(options: $model.options, context: .convert)
            TimeRangeCard(range: $model.range, toggleLabel: "Cortar antes de converter", duration: model.file?.probe?.duration)
            SaveLocationCard(location: $model.save, allowSource: true)
            ActivityCard(queue: model.runner, title: "Conversões")
        } actions: {
            OpenFolderButton { model.save.resolve(source: model.file?.url) }
            AddToQueueButton {
                guard let jobs = model.makeJobs() else { return }
                app.convertQueue.add(jobs)
                app.showToast("Adicionado à fila de conversão")
            }
            .disabled(model.file == nil)
            PrimaryButton(title: "Converter", icon: "arrow.triangle.2.circlepath") {
                guard let jobs = model.makeJobs() else { return }
                withAnimation { model.runner.run(jobs) }
            }
            .disabled(model.file == nil || model.range.validationError != nil)
        }
    }
}
