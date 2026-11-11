import SwiftUI

/// Tela genérica de fila (downloads, conversões ou cortes).
struct QueueView: View {
    let page: Page
    @ObservedObject var queue: JobQueue
    @EnvironmentObject var app: AppState

    private var verb: String {
        switch page {
        case .dlQueue: return "Baixar"
        case .cvQueue: return "Converter"
        default: return "Cortar"
        }
    }

    private var emptyHint: String {
        switch page {
        case .dlQueue: return "Em Vídeo Único, Vários Vídeos ou Playlist, use “Enviar para a fila” em vez de baixar na hora."
        case .cvQueue: return "Em Converter Único ou Converter Vários, use “Enviar para a fila”."
        default: return "Em Cortar Único ou Cortar Vários, use “Enviar para a fila”."
        }
    }

    var body: some View {
        PageScaffold(page: page, subtitle: "Monte uma lista e execute tudo de uma vez") {
            if queue.jobs.isEmpty {
                Section {
                    VStack(spacing: 12) {
                        Image(systemName: "tray")
                            .font(.system(size: 40, weight: .light))
                            .foregroundStyle(.tertiary)
                        Text("A fila está vazia").font(.headline)
                        Text(emptyHint)
                            .font(.callout).foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 380)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                }
            } else {
                Section {
                    HStack(spacing: 18) {
                        stat("\(queue.jobs.count)", "itens")
                        stat("\(queue.pendingCount)", "aguardando")
                        stat("\(queue.activeCount)", "em andamento")
                        stat("\(queue.doneCount)", "concluídos")
                        Spacer()
                        if queue.isRunning {
                            ProgressView(value: queue.overallProgress)
                                .progressViewStyle(.circular)
                                .controlSize(.small)
                        }
                    }
                }
                Section {
                    ForEach(queue.jobs) { job in
                        JobRow(job: job) { withAnimation { queue.remove(job) } }
                    }
                    .onMove { queue.move(from: $0, to: $1) }
                } header: {
                    HStack {
                        Text("Itens")
                        Spacer()
                        if queue.hasFinished {
                            Button("Limpar concluídos") { withAnimation { queue.clearFinished() } }
                                .buttonStyle(.link).font(.caption)
                        }
                        Button("Limpar tudo") { withAnimation { queue.removeAll() } }
                            .buttonStyle(.link).font(.caption)
                    }
                } footer: {
                    Text("Arraste para reordenar. Clique com o botão direito em um item para mais opções.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                .onChange(of: queue.pendingCount) { old, new in
                    if new > old && queue.isRunning { queue.start() }
                }
            }
        } actions: {
            OpenFolderButton { queue.jobs.last?.outputDir }
            Spacer()
            if queue.isRunning {
                Button(role: .destructive) { queue.cancelAll() } label: {
                    Label("Parar tudo", systemImage: "stop.fill")
                }
            } else if queue.jobs.contains(where: { if case .failed = $0.status { return true }; return $0.status == .cancelled }) {
                Button { queue.retryFailed() } label: { Label("Repetir falhas", systemImage: "arrow.clockwise") }
            }
            PrimaryButton(title: "\(verb) tudo", icon: "play.fill") { queue.start() }
                .disabled(queue.pendingCount == 0 || queue.isRunning)
        }
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(value).font(.title3.weight(.semibold)).monospacedDigit()
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
    }
}
