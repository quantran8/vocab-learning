import SwiftUI

/// Curated spelling groups (visual only — not syllables) arrive one by one, then join into one word.
struct ChunkMergeView: View {
    let chunks: [String]
    @State private var isRevealed = false
    @State private var isMerged = false

    var body: some View {
        HStack(spacing: isMerged ? 0 : Spacing.s) {
            ForEach(Array(chunks.enumerated()), id: \.offset) { index, chunk in
                Text(verbatim: chunk)
                    .foregroundStyle(index == 0 && !isMerged ? Color.interactive : Color.ink)
                    .padding(.horizontal, isMerged ? 0 : Spacing.xs)
                    .background {
                        RoundedRectangle(cornerRadius: Radii.chip, style: .continuous)
                            .strokeBorder(Color.stroke, lineWidth: 1.5)
                            .opacity(isMerged ? 0 : 1)
                    }
                    .opacity(isRevealed ? 1 : 0)
                    .offset(y: isRevealed ? 0 : 18)
                    .animation(MotionTokens.introAccent.delay(Double(index) * MotionTokens.introChunkStagger), value: isRevealed)
            }
        }
        .fixedSize()
        .onAppear { isRevealed = true }
        // Join is a separate transaction after the groups have arrived. Decorative only:
        // the task is cancelled on replay, skip or navigation, so a stale join can never run.
        .task {
            let delay = Double(chunks.count) * MotionTokens.introChunkStagger + MotionTokens.introChunkHold
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled else { return }
            withAnimation(MotionTokens.introLetter) { isMerged = true }
        }
    }
}
