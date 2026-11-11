import SwiftUI

/// Offered from Home when many learned words wait for review. Three equal choices: none is pushed.
/// Any way out of the sheet counts as seen (the caller acknowledges it on dismiss).
struct ReviewLoadChoiceSheet: View {
    let load: ReviewLoad
    /// The learner's daily goal; a temporary value goes from 1 to one below it.
    let goal: Int
    let onExtraReview: () -> Void
    let onLower: (_ value: Int, _ mode: NewWordOverrideMode) async throws -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(AppSettingsStore.self) private var settings
    @Environment(\.motion) private var motion
    @State private var isPickingLower = false
    @State private var value: Int
    @State private var mode = NewWordOverrideMode.untilDate
    @State private var isSaving = false
    @State private var error: String?

    init(load: ReviewLoad, goal: Int, onExtraReview: @escaping () -> Void,
         onLower: @escaping (_ value: Int, _ mode: NewWordOverrideMode) async throws -> Void) {
        self.load = load
        self.goal = goal
        self.onExtraReview = onExtraReview
        self.onLower = onLower
        _value = State(initialValue: max(1, min(goal - 1, Int((Double(goal) / 2).rounded()))))
    }

    /// While the checkpoint gate holds, Daily has no new words to lower.
    private var canLower: Bool { goal > 1 && load.newWordReason != .checkpointGate }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Eyebrow(text: "Review")
                    Spacer()
                    SheetCloseButton()
                }

                Text("You have \(load.backlog) learned words waiting for review.")
                    .font(Typography.screenTitle)
                    .tracking(Typography.tightTracking)
                    .foregroundStyle(Color.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                    .padding(.top, Spacing.xs)

                Text("Each session reviews \(load.dueCap) words, so some words will come back later than planned and are easier to forget.")
                    .font(Typography.body)
                    .foregroundStyle(Color.mutedInk)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, Spacing.s)

                VStack(spacing: Spacing.s) {
                    SecondaryButton(title: "Keep learning as usual") { dismiss() }
                    SecondaryButton(title: "Review one more session") {
                        dismiss()
                        onExtraReview()
                    }
                    if canLower {
                        SecondaryButton(title: "Fewer new words for now") {
                            motion.perform(MotionTokens.snap) { isPickingLower.toggle() }
                        }
                    }
                }
                .padding(.top, Spacing.l)

                if isPickingLower {
                    lowerPicker
                        .padding(.top, Spacing.l)
                        .transition(.opacity)
                }
            }
            .padding(.horizontal, Spacing.screenGutter)
            .padding(.top, Spacing.l)
            .padding(.bottom, Spacing.l)
        }
    }

    private var lowerPicker: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            PlanSectionTitle(text: "New words per session")
            Stepper(value: $value, in: 1...max(1, goal - 1)) {
                Text("\(value) new words")
                    .font(Typography.emphasis)
                    .foregroundStyle(Color.ink)
            }

            PlanSectionTitle(text: "For how long")
            VStack(spacing: Spacing.xs) {
                durationRow(.untilDate, title: "Until the end of Sunday")
                durationRow(.untilBacklogClear, title: "Until 10 or fewer words are waiting")
            }

            if let error {
                Text(verbatim: error)
                    .font(Typography.micro)
                    .foregroundStyle(Color.mutedInk)
            }

            PrimaryButton(title: "Lower new words", isEnabled: !isSaving) {
                Task { await save() }
            }
        }
        .padding(Spacing.m)
        .cardSurface(radius: Radii.card - 2)
    }

    private func durationRow(_ option: NewWordOverrideMode, title: LocalizedStringKey) -> some View {
        Button {
            mode = option
            settings.feedback.selectionChanged()
        } label: {
            HStack {
                Text(title)
                    .font(Typography.secondary.weight(.semibold))
                    .foregroundStyle(Color.ink)
                    .multilineTextAlignment(.leading)
                Spacer()
                Image(systemName: mode == option ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(mode == option ? Color.interactive : Color.stroke)
                    .accessibilityHidden(true)
            }
            .frame(minHeight: Spacing.minTouchTarget)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressScaleButtonStyle())
        .accessibilityAddTraits(mode == option ? .isSelected : [])
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }
        do {
            try await onLower(value, mode)
            settings.feedback.success()
            dismiss()
        } catch {
            self.error = error.asAPIError.userMessage
        }
    }
}
