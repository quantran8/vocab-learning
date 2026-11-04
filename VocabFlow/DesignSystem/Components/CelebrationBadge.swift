import Lottie
import SwiftUI

/// End-of-session mark: a thick yellow badge that pops in. Decorative only.
struct CelebrationBadge: View {
    @Environment(\.motion) private var motion
    @State private var hasAppeared = false

    var body: some View {
        Image(systemName: "checkmark")
            .font(.system(.largeTitle, weight: .heavy))
            .foregroundStyle(Color.ink)
            .frame(width: 96, height: 96)
            .background(Color.reward, in: Circle())
            .background(Circle().fill(Color.rewardDepth).offset(y: Spacing.buttonDepth))
            .padding(.bottom, Spacing.buttonDepth)
            .scaleEffect(hasAppeared || motion.reduceMotion ? 1 : 0.6)
            .animation(motion.travel(MotionTokens.entrance), value: hasAppeared)
            .accessibilityHidden(true)
            .onAppear { hasAppeared = true }
    }
}

/// Loops `Confetti.lottie` over the screen, showing the whole animation. Never plays with reduced motion.
struct ConfettiBurst: View {
    @Environment(\.motion) private var motion

    var body: some View {
        if !motion.reduceMotion {
            LottieView { () async throws -> DotLottieFile? in
                try await DotLottieFile.named("Confetti")
            }
            .looping()
            .resizable()
            .configure { $0.contentMode = .scaleAspectFit }
            .ignoresSafeArea()
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }
}
