import SwiftUI

/// Settings test tool: plays Syllie's moods, the loading flight and the end-of-session celebration from `syllie.riv`
/// so they can be checked on a device. Mood names are the Rive enum keys, so they're shown as data.
struct SylliePreviewView: View {
    private enum Mode: Hashable {
        case moods, loading, celebrate
    }

    @Environment(\.dismiss) private var dismiss
    @State private var mood = SyllieMood.idle
    @State private var replays = 0
    @State private var mode = Mode.moods
    @State private var showsConfetti = false

    var body: some View {
        VStack(spacing: Spacing.m) {
            Text("Syllie animations")
                .font(Typography.screenTitle)
                .foregroundStyle(Color.ink)
                .accessibilityAddTraits(.isHeader)

            Picker("Animation", selection: $mode) {
                Text("Moods").tag(Mode.moods)
                Text("Loading").tag(Mode.loading)
                Text("Celebrate").tag(Mode.celebrate)
            }
            .pickerStyle(.segmented)

            // The celebration covers the whole screen (as on the results screen), so it has no card.
            if mode != .celebrate {
                Group {
                    if mode == .loading {
                        SyllieLoadingView()
                            .id(replays)
                    } else {
                        SyllieView(mood: mood, replayToken: replays) { mood = .idle }
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 300)
                .cardSurface(radius: Radii.tile)
            }

            if mode == .moods {
                moodButtons
            }

            Spacer()

            SecondaryButton(title: "Replay") { replays += 1 }
            PrimaryButton(title: "Done") { dismiss() }
        }
        .padding(Spacing.screenGutter)
        .background(Color.canvas)
        .overlay {
            if mode == .celebrate {
                SyllieCelebrationView()
                    .id(replays)
                    .ignoresSafeArea()
            }
        }
        .overlay {
            if mode == .celebrate, showsConfetti {
                ConfettiBurst()
                    .id(replays)
            }
        }
        .task(id: CelebrationRun(mode: mode, replays: replays)) {
            // Same timing as the results screen: confetti as Syllie nears the top of his loop.
            showsConfetti = false
            guard mode == .celebrate else { return }
            do {
                try await Task.sleep(for: SyllieCelebrationView.confettiCue)
            } catch {
                return
            }
            showsConfetti = true
        }
    }

    private struct CelebrationRun: Equatable {
        let mode: Mode
        let replays: Int
    }

    private var moodButtons: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: Spacing.xs)], spacing: Spacing.xs) {
            ForEach(SyllieMood.allCases) { item in
                Button {
                    mood = item
                } label: {
                    Text(verbatim: item.rawValue)
                        .font(Typography.secondary.weight(.bold))
                        .foregroundStyle(item == mood ? Color.canvas : Color.ink)
                        .frame(maxWidth: .infinity, minHeight: 40)
                        .background(item == mood ? Color.ink : Color.neutralSurface, in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(item == mood ? .isSelected : [])
            }
        }
    }
}
