import SwiftUI

/// Sheet editing the collection and its topics; the routine is untouched. Dismissing discards the draft.
struct EditFocusView: View {
    let onSave: (LearningPreferences) -> Void
    @Environment(AppSettingsStore.self) private var settings
    @State private var draft: LearningPreferences
    private let initial: LearningPreferences

    init(initial: LearningPreferences, onSave: @escaping (LearningPreferences) -> Void) {
        self.onSave = onSave
        self.initial = initial
        _draft = State(initialValue: initial)
    }

    /// Topics the draft drops that the learner has learned from: their words stay in review.
    private var droppedLearnedTopics: String? {
        let dropped = TopicCatalog.topics(ids: initial.topicIDs.subtracting(draft.topicIDs)).filter { ($0.learned ?? 0) > 0 }
        guard !dropped.isEmpty else { return nil }
        return dropped.map(\.name).formatted(.list(type: .and).locale(AppLanguage.active.locale))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Eyebrow(text: "Learning plan")
                    Spacer()
                    SheetCloseButton()
                }

                PunctuatedTitle(text: "Your focus")
                    .padding(.top, Spacing.xs)
                    .padding(.bottom, Spacing.l - 4)

                VStack(alignment: .leading, spacing: Spacing.l) {
                    VStack(alignment: .leading, spacing: Spacing.s) {
                        PlanSectionTitle(text: "Collection")
                        collectionChips
                    }
                    if let collection = draft.collection {
                        TopicPicker(
                            collection: collection,
                            selectedIDs: draft.topicIDs,
                            onToggleTopic: { id in
                                draft.toggleTopic(id)
                                settings.feedback.selectionChanged()
                            },
                            onToggleAll: {
                                draft.toggleAllTopics()
                                settings.feedback.selectionChanged()
                            }
                        )
                    }
                }
            }
            .padding(.horizontal, Spacing.screenGutter)
            .padding(.top, Spacing.l)
            .padding(.bottom, Spacing.l)
        }
        .safeAreaInset(edge: .bottom) {
            PinnedActionBar {
                VStack(spacing: Spacing.s) {
                    if let dropped = droppedLearnedTopics {
                        Text("Words you learned in \(dropped) will still come back for review so you don’t forget them. They’ll show up less often as you remember them better.")
                            .font(Typography.micro)
                            .foregroundStyle(Color.mutedInk)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if !draft.topicIDs.isEmpty {
                        Text("\(draft.topicIDs.count) topics selected")
                            .font(Typography.micro.weight(.semibold))
                            .foregroundStyle(Color.mutedInk)
                            .contentTransition(.numericText())
                    }
                    PrimaryButton(
                        title: "Save changes",
                        requirement: "Choose at least one topic",
                        isEnabled: draft.isComplete
                    ) {
                        settings.feedback.success()
                        onSave(draft)
                    }
                }
            }
        }
    }

    /// Switching collection clears the topics, since each collection has its own.
    private var collectionChips: some View {
        FlowLayout(spacing: Spacing.xs, lineSpacing: Spacing.xs, alignment: .leading) {
            ForEach(TopicCatalog.collections) { collection in
                TopicChip(
                    title: collection.name,
                    systemImage: collection.systemImage,
                    isSelected: collection.id == draft.collectionID
                ) {
                    guard collection.id != draft.collectionID else { return }
                    draft.selectCollection(collection.id)
                    settings.feedback.selectionChanged()
                }
            }
        }
    }
}
