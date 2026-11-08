import SwiftUI

/// A speaker with three sound waves. While `isPlaying` the waves cycle 1 → 2 → 3 → 1 …; at rest all three show.
/// When playback stops mid-cycle the waves keep stepping at the same pace until all three are back, so the icon
/// never freezes on a partial cycle. With reduced motion the waves stay put. Decorative: the host labels it.
struct SpeakerWaveIcon: View {
    let isPlaying: Bool
    var side: CGFloat = 28

    @Environment(\.motion) private var motion
    @State private var visibleWaves = 3

    /// Where the waves come out of the cone, in unit space.
    private static let source = UnitPoint(x: 0.46, y: 0.5)
    private static let waveRadii: [CGFloat] = [0.14, 0.27, 0.40]

    var body: some View {
        ZStack {
            SpeakerBody().fill()
            SpeakerBody().stroke(style: StrokeStyle(lineWidth: side * 0.06, lineJoin: .round))
            ForEach(Self.waveRadii.indices, id: \.self) { index in
                let isShown = index < visibleWaves
                SpeakerWave(center: Self.source, radius: Self.waveRadii[index])
                    .stroke(style: StrokeStyle(lineWidth: side * 0.075, lineCap: .round))
                    .opacity(isShown ? 1 : 0)
                    .scaleEffect(isShown ? 1 : 0.7, anchor: Self.source)
            }
        }
        .frame(width: side, height: side)
        .accessibilityHidden(true)
        // A new id cancels the previous loop; the stopping loop picks up from wherever the cycle is.
        .task(id: isPlaying) {
            if isPlaying {
                await cycle()
            } else {
                await finishCycle()
            }
        }
    }

    /// Steps the waves forever, starting right away so the tap gets instant feedback.
    private func cycle() async {
        guard !motion.reduceMotion else { return }
        while true {
            step()
            do { try await Task.sleep(for: .seconds(MotionTokens.speakerWaveStep)) } catch { return }
        }
    }

    /// Keeps stepping at the cycle's pace until all three waves show, then rests.
    private func finishCycle() async {
        while visibleWaves < Self.waveRadii.count {
            do { try await Task.sleep(for: .seconds(MotionTokens.speakerWaveStep)) } catch { return }
            step()
        }
    }

    private func step() {
        motion.perform(MotionTokens.speakerWave) {
            visibleWaves = visibleWaves >= Self.waveRadii.count ? 1 : visibleWaves + 1
        }
    }
}

/// The speaker box and cone, drawn in the left half of a unit square.
private struct SpeakerBody: Shape {
    func path(in rect: CGRect) -> Path {
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x * rect.width, y: rect.minY + y * rect.height)
        }
        var path = Path()
        path.move(to: point(0.08, 0.37))
        path.addLine(to: point(0.24, 0.37))
        path.addLine(to: point(0.44, 0.2))
        path.addLine(to: point(0.44, 0.8))
        path.addLine(to: point(0.24, 0.63))
        path.addLine(to: point(0.08, 0.63))
        path.closeSubpath()
        return path
    }
}

/// One sound wave: a 90° arc around `center`, `radius` in unit space.
private struct SpeakerWave: Shape {
    let center: UnitPoint
    let radius: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addArc(
            center: CGPoint(x: rect.minX + center.x * rect.width, y: rect.minY + center.y * rect.height),
            radius: radius * rect.width,
            startAngle: .degrees(-45),
            endAngle: .degrees(45),
            clockwise: false
        )
        return path
    }
}

#Preview {
    @Previewable @State var isPlaying = false
    VStack(spacing: 24) {
        SpeakerWaveIcon(isPlaying: isPlaying, side: 64)
            .foregroundStyle(Color.selectedInk)
        // Preview-only control, kept out of the string catalog.
        Button { isPlaying.toggle() } label: { Text(verbatim: isPlaying ? "Pause" : "Play") }
    }
}
