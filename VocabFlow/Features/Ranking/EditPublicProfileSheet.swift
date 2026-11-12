import SwiftUI

/// Username and avatar shown on the leaderboard. Never derived from the email (spec §5).
struct EditPublicProfileSheet: View {
    @Environment(RankingStore.self) private var ranking
    @Environment(LearnerStore.self) private var learner
    @Environment(\.dismiss) private var dismiss
    @State private var username = ""
    @State private var avatarKey = ""
    @State private var error: String?
    @State private var isSaving = false
    @FocusState private var isEditingName: Bool

    /// The server's rule, checked here only to enable Save; the server decides.
    static func isWellFormed(_ name: String) -> Bool {
        name.wholeMatch(of: /[a-z][a-z0-9_.]{2,19}/) != nil && !name.contains("..")
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.m) {
                HStack {
                    PunctuatedTitle(text: "Your public profile", font: Typography.screenTitle)
                    Spacer(minLength: Spacing.xs)
                    SheetCloseButton()
                }
                Text("Only shown on the leaderboard if you join it. Your email is never shown.")
                    .font(Typography.secondary)
                    .foregroundStyle(Color.mutedInk)
                    .fixedSize(horizontal: false, vertical: true)

                LabeledField("Name") {
                    TextField("Name", text: $username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .textContentType(.username)
                        .focused($isEditingName)
                        .submitLabel(.done)
                        .onSubmit(save)
                }
                nameHint

                Eyebrow(text: "Avatar")
                    .padding(.top, Spacing.xs)
                avatarGrid

                if let error {
                    Text(verbatim: error)
                        .font(Typography.secondary)
                        .foregroundStyle(Color.errorInk)
                        .fixedSize(horizontal: false, vertical: true)
                }
                PrimaryButton(title: "Save", isEnabled: canSave, action: save)
                    .padding(.top, Spacing.xs)
                if isSaving {
                    ProgressView().frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, Spacing.screenGutter)
            .padding(.top, Spacing.m)
            .padding(.bottom, Spacing.l)
        }
        .scrollDismissesKeyboard(.interactively)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationBackground(Color.canvas)
        .onAppear {
            username = learner.profile?.username ?? ""
            avatarKey = learner.profile?.avatarKey ?? ""
        }
        .task { await ranking.loadMeta() }
    }

    private var canonicalName: String { username.trimmingCharacters(in: .whitespaces).lowercased() }
    private var nameChanged: Bool { canonicalName != learner.profile?.username }
    private var nameLocked: Bool { learner.profile?.usernameChangeAvailableAt != nil }

    private var canSave: Bool {
        guard !isSaving else { return false }
        let avatarChanged = !avatarKey.isEmpty && avatarKey != learner.profile?.avatarKey
        if nameChanged { return !nameLocked && Self.isWellFormed(canonicalName) }
        return avatarChanged
    }

    @ViewBuilder
    private var nameHint: some View {
        Group {
            if let date = learner.profile?.usernameChangeAvailableAt {
                Text("You can change your name again on \(date.formatted(.dateTime.day().month(.wide).locale(AppLanguage.active.locale)))")
            } else {
                Text("3–20 letters, numbers, “_” or “.”, starting with a letter.")
            }
        }
        .font(Typography.micro)
        .foregroundStyle(Color.mutedInk)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var avatarGrid: some View {
        let keys = ranking.avatarKeys.isEmpty ? [avatarKey].filter { !$0.isEmpty } : ranking.avatarKeys
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Spacing.s), count: 4), spacing: Spacing.s) {
            ForEach(keys, id: \.self) { key in
                Button {
                    avatarKey = key
                } label: {
                    AvatarView(key: key, size: 56)
                        .padding(Spacing.xxs)
                        .overlay(
                            Circle().strokeBorder(Color.interactive, lineWidth: 3).opacity(key == avatarKey ? 1 : 0)
                        )
                }
                .buttonStyle(PressScaleButtonStyle())
                .accessibilityLabel(Text("Avatar \((keys.firstIndex(of: key) ?? 0) + 1)"))
                .accessibilityAddTraits(key == avatarKey ? .isSelected : [])
            }
        }
    }

    private func save() {
        guard canSave else { return }
        isEditingName = false
        isSaving = true
        error = nil
        let name = nameChanged ? canonicalName : nil
        let avatar = avatarKey != learner.profile?.avatarKey ? avatarKey : nil
        Task {
            defer { isSaving = false }
            do {
                _ = try await ranking.updateProfile(username: name, avatarKey: avatar)
                dismiss()
            } catch {
                self.error = error.asAPIError.userMessage
            }
        }
    }
}
