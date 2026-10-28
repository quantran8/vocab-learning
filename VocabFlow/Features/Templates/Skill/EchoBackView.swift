import SwiftUI

/// Self-check only: no recording, no microphone, no pronunciation score.
struct EchoBackView: View {
    let run: TemplateRun
    @Environment(TemplateSandboxStore.self) private var sandbox

    var body: some View {
        TemplateFrame(run: run) {
            VStack(spacing: Spacing.l) {
                VStack(spacing: Spacing.xxs) {
                    Text(verbatim: run.word.term)
                        .font(Typography.challengeTerm)
                        .foregroundStyle(Color.ink)
                    if let ipa = run.word.ipa {
                        Text(verbatim: ipa)
                            .font(Typography.body.weight(.semibold))
                            .foregroundStyle(Color.mutedInk)
                    }
                }

                AudioCuePanel(run: run, fallbackClue: String(localized: "Read the word and its sounds above aloud instead."), isLarge: true)

                VStack(alignment: .leading, spacing: Spacing.s) {
                    step(1, "Listen to the word.", done: run.audioPlayCount > 0 || run.usesAudioFallback)
                    step(2, "Say it out loud, twice.", done: run.phase == .selfChecked)
                    step(3, "Mark it as practised.", done: run.phase == .selfChecked)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Label("Vocab Flow doesn’t record or grade your voice. This is your own check.", systemImage: "info.circle")
                    .font(Typography.micro)
                    .foregroundStyle(Color.mutedInk)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        } action: {
            TemplateActionBar(
                run: run,
                checkTitle: "I said it out loud",
                canCheck: run.canSelfCheck,
                requirement: "Listen first (or use the written clue).",
                onCheck: { sandbox.selfCheck() }
            )
        }
    }

    private func step(_ number: Int, _ text: LocalizedStringKey, done: Bool) -> some View {
        HStack(spacing: Spacing.s) {
            Image(systemName: done ? "checkmark.circle.fill" : "\(number).circle")
                .font(.title3)
                .foregroundStyle(done ? Color.success : Color.mutedInk)
                .accessibilityHidden(true)
            Text(text)
                .font(Typography.body)
                .foregroundStyle(Color.ink)
        }
        .accessibilityElement(children: .combine)
        .accessibilityValue(done ? Text("Done") : Text(verbatim: ""))
    }
}
