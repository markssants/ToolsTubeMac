import SwiftUI

struct SingleVideoView: View {
    @EnvironmentObject var app: AppState
    @ObservedObject var model: SingleDownloadModel

    var body: some View {
        PageView(page: .dlSingle, subtitle: "Baixe um vídeo ou só o áudio a partir de um link") {
            GlassCard("Link do vídeo", icon: "link") {
                LinkField(placeholder: "Cole aqui: https://www.youtube.com/watch?v=…", text: $model.url) {
                    Task { await model.analyze() }
                }
                if model.loading {
                    HStack(spacing: 10) {
                        ProgressView().controlSize(.small)
                        Text("Buscando informações…").font(.system(size: 12)).foregroundStyle(.secondary)
                    }
                } else if let info = model.info {
                    VideoCard(entry: info).transition(.opacity.combined(with: .scale(scale: 0.98)))
                } else if let err = model.error {
                    Label(err, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange).font(.system(size: 12)).lineLimit(3)
                }
            }
            .animation(.spring(response: 0.4), value: model.info)

            MediaOptionsCard(options: $model.options)
            TimeRangeCard(range: $model.range, duration: model.info?.duration)
            SaveLocationCard(location: $model.save)
            ActivityCard(queue: model.runner, title: "Downloads")
        } actions: {
            OpenFolderButton { model.save.resolve() }
            AddToQueueButton {
                guard let jobs = model.makeJobs() else { return }
                app.downloadQueue.add(jobs)
                app.showToast("Adicionado à fila de downloads")
            }
            .disabled(!model.isValidURL)
            PrimaryButton(title: "Baixar", icon: "arrow.down.circle.fill") {
                guard let jobs = model.makeJobs() else { return }
                withAnimation { model.runner.run(jobs) }
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
