import SwiftUI

/// Syllie flying in place while something loads: the `Loading` artboard of `syllie.riv` (wind lines and bob around
/// a nested Syllie running `LoadingFly`). Loops until the view goes away. Decorative only.
struct SyllieLoadingView: View {
    var body: some View {
        SyllieArtboardView(artboard: "Loading", stateMachine: "Loading")
    }
}
