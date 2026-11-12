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

    private var isVisible: Bool { learner.profile?.settings.leaderboardVisible ?? false }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.l) {
                PunctuatedTitle(text: "Weekly ranking")
                if let mine = ranking.mine {
                    weekHeader(mine)
                    lifetimeTier(mine.tier)
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
                history
            }
            .padding(.horizontal, Spacing.screenGutter)
            .padding(.top, Spacing.m)
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

    private func weekHeader(_ mine: MyRanking) -> some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            Eyebrow(text: "This week")
            HStack(alignment: .firstTextBaseline, spacing: Spacing.m) {
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(mine.weeklyLP, format: .number)
                        .font(Typography.display.monospacedDigit())
                        .foregroundStyle(Color.ink)
                    Text("LP this week")
                        .font(Typography.micro)
                        .foregroundStyle(Color.mutedInk)
                }
                Spacer(minLength: Spacing.s)
                if let position = mine.position {
                    positionLabel(position)
                }
            }
            if mine.weeklyLP == 0 {
                Text("No learning recorded this week yet.")
                    .font(Typography.secondary)
                    .foregroundStyle(Color.mutedInk)
            }
            Text("Resets \(mine.weekEndsAt.formatted(.dateTime.weekday(.wide).hour().minute().locale(AppLanguage.active.locale)))")
                .font(Typography.micro)
                .foregroundStyle(Color.mutedInk)
        }
        .padding(Spacing.m)
        .cardSurface(radius: Radii.card - 2)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func positionLabel(_ position: RankingPosition) -> some View {
        switch position.kind {
        case .rank:
            if let rank = position.rank {
                VStack(alignment: .trailing, spacing: Spacing.xxs) {
                    Text("#\(rank)")
                        .font(Typography.screenTitle.monospacedDigit())
                        .foregroundStyle(Color.ink)
                    Text("Weekly rank")
                        .font(Typography.micro)
                        .foregroundStyle(Color.mutedInk)
                }
            }
        case .percentile:
            if let percentile = position.percentile {
                VStack(alignment: .trailing, spacing: Spacing.xxs) {
                    Text("About top \(percentText(percentile))")
                        .font(Typography.emphasis)
                        .foregroundStyle(Color.ink)
                    Text("Estimated")
                        .font(Typography.micro)
                        .foregroundStyle(Color.mutedInk)
                }
            }
        case .unranked:
            EmptyView()
        }
    }

    private func percentText(_ value: Int) -> String {
        (Double(value) / 100).formatted(.percent.precision(.fractionLength(0)).locale(AppLanguage.active.locale))
    }

    private func lifetimeTier(_ tier: TierDetailSummary) -> some View {
        HStack(spacing: Spacing.s) {
            Image(systemName: (tier.level > 0 ? tier.key : nil)?.systemImage ?? "leaf")
                .font(.headline)
                .frame(width: 36, height: 36)
                .background(tier.level > 0 ? Color.reward : Color.neutralSurface, in: Circle())
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text("Lifetime Tier")
                    .font(Typography.micro)
                    .foregroundStyle(Color.mutedInk)
                Group {
                    if tier.level > 0, let key = tier.key { Text(key.name) } else { Text("No Tier yet") }
                }
                .font(Typography.secondary.weight(.bold))
                .foregroundStyle(Color.ink)
            }
            Spacer()
            Text("\(tier.lifetimeLP) LP earned")
                .font(Typography.micro)
                .foregroundStyle(Color.mutedInk)
        }
        .accessibilityElement(children: .combine)
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
        .cardSurface(radius: Radii.card - 2)
    }

    private var board: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            Picker("Leaderboard", selection: $view) {
                Text("Top 100").tag(LeaderboardView.top)
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
                .padding(.horizontal, Spacing.m)
                .cardSurface(radius: Radii.card - 2)
            }
        }
    }

    // MARK: History

    @ViewBuilder
    private var history: some View {
        if let weeks = ranking.history?.weeks {
            let active = weeks.filter { $0.weeklyLP > 0 }
            VStack(alignment: .leading, spacing: Spacing.s) {
                PlanSectionTitle(text: "Past weeks")
                if active.isEmpty {
                    Text("Your past weeks will show up here.")
                        .font(Typography.secondary)
                        .foregroundStyle(Color.mutedInk)
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(active.enumerated()), id: \.element.id) { index, week in
                            if index > 0 { Divider().overlay(Color.neutralSurface) }
                            historyRow(week)
                        }
                    }
                    .padding(.horizontal, Spacing.m)
                    .cardSurface(radius: Radii.card - 2)
                }
            }
        }
    }

    private func historyRow(_ week: RankingWeek) -> some View {
        HStack {
            Text("Week of \(WeekLabel.text(week.weekStart))")
                .font(Typography.secondary.weight(.semibold))
                .foregroundStyle(Color.ink)
            Spacer()
            VStack(alignment: .trailing, spacing: Spacing.xxs) {
                Text("\(week.weeklyLP) LP")
                    .font(Typography.secondary.weight(.bold).monospacedDigit())
                    .foregroundStyle(Color.ink)
                Group {
                    if let rank = week.rank { Text("#\(rank)") } else { Text("Not on the board") }
                }
                .font(Typography.micro)
                .foregroundStyle(Color.mutedInk)
            }
        }
        .frame(minHeight: 54)
        .accessibilityElement(children: .combine)
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
                if let rank = row.rank { Text("#\(rank)") } else { Text(verbatim: "–") }
            }
            .font(Typography.secondary.weight(.bold).monospacedDigit())
            .foregroundStyle(Color.mutedInk)
            .frame(minWidth: 44, alignment: .leading)
            AvatarView(key: row.avatarKey, size: 36)
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                HStack(spacing: Spacing.xs) {
                    Text(verbatim: row.username)
                        .font(Typography.secondary.weight(.semibold))
                        .foregroundStyle(Color.ink)
                        .lineLimit(1)
                    if row.isMe {
                        Chip(text: "You", fill: .selectedSurface, foreground: .selectedInk)
                    }
                }
                TierBadgeLabel(badge: row.lifetimeTier)
            }
            Spacer(minLength: Spacing.s)
            Text("\(row.weeklyLP) LP")
                .font(Typography.secondary.weight(.bold).monospacedDigit())
                .foregroundStyle(Color.ink)
        }
        .frame(minHeight: 60)
        .padding(.horizontal, row.isMe ? Spacing.xs : 0)
        .background(row.isMe ? Color.selectedSurface : Color.clear, in: RoundedRectangle(cornerRadius: Radii.chip, style: .continuous))
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

    static func text(_ weekStart: String) -> String {
        guard let date = parser.date(from: weekStart) else { return weekStart }
        var style = Date.FormatStyle.dateTime.day().month(.abbreviated).locale(AppLanguage.active.locale)
        style.timeZone = TimeZone(identifier: "UTC")!
        return date.formatted(style)
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

/// Lifetime Tier in full: both progress bars and the milestones unlocked so far (spec §3.5).
struct TierDetailView: View {
    @Environment(RankingStore.self) private var ranking
    @Environment(LearnerStore.self) private var learner

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.l) {
                PunctuatedTitle(text: "Your Tier")
                if let tier = ranking.tier {
                    TierCard(summary: tier.summary, next: tier.nextTier)
                    Text("A learning day is a UTC day with at least \(tier.minQualifiedDayLP ?? 5) LP. Days don’t need to be in a row, and taking a break never lowers your Tier.")
                        .font(Typography.micro)
                        .foregroundStyle(Color.mutedInk)
                        .fixedSize(horizontal: false, vertical: true)
                    milestones(tier.milestones)
                } else if let summary = learner.profile?.tierSummary {
                    TierCard(summary: summary)
                }
                if let error = ranking.error, ranking.tier == nil {
                    Text(verbatim: error)
                        .font(Typography.secondary)
                        .foregroundStyle(Color.mutedInk)
                }
            }
            .padding(.horizontal, Spacing.screenGutter)
            .padding(.top, Spacing.xs)
            .padding(.bottom, Spacing.l)
        }
        .background(Color.canvas)
        .navigationBarTitleDisplayMode(.inline)
        .task { await ranking.refreshTier() }
    }

    @ViewBuilder
    private func milestones(_ items: [TierMilestone]) -> some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: Spacing.s) {
                PlanSectionTitle(text: "Milestones")
                VStack(spacing: 0) {
                    ForEach(Array(items.reversed().enumerated()), id: \.element.id) { index, item in
                        if index > 0 { Divider().overlay(Color.neutralSurface) }
                        HStack(spacing: Spacing.s) {
                            Image(systemName: (item.key ?? .unknown).systemImage)
                                .frame(width: 28)
                                .foregroundStyle(Color.ink)
                                .accessibilityHidden(true)
                            Text((item.key ?? .unknown).name)
                                .font(Typography.secondary.weight(.semibold))
                                .foregroundStyle(Color.ink)
                            Spacer()
                            Text(item.unlockedAt, format: .dateTime.day().month().year().locale(AppLanguage.active.locale))
                                .font(Typography.micro)
                                .foregroundStyle(Color.mutedInk)
                        }
                        .frame(minHeight: 50)
                        .accessibilityElement(children: .combine)
                    }
                }
                .padding(.horizontal, Spacing.m)
                .cardSurface(radius: Radii.card - 2)
            }
        }
    }
}
