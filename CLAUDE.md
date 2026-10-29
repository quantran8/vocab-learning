# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

VocabFlow is a SwiftUI iOS app (iOS 17+, Swift 5 mode, no third-party dependencies) for learning English vocabulary with Vietnamese meanings. All content is bundled JSON — there is no backend.

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
- `App/VocabFlowApp.swift` builds every store once and injects them with `.environment(...)`. Stores are `@Observable @MainActor` classes; views read them via `@Environment(StoreType.self)`. Previews must inject the same set of stores (see the `#Preview` in `AppRootView.swift`) using test doubles (`NoOpFeedback`, `SilentSpeech`, `InMemoryPreferencesStore`, `NoReminders`, `defaults: nil`).
- There is no `NavigationStack`. `App/AppRootView.swift` derives a single `RouteID` from store state (onboarding → Practice Lab sandbox → session phase) and swaps whole screens with `.id(route)` + a transition. Changing a screen means changing store state, not pushing views.

### Two independent learning engines
1. **Scored session** (Learn → Build → Recall → Results)
   - `Domain/Learning/SessionReducer.swift` is a pure reducer: `(SessionState, SessionAction, DemoContent) -> SessionTransition(state, events)`. Invalid action/phase combos return `.unchanged`. All scoring rules live here and are what the tests target.
   - `Features/SessionStore.swift` is a thin wrapper: intent methods → `send(action)`, then maps `SessionEvent`s to side effects (haptics, `sessionToken` rotation on restart, `onFinish` → `ProgressStore`).
   - `Features/SessionFlowView.swift` keeps one persistent frame (header + pinned action bar) across all Learn/Build/Recall steps; only stage content transitions. Per-step UI input (selected tile, typed text, drag state) lives in `FlowDraft`, which is *not* part of scored state and is reset before every advance.
2. **Practice Lab templates** (sandbox, unscored)
   - `Features/PracticeLab/TemplateSandboxStore.swift` owns navigation and an ephemeral `TemplateRun` (`Domain/Learning/TemplateRun.swift`, a mutating value type returning `[TemplateEvent]`). It must never write to `SessionStore`.
   - `TemplateKind` (`Domain/Models/TemplateDefinition.swift`) is the registry of templates, their category (classic/creative/skill), allowed variants, and whether they use audio (audio templates must provide a non-audio fallback). Variants reuse one mechanic/evaluator (e.g. Fill the Blank and Phrase Snap are Word Stack variants). Views are in `Features/Templates/{Classic,Creative,Skill}/`, hosted by `TemplateHostView`.

Adding a template touches: `TemplateKind`, `TemplateRun`/`TemplateEvaluator` logic, `TemplateContentValidator`, a view in `Features/Templates/`, the `TemplateHostView` switch, and `Resources/demo_templates.json`.

### Content pipeline
- `Resources/demo_words.json` (words, build challenges, recall prompts, intro motion config) and `Resources/demo_templates.json` (Practice Lab exercises, referencing words by `wordID`).
- `DemoContentRepository` decodes → validates (`ContentValidator` / `TemplateContentValidator`) → shuffles options deterministically from the JSON `seed` (`DemoSeed`). Invalid content is a `fatalError` at launch, so any JSON edit must keep validators passing; `ContentValidationTests` loads the real bundled files.

### Design system and motion
- `DesignSystem/Tokens/` (colors, spacing, radii, typography, motion) — use tokens rather than literal values. App is forced to light mode.
- All animation goes through `MotionCoordinator` (`@Environment(\.motion)`), which honors both system Reduce Motion and the in-app setting. Use `motion.perform(...)`, `motion.travel(...)`, `motion.stepTransition`, etc. instead of raw `withAnimation`/transitions.
- Haptics go through the `FeedbackProviding` protocol (wrapped by `SettingsAwareFeedback` so the user setting applies); speech through `SpeechProviding`.
- Learn-stage word intros use six motion recipes in `Features/Learn/MotionTemplates/`, selected per word by `intro.templateID` in `demo_words.json` and hosted by `IntroMotionHost` (presentation only — never affects scoring or advancement).

### Persistence
`UserDefaults` only: `ProgressStore` (finished-run history), `AppSettingsStore`, `LearningPlanStore` (via `PreferencesStoring`, plus `ReminderScheduling` for notifications). Each accepts an injectable/nil `UserDefaults` or in-memory implementation for tests and previews.

### Localization
User-facing strings use `LocalizedStringKey` and live in `Resources/Localizable.xcstrings`. Learning content (Vietnamese meanings, feedback) comes from the JSON files, not the string catalog.
