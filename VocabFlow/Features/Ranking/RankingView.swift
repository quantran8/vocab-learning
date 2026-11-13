import SwiftUI

/// Weekly leaderboard (spec §4, §10). This week's LP and rank stay apart from the lifetime Tier,
/// and nothing here pressures: no "falling behind", no timer on Home, no rank on the session results.
struct RankingView: View {
    @Environment(RankingStore.self) private var ranking
    @Environment(LearnerStore.self) private var learner
    @Environment(\.motion) private var motion
    @State private var view: LeaderboardView = .top
    @State private var showsIntro = false
    @State private var isEditingProfile = false
    @State private var reportTarget: LeaderboardRow?
    @State private var notice: String?
    @State private var showsLPInfo = false

    private var isVisible: Bool { learner.profile?.settings.leaderboardVisible ?? false }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.l) {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    PunctuatedTitle(text: "Weekly ranking")
                    if let mine = ranking.mine {
                        Text(verbatim: weekSubtitle(mine))
                            .font(Typography.secondary)
                            .foregroundStyle(Color.mutedInk)
                    }
                }
                if let mine = ranking.mine {
                    statsCard(mine)
                } else if ranking.isLoading {
                    ProgressView().frame(maxWidth: .infinity)
                }
                if let error = ranking.error {
                    message(Text(verbatim: error))
                }
                if ranking.isBoardClosed {
                    closedCard
                } else if ranking.mine != nil {
                    if !isVisible { joinCard }
                    board
                }
                if let notice {
                    message(Text(verbatim: notice))
                }
            }
            .padding(.horizontal, Spacing.screenGutter)
            .padding(.top, Spacing.l)
            .padding(.bottom, Spacing.l)
        }
        .background(Color.canvas)
        .refreshable { await ranking.refreshRanking() }
        .task {
            await ranking.refreshRanking()
            if learner.profile?.rankingIntroSeen == false, !ranking.isBoardClosed { showsIntro = true }
        }
        .sheet(isPresented: $showsIntro) {
            RankingIntroSheet { isEditingProfile = true }
        }
        .sheet(isPresented: $isEditingProfile) {
            EditPublicProfileSheet()
        }
        .confirmationDialog(
            Text("Report \(reportTarget?.username ?? "")?"),
            isPresented: Binding(get: { reportTarget != nil }, set: { if !$0 { reportTarget = nil } }),
            titleVisibility: .visible,
            presenting: reportTarget
        ) { row in
            ForEach(ranking.reportReasons) { reason in
                Button(reason.title) { report(row, reason) }
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    // MARK: This week

    /// "09–15/11 · Resets Monday, 07:00": the ISO week in UTC, the reset in device time.
    private func weekSubtitle(_ mine: MyRanking) -> String {
        let locale = AppLanguage.active.locale
        let reset = mine.weekEndsAt.formatted(.dateTime.weekday(.wide).hour().minute().locale(locale))
        guard let range = WeekLabel.range(mine.weekStart) else {
            return String(localized: "Resets \(reset)", bundle: .appLanguage)
        }
        return String(localized: "\(range) · Resets \(reset)", bundle: .appLanguage)
    }

    private func statsCard(_ mine: MyRanking) -> some View {
        HStack(alignment: .top, spacing: 0) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                positionValue(mine)
                    .frame(minHeight: 44, alignment: .bottomLeading)
                Text(mine.position?.kind == .percentile ? "Estimated" : "Weekly rank")
                    .font(Typography.micro)
                    .foregroundStyle(Color.mutedInk)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)

            Rectangle()
                .fill(Color.stroke)
                .frame(width: 1)
                .padding(.horizontal, Spacing.m)

            VStack(alignment: .leading, spacing: Spacing.xs) {
                HStack(alignment: .firstTextBaseline, spacing: Spacing.xxs) {
                    Text(mine.weeklyLP, format: .number.locale(AppLanguage.active.locale))
                        .font(Typography.display.monospacedDigit())
                    Text(verbatim: "LP")
                        .font(Typography.emphasis.weight(.heavy))
                }
                .foregroundStyle(Color.ink)
                .frame(minHeight: 44, alignment: .bottomLeading)
                .accessibilityElement(children: .combine)
                HStack(spacing: Spacing.xs) {
                    Text("LP this week")
                        .font(Typography.micro)
                        .foregroundStyle(Color.mutedInk)
                    lpInfoButton
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(.horizontal, Spacing.m + 2)
        .padding(.vertical, Spacing.l - 2)
        .cardSurface(radius: Radii.card)
    }

    @ViewBuilder
    private func positionValue(_ mine: MyRanking) -> some View {
        switch mine.position?.kind {
        case .rank?:
            if let rank = mine.position?.rank {
                HStack(alignment: .firstTextBaseline, spacing: Spacing.xxs) {
                    Text(verbatim: "#\(rank)")
                        .font(Typography.display.monospacedDigit())
                        .foregroundStyle(Color.ink)
                    if let total = mine.totalListed, total >= rank {
                        Text(verbatim: "/ \(total)")
                            .font(Typography.emphasis.weight(.semibold).monospacedDigit())
                            .foregroundStyle(Color.mutedInk)
                    }
                }
            } else {
                noPosition
            }
        case .percentile?:
            if let percentile = mine.position?.percentile {
                Text("About top \(percentText(percentile))")
                    .font(Typography.screenTitle)
                    .foregroundStyle(Color.ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
            } else {
                noPosition
            }
        default:
            noPosition
        }
    }

    private var noPosition: some View {
        Text(verbatim: "–")
            .font(Typography.display)
            .foregroundStyle(Color.mutedInk)
            .accessibilityLabel(Text("Not on the board"))
    }

    private var lpInfoButton: some View {
        Button {
            showsLPInfo = true
        } label: {
            Text(verbatim: "?")
                .font(Typography.micro.weight(.heavy))
                .foregroundStyle(Color.mutedInk)
                .frame(width: 22, height: 22)
                .background(Color.neutralSurface, in: Circle())
                .frame(minWidth: Spacing.minTouchTarget, minHeight: Spacing.minTouchTarget, alignment: .leading)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.vertical, -Spacing.s)
        .accessibilityLabel(Text("About LP"))
        .popover(isPresented: $showsLPInfo) {
            Text("You earn LP by learning new words, reviewing words when they’re due and practising extra. Right and wrong answers earn the same. Weekly LP starts again every Monday.")
                .font(Typography.secondary)
                .foregroundStyle(Color.ink)
                .fixedSize(horizontal: false, vertical: true)
                .padding(Spacing.m)
                .frame(width: 280, alignment: .leading)
                .presentationCompactAdaptation(.popover)
        }
    }

    private func percentText(_ value: Int) -> String {
        (Double(value) / 100).formatted(.percent.precision(.fractionLength(0)).locale(AppLanguage.active.locale))
    }

    // MARK: Board

    private var closedCard: some View {
        message(Text("The leaderboard opens soon. Your LP and Tier already count."))
    }

    private var joinCard: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            Text("You’re not on the leaderboard")
                .font(Typography.emphasis)
                .foregroundStyle(Color.ink)
            Text("If you join, your name, avatar, Tier and LP this week are public.")
                .font(Typography.secondary)
                .foregroundStyle(Color.mutedInk)
                .fixedSize(horizontal: false, vertical: true)
            PrimaryButton(title: "Join the leaderboard") { setVisible(true) }
        }
        .padding(Spacing.m)
        .cardSurface(radius: Radii.card)
    }

    private var board: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            Picker("Leaderboard", selection: $view) {
                Text("All").tag(LeaderboardView.top)
                Text("Around me").tag(LeaderboardView.around)
            }
            .pickerStyle(.segmented)

            let rows = view == .top ? ranking.top : ranking.around
            if rows.isEmpty {
                Text(view == .around
                     ? (isVisible ? "Earn LP this week to appear on the board." : "Join the leaderboard to see who’s around you.")
                     : "Nobody is on the board yet this week.")
                    .font(Typography.secondary)
                    .foregroundStyle(Color.mutedInk)
                    .padding(.vertical, Spacing.s)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                        if index > 0 { Divider().overlay(Color.neutralSurface) }
                        LeaderboardRowView(row: row)
                            .contextMenu {
                                if !row.isMe {
                                    Button("Report", systemImage: "flag") { reportTarget = row }
                                }
                            }
                    }
                }
                .cardSurface(radius: Radii.card)
            }
        }
    }

    // MARK: Actions

    private func message(_ text: Text) -> some View {
        text
            .font(Typography.secondary)
            .foregroundStyle(Color.mutedInk)
            .fixedSize(horizontal: false, vertical: true)
            .padding(Spacing.m)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.neutralSurface, in: RoundedRectangle(cornerRadius: Radii.tile, style: .continuous))
    }

    private func setVisible(_ visible: Bool) {
        Task {
            do {
                try await ranking.setVisible(visible)
                notice = nil
            } catch {
                notice = error.asAPIError.userMessage
            }
        }
    }

    private func report(_ row: LeaderboardRow, _ reason: ReportReason) {
        Task {
            do {
                try await ranking.report(username: row.username, reason: reason)
                notice = String(localized: "Thanks. We’ll take a look.", bundle: .appLanguage)
            } catch {
                notice = error.asAPIError.userMessage
            }
        }
    }
}

struct LeaderboardRowView: View {
    let row: LeaderboardRow

    var body: some View {
        HStack(spacing: Spacing.s) {
            Group {
                if let rank = row.rank { Text(verbatim: "\(rank)") } else { Text(verbatim: "–") }
            }
            .font(Typography.secondary.weight(.bold).monospacedDigit())
            .foregroundStyle(Color.mutedInk)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .frame(width: 32, alignment: .leading)
            AvatarView(key: row.avatarKey, size: 40, cornerRadius: Radii.chip)
            HStack(spacing: Spacing.xs) {
                Text(verbatim: row.username)
                    .font(Typography.emphasis)
                    .foregroundStyle(Color.ink)
                    .lineLimit(1)
                if row.isMe {
                    Chip(text: "You", fill: .surface, foreground: .selectedInk)
                }
            }
            Spacer(minLength: Spacing.s)
            Text("\(row.weeklyLP) LP")
                .font(Typography.emphasis.monospacedDigit())
                .foregroundStyle(Color.ink)
        }
        .padding(.horizontal, Spacing.m + 2)
        .frame(minHeight: 66)
        .background(row.isMe ? Color.selectedSurface : Color.clear)
        .accessibilityElement(children: .combine)
    }
}

/// Ranking weeks start Monday 00:00 UTC, so their dates read in UTC whatever the device zone.
enum WeekLabel {
    private static let parser: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .iso8601)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    /// Monday to Sunday of the week, e.g. "09–15/11".
    static func range(_ weekStart: String) -> String? {
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        guard let start = parser.date(from: weekStart),
              let end = calendar.date(byAdding: .day, value: 6, to: start) else { return nil }
        let formatter = DateIntervalFormatter()
        formatter.locale = AppLanguage.active.locale
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateTemplate = "ddMM"
        return formatter.string(from: start, to: end)
    }
}

extension ReportReason {
    var title: LocalizedStringKey {
        switch self {
        case .offensiveName: "Offensive name"
        case .impersonation: "Pretending to be someone else"
        case .suspiciousActivity: "Suspicious activity"
        case .other: "Something else"
        }
    }
}

/// First visit: what the leaderboard is and what becomes public. Seeing it never opts in (spec §4.3).
struct RankingIntroSheet: View {
    let onEditProfile: () -> Void
    @Environment(RankingStore.self) private var ranking
    @Environment(LearnerStore.self) private var learner
    @Environment(\.dismiss) private var dismiss
    @State private var error: String?
    @State private var isJoining = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.m) {
                HStack {
                    PunctuatedTitle(text: "Weekly leaderboard", font: Typography.screenTitle)
                    Spacer(minLength: Spacing.xs)
                    SheetCloseButton()
                }
                Text("Compare the LP you earn this week with other learners. It starts again every Monday.")
                    .font(Typography.body)
                    .foregroundStyle(Color.ink)
                    .fixedSize(horizontal: false, vertical: true)
                if let profile = learner.profile, let username = profile.username {
                    HStack(spacing: Spacing.s) {
                        AvatarView(key: profile.avatarKey ?? "", size: 48)
                        Text(verbatim: username)
                            .font(Typography.emphasis)
                            .foregroundStyle(Color.ink)
                    }
                    .padding(Spacing.m)
                    .cardSurface(radius: Radii.card - 2)
                }
                Label("If you join, your name, avatar, Tier and LP this week are public. Your email, level and words are never shown.",
                      systemImage: "eye")
                    .font(Typography.secondary)
                    .foregroundStyle(Color.mutedInk)
                    .fixedSize(horizontal: false, vertical: true)
                if let error {
                    Text(verbatim: error)
                        .font(Typography.secondary)
                        .foregroundStyle(Color.errorInk)
                }
                PrimaryButton(title: "Join", isEnabled: !isJoining, action: join)
                SecondaryButton(title: "Edit name and avatar") {
                    dismiss()
                    onEditProfile()
                }
                SecondaryButton(title: "Not now") { dismiss() }
            }
            .padding(.horizontal, Spacing.screenGutter)
            .padding(.top, Spacing.m)
            .padding(.bottom, Spacing.l)
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationBackground(Color.canvas)
        .task { await ranking.markIntroSeen() }
    }

    private func join() {
        isJoining = true
        Task {
            defer { isJoining = false }
            do {
                try await ranking.setVisible(true)
                dismiss()
            } catch {
                self.error = error.asAPIError.userMessage
            }
        }
    }
}
