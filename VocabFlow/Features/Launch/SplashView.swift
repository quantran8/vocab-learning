import SwiftUI

/// First screen on launch: Syllie idling with the wordmark below. `AppRootView` keeps it up for at least
/// `MotionTokens.splashHold` and until the account has loaded, so no loading screen flashes in between.
///
/// Syllie sits exactly where the static launch screen draws `LaunchSyllieV2` (centred on the full screen, body
/// 169 pt wide, image 175×130 pt centred on the body), so the hand-off from the launch screen doesn't jump.
struct SplashView: View {
    var body: some View {
        SyllieView(mood: .idle)
            // `Syllie` artboard (520×430) at the scale that makes the body as wide as `LaunchSyllieV2`.
            .frame(width: 217, height: 179)
            // The body isn't centred in the artboard: move it onto the screen centre.
            .offset(x: 4.5, y: -17.6)
            .overlay {
                Text(verbatim: "syll")
                    .font(Typography.display)
                    .tracking(Typography.tightTracking)
                    .foregroundStyle(Color.ink)
                    .fixedSize()
                    .offset(y: 120)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .ignoresSafeArea()
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(verbatim: "Syll"))
    }
}

#Preview {
    SplashView()
        .background(Color.canvas)
}
