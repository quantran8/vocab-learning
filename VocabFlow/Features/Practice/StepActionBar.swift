import SwiftUI

/// A step's pinned bottom bar, handed to the flow so it stays put while steps slide.
/// `step` picks the newest bar while the outgoing and incoming steps are both on screen.
struct StepActionBar {
    let step: Int
    let view: AnyView
}

struct StepActionBarKey: PreferenceKey {
    static let defaultValue: StepActionBar? = nil

    static func reduce(value: inout StepActionBar?, nextValue: () -> StepActionBar?) {
        guard let next = nextValue() else { return }
        if value == nil || next.step >= value!.step {
            value = next
        }
    }
}

private struct StepActionBarHostKey: EnvironmentKey {
    static let defaultValue: Int? = nil
}

extension EnvironmentValues {
    /// Set by a flow that pins step bars itself (`hostsStepActionBar()`): the index of the step being drawn.
    var stepActionBarHost: Int? {
        get { self[StepActionBarHostKey.self] }
        set { self[StepActionBarHostKey.self] = newValue }
    }
}

extension View {
    /// Pins `bar` to the bottom. Inside a hosting flow the flow draws it outside the step transition;
    /// anywhere else (Practice Lab) it's a plain bottom safe-area inset.
    func stepActionBar<Bar: View>(@ViewBuilder _ bar: () -> Bar) -> some View {
        modifier(StepActionBarModifier(bar: bar()))
    }

    /// Draws the bar of the newest step below `self`, outside any transition applied to the steps.
    func hostsStepActionBar() -> some View {
        modifier(StepActionBarHost())
    }
}

private struct StepActionBarModifier<Bar: View>: ViewModifier {
    let bar: Bar
    @Environment(\.stepActionBarHost) private var step

    func body(content: Content) -> some View {
        if let step {
            content.preference(key: StepActionBarKey.self, value: StepActionBar(step: step, view: AnyView(bar)))
        } else {
            content.safeAreaInset(edge: .bottom) { bar }
        }
    }
}

private struct StepActionBarHost: ViewModifier {
    @State private var barHeight: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .safeAreaPadding(.bottom, barHeight)
            .overlayPreferenceValue(StepActionBarKey.self, alignment: .bottom) { bar in
                bar?.view
                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { barHeight = $0 }
            }
    }
}
