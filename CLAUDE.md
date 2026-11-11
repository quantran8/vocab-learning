# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

VocabFlow is a SwiftUI iOS app (iOS 17+, Swift 5 mode, dependencies via SPM: `lottie-ios` for the end-of-session confetti, `rive-ios` (`RiveRuntime`) for the Syllie mascot in `Resources/Animations/syllie.riv`) for learning English vocabulary with Vietnamese meanings. Learning sessions, accounts and progress come from the backend (sibling repo `vocab-backend`, contract in its `docs/FRONTEND_FLOW.md`). Practice Lab content is bundled JSON.

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
- `Networking/`: `APIClient` (actor: bearer auth, one refresh-and-retry on 401, backoff), `VocabAPI` (protocol, `LiveVocabAPI`, and `OfflineVocabAPI` for previews). Default server: local backend on the simulator, `https://moneytogether.dpdns.org/service/vocab/` on a real device (`APIConfiguration`). Override with the `VOCABFLOW_API_URL` scheme environment variable.
- `Domain/Practice/`: `PracticeTask` decodes a plan (an unknown template or variant fails the whole plan on purpose), `TaskAttempt` is the pure per-task state that records `TaskEvent`s, and it enforces the rules that would otherwise reject the entire commit with 422.
- `Features/Practice/PracticeSessionStore.swift` runs plan → steps → commit. The commit body is encoded once so retries are byte-identical. Task views are in `Features/Practice/Tasks/`, hosted by `TaskScaffold`.
- Routing: `AuthStore.phase` → language step (`AppSettingsStore.language`, until chosen; `GET /me` waits for it) → `LearnerStore.phase` (`GET /me` decides onboarding) → onboarding → active practice session → active challenge run → sandbox → shell.
- `Features/Auth/`: `AuthView` (log in, password reset by emailed code in two steps) hosts its own `NavigationStack` to push `SignUpView`. New passwords follow `PasswordPolicy` (shown live by `PasswordRuleList`; the backend enforces the same rules). Sign in with Apple, and Google without the SDK (`SocialSignIn.swift`: OAuth code + PKCE in `WebAuthenticationSession`, client ID from Info.plist `GoogleClientID`). Both send an ID token plus the raw nonce to the backend. Change password lives in Settings (`ChangePasswordSheet`). Provider setup (Google Cloud, Apple Developer, Supabase templates/SMTP) is in `docs/AUTH_SETUP.md`.
- `Features/PlacementTest/`: `PlacementTestStore` and `PlacementTestView` run the level test, hosted as an onboarding step and as a full-screen cover from `EditLevelView`. No answer key on the client; the backend scores it and saves the level.

### Challenge (Match Madness)
- Replaces the Journey/Checkpoint UI (Home card `ChallengeHomeCard`, map `ChallengeMapView` pushed as `ShellPage.challengeMap`). The old Journey files and `LearnerStore` checkpoint/journey loading remain only until the backend migration; nothing user-facing routes to them. Challenge never touches Daily, SRS or `PracticeSessionStore`.
- Wire models live in `Domain/Challenge/ChallengeMapModels.swift` and `ChallengeRunModels.swift`, matching `vocab-backend/docs/FRONTEND_FLOW.md` §12. Unknown enum values decode to `.unknown`. Map levels carry the current goal and star rules for the level sheet; the run plan has the final say.
- `MatchMadnessEngine` is the pure reducer and must equal the backend's `Board`/`replay` (`src/modules/challenge/domain/match-madness.ts`), or commits fail with 422: refill takes the first queued pair whose `word` is neither on the board nor matched in the last `minMatchesBetweenRepeats` matches; event `elapsedMs` strictly increases; `goal_reached` ends at the last event. `ChallengeBoardOrdering` is the shared column order (SHA256 of `seed|correctCount|side|tileId`). `MatchMadnessBackendParityTests` holds a fixture generated by running the backend's code: regenerate it when those rules change. Stars and the official score come only from the server; the plan's `score` rule (incl. `perSecondLeft` clear bonus) drives the live display score, hidden when a plan lacks it.
- The board on screen does not follow the engine's per-match reorder: `ChallengeBoardSlots` keeps tiles in fixed slots, a matched pair shows correct for `MotionTokens.matchCorrectHold`, then fades and the next pair fades into the freed slots. Commits carry tile IDs only, never positions. Match tiles (here and in `MatchTaskView`) share `Spacing.matchTileMinHeight` and grow to the tallest tile.
- `ChallengeRunStore`: issue → ready → start (the monotonic clock starts only after `POST …/start` answers) → playing (never pauses; `tick()` on foreground ends a run as `time_up`) → commit (body frozen once, retries are byte-identical, `PendingRun` in `UserDefaults` lets the next launch settle a killed run) → results. `startSandbox` runs a static plan on the same engine for the Practice Lab (timed and untimed), with no API calls. `ChallengeMapStore` refreshes after every settled run and when the shell appears.

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
- Syllie (`DesignSystem/Components/SyllieView.swift`): artboard `Syllie`, state machine `Syllie`, view model `Syllie` with `mood` (enum `Mood`: idle, happy, excited, thinking, oops, sleepy, the happy variants happyPop/happyWiggle/happyPuff/happyFloat/proud and the oops variants oopsSquish/oopsWobble/oopsFreeze/oopsSlip — mirrored by `SyllieMood`; `thinking` and `deepThoughtHold` are loops, the rest are one-shots; `deepThought` (timeline `deep_thought_in`, 2 s: one eye squints, the other looks up-right, head cocked, the top-right lobe throbs; no props, and no inward-slanted eyes, which read as angry) ends on the pose `deepThoughtHold` (`deep_thought_hold`, 3 s: lobe throbs, then the eyes swap sides and back) loops on; `SyllieReactionView` switches to it via `SyllieMood.settledMood`, because an Any State transition back to the intro would keep firing) and `react` (trigger, replays the current mood). State machine `Syllie` has a second layer `Snore` that plays the rising "z" marks (`SnoreZ1-3`, hidden by default so other state machines never show them) only while `mood == sleepy`. `Syllie` also has state machine `LoadingFly` (layers `Fly` + `Blink`: body stretch, lobe lag, blinking). The `Loading` artboard (state machine `Loading`) nests Syllie running `LoadingFly` and adds the wind lines and bob; `SyllieLoadingView` plays it. The `Celebrate` artboard (390×844, state machine `Celebrate`: fly-in, landing, double bounce, then `hold`) nests Syllie running its own `Celebrate` state machine (`celebrate_face` → `celebrate_sway`, a happy left/right sway loop); `SyllieCelebrationView` covers `PracticeResultsView` with it and the confetti starts at `confettiCue` (~1.1 s). On Home, `LessonMascot` uses its own artboard `HomeSyllie` (520×560, state machine `HomeSyllie`, view model `HomeSyllie` with `scene`, enum `HomeScene`: idle, sleepy, wakeUp, playLetters, planeChase), played by `HomeSyllieView` / `HomeSyllieScene`. It holds a separate copy of Syllie's shapes (under `Stage`, offset 130 down so the props have room above) plus the `Letter` tile and `Plane` props (blue, `interactive` tokens), and its own timelines (`idle`, `sleepy`, `wake_up`, `snore_bubbles`, `snore_off`, `play_letters` 5.5 s, `plane_chase` 5.0 s: the plane flies in, does one loop (radius 75) over Syllie's head and exits right, sampled every 4 frames as linear keys, rotation following the heading; travel keys use linear or ease-in/out cubic params, not the default cubic, which stops the prop at every key; every timeline keys both props' start pose and opacity 0 on frame 0, so a replay doesn't blend in from where the prop last stopped) — editing the `Syllie` artboard does not change it. One cycle: Syllie idles for `idleBeat`, plays one random play scene, then goes `sleepy` (layer `Snore` shows the z marks); a tap plays `wakeUp` and starts the cycle again from idle. With reduced motion he skips the play. `ReviewPreviewView` (the session's "Words to review" step) puts Syllie between the intro text and the word list: while the words fly in he loops `reviewWatch` (eyes down at the list, scanning left to right; each 1.6 s loop starts and ends with the eyes centred), starting as the words start flying; the entrance (`entranceTiming`: stagger stretched/shrunk from `MotionTokens.reviewTileStagger`/`reviewTrainStagger`, plus a short lead) is timed so the last word comes to rest (`reviewTileSettle`/`reviewTrainSettle`) after a whole number of loops (`SyllieMood.reviewWatchLoop`, at least one), and then he plays `reviewReady` once (one nod, starting from that pose), then idles. `ReviewFinishedView` (review done → new words) replaces the checkmark with Syllie playing `reviewToLearn` (timeline `review_to_learn`, 1.2 s: proud puff, look down at the list, eager stretch) once, then idle. In practice, `TaskScaffold` puts Syllie beside the action (`FeedbackActionPanel(mascot:)`): a random `SyllieMood.thinkingMoods` loop (`thinking` or `deepThought`, re-picked per question and after "Try again") while answering, a random `SyllieMood.happyReactions` variant when solved, a random `oopsReactions` variant when wrong/exhausted (both start only after the answer's own animation, `MotionTokens.answerFeedbackSettle`; until then he keeps thinking), and `SyllieReactionView` returns him to idle after the one-shot (`SyllieMood.reactionDuration`, nil for held moods; keep in sync with the timelines). The happy/oops variant timelines, `idle` and `thinking_wait` key the full rest pose (root x/y/rotation/scale, eyes, eye corners, top-right lobe vertices) at their first and last frame, so an interrupted mood can't leave a stray pose; a new mood timeline should do the same. Rive only exports artboards marked as Component, so any new artboard must be one. The `.riv` is built in the Rive editor (cloud file still named "inky", so its export comes out as `inky.riv`: save it as `Resources/Animations/syllie.riv`); keep these names stable.
- Haptics go through the `FeedbackProviding` protocol (wrapped by `SettingsAwareFeedback` so the user setting applies); speech through `SpeechProviding`.
- Learn-stage word intros use six motion recipes in `Features/Learn/MotionTemplates/`, selected per word by `intro.templateID` in `demo_words.json` and hosted by `IntroMotionHost` (presentation only — never affects scoring or advancement).

### Persistence
Tokens live in the Keychain (`KeychainTokenStore`). Otherwise `UserDefaults`: `ProgressStore` (demo run history), `AppSettingsStore`, `LearningPlanStore` (via `PreferencesStoring`, plus `ReminderScheduling` for notifications). Each accepts an injectable/nil `UserDefaults` or in-memory implementation for tests and previews.

### Localization
User-facing strings use `LocalizedStringKey` and live in `Resources/Localizable.xcstrings`. Learning content (Vietnamese meanings, feedback) comes from the JSON files, not the string catalog.

**Rule: every displayed text that doesn't come from data (JSON content, backend responses, user input) must be localized** — UI labels, buttons, titles, errors, accessibility labels/hints/values, VoiceOver announcements, notification text.
- View-facing parameters take `LocalizedStringKey`, not `String`. Where a `String` is required (stores, errors, `StreamingText`, models), build it with `String(localized: "…", bundle: .appLanguage)`; without the bundle it ignores the language chosen in the app.
- The display language (`AppLanguage`, chosen on `LanguageSelectionView` after the first login and in Settings) applies live: `AppRootView` sets `\.locale` and rebuilds the screen, and `Bundle.appLanguage` serves `String(localized:)`. Formatters outside `Text` take `AppLanguage.active.locale`.
- `Text(verbatim:)` / `Text(someString)` only for data, numbers/counters, or the brand name.
- Every new key must be in `Localizable.xcstrings` (Xcode syncs it on build; `xcodebuild` does not). Check with the compiler's `.stringsdata` output when in doubt.
- **Vietnamese (`vi`) is mandatory**: every key needs a `vi` translation (state `translated`) in the same change. Multi-argument strings use positional specifiers (`%1$@`, `%2$lld`). Info.plist strings (permission prompts) live in `Resources/InfoPlist.xcstrings`.
