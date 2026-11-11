import SwiftUI
import AVKit

@MainActor
final class PlayerHolder: ObservableObject {
    let player: AVPlayer
    @Published var current: Double = 0
    @Published var duration: Double?
    @Published var playable = true
    private var timeObserver: Any?
    private var boundaryObserver: Any?

    init(url: URL, fallbackDuration: Double?) {
        player = AVPlayer(url: url)
        duration = fallbackDuration
        timeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.05, preferredTimescale: 600), queue: .main
        ) { [weak self] t in
            MainActor.assumeIsolated { if t.seconds.isFinite { self?.current = t.seconds } }
        }
        let asset = AVURLAsset(url: url)
        Task {
            let ok = (try? await asset.load(.isPlayable)) ?? false
            self.playable = ok
            if let d = try? await asset.load(.duration).seconds, d.isFinite, d > 0 { self.duration = d }
        }
    }

    func seek(_ s: Double) {
        player.seek(to: CMTime(seconds: s, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero)
        current = s
    }

    func previewRange(_ start: Double, _ end: Double?) {
        if let b = boundaryObserver { player.removeTimeObserver(b); boundaryObserver = nil }
        seek(start)
        if let end {
            boundaryObserver = player.addBoundaryTimeObserver(
                forTimes: [NSValue(time: CMTime(seconds: end, preferredTimescale: 600))], queue: .main
            ) { [weak self] in
                MainActor.assumeIsolated { self?.player.pause() }
            }
        }
        player.play()
    }

    func stop() {
        player.pause()
        if let t = timeObserver { player.removeTimeObserver(t); timeObserver = nil }
        if let b = boundaryObserver { player.removeTimeObserver(b); boundaryObserver = nil }
    }
}

struct PlayerSurface: NSViewRepresentable {
    let player: AVPlayer
    func makeNSView(context: Context) -> AVPlayerView {
        let v = AVPlayerView()
        v.player = player
        v.controlsStyle = .inline
        v.showsFrameSteppingButtons = true
        v.videoGravity = .resizeAspect
        return v
    }
    func updateNSView(_ v: AVPlayerView, context: Context) {
        if v.player !== player { v.player = player }
    }
}

/// Barra de linha do tempo com alças de início/fim arrastáveis.
struct RangeBar: View {
    @Binding var range: TimeRange
    let duration: Double
    let current: Double
    var onSeek: (Double) -> Void

    private var start: Double { range.startSeconds ?? 0 }
    private var end: Double { range.endSeconds ?? duration }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let x = { (t: Double) -> CGFloat in CGFloat(min(max(t / duration, 0), 1)) * w }
            ZStack(alignment: .leading) {
                Capsule().fill(.quaternary).frame(height: 8)
                Rectangle()
                    .fill(Color.accentColor.opacity(0.35))
                    .frame(width: max(x(end) - x(start), 0), height: 8)
                    .offset(x: x(start))
                Rectangle().fill(.primary).frame(width: 2, height: 22).offset(x: x(current) - 1)
                handle(color: .green).offset(x: x(start) - 6)
                    .gesture(DragGesture(coordinateSpace: .named("bar")).onChanged { g in
                        let t = min(max(Double(g.location.x / w) * duration, 0), end - 0.1)
                        range.start = TimeUtils.format(t, showMillis: true)
                        onSeek(t)
                    })
                handle(color: .red).offset(x: x(end) - 6)
                    .gesture(DragGesture(coordinateSpace: .named("bar")).onChanged { g in
                        let t = max(min(Double(g.location.x / w) * duration, duration), start + 0.1)
                        range.end = TimeUtils.format(t, showMillis: true)
                        onSeek(t)
                    })
            }
            .frame(height: 26)
            .contentShape(Rectangle())
            .coordinateSpace(name: "bar")
            .onTapGesture { loc in onSeek(Double(loc.x / w) * duration) }
        }
        .frame(height: 26)
    }

    private func handle(color: Color) -> some View {
        RoundedRectangle(cornerRadius: 3)
            .fill(color.gradient)
            .frame(width: 12, height: 26)
            .shadow(radius: 1, y: 1)
            .contentShape(Rectangle().inset(by: -6))
            .onHover { inside in
                if inside { NSCursor.resizeLeftRight.push() } else { NSCursor.pop() }
            }
    }
}

struct TrimEditor: View {
    @StateObject private var holder: PlayerHolder
    @Binding var range: TimeRange
    var hasVideo: Bool

    init(url: URL, range: Binding<TimeRange>, fallbackDuration: Double?, hasVideo: Bool = true) {
        _holder = StateObject(wrappedValue: PlayerHolder(url: url, fallbackDuration: fallbackDuration))
        _range = range
        self.hasVideo = hasVideo
    }

    var body: some View {
        VStack(spacing: 12) {
            if holder.playable {
                PlayerSurface(player: holder.player)
                    .frame(minHeight: hasVideo ? 280 : 60, maxHeight: hasVideo ? 420 : 60)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            } else {
                Label("Pré-visualização indisponível para este formato. Digite os tempos manualmente.",
                      systemImage: "eye.slash")
                    .font(.callout).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if let d = holder.duration, d > 0 {
                RangeBar(range: $range, duration: d, current: holder.current) { holder.seek($0) }
                    .padding(.horizontal, 6)
                HStack {
                    Text("00:00").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                    Spacer()
                    Text(TimeUtils.format(holder.current, showMillis: true))
                        .font(.callout.monospacedDigit().weight(.medium))
                    Spacer()
                    Text(TimeUtils.format(d)).font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                }
            }

            if holder.playable {
                HStack(spacing: 8) {
                    Button {
                        range.start = TimeUtils.format(holder.current, showMillis: true)
                    } label: { Label("Marcar início", systemImage: "arrow.right.to.line") }
                    Button {
                        range.end = TimeUtils.format(holder.current, showMillis: true)
                    } label: { Label("Marcar fim", systemImage: "arrow.left.to.line") }
                    Spacer()
                    Button {
                        holder.previewRange(range.startSeconds ?? 0, range.endSeconds)
                    } label: { Label("Ouvir/ver trecho", systemImage: "play.circle") }
                    .disabled(!range.isActive)
                }
            }
        }
        .padding(.vertical, 6)
        .onDisappear { holder.stop() }
    }
}
