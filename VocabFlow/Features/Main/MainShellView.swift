import SwiftUI
import UIKit

enum MainTab: CaseIterable, Hashable {
    case home, words, profile

    var title: LocalizedStringKey {
        switch self {
        case .home: "Home"
        case .words: "My Words"
        case .profile: "Profile"
        }
    }

    var systemImage: String {
        switch self {
        case .home: "house"
        case .words: "book"
        case .profile: "person"
        }
    }
}

/// Pages the Profile tab pushes onto its navigation stack.
enum ShellPage: Hashable {
    case settings
}

/// Plan editors Profile presents as bottom sheets.
enum PlanSheet: String, Identifiable {
    case focus, routine

    var id: String { rawValue }
}

/// Home · My Words · Profile in the system `TabView`, so the tab bar is whatever the OS provides:
/// Liquid Glass on iOS 26+, the classic bar before that. Session screens live outside this shell.
struct MainShellView: View {
    @Environment(LearningPlanStore.self) private var plan
    @Environment(\.motion) private var motion
    @State private var tab: MainTab = .home
    @State private var profilePath: [ShellPage] = []
    @State private var planSheet: PlanSheet?
    @State private var toast: String?
    @State private var toastToken = UUID()

    var body: some View {
        TabView(selection: $tab) {
            HomeView(onShowWords: { tab = .words })
                .background(Color.canvas)
                .tabItem { Label(MainTab.home.title, systemImage: MainTab.home.systemImage) }
                .tag(MainTab.home)

            MyWordsView()
                .background(Color.canvas)
                .tabItem { Label(MainTab.words.title, systemImage: MainTab.words.systemImage) }
                .tag(MainTab.words)

            profileStack
                .tabItem { Label(MainTab.profile.title, systemImage: MainTab.profile.systemImage) }
                .tag(MainTab.profile)
        }
        .tint(Color.interactive)
        .minimizingTabBarOnScroll()
    }

    private var profileStack: some View {
        NavigationStack(path: $profilePath) {
            ProfileView(
                onEditFocus: { planSheet = .focus },
                onEditRoutine: { planSheet = .routine },
                onOpenSettings: { profilePath.append(.settings) }
            )
            .background(Color.canvas)
            // Hidden bar, but the title still labels the system back button on pushed pages.
            .navigationTitle(MainTab.profile.title)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: ShellPage.self, destination: destination)
        }
        .sheet(item: $planSheet) { sheet in
            planEditor(sheet)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationBackground(Color.canvas)
        }
        // Sits above the tab bar because the tab bar is part of this stack's safe area.
        .overlay(alignment: .bottom) {
            if let toast {
                ToastView(text: toast)
                    .padding(.horizontal, Spacing.screenGutter)
                    .padding(.bottom, Spacing.s)
                    .transition(motion.popTransition)
            }
        }
    }

    @ViewBuilder
    private func destination(_ page: ShellPage) -> some View {
        switch page {
        case .settings:
            AppSettingsView()
                .toolbar(.hidden, for: .tabBar)
        }
    }

    @ViewBuilder
    private func planEditor(_ sheet: PlanSheet) -> some View {
        switch sheet {
        case .focus:
            EditFocusView(initial: plan.current) { preferences in
                save(preferences, toast: String(localized: "Focus updated"))
            }
        case .routine:
            EditRoutineView(initial: plan.current) { preferences in
                save(preferences, toast: String(localized: "Routine updated"))
            }
        }
    }

    private func save(_ preferences: LearningPreferences, toast text: String) {
        plan.save(preferences)
        planSheet = nil
        showToast(text)
    }

    private func showToast(_ text: String) {
        let token = UUID()
        toastToken = token
        motion.perform(MotionTokens.feedback) { toast = text }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2.4))
            guard toastToken == token else { return }
            motion.perform(MotionTokens.press) { toast = nil }
        }
    }
}

private extension View {
    /// iOS 26+: the Liquid Glass tab bar shrinks while scrolling down. Earlier versions keep the classic bar.
    @ViewBuilder
    func minimizingTabBarOnScroll() -> some View {
        if #available(iOS 26.0, *) {
            tabBarMinimizeBehavior(.onScrollDown)
        } else {
            self
        }
    }
}

struct ToastView: View {
    let text: String

    var body: some View {
        Text(verbatim: text)
            .font(Typography.micro.weight(.bold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.s + 1)
            .padding(.horizontal, Spacing.m)
            .background(Color.ink, in: RoundedRectangle(cornerRadius: Radii.chip + 2, style: .continuous))
            .shadow(color: Color.ink.opacity(0.2), radius: 10, y: 6)
            .onAppear {
                UIAccessibility.post(notification: .announcement, argument: text)
            }
    }
}
