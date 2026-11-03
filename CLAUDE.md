# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

VocabFlow is a SwiftUI iOS app (iOS 17+, Swift 5 mode, no third-party dependencies) for learning English vocabulary with Vietnamese meanings. Learning sessions, accounts and progress come from the backend (sibling repo `vocab-backend`, contract in its `docs/FRONTEND_FLOW.md`). Practice Lab content is bundled JSON.

## Commands

```sh
# Build
xcodebuild -project VocabFlow.xcodeproj -scheme VocabFlow \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build

# All tests (XCTest)
xcodebuild -project VocabFlow.xcodeproj -scheme VocabFlow \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test

# One test class / one test method
xcodebuild ... test -only-testing:VocabFlowTests/SessionReducerTests
xcodebuild ... test -only-testing:VocabFlowTests/SessionReducerTests/testStartBeginsLearnAndLearnFlowsToBuild
```

The project uses Xcode file-system synchronized groups (`objectVersion = 77`): new files under `VocabFlow/` or `VocabFlowTests/` are picked up automatically — do not edit `project.pbxproj` to add them.

## Architecture

### Composition and routing
- `App/VocabFlowApp.swift` builds every store once and injects them with `.environment(...)`. Stores are `@Observable @MainActor` classes; views read them via `@Environment(StoreType.self)`. Previews must inject the same set of stores (see the `#Preview` in `AppRootView.swift`) using test doubles (`NoOpFeedback`, `SilentSpeech`, `InMemoryPreferencesStore`, `NoReminders`, `OfflineVocabAPI`, `SilentAudioClips`, `NoVoiceRecorder`, `defaults: nil`).
- There is no `NavigationStack`. `App/AppRootView.swift` derives a single `RouteID` from store state (onboarding → Practice Lab sandbox → session phase) and swaps whole screens with `.id(route)` + a transition. Changing a screen means changing store state, not pushing views.

### Backend session (the live flow)
- `Networking/`: `APIClient` (actor: bearer auth, one refresh-and-retry on 401, backoff), `VocabAPI` (protocol, `LiveVocabAPI`, and `OfflineVocabAPI` for previews). Set the server with the `VOCABFLOW_API_URL` scheme environment variable; the default is the local backend.
- `Domain/Practice/`: `PracticeTask` decodes a plan (an unknown template or variant fails the whole plan on purpose), `TaskAttempt` is the pure per-task state that records `TaskEvent`s, and it enforces the rules that would otherwise reject the entire commit with 422.
- `Features/Practice/PracticeSessionStore.swift` runs plan → steps → commit. The commit body is encoded once so retries are byte-identical. Task views are in `Features/Practice/Tasks/`, hosted by `TaskScaffold`.
- Routing: `AuthStore.phase` → `LearnerStore.phase` (`GET /me` decides onboarding) → onboarding → active practice session → sandbox → shell.

### Two independent demo engines
The scored session below is no longer reachable from the UI; Home and My Words start backend sessions instead.

1. **Scored session** (Learn → Build → Recall → Results)
   - `Domain/Learning/SessionReducer.swift` is a pure reducer: `(SessionState, SessionAction, DemoContent) -> SessionTransition(state, events)`. Invalid action/phase combos return `.unchanged`. All scoring rules live here and are what the tests target.
   - `Features/SessionStore.swift` is a thin wrapper: intent methods → `send(action)`, then maps `SessionEvent`s to side effects (haptics, `sessionToken` rotation on restart, `onFinish` → `ProgressStore`).
   - `Features/SessionFlowView.swift` keeps one persistent frame (header + pinned action bar) across all Learn/Build/Recall steps; only stage content transitions. Per-step UI input (selected tile, typed text, drag state) lives in `FlowDraft`, which is *not* part of scored state and is reset before every advance.
2. **Practice Lab** (sandbox, unscored)
   - Lab entries mirror the seven backend task templates (`TaskTemplate`: select, clozeSelect, typing, flyReorder, match, surgery, recording). `Resources/practice_lab.json` holds example tasks in the plan wire format; `LabLibrary.validate()` requires every template to be present.
   - `Features/PracticeLab/TemplateSandboxStore.swift` owns Lab navigation and its own `PracticeSessionStore` running in sandbox mode (`startSandbox`): same task views via `PracticeTaskView`, no planning, assessment or commit. It is a separate instance from the live session store, injected into the Lab subtree by `LabTaskView`.

Adding a template touches the backend contract (`TaskTemplate`, `TaskAttempt`, a view in `Features/Practice/Tasks/`, `PracticeTaskView`) and a `practice_lab.json` entry.

### Content pipeline
- `Resources/demo_words.json` (words, build challenges, recall prompts, intro motion config) and `Resources/practice_lab.json` (Practice Lab example tasks).
- `DemoContentRepository` decodes → validates (`ContentValidator` / `LabLibrary.validate`) → shuffles options deterministically from the JSON `seed` (`DemoSeed`). Invalid content is a `fatalError` at launch, so any JSON edit must keep validators passing; `ContentValidationTests` and `LabLibraryTests` load the real bundled files.

### Design system and motion
- `DesignSystem/Tokens/` (colors, spacing, radii, typography, motion) — use tokens rather than literal values. App is forced to light mode.
- All animation goes through `MotionCoordinator` (`@Environment(\.motion)`), which honors both system Reduce Motion and the in-app setting. Use `motion.perform(...)`, `motion.travel(...)`, `motion.stepTransition`, etc. instead of raw `withAnimation`/transitions.
- Haptics go through the `FeedbackProviding` protocol (wrapped by `SettingsAwareFeedback` so the user setting applies); speech through `SpeechProviding`.
- Learn-stage word intros use six motion recipes in `Features/Learn/MotionTemplates/`, selected per word by `intro.templateID` in `demo_words.json` and hosted by `IntroMotionHost` (presentation only — never affects scoring or advancement).

### Persistence
Tokens live in the Keychain (`KeychainTokenStore`). Otherwise `UserDefaults`: `ProgressStore` (demo run history), `AppSettingsStore`, `LearningPlanStore` (via `PreferencesStoring`, plus `ReminderScheduling` for notifications). Each accepts an injectable/nil `UserDefaults` or in-memory implementation for tests and previews.

### Localization
User-facing strings use `LocalizedStringKey` and live in `Resources/Localizable.xcstrings`. Learning content (Vietnamese meanings, feedback) comes from the JSON files, not the string catalog.

**Rule: every displayed text that doesn't come from data (JSON content, backend responses, user input) must be localized** — UI labels, buttons, titles, errors, accessibility labels/hints/values, VoiceOver announcements, notification text.
- View-facing parameters take `LocalizedStringKey`, not `String`. Where a `String` is required (stores, errors, `StreamingText`, models), build it with `String(localized:)`.
- `Text(verbatim:)` / `Text(someString)` only for data, numbers/counters, or the brand name.
- Every new key must be in `Localizable.xcstrings` (Xcode syncs it on build; `xcodebuild` does not). Check with the compiler's `.stringsdata` output when in doubt.
- **Vietnamese (`vi`) is mandatory**: every key needs a `vi` translation (state `translated`) in the same change. Multi-argument strings use positional specifiers (`%1$@`, `%2$lld`). Info.plist strings (permission prompts) live in `Resources/InfoPlist.xcstrings`.
