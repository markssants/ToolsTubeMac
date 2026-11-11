import SwiftUI

struct SettingsView: View {
    @ObservedObject private var settings = AppSettings.shared
    @State private var ytVersion = "…"
    @State private var ffVersion = "…"
    @State private var updating = false
    @State private var updateLog = ""

    var body: some View {
        TabView {
            Form {
                Section("Pastas") {
                    LabeledContent("Pasta padrão") {
                        HStack {
                            Text(settings.defaultFolder.path(percentEncoded: false).abbreviatingHome)
                                .lineLimit(1).truncationMode(.middle).foregroundStyle(.secondary)
                            Button("Alterar…") {
                                if let u = Finder.chooseFolder(message: "Escolha a pasta padrão") { settings.defaultFolder = u }
                            }
                        }
                    }
                    if let last = settings.lastFolder {
                        LabeledContent("Última pasta usada") {
                            Text(last.path(percentEncoded: false).abbreviatingHome)
                                .lineLimit(1).truncationMode(.middle).foregroundStyle(.secondary)
                        }
                    }
                }
                Section("Execução") {
                    Stepper("Tarefas simultâneas: \(settings.maxConcurrent)", value: $settings.maxConcurrent, in: 1...6)
                    Toggle("Tocar som ao terminar", isOn: $settings.playSound)
                }
            }
            .formStyle(.grouped)
            .tabItem { Label("Geral", systemImage: "gearshape") }

            Form {
                Section {
                    Toggle("Priorizar H.264 (compatível com QuickTime/Fotos)", isOn: $settings.preferH264)
                    Toggle("Incorporar capa e metadados", isOn: $settings.embedMetadata)
                    Picker("Usar cookies do navegador", selection: $settings.cookieBrowser) {
                        ForEach(CookieBrowser.allCases) { b in Text(b.label).tag(b) }
                    }
                } footer: {
                    Text("Cookies ajudam a baixar vídeos com restrição de idade ou quando o YouTube pede login.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section("Conversão") {
                    Toggle("Usar aceleração de hardware (VideoToolbox)", isOn: $settings.hardwareEncoding)
                }
            }
            .formStyle(.grouped)
            .tabItem { Label("Downloads", systemImage: "arrow.down.circle") }

            Form {
                Section("Ferramentas") {
                    LabeledContent("yt-dlp", value: ytVersion)
                    LabeledContent("ffmpeg", value: ffVersion)
                    HStack {
                        Spacer()
                        if updating { ProgressView().controlSize(.small) }
                        Button("Atualizar yt-dlp") { Task { await update() } }.disabled(updating)
                    }
                    if !updateLog.isEmpty {
                        Text(updateLog).font(.caption.monospaced()).foregroundStyle(.secondary).textSelection(.enabled)
                    }
                }
            }
            .formStyle(.grouped)
            .tabItem { Label("Ferramentas", systemImage: "wrench.and.screwdriver") }
            .task { await loadVersions() }
        }
        .frame(width: 520, height: 360)
    }

    private func loadVersions() async {
        if let y = Binaries.ytdlp, let r = try? await ProcessRunner.capture(y, ["--version"]) {
            ytVersion = String(decoding: r.stdout, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        } else { ytVersion = "não encontrado" }
        if let f = Binaries.ffmpeg, let r = try? await ProcessRunner.capture(f, ["-version"]) {
            let first = String(decoding: r.stdout, as: UTF8.self).split(separator: "\n").first ?? ""
            ffVersion = first.split(separator: " ").dropFirst(2).first.map(String.init) ?? String(first)
        } else { ffVersion = "não encontrado" }
    }

    private func update() async {
        guard let y = Binaries.ytdlp else { return }
        updating = true
        defer { updating = false }
        let viaBrew = y.path.hasPrefix("/opt/homebrew") || y.path.hasPrefix("/usr/local")
        let r: (status: Int32, stdout: Data, stderr: String)?
        if viaBrew, let brew = Binaries.find("brew") {
            r = try? await ProcessRunner.capture(brew, ["upgrade", "yt-dlp"])
        } else {
            r = try? await ProcessRunner.capture(y, ["-U"])
        }
        let out = (r.map { String(decoding: $0.stdout, as: UTF8.self) + $0.stderr } ?? "Falhou")
        updateLog = out.split(separator: "\n").suffix(4).joined(separator: "\n")
        if updateLog.isEmpty { updateLog = "yt-dlp já está atualizado." }
        await loadVersions()
    }
}
