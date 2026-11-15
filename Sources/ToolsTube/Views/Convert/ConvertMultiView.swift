import SwiftUI

struct ConvertMultiView: View {
    @EnvironmentObject var app: AppState
    @ObservedObject var model: ConvertMultiModel

    var body: some View {
        PageView(page: .cvMulti, subtitle: "Converta vários arquivos, cada um com suas próprias opções") {
            GlassCard("Arquivos", icon: "doc.on.doc.fill") {
                FileDropZone(multiple: true, compact: !model.files.isEmpty) { urls in withAnimation { model.add(urls) } }
            }

            if !model.files.isEmpty {
                GlassCard("Opções para todos", icon: "square.stack.3d.up.fill", accessory: {
                    Button { withAnimation { model.applyToAll() } } label: { Label("Aplicar a todos", systemImage: "checkmark.circle") }
                        .buttonStyle(LiquidButtonStyle(kind: .primary, compact: true))
                }) {
                    MediaOptionsFields(options: $model.globalOptions, context: .convert)
                }
            }

            ForEach($model.files) { $file in
                GlassCard {
                    FileHeaderRow(file: file) {
                        Button {
                            withAnimation(.spring(response: 0.35)) { file.expanded.toggle() }
                        } label: {
                            Label(file.expanded ? "Fechar" : "Personalizar", systemImage: file.expanded ? "chevron.up" : "slider.horizontal.3")
                        }
                        .buttonStyle(LiquidButtonStyle(kind: .secondary, compact: true))
                        IconButton(icon: "xmark", help: "Remover") {
                            withAnimation { model.files.removeAll { $0.id == file.id } }
                        }
                    }
                    HStack(spacing: 6) {
                        MetaChip(icon: file.options.kind.icon, text: file.options.summary(original: true))
                        if file.range.isActive { MetaChip(icon: "timer", text: file.range.summary) }
                    }
                    if file.expanded {
                        VStack(alignment: .leading, spacing: 12) {
                            RowDivider()
                            MediaOptionsFields(options: $file.options, context: .convert)
                            RowDivider()
                            OptionRow(title: "Cortar antes de converter") {
                                Toggle("", isOn: $file.range.enabled.animation()).toggleStyle(.switch).labelsHidden()
                            }
                            if file.range.enabled {
                                TimeRangeFields(range: $file.range, duration: file.probe?.duration)
                            }
                        }
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
            }

            SaveLocationCard(location: $model.save, allowSource: true)
            ActivityCard(queue: model.runner, title: "Conversões")
        } actions: {
            OpenFolderButton { model.save.resolve(source: model.files.first?.url) }
            AddToQueueButton(count: model.files.count) {
                guard let jobs = model.makeJobs() else { return }
                app.convertQueue.add(jobs)
                app.showToast("\(jobs.count) arquivo(s) adicionados à fila")
            }
            .disabled(model.files.isEmpty)
            PrimaryButton(title: model.files.count > 1 ? "Converter \(model.files.count)" : "Converter", icon: "arrow.triangle.2.circlepath") {
                guard let jobs = model.makeJobs() else { return }
                withAnimation { model.runner.run(jobs) }
            }
            .disabled(model.files.isEmpty)
        }
    }
}
