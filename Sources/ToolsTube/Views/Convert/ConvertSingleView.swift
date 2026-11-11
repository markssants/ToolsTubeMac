import SwiftUI

struct ConvertSingleView: View {
    @EnvironmentObject var app: AppState
    @ObservedObject var model: ConvertSingleModel

    var body: some View {
        PageScaffold(page: .cvSingle, subtitle: "Converta um arquivo de vídeo ou áudio") {
            Section("Arquivo") {
                if let f = model.file {
                    FileHeaderRow(file: f) {
                        if let u = Finder.chooseMediaFiles(multiple: false).first { model.setFile(u) }
                    }
                } else {
                    FileDropZone(multiple: false) { urls in if let u = urls.first { model.setFile(u) } }
                }
            }
            TimeRangeSection(range: $model.range, toggleLabel: "Cortar antes de converter", duration: model.file?.probe?.duration)
            MediaOptionsSection(options: $model.options, context: .convert)
            SaveLocationSection(location: $model.save, allowSource: true)
            ActivitySection(queue: model.runner, title: "Conversões")
        } actions: {
            OpenFolderButton { model.save.resolve(source: model.file?.url) }
            Spacer()
            AddToQueueButton {
                guard let jobs = model.makeJobs() else { return }
                app.convertQueue.add(jobs)
                app.showToast("Adicionado à fila de conversão")
            }
            .disabled(model.file == nil)
            PrimaryButton(title: "Converter", icon: "arrow.triangle.2.circlepath") {
                guard let jobs = model.makeJobs() else { return }
                model.runner.run(jobs)
            }
            .disabled(model.file == nil || model.range.validationError != nil)
        }
    }
}
