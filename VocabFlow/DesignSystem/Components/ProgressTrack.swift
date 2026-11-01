import SwiftUI

/// A single continuous progress bar. `fraction` runs from 0 to 1.
struct ProgressTrack: View {
    let fraction: CGFloat
    @Environment(\.motion) private var motion

    var body: some View {
        Capsule()
            .fill(Color.track)
            .frame(height: 8)
            .overlay(alignment: .leading) {
                GeometryReader { proxy in
                    Capsule()
                        .fill(Color.interactive)
                        .frame(width: proxy.size.width * fraction)
                }
            }
            .clipShape(Capsule())
            .animation(motion.animation(MotionTokens.progress), value: fraction)
    }
}
