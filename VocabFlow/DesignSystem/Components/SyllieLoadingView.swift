import RiveRuntime
import SwiftUI

/// Syllie flying in place while something loads: the `Loading` artboard of `syllie.riv` (wind lines and bob around
/// a nested Syllie running `LoadingFly`). Loops until the view goes away. Decorative only.
struct SyllieLoadingView: View {
    @StateObject private var rive = RiveViewModel(
        fileName: "syllie",
        stateMachineName: "Loading",
        fit: .contain,
        artboardName: "Loading"
    )

    var body: some View {
        rive.view()
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}
