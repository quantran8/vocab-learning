import SwiftUI

struct HomeView: View {
    @Environment(SessionStore.self) private var store
    @Environment(\.motion) private var motion
    @State private var hasAppeared = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                BrandBar()

                badge
                    .padding(.top, Spacing.xl + Spacing.s)

                VStack(alignment: .leading, spacing: 0) {
                    Text("Small steps.")
                        .foregroundStyle(Color.ink)
                    Text("Big words.")
                        .foregroundStyle(Color.primaryAction)
                }
                .font(Typography.display)
                .tracking(-1.6)
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(.isHeader)
                .padding(.top, Spacing.l - 4)

                Text("A few minutes to grow your vocabulary: meet the words, build them into sentences, then recall them.")
                    .font(Typography.body)
                    .foregroundStyle(Color.mutedInk)
                    .lineSpacing(4)
                    .padding(.top, Spacing.m)

                playground
                    .padding(.top, Spacing.xl)

                sessionCard
                    .padding(.top, Spacing.l)
            }
            .padding(.horizontal, Spacing.screenGutter + 4)
            .padding(.top, Spacing.s)
            .padding(.bottom, Spacing.l)
        }
        .safeAreaInset(edge: .bottom) {
            PinnedActionBar {
                VStack(spacing: Spacing.m) {
                    PrimaryButton(title: "Start a flow") {
                        motion.perform(MotionTokens.transition) { store.start() }
                    }
                    Text("No pressure. Just progress. ✨")
                        .font(Typography.micro)
                        .foregroundStyle(Color.mutedInk)
                }
            }
        }
        .onAppear {
            withAnimation(motion.travel(MotionTokens.entrance)) { hasAppeared = true }
        }
    }

    private var badge: some View {
        HStack(spacing: Spacing.xs) {
            Circle()
                .fill(Color.primaryAction)
                .frame(width: 8, height: 8)
            Text("Your daily little win")
        }
        .font(Typography.eyebrow)
        .tracking(0.6)
        .textCase(.uppercase)
        .foregroundStyle(Color.primarySoftInk)
        .padding(.horizontal, Spacing.s)
        .padding(.vertical, Spacing.xs)
        .background(Color.primarySoft, in: Capsule())
    }

    private var playground: some View {
        let terms = store.content.words.map(\.term)
        return ZStack(alignment: .topLeading) {
            DotGrid()

            Eyebrow(text: "Today’s playground", color: .primarySoftInk)
                .padding(Spacing.l - 4)

            ZStack {
                decorativeTile(terms.first ?? "", filled: false)
                    .rotationEffect(.degrees(-12))
                    .offset(x: -62, y: 10)
                decorativeTile(terms.last ?? "", filled: true)
                    .rotationEffect(.degrees(6))
                    .offset(x: 62, y: 10)
                Text(verbatim: "✦")
                    .font(.title3)
                    .foregroundStyle(Color.mint)
                    .offset(x: 12, y: -52)
                Text(verbatim: "✳")
                    .font(.title)
                    .foregroundStyle(Color.coral)
                    .offset(x: -24, y: 64)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .scaleEffect(hasAppeared ? 1 : 0.85)
            .opacity(hasAppeared ? 1 : 0)
        }
        .frame(height: 225)
        .background(Color.primarySoft)
        .clipShape(RoundedRectangle(cornerRadius: Radii.hero, style: .continuous))
        .accessibilityHidden(true)
    }

    private func decorativeTile(_ text: String, filled: Bool) -> some View {
        let shape = RoundedRectangle(cornerRadius: Radii.tile, style: .continuous)
        return Text(verbatim: text)
            .font(.system(.title3, design: .rounded, weight: .heavy))
            .foregroundStyle(filled ? Color.white : Color.primarySoftInk)
            .padding(.horizontal, Spacing.l - 4)
            .padding(.vertical, Spacing.m)
            .background(filled ? Color.primaryAction : Color.surface, in: shape)
            .overlay(shape.strokeBorder(filled ? Color.clear : Color.selectedDepth, lineWidth: 2))
            .background(shape.fill(filled ? Color.primaryDepth : Color.selectedDepth).offset(y: 8))
            .fixedSize()
    }

    private var sessionCard: some View {
        HStack(spacing: Spacing.m) {
            RoundedRectangle(cornerRadius: Radii.tile, style: .continuous)
                .fill(Color.successSurface)
                .frame(width: 48, height: 48)
                .overlay(
                    Image(systemName: "bolt.fill")
                        .font(.title3)
                        .foregroundStyle(Color.successInk)
                )
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text("Business English")
                    .font(Typography.emphasis)
                    .foregroundStyle(Color.ink)
                Text("\(store.totalWords) words · 2–3 min · beginner friendly")
                    .font(Typography.micro)
                    .foregroundStyle(Color.mutedInk)
            }
            Spacer(minLength: 0)
        }
        .padding(Spacing.m)
        .cardSurface(radius: Radii.primaryAction)
        .accessibilityElement(children: .combine)
    }
}
