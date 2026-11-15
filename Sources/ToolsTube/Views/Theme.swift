import SwiftUI
import AppKit

// MARK: - Cores por aba

extension MainTab {
    var colors: [Color] {
        switch self {
        case .download: return [Color(red: 0.16, green: 0.48, blue: 1.00), Color(red: 0.35, green: 0.35, blue: 1.00), Color(red: 0.10, green: 0.78, blue: 1.00)]
        case .convert: return [Color(red: 1.00, green: 0.55, blue: 0.10), Color(red: 1.00, green: 0.36, blue: 0.22), Color(red: 1.00, green: 0.78, blue: 0.20)]
        case .cut: return [Color(red: 0.12, green: 0.78, blue: 0.42), Color(red: 0.05, green: 0.62, blue: 0.55), Color(red: 0.55, green: 0.88, blue: 0.25)]
        }
    }
    var tint: Color { colors[0] }
}

private struct PageTintKey: EnvironmentKey { static let defaultValue: [Color] = MainTab.download.colors }
extension EnvironmentValues {
    var pageColors: [Color] {
        get { self[PageTintKey.self] }
        set { self[PageTintKey.self] = newValue }
    }
}

// MARK: - Vidro

/// Vidro feito à mão para macOS anterior ao 26.
private struct FallbackGlass<S: Shape>: ViewModifier {
    let shape: S
    let tint: Color?
    let elevated: Bool
    @Environment(\.colorScheme) private var scheme

    func body(content: Content) -> some View {
        let dark = scheme == .dark
        content
            .background {
                ZStack {
                    shape.fill(.ultraThinMaterial)
                    shape.fill(LinearGradient(
                        colors: [.white.opacity(dark ? 0.10 : 0.50), .white.opacity(dark ? 0.02 : 0.15)],
                        startPoint: .top, endPoint: .bottom))
                    if let tint { shape.fill(tint.opacity(dark ? 0.16 : 0.10)) }
                }
                .compositingGroup()
                .shadow(color: .black.opacity(elevated ? (dark ? 0.40 : 0.12) : 0), radius: 22, y: 10)
            }
            .overlay {
                shape.stroke(LinearGradient(
                    colors: [.white.opacity(dark ? 0.38 : 0.95), .white.opacity(dark ? 0.04 : 0.30), .white.opacity(dark ? 0.16 : 0.60)],
                    startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
                    .allowsHitTesting(false)
            }
    }
}

extension View {
    /// Liquid Glass nativo no macOS 26+, vidro simulado nas versões anteriores.
    @ViewBuilder
    func glass<S: Shape>(_ shape: S, tint: Color? = nil, interactive: Bool = false, elevated: Bool = true) -> some View {
        if #available(macOS 26.0, *) {
            self.glassEffect(Self.makeGlass(tint: tint, interactive: interactive), in: shape)
        } else {
            self.modifier(FallbackGlass(shape: shape, tint: tint, elevated: elevated))
        }
    }

    @available(macOS 26.0, *)
    private static func makeGlass(tint: Color?, interactive: Bool) -> Glass {
        var g = Glass.regular
        if let tint { g = g.tint(tint.opacity(0.35)) }
        if interactive { g = g.interactive() }
        return g
    }

    func glassCard(radius: CGFloat = 24) -> some View {
        glass(RoundedRectangle(cornerRadius: radius, style: .continuous))
    }
}

// MARK: - Fundo aurora

struct VisualEffectBackground: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .underWindowBackground
    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material = material
        v.blendingMode = .behindWindow
        v.state = .followsWindowActiveState
        return v
    }
    func updateNSView(_ v: NSVisualEffectView, context: Context) { v.material = material }
}

struct AuroraBackground: View {
    let colors: [Color]
    @Environment(\.colorScheme) private var scheme
    @State private var phase = false

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            let dark = scheme == .dark
            ZStack {
                VisualEffectBackground()
                (dark ? Color.black.opacity(0.45) : Color.white.opacity(0.35))
                ZStack {
                    blob(colors[0], size: w * 0.55)
                        .offset(x: phase ? -w * 0.20 : -w * 0.30, y: phase ? -h * 0.30 : -h * 0.15)
                    blob(colors[1], size: w * 0.50)
                        .offset(x: phase ? w * 0.32 : w * 0.20, y: phase ? h * 0.05 : -h * 0.25)
                    blob(colors[2], size: w * 0.45)
                        .offset(x: phase ? w * 0.00 : w * 0.12, y: phase ? h * 0.38 : h * 0.30)
                }
                .opacity(dark ? 0.75 : 0.55)
            }
            .frame(width: w, height: h)
            .animation(.easeInOut(duration: 0.9), value: colors)
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.easeInOut(duration: 16).repeatForever(autoreverses: true)) { phase = true }
        }
    }

    private func blob(_ c: Color, size: CGFloat) -> some View {
        Circle()
            .fill(RadialGradient(colors: [c, c.opacity(0.45), c.opacity(0)], center: .center,
                                 startRadius: 0, endRadius: size * 0.75))
            .frame(width: size * 1.5, height: size * 1.5)
    }
}

// MARK: - Botões

struct LiquidButtonStyle: ButtonStyle {
    enum Kind { case primary, secondary, destructive, plain }
    var kind: Kind = .secondary
    var compact = false
    @Environment(\.pageColors) private var colors
    @Environment(\.isEnabled) private var enabled

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        configuration.label
            .font(.system(size: compact ? 12 : 13, weight: .semibold))
            .labelStyle(TightLabelStyle())
            .padding(.horizontal, compact ? 12 : 18)
            .padding(.vertical, compact ? 6 : 10)
            .foregroundStyle(kind == .primary ? AnyShapeStyle(.white) : kind == .destructive ? AnyShapeStyle(.red) : AnyShapeStyle(.primary))
            .background { background }
            .contentShape(Capsule())
            .scaleEffect(pressed ? 0.95 : 1)
            .brightness(pressed ? -0.05 : 0)
            .opacity(enabled ? 1 : 0.42)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: pressed)
    }

    @ViewBuilder private var background: some View {
        switch kind {
        case .primary:
            Capsule()
                .fill(LinearGradient(colors: [colors[0], colors[1]], startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay(Capsule().fill(LinearGradient(colors: [.white.opacity(0.35), .clear], startPoint: .top, endPoint: .center)))
                .overlay(Capsule().stroke(.white.opacity(0.45), lineWidth: 1))
                .shadow(color: colors[0].opacity(enabled ? 0.5 : 0), radius: 12, y: 5)
        case .plain:
            EmptyView()
        default:
            Color.clear.glass(Capsule(), interactive: true, elevated: false)
        }
    }
}

struct TightLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 6) { configuration.icon; configuration.title }
    }
}

struct IconButton: View {
    let icon: String
    var help = ""
    var tint: Color? = nil
    let action: () -> Void
    @State private var hover = false

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(tint ?? .secondary)
                .frame(width: 26, height: 26)
                .background(Circle().fill(.primary.opacity(hover ? 0.12 : 0.06)))
        }
        .buttonStyle(.plain)
        .help(help)
        .onHover { hover = $0 }
    }
}

// MARK: - Janela

/// Configura a janela: barra de título transparente e conteúdo sob ela.
struct WindowConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let v = NSView()
        DispatchQueue.main.async {
            guard let w = v.window else { return }
            w.titlebarAppearsTransparent = true
            w.titleVisibility = .hidden
            w.styleMask.insert(.fullSizeContentView)
            w.isOpaque = false
            w.backgroundColor = .clear
        }
        return v
    }
    func updateNSView(_ nsView: NSView, context: Context) {}
}

/// Área que permite arrastar a janela.
struct WindowDragArea: NSViewRepresentable {
    final class DragView: NSView {
        override func mouseDown(with event: NSEvent) {
            if event.clickCount == 2 { window?.performZoom(nil) } else { window?.performDrag(with: event) }
        }
    }
    func makeNSView(context: Context) -> NSView { DragView() }
    func updateNSView(_ nsView: NSView, context: Context) {}
}
