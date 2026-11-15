import SwiftUI

struct QueueView: View {
    let page: Page
    @ObservedObject var queue: JobQueue
    @EnvironmentObject var app: AppState
    @Environment(\.pageColors) private var colors

    private var verb: String {
        switch page {
        case .dlQueue: return "Baixar"
        case .cvQueue: return "Converter"
        default: return "Cortar"
        }
    }

    private var emptyHint: String {
        switch page {
        case .dlQueue: return "Em Vídeo Único, Vários Vídeos ou Playlist, toque em “Enviar à fila” em vez de baixar na hora."
        case .cvQueue: return "Em Converter Único ou Converter Vários, toque em “Enviar à fila”."
        default: return "Em Cortar Único ou Cortar Vários, toque em “Enviar à fila”."
        }
    }

    var body: some View {
        PageView(page: page, subtitle: "Monte uma lista e execute tudo de uma vez") {
            if queue.jobs.isEmpty {
                GlassCard {
                    VStack(spacing: 14) {
                        IconOrb(icon: "tray.fill", colors: colors, size: 64)
                        Text("A fila está vazia").font(.system(size: 18, weight: .semibold, design: .rounded))
                        Text(emptyHint)
                            .font(.system(size: 13)).foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 380)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 36)
                }
            } else {
                HStack(spacing: 12) {
                    stat("\(queue.jobs.count)", "itens", "square.stack.fill")
                    stat("\(queue.pendingCount)", "aguardando", "clock.fill")
                    stat("\(queue.activeCount)", "em andamento", "bolt.fill")
                    stat("\(queue.doneCount)", "concluídos", "checkmark.circle.fill")
                }
                if queue.isRunning {
                    GlassCard {
                        HStack(spacing: 12) {
                            Text("Progresso geral").font(.system(size: 13, weight: .semibold))
                            GlassProgressBar(value: queue.overallProgress)
                            Text("\(Int(queue.overallProgress * 100))%")
                                .font(.system(size: 13, weight: .bold, design: .rounded).monospacedDigit())
                                .foregroundStyle(colors[0])
                        }
                    }
                }
                GlassCard("Itens", icon: "list.bullet", accessory: {
                    HStack(spacing: 8) {
                        if queue.hasFinished {
                            Button("Limpar concluídos") { withAnimation { queue.clearFinished() } }
                                .buttonStyle(LiquidButtonStyle(kind: .secondary, compact: true))
                        }
                        Button("Limpar tudo") { withAnimation { queue.removeAll() } }
                            .buttonStyle(LiquidButtonStyle(kind: .destructive, compact: true))
                    }
                }) {
                    VStack(spacing: 8) {
                        ForEach(Array(queue.jobs.enumerated()), id: \.element.id) { i, job in
                            HStack(spacing: 6) {
                                JobRow(job: job) { withAnimation { queue.remove(job) } }
                                if job.status == .pending {
                                    VStack(spacing: 2) {
                                        IconButton(icon: "chevron.up", help: "Subir") {
                                            withAnimation { queue.move(from: IndexSet(integer: i), to: max(0, i - 1)) }
                                        }
                                        .disabled(i == 0)
                                        IconButton(icon: "chevron.down", help: "Descer") {
                                            withAnimation { queue.move(from: IndexSet(integer: i), to: min(queue.jobs.count, i + 2)) }
                                        }
                                        .disabled(i == queue.jobs.count - 1)
                                    }
                                }
                            }
                        }
                    }
                }
                .onChange(of: queue.pendingCount) { old, new in
                    if new > old && queue.isRunning { queue.start() }
                }
            }
        } actions: {
            OpenFolderButton { queue.jobs.last?.outputDir }
            if queue.isRunning {
                Button { queue.cancelAll() } label: { Label("Parar tudo", systemImage: "stop.fill") }
                    .buttonStyle(LiquidButtonStyle(kind: .destructive))
            } else if queue.jobs.contains(where: { if case .failed = $0.status { return true }; return $0.status == .cancelled }) {
                Button { queue.retryFailed() } label: { Label("Repetir falhas", systemImage: "arrow.clockwise") }
                    .buttonStyle(LiquidButtonStyle(kind: .secondary))
            }
            PrimaryButton(title: "\(verb) tudo", icon: "play.fill") { queue.start() }
                .disabled(queue.pendingCount == 0 || queue.isRunning)
        }
    }

    private func stat(_ value: String, _ label: String, _ icon: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: icon).font(.system(size: 12, weight: .semibold)).foregroundStyle(colors[0])
            Text(value).font(.system(size: 26, weight: .bold, design: .rounded).monospacedDigit())
                .contentTransition(.numericText())
            Text(label).font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(radius: 20)
        .animation(.spring, value: value)
    }
}
