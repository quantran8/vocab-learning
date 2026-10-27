import SwiftUI

struct ResultsView: View {
    @Environment(SessionStore.self) private var store
    @Environment(\.motion) private var motion
    @State private var hasAppeared = false

    var body: some View {
        let result = store.result

        ScrollView {
            VStack(spacing: 0) {
                BrandBar()

                hero
                    .padding(.top, Spacing.xl + Spacing.s)

                Eyebrow(text: "Flow complete", color: .primarySoftInk)
                    .padding(.top, Spacing.xl + Spacing.xs)

                Text("Look at you go! 🎉")
                    .font(Typography.display)
                    .tracking(-1.4)
                    .foregroundStyle(Color.ink)
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)
                    .padding(.top, Spacing.s)

                Text("One session isn’t mastery — come back to the words below in a day or two.")
                    .font(Typography.secondary)
                    .foregroundStyle(Color.mutedInk)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .padding(.top, Spacing.m)

                stats(result)
                    .padding(.top, Spacing.xl)

                reviewCard(result)
                    .padding(.top, Spacing.m)
            }
            .padding(.horizontal, Spacing.screenGutter + 4)
            .padding(.top, Spacing.s)
            .padding(.bottom, Spacing.l)
        }
        .safeAreaInset(edge: .bottom) {
            PinnedActionBar {
                VStack(spacing: Spacing.s) {
                    PrimaryButton(title: "Play another round", systemImage: "arrow.clockwise") {
                        motion.perform(MotionTokens.transition) { store.playAgain() }
                    }
                    Button {
                        motion.perform(MotionTokens.transition) { store.restart() }
                    } label: {
                        Text("Back to home")
                            .font(Typography.secondary.weight(.bold))
                            .foregroundStyle(Color.mutedInk)
                            .frame(maxWidth: .infinity, minHeight: Spacing.minTouchTarget)
                    }
                }
            }
        }
        .onAppear {
            withAnimation(motion.travel(MotionTokens.entrance)) { hasAppeared = true }
        }
    }

    private var hero: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 38, style: .continuous)
                .fill(Color.successSurface)
                .frame(width: 128, height: 128)
            Text(verbatim: "✦")
                .font(.system(size: 60))
                .foregroundStyle(Color.mint)
            Text(verbatim: "✳")
                .font(.largeTitle)
                .foregroundStyle(Color.coral)
                .offset(x: 72, y: -48)
            Text(verbatim: "✦")
                .font(.title)
                .foregroundStyle(Color.primaryAction)
                .offset(x: -70, y: 46)
        }
        .scaleEffect(hasAppeared ? 1 : 0.6)
        .opacity(hasAppeared ? 1 : 0)
        .accessibilityHidden(true)
    }

    private func stats(_ result: SessionResult) -> some View {
        let total = result.totalWords
        var items: [(LocalizedStringKey, String, Color)] = [
            ("Recalled without hints", "\(result.unaidedCount)/\(total)", .primaryAction),
            ("Recalled with hints", "\(result.hintedCount)/\(total)", .successInk),
            ("Build completed", "\(result.recognizedCount)/\(total)", .ink),
            ("Total attempts", "\(result.totalAttempts)", .ink),
        ]
        if result.afterRetryCount > 0 {
            items.append(("Recalled after a retry", "\(result.afterRetryCount)/\(total)", .ink))
        }
        if result.notRecalledCount > 0 {
            items.append(("Not recalled yet", "\(result.notRecalledCount)/\(total)", .errorInk))
        }

        return LazyVGrid(columns: [GridItem(.flexible(), spacing: Spacing.s), GridItem(.flexible())], spacing: Spacing.s) {
            ForEach(items.indices, id: \.self) { index in
                statCard(label: items[index].0, value: items[index].1, color: items[index].2)
            }
        }
    }

    private func statCard(label: LocalizedStringKey, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text(verbatim: value)
                .font(Typography.screenTitle.monospacedDigit())
                .foregroundStyle(color)
            Text(label)
                .font(Typography.micro)
                .foregroundStyle(Color.mutedInk)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.l - 4)
        .cardSurface(radius: Radii.tile)
        .accessibilityElement(children: .combine)
    }

    private func reviewCard(_ result: SessionResult) -> some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            Text(result.wordsToReview.isEmpty ? LocalizedStringKey("Nothing to review") : LocalizedStringKey("Words to review"))
                .font(Typography.emphasis)
                .foregroundStyle(Color.primarySoftInk)
                .accessibilityAddTraits(.isHeader)

            if result.wordsToReview.isEmpty {
                Text("You recalled every word on the first try without hints.")
                    .font(Typography.secondary)
                    .foregroundStyle(Color.primarySoftInk)
            }

            ForEach(result.wordsToReview) { word in
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: word.term)
                        .font(Typography.emphasis)
                        .foregroundStyle(Color.ink)
                    Text("Recall \(outcomeText(word.recallOutcome)) · \(word.recallAttemptCount) tries · \(word.hintCount) hints")
                        .font(Typography.micro)
                        .foregroundStyle(Color.primarySoftInk)
                }
                .accessibilityElement(children: .combine)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.m)
        .background(Color.primarySoft, in: RoundedRectangle(cornerRadius: Radii.tile, style: .continuous))
    }

    private func outcomeText(_ outcome: RecallOutcome?) -> String {
        switch outcome {
        case .unaidedRecall: String(localized: "without hints")
        case .hintedRecall: String(localized: "with hints")
        case .recalledAfterRetry: String(localized: "after a retry")
        case .notRecalled, nil: String(localized: "not recalled")
        }
    }
}
