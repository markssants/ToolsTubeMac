import SwiftUI
import UniformTypeIdentifiers

extension String {
    var abbreviatingHome: String { (self as NSString).abbreviatingWithTildeInPath }
}

// MARK: - Página

struct PageView<Content: View, Actions: View>: View {
    let page: Page
    let subtitle: String
    @ViewBuilder var content: Content
    @ViewBuilder var actions: Actions

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(spacing: 18) {
                    PageHeader(page: page, subtitle: subtitle)
                        .padding(.bottom, 4)
                    content
                }
                .frame(maxWidth: 780)
                .padding(.horizontal, 28)
                .padding(.top, 78)
                .padding(.bottom, 110)
                .frame(maxWidth: .infinity)
            }
            .scrollIndicators(.automatic)

            HStack(spacing: 10) { actions }
                .padding(8)
                .glass(Capsule())
                .padding(.bottom, 18)
        }
    }
}

struct PageHeader: View {
    let page: Page
    let subtitle: String
    @Environment(\.pageColors) private var colors

    var body: some View {
        HStack(spacing: 16) {
            IconOrb(icon: page.icon, colors: colors, size: 56)
            VStack(alignment: .leading, spacing: 3) {
                Text(page.title)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                Text(subtitle)
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }
}

struct IconOrb: View {
    let icon: String
    let colors: [Color]
    var size: CGFloat = 40

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.3, style: .continuous)
                .fill(LinearGradient(colors: [colors[0], colors[1]], startPoint: .topLeading, endPoint: .bottomTrailing))
            RoundedRectangle(cornerRadius: size * 0.3, style: .continuous)
                .fill(LinearGradient(colors: [.white.opacity(0.45), .clear], startPoint: .top, endPoint: .center))
            RoundedRectangle(cornerRadius: size * 0.3, style: .continuous)
                .stroke(.white.opacity(0.5), lineWidth: 1)
            Image(systemName: icon)
                .font(.system(size: size * 0.42, weight: .semibold))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.2), radius: 2, y: 1)
        }
        .frame(width: size, height: size)
        .shadow(color: colors[0].opacity(0.5), radius: size * 0.25, y: size * 0.1)
    }
}

extension Page {
    var title: String {
        switch self {
        case .dlQueue: return "Fila de Downloads"
        case .cvQueue: return "Fila de Conversão"
        case .ctQueue: return "Fila de Cortes"
        default: return label
        }
    }
}

// MARK: - Card e linhas

struct GlassCard<Content: View, Accessory: View>: View {
    var title: String?
    var icon: String?
    @ViewBuilder var accessory: Accessory
    @ViewBuilder var content: Content
    @Environment(\.pageColors) private var colors

    init(_ title: String? = nil, icon: String? = nil,
         @ViewBuilder accessory: () -> Accessory = { EmptyView() },
         @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.accessory = accessory()
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if title != nil || icon != nil {
                HStack(spacing: 10) {
                    if let icon {
                        Image(systemName: icon)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(colors[0])
                            .frame(width: 26, height: 26)
                            .background(Circle().fill(colors[0].opacity(0.15)))
                    }
                    if let title {
                        Text(title).font(.system(size: 15, weight: .semibold))
                    }
                    Spacer()
                    accessory
                }
            }
            content
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }
}

struct OptionRow<Control: View>: View {
    let title: String
    var subtitle: String?
    @ViewBuilder var control: Control

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 13, weight: .medium))
                if let subtitle {
                    Text(subtitle).font(.system(size: 11)).foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 12)
            control
        }
        .frame(minHeight: 30)
    }
}

struct RowDivider: View {
    var body: some View { Rectangle().fill(.primary.opacity(0.07)).frame(height: 1) }
}

// MARK: - Segmentado com pílula deslizante

struct GlassSegmented<T: Hashable>: View {
    @Binding var selection: T
    let options: [T]
    let label: (T) -> String
    var icon: ((T) -> String)? = nil
    var compact = false
    @Namespace private var ns
    @Environment(\.pageColors) private var colors

    var body: some View {
        HStack(spacing: 2) {
            ForEach(options, id: \.self) { opt in
                let selected = opt == selection
                Button {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) { selection = opt }
                } label: {
                    HStack(spacing: 6) {
                        if let icon { Image(systemName: icon(opt)).font(.system(size: compact ? 10 : 12, weight: .semibold)) }
                        Text(label(opt)).font(.system(size: compact ? 11 : 13, weight: selected ? .semibold : .medium))
                    }
                    .padding(.horizontal, compact ? 10 : 14)
                    .padding(.vertical, compact ? 5 : 8)
                    .frame(maxWidth: compact ? nil : .infinity)
                    .foregroundStyle(selected ? AnyShapeStyle(.white) : AnyShapeStyle(.primary.opacity(0.75)))
                    .background {
                        if selected {
                            Capsule()
                                .fill(LinearGradient(colors: [colors[0], colors[1]], startPoint: .topLeading, endPoint: .bottomTrailing))
                                .overlay(Capsule().fill(LinearGradient(colors: [.white.opacity(0.35), .clear], startPoint: .top, endPoint: .center)))
                                .overlay(Capsule().stroke(.white.opacity(0.4), lineWidth: 1))
                                .shadow(color: colors[0].opacity(0.4), radius: 6, y: 2)
                                .matchedGeometryEffect(id: "pill", in: ns)
                        }
                    }
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(Capsule().fill(.primary.opacity(0.06)))
        .overlay(Capsule().stroke(.primary.opacity(0.06), lineWidth: 1))
    }
}

// MARK: - Menu em chip

struct ChipMenu<T: Hashable>: View {
    @Binding var selection: T
    let options: [T]
    let label: (T) -> String

    var body: some View {
        Menu {
            Picker("", selection: $selection) {
                ForEach(options, id: \.self) { Text(label($0)).tag($0) }
            }
            .pickerStyle(.inline)
            .labelsHidden()
        } label: {
            HStack(spacing: 6) {
                Text(label(selection)).font(.system(size: 13, weight: .medium))
                Image(systemName: "chevron.up.chevron.down").font(.system(size: 9, weight: .bold)).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Capsule().fill(.primary.opacity(0.07)))
            .overlay(Capsule().stroke(.primary.opacity(0.08), lineWidth: 1))
            .contentShape(Capsule())
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize()
    }
}

// MARK: - Campos

struct InsetField<Content: View>: View {
    @ViewBuilder var content: Content
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        content
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(scheme == .dark ? Color.black.opacity(0.25) : Color.white.opacity(0.6)))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(.primary.opacity(0.08), lineWidth: 1))
    }
}

struct LinkField: View {
    let placeholder: String
    @Binding var text: String
    var onSubmit: () -> Void = {}

    var body: some View {
        HStack(spacing: 10) {
            InsetField {
                HStack(spacing: 8) {
                    Image(systemName: "link").foregroundStyle(.secondary).font(.system(size: 12, weight: .semibold))
                    TextField("", text: $text, prompt: Text(placeholder))
                        .textFieldStyle(.plain)
                        .font(.system(size: 13))
                        .onSubmit(onSubmit)
                    if !text.isEmpty {
                        Button { text = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.tertiary) }
                            .buttonStyle(.plain)
                    }
                }
            }
            Button {
                if let s = NSPasteboard.general.string(forType: .string) {
                    text = s.trimmingCharacters(in: .whitespacesAndNewlines)
                    onSubmit()
                }
            } label: { Label("Colar", systemImage: "doc.on.clipboard") }
            .buttonStyle(LiquidButtonStyle(kind: .secondary, compact: true))
        }
    }
}

struct LinksEditor: View {
    @Binding var text: String
    let placeholder: String

    var body: some View {
        InsetField {
            ZStack(alignment: .topLeading) {
                TextEditor(text: $text)
                    .font(.system(size: 12, design: .monospaced))
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 96, maxHeight: 150)
                if text.isEmpty {
                    Text(placeholder).font(.system(size: 13)).foregroundStyle(.tertiary)
                        .padding(.leading, 5).allowsHitTesting(false)
                }
            }
        }
    }
}

struct TimeField: View {
    let label: String
    @Binding var text: String
    var placeholder = "00:00"

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary).textCase(.uppercase)
            InsetField {
                TextField("", text: $text, prompt: Text(placeholder))
                    .textFieldStyle(.plain)
                    .font(.system(size: 17, weight: .medium, design: .rounded).monospacedDigit())
            }
        }
    }
}

// MARK: - Mídia

struct Thumbnail: View {
    let url: URL?
    var width: CGFloat = 96

    var body: some View {
        AsyncImage(url: url) { phase in
            if let img = phase.image {
                img.resizable().aspectRatio(contentMode: .fill)
            } else {
                ZStack {
                    Rectangle().fill(.primary.opacity(0.06))
                    Image(systemName: "play.fill").foregroundStyle(.tertiary)
                }
            }
        }
        .frame(width: width, height: width * 9 / 16)
        .clipShape(RoundedRectangle(cornerRadius: width > 120 ? 14 : 8, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: width > 120 ? 14 : 8, style: .continuous).stroke(.white.opacity(0.18), lineWidth: 1))
        .shadow(color: .black.opacity(0.18), radius: 6, y: 3)
    }
}

struct VideoCard: View {
    let entry: VideoEntry

    var body: some View {
        HStack(spacing: 16) {
            Thumbnail(url: entry.thumbnail, width: 176)
            VStack(alignment: .leading, spacing: 8) {
                Text(entry.title).font(.system(size: 16, weight: .semibold)).lineLimit(2)
                HStack(spacing: 8) {
                    if let u = entry.uploader { MetaChip(icon: "person.fill", text: u) }
                    if let d = entry.duration { MetaChip(icon: "clock.fill", text: TimeUtils.format(d)) }
                }
            }
            Spacer()
        }
    }
}

struct MetaChip: View {
    let icon: String
    let text: String
    var body: some View {
        Label(text, systemImage: icon)
            .labelStyle(TightLabelStyle())
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 9).padding(.vertical, 4)
            .background(Capsule().fill(.primary.opacity(0.06)))
            .lineLimit(1)
    }
}

struct CheckCircle: View {
    let on: Bool
    var disabled = false
    @Environment(\.pageColors) private var colors
    var body: some View {
        ZStack {
            Circle().stroke(.primary.opacity(on ? 0 : 0.25), lineWidth: 1.5)
            if on {
                Circle().fill(LinearGradient(colors: [colors[0], colors[1]], startPoint: .topLeading, endPoint: .bottomTrailing))
                Image(systemName: "checkmark").font(.system(size: 10, weight: .heavy)).foregroundStyle(.white)
            }
        }
        .frame(width: 20, height: 20)
        .opacity(disabled ? 0.4 : 1)
        .animation(.spring(response: 0.25), value: on)
    }
}

struct VideoEntryRow: View {
    @Binding var entry: VideoEntry
    var showIndex = false
    var onRemove: (() -> Void)?
    @State private var hover = false

    var body: some View {
        HStack(spacing: 12) {
            CheckCircle(on: entry.selected, disabled: entry.state != .ready)
            if showIndex, let i = entry.index {
                Text("\(i)").font(.system(size: 11, weight: .semibold).monospacedDigit())
                    .foregroundStyle(.secondary).frame(width: 24, alignment: .trailing)
            }
            Thumbnail(url: entry.thumbnail, width: 76)
            VStack(alignment: .leading, spacing: 3) {
                Text(entry.title).font(.system(size: 13, weight: .medium)).lineLimit(1)
                switch entry.state {
                case .loading:
                    HStack(spacing: 6) { ProgressView().controlSize(.mini); Text("Carregando…") }
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                case .failed(let msg):
                    Label(msg, systemImage: "exclamationmark.triangle.fill")
                        .font(.system(size: 11)).foregroundStyle(.red).lineLimit(1)
                case .ready:
                    Text([entry.uploader, entry.duration.map { TimeUtils.format($0) }].compactMap { $0 }.joined(separator: " · "))
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                }
            }
            Spacer()
            if let onRemove, hover {
                IconButton(icon: "xmark", help: "Remover", action: onRemove)
            }
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(.primary.opacity(hover ? 0.05 : 0)))
        .contentShape(Rectangle())
        .onTapGesture { if entry.state == .ready { entry.selected.toggle() } }
        .onHover { hover = $0 }
    }
}

// MARK: - Opções

enum OptionsContext { case download, convert }

struct MediaOptionsCard: View {
    @Binding var options: MediaOptions
    var context: OptionsContext = .download
    var title = "Formato e qualidade"

    var body: some View {
        GlassCard(title, icon: "slider.horizontal.3") {
            MediaOptionsFields(options: $options, context: context)
        }
    }
}

struct MediaOptionsFields: View {
    @Binding var options: MediaOptions
    var context: OptionsContext = .download

    var body: some View {
        VStack(spacing: 12) {
            GlassSegmented(selection: $options.kind.animation(), options: MediaKind.allCases,
                           label: { $0.label }, icon: { $0.icon })
            if options.kind == .video {
                OptionRow(title: "Qualidade") {
                    ChipMenu(selection: $options.quality, options: VideoQuality.allCases) { $0.label(original: context == .convert) }
                }
                RowDivider()
                OptionRow(title: "Formato") {
                    GlassSegmented(selection: $options.container,
                                   options: context == .download ? VideoContainer.downloadable : VideoContainer.allCases,
                                   label: { $0.label }, compact: true)
                }
                if context == .convert {
                    RowDivider()
                    OptionRow(title: "Compressão") {
                        GlassSegmented(selection: $options.preset, options: EncodePreset.allCases, label: { $0.label }, compact: true)
                    }
                }
            } else {
                OptionRow(title: "Formato") {
                    GlassSegmented(selection: $options.audioFormat, options: AudioFormat.allCases, label: { $0.label }, compact: true)
                }
                if !options.audioFormat.isLossless {
                    RowDivider()
                    OptionRow(title: "Qualidade") {
                        ChipMenu(selection: $options.audioBitrate, options: AudioBitrate.allCases) { $0.label }
                    }
                }
            }
        }
    }
}

struct ChoiceTile: View {
    let title: String
    var subtitle: String?
    let icon: String
    let selected: Bool
    let action: () -> Void
    @Environment(\.pageColors) private var colors

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(selected ? .white : colors[0])
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(selected
                        ? AnyShapeStyle(LinearGradient(colors: [colors[0], colors[1]], startPoint: .topLeading, endPoint: .bottomTrailing))
                        : AnyShapeStyle(colors[0].opacity(0.12))))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.system(size: 13, weight: .semibold)).foregroundStyle(.primary)
                    if let subtitle {
                        Text(subtitle).font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(selected ? colors[0].opacity(0.12) : Color.primary.opacity(0.04)))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(selected ? colors[0].opacity(0.6) : Color.primary.opacity(0.07), lineWidth: selected ? 1.5 : 1))
            .contentShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.3), value: selected)
    }
}

struct NamingCard: View {
    @Binding var naming: NamingMode
    var body: some View {
        GlassCard("Nomear arquivos", icon: "textformat") {
            HStack(spacing: 10) {
                ForEach(NamingMode.allCases) { n in
                    ChoiceTile(title: n.label, subtitle: n.example,
                               icon: n == .enumerated ? "list.number" : "textformat.abc",
                               selected: naming == n) { naming = n }
                }
            }
        }
    }
}

struct SaveLocationCard: View {
    @Binding var location: SaveLocation
    var allowSource = false
    @ObservedObject private var settings = AppSettings.shared

    private var modes: [SaveMode] { allowSource ? SaveMode.allCases : [.lastUsed, .choose, .defaultFolder] }

    var body: some View {
        GlassCard("Salvar em", icon: "folder.fill") {
            OptionRow(title: "Escolher onde salvar", subtitle: location.customize ? nil : "Desativado: usa a pasta padrão") {
                Toggle("", isOn: $location.customize.animation(.spring(response: 0.35))).toggleStyle(.switch).labelsHidden()
            }
            if location.customize {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                    ForEach(modes) { m in
                        ChoiceTile(title: m.shortLabel, icon: m.icon, selected: location.mode == m) {
                            location.mode = m
                            if m == .choose && location.chosenFolder == nil {
                                location.chosenFolder = Finder.chooseFolder()
                            }
                        }
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
            HStack(spacing: 10) {
                Image(systemName: "folder.fill").foregroundStyle(.blue.gradient)
                Text(destinationText)
                    .font(.system(size: 12, weight: .medium)).foregroundStyle(.secondary)
                    .lineLimit(1).truncationMode(.middle)
                Spacer()
                if location.customize && location.mode == .choose {
                    Button("Alterar…") { if let u = Finder.chooseFolder() { location.chosenFolder = u } }
                        .buttonStyle(LiquidButtonStyle(kind: .secondary, compact: true))
                }
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(.primary.opacity(0.05)))
        }
    }

    private var destinationText: String {
        if location.customize && location.mode == .sourceFolder { return "Mesma pasta de cada arquivo" }
        if let u = location.resolve() { return u.path(percentEncoded: false).abbreviatingHome }
        return "Escolha uma pasta"
    }
}

extension SaveMode {
    var shortLabel: String {
        switch self {
        case .lastUsed: return "Última pasta usada"
        case .choose: return "Escolher pasta…"
        case .defaultFolder: return "Pasta padrão"
        case .sourceFolder: return "Pasta do original"
        }
    }
}

struct TimeRangeFields: View {
    @Binding var range: TimeRange
    var duration: Double?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                TimeField(label: "Início", text: $range.start, placeholder: "00:00")
                Image(systemName: "arrow.right").foregroundStyle(.tertiary).padding(.top, 18)
                TimeField(label: "Fim", text: $range.end, placeholder: duration.map { TimeUtils.format($0) } ?? "fim")
            }
            if let err = range.validationError {
                Label(err, systemImage: "exclamationmark.triangle.fill").foregroundStyle(.orange).font(.system(size: 12))
            } else if range.isActive {
                let s = range.startSeconds ?? 0
                let e = range.endSeconds ?? duration
                MetaChip(icon: "timer", text: "Duração do trecho: \(e.map { TimeUtils.format($0 - s) } ?? "até o fim")")
            } else {
                Text("Formatos aceitos: hh:mm:ss, mm:ss ou segundos. Em branco = do início / até o fim.")
                    .font(.system(size: 11)).foregroundStyle(.tertiary)
            }
        }
    }
}

struct TimeRangeCard: View {
    @Binding var range: TimeRange
    var toggleLabel = "Baixar apenas um trecho"
    var duration: Double?

    var body: some View {
        GlassCard("Trecho", icon: "timer") {
            OptionRow(title: toggleLabel) {
                Toggle("", isOn: $range.enabled.animation(.spring(response: 0.35))).toggleStyle(.switch).labelsHidden()
            }
            if range.enabled {
                TimeRangeFields(range: $range, duration: duration)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}

// MARK: - Arquivos

struct FileDropZone: View {
    var multiple: Bool
    var compact = false
    var onFiles: ([URL]) -> Void
    @State private var targeted = false
    @Environment(\.pageColors) private var colors

    var body: some View {
        Group {
            if compact {
                HStack(spacing: 12) {
                    Image(systemName: "plus.circle.fill").font(.system(size: 20)).foregroundStyle(colors[0].gradient)
                    Text("Arraste mais arquivos aqui ou").font(.system(size: 13)).foregroundStyle(.secondary)
                    Button("Selecionar…") { pick() }.buttonStyle(LiquidButtonStyle(kind: .secondary, compact: true))
                    Spacer()
                }
                .padding(14)
            } else {
                VStack(spacing: 12) {
                    IconOrb(icon: multiple ? "square.and.arrow.down.on.square.fill" : "square.and.arrow.down.fill", colors: colors, size: 54)
                        .scaleEffect(targeted ? 1.1 : 1)
                    Text(multiple ? "Arraste seus arquivos aqui" : "Arraste um arquivo aqui")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Vídeo ou áudio · MP4, MOV, MKV, WEBM, MP3, WAV…").font(.system(size: 12)).foregroundStyle(.secondary)
                    Button(multiple ? "Selecionar arquivos…" : "Selecionar arquivo…") { pick() }
                        .buttonStyle(LiquidButtonStyle(kind: .secondary))
                        .padding(.top, 4)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 34)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [7, 5]))
                .foregroundStyle(targeted ? colors[0] : Color.primary.opacity(0.18))
                .background(RoundedRectangle(cornerRadius: 18).fill(targeted ? colors[0].opacity(0.10) : .clear))
        )
        .animation(.spring(response: 0.3), value: targeted)
        .onDrop(of: [.fileURL], isTargeted: $targeted) { providers in
            loadURLs(providers) { urls in onFiles(multiple ? urls : Array(urls.prefix(1))) }
            return true
        }
    }

    private func pick() {
        let urls = Finder.chooseMediaFiles(multiple: multiple)
        if !urls.isEmpty { onFiles(urls) }
    }
}

func loadURLs(_ providers: [NSItemProvider], completion: @escaping @MainActor ([URL]) -> Void) {
    let group = DispatchGroup()
    let lock = NSLock()
    var urls: [URL] = []
    for p in providers {
        group.enter()
        _ = p.loadObject(ofClass: URL.self) { url, _ in
            if let url { lock.lock(); urls.append(url); lock.unlock() }
            group.leave()
        }
    }
    group.notify(queue: .main) {
        MainActor.assumeIsolated { completion(urls.sorted { $0.lastPathComponent < $1.lastPathComponent }) }
    }
}

struct FileHeaderRow<Trailing: View>: View {
    let file: MediaFile
    @ViewBuilder var trailing: Trailing

    init(file: MediaFile, @ViewBuilder trailing: () -> Trailing = { EmptyView() }) {
        self.file = file
        self.trailing = trailing()
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: file.url.path))
                .resizable().frame(width: 40, height: 40)
                .shadow(color: .black.opacity(0.15), radius: 3, y: 2)
            VStack(alignment: .leading, spacing: 3) {
                Text(file.name).font(.system(size: 14, weight: .semibold)).lineLimit(1).truncationMode(.middle)
                Text(file.infoText).font(.system(size: 11)).foregroundStyle(.secondary)
            }
            Spacer()
            trailing
        }
    }
}

// MARK: - Progresso

struct GlassProgressBar: View {
    var value: Double?
    @Environment(\.pageColors) private var colors
    @State private var shimmer = false

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(.primary.opacity(0.08))
                if let value {
                    Capsule()
                        .fill(LinearGradient(colors: [colors[0], colors[1]], startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(6, geo.size.width * value))
                        .shadow(color: colors[0].opacity(0.6), radius: 4)
                        .animation(.easeOut(duration: 0.3), value: value)
                } else {
                    Capsule()
                        .fill(LinearGradient(colors: [.clear, colors[0], colors[1], .clear], startPoint: .leading, endPoint: .trailing))
                        .frame(width: geo.size.width * 0.35)
                        .offset(x: shimmer ? geo.size.width * 0.7 : -geo.size.width * 0.05)
                        .onAppear {
                            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) { shimmer = true }
                        }
                }
            }
        }
        .frame(height: 6)
        .clipShape(Capsule())
    }
}

struct JobRow: View {
    @ObservedObject var job: Job
    var onRemove: (() -> Void)?
    @Environment(\.pageColors) private var colors
    @State private var hover = false

    var body: some View {
        HStack(spacing: 12) {
            statusIcon
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(job.title).font(.system(size: 13, weight: .semibold)).lineLimit(1).truncationMode(.middle)
                    Spacer()
                    if job.status == .running, let p = job.progress {
                        Text("\(Int(p * 100))%").font(.system(size: 12, weight: .bold, design: .rounded).monospacedDigit())
                            .foregroundStyle(colors[0])
                    }
                }
                if job.status.isActive {
                    GlassProgressBar(value: job.status == .finishing ? nil : job.progress)
                }
                HStack(spacing: 6) {
                    Text(job.subtitle)
                    if !statusText.isEmpty { Text("·"); Text(statusText).foregroundStyle(statusColor) }
                }
                .font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(1)
            }
            actions
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(.primary.opacity(hover ? 0.06 : 0.035)))
        .onHover { hover = $0 }
        .contextMenu {
            if let u = job.outputURL { Button("Mostrar no Finder") { Finder.reveal(u) } }
            Button("Abrir pasta de destino") { Finder.open(job.outputDir) }
            if case .download(let s) = job.work {
                Button("Copiar link") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(s.url, forType: .string)
                }
            }
        }
    }

    private var statusText: String {
        switch job.status {
        case .pending: return "Aguardando"
        case .running, .finishing: return job.detail
        case .done: return job.outputURL?.lastPathComponent ?? "Concluído"
        case .failed(let m): return m
        case .cancelled: return "Cancelado"
        }
    }

    private var statusColor: Color {
        switch job.status {
        case .done: return .green
        case .failed: return .red
        default: return .secondary
        }
    }

    @ViewBuilder private var statusIcon: some View {
        Group {
            switch job.status {
            case .pending:
                Image(systemName: job.icon).foregroundStyle(.secondary)
                    .frame(width: 34, height: 34).background(Circle().fill(.primary.opacity(0.07)))
            case .running, .finishing:
                ZStack {
                    Circle().stroke(.primary.opacity(0.1), lineWidth: 3)
                    if let p = job.progress, job.status == .running {
                        Circle().trim(from: 0, to: p)
                            .stroke(LinearGradient(colors: [colors[0], colors[1]], startPoint: .top, endPoint: .bottom),
                                    style: StrokeStyle(lineWidth: 3, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                            .animation(.easeOut(duration: 0.3), value: p)
                    } else {
                        ProgressView().controlSize(.small)
                    }
                    Image(systemName: job.icon).font(.system(size: 11, weight: .semibold)).foregroundStyle(colors[0])
                }
                .frame(width: 34, height: 34)
            case .done:
                Image(systemName: "checkmark").font(.system(size: 13, weight: .heavy)).foregroundStyle(.white)
                    .frame(width: 34, height: 34).background(Circle().fill(Color.green.gradient))
                    .shadow(color: .green.opacity(0.4), radius: 5, y: 2)
            case .failed:
                Image(systemName: "exclamationmark").font(.system(size: 14, weight: .heavy)).foregroundStyle(.white)
                    .frame(width: 34, height: 34).background(Circle().fill(Color.red.gradient))
            case .cancelled:
                Image(systemName: "xmark").font(.system(size: 12, weight: .bold)).foregroundStyle(.secondary)
                    .frame(width: 34, height: 34).background(Circle().fill(.primary.opacity(0.07)))
            }
        }
    }

    @ViewBuilder private var actions: some View {
        HStack(spacing: 6) {
            if job.status.isActive || job.status == .pending {
                IconButton(icon: "xmark", help: "Cancelar") { job.cancel() }
            }
            if case .failed = job.status { IconButton(icon: "arrow.clockwise", help: "Tentar novamente") { job.retry() } }
            if job.status == .cancelled { IconButton(icon: "arrow.clockwise", help: "Tentar novamente") { job.retry() } }
            if let u = job.outputURL, job.status == .done {
                IconButton(icon: "magnifyingglass", help: "Mostrar no Finder") { Finder.reveal(u) }
            }
            if let onRemove, !job.status.isActive {
                IconButton(icon: "trash", help: "Remover", action: onRemove)
            }
        }
    }
}

/// Card com os trabalhos iniciados na própria página.
struct ActivityCard: View {
    @ObservedObject var queue: JobQueue
    var title = "Atividade"

    var body: some View {
        if !queue.jobs.isEmpty {
            GlassCard(title, icon: "bolt.fill", accessory: {
                HStack(spacing: 10) {
                    if queue.jobs.count > 1 {
                        Text("\(queue.doneCount)/\(queue.jobs.count)").font(.system(size: 12, weight: .semibold).monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    if queue.hasFinished {
                        Button("Limpar") { withAnimation { queue.clearFinished() } }
                            .buttonStyle(LiquidButtonStyle(kind: .secondary, compact: true))
                    }
                }
            }) {
                VStack(spacing: 8) {
                    ForEach(queue.jobs) { job in
                        JobRow(job: job) { withAnimation { queue.remove(job) } }
                            .transition(.opacity.combined(with: .scale(scale: 0.97)))
                    }
                }
            }
            .onChange(of: queue.jobs.contains { $0.status == .pending }) { _, hasPending in
                if hasPending && !queue.isRunning { queue.start() }
            }
        }
    }
}

// MARK: - Botões da barra

struct OpenFolderButton: View {
    var folder: () -> URL?
    var body: some View {
        Button { Finder.open(folder()) } label: { Label("Abrir pasta", systemImage: "folder") }
            .buttonStyle(LiquidButtonStyle(kind: .secondary))
    }
}

struct AddToQueueButton: View {
    var count: Int = 1
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            Label(count > 1 ? "Enviar \(count) à fila" : "Enviar à fila", systemImage: "text.badge.plus")
        }
        .buttonStyle(LiquidButtonStyle(kind: .secondary))
    }
}

struct PrimaryButton: View {
    let title: String
    let icon: String
    var action: () -> Void
    var body: some View {
        Button(action: action) { Label(title, systemImage: icon) }
            .buttonStyle(LiquidButtonStyle(kind: .primary))
            .keyboardShortcut(.defaultAction)
    }
}
