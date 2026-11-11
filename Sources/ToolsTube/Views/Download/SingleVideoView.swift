import SwiftUI

struct SingleVideoView: View {
    @EnvironmentObject var app: AppState
    @ObservedObject var model: SingleDownloadModel

    var body: some View {
        PageScaffold(page: .dlSingle, subtitle: "Baixe um vídeo ou o áudio de um link") {
            Section("Link do vídeo") {
                LinkField(placeholder: "https://www.youtube.com/watch?v=…", text: $model.url) {
                    Task { await model.analyze() }
                }
                if model.loading {
                    HStack(spacing: 10) {
                        ProgressView().controlSize(.small)
                        Text("Buscando informações…").foregroundStyle(.secondary)
                    }
                } else if let info = model.info {
                    VideoCard(entry: info)
                } else if let err = model.error {
                    Label(err, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange).font(.callout).lineLimit(3)
                }
            }

            MediaOptionsSection(options: $model.options)
            SaveLocationSection(location: $model.save)
            TimeRangeSection(range: $model.range, duration: model.info?.duration)
            ActivitySection(queue: model.runner, title: "Downloads")
        } actions: {
            OpenFolderButton { model.save.resolve() }
            Spacer()
            AddToQueueButton {
                guard let jobs = model.makeJobs() else { return }
                app.downloadQueue.add(jobs)
                app.showToast("Adicionado à fila de downloads")
            }
            .disabled(!model.isValidURL)
            PrimaryButton(title: "Baixar", icon: "arrow.down.circle.fill") {
                guard let jobs = model.makeJobs() else { return }
                model.runner.run(jobs)
            }
            .disabled(!model.isValidURL || model.range.validationError != nil)
        }
        .task(id: model.url) {
            try? await Task.sleep(for: .milliseconds(600))
            guard !Task.isCancelled else { return }
            await model.analyze()
        }
    }
}
