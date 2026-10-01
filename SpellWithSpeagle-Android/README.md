# Spell With Speagle (Android)

A Kotlin + Jetpack Compose + Room port of the iOS "Spell With Speagle" app
(see `../SpellWell/README.md` for the full feature spec this is built
against). This is a from-scratch native Android build, not a line-by-line
port of the SwiftUI code -- same data model and behavior, idiomatic
Android/Compose/Room patterns.

This project was written without access to Android Studio, the Android
SDK, or an emulator -- there was no way to compile or run it while writing
it. Expect a small build-fix or two on first open (an import, an API
signature mismatch), same caveat the iOS README carries for Xcode.

## Requirements

- Android Studio (Ladybug or newer recommended) with an SDK for API 35
  installed, or a command-line Android SDK
- JDK 17 (bundled with recent Android Studio)

## Setup

1. Open the `SpellWithSpeagle-Android/` folder directly in Android Studio
   ("Open" -> this folder, not the repo root).
2. Let Gradle sync -- the wrapper (`gradlew`/`gradlew.bat`) is committed,
   so Android Studio will download the pinned Gradle 8.9 distribution and
   the Android Gradle Plugin (8.6.1) / Kotlin (2.0.21) automatically the
   first time.
3. Run the `app` configuration on an emulator or device (API 26+).

## What's implemented

- **Gradle project** -- `settings.gradle.kts`, root/`app` build scripts,
  a version catalog (`gradle/libs.versions.toml`), and a committed Gradle
  wrapper, so this opens directly in Android Studio with no extra setup.
- **Room schema** (`data/model`, `data/dao`, `data/db/AppDatabase.kt`) --
  `Child`, `WeekList`, `SpellingWord`, `PracticeAttempt`, `DailyReward`,
  `WeeklyPrize`, mirroring the iOS SwiftData models field-for-field
  (including cascade deletes via `ForeignKey.CASCADE`). `SpellingRepository`
  is the single entry point the UI layer talks to, bundling multi-table
  operations like "find or create this week's list" and the mid-week
  word-save-by-order-index matching iOS's "don't wipe test history on
  every save" fix.
- **Theme system** (`ui/theme`) -- `ColorProfile` ported 1:1 from
  `DesignSystem/Theme.swift`'s four themes (Default/Space/Princess/Circus),
  resolved into a `SpellColors` bundle read via `SpellTheme.colors` from
  any composable, the same role-based-color ergonomics as the iOS
  `Theme.xxx` static accessors.
- **Speagle mascot** (`ui/speagle`) -- the four pose PNGs copied directly
  from the iOS asset catalog into `res/drawable-nodpi`, with `Speagle`/
  `SpeagleTip` composables matching the iOS helpers of the same name.
- **Services** -- `SpeechService` (Android `TextToSpeech`, the
  AVSpeechSynthesizer equivalent, with a curated voice shortlist matching
  iOS's), `PinService` (`EncryptedSharedPreferences` + Android Keystore,
  `allowBackup="false"` + `data_extraction_rules.xml` so the PIN does NOT
  survive a real uninstall+reinstall, but does survive a normal app
  update -- same behavior iOS's local, non-iCloud-synced Keychain entry
  has), `ActiveChildStore` (DataStore, the `@AppStorage("activeChildID")`
  equivalent -- device-local active profile).
- **Home screen** -- greeting, Practice/Test toggle, big CTA card, a row
  of Monday-Friday day-grade cards (letter grade + percent, "No test yet"
  when nothing's been taken, a tappable "Retake N missed" when a day has
  wrong answers, a pulsing-gold-in-spirit "Reward Earned!" badge that
  opens a dialog with the reward text), and a weekly-prize progress bar.
  Grading uses the same "collapse to each weekday's latest test session"
  rule as iOS (`domain/AttemptAggregation.kt`,
  `List<PracticeAttempt>.latestSessionPerWeekday()`) so a retaken day, or
  a retaken week average, is never dragged down by attempts a same-day
  retake already superseded.
- **Practice/Test screen** -- TTS speaks the current word on arrival and
  on tapping "Tap to hear the word"; a lightbulb "Hear a hint" button
  appears when the word has a hint and (Practice always / Test only if
  `Child.allowHintsDuringTest`); typed-answer checking with right/wrong
  feedback; Practice allows retrying a missed word (with "Skip word" to
  move on without getting it right), Test always advances immediately and
  only Test attempts are persisted as `PracticeAttempt` rows, matching
  iOS. Ends on a results list (green check / red x per word, what was
  typed for anything wrong) with a bounced-in grade.
- **First-run flow** -- zero profiles on launch goes straight to a
  no-PIN-gate "what's your name?" screen (`ui/profiles/AddChildScreen.kt`),
  same reasoning as iOS: nothing to protect yet on a fresh install.
- **Parent PIN gate** (`ui/gate/PinGateScreen.kt`) -- a shared 0-9 keypad +
  masked-dot display (`ui/components/PinPad.kt`) matching iOS's PINPad,
  checked fresh on every visit to Add List/Rewards/Settings (never cached
  across visits, same as iOS's `ParentGate.verify`). No PIN set yet goes
  straight into a two-step create-and-confirm flow instead of failing a
  check against nothing. Settings' "Change PIN" reuses the same screen in
  a forced-create mode.
- **Add spelling list** (`ui/addlist`) -- a numbered word list with an
  optional hint field per word, add/remove rows, "Save list" writes
  through `SpellingRepository.saveWords` (the order-index-matching save
  that preserves a word's test history across edits, same as iOS).
- **Rewards** (`ui/rewards`) -- per-weekday (Mon-Thu) reward text +
  accuracy-threshold slider, plus a weekly prize title + threshold.
  Reuses each row's existing database id on save so editing a reward
  updates it in place instead of inserting a duplicate row.
- **Settings** (`ui/settings`) -- color theme picker (4 swatches),
  appearance (system/light/dark) and text-size slider, a scrollable
  voice-picker dropdown capped to the 5 best on-device TTS voices with
  friendly names and a "Preview" button, per-weekday practice schedule
  (`WordInputMode` chips, 2-per-row, for Monday-Thursday), hints-during-test
  toggle, a real Friday reminder toggle + time picker, "Student profiles,"
  "Take a Tour," "Change PIN," and a "View report" link into the full
  Progress Report screen.
- **Multiple profiles** (`ui/profiles`) -- add-a-sibling, switch active
  profile, and remove-profile screen (`ProfilesScreen`/`ProfilesViewModel`),
  on top of the `ActiveChildStore`/`SpellingRepository` data layer that
  already isolated each `Child` fully.
- **Full Progress Report** (`ui/progress`) -- per-week accuracy history
  with a graphical bar chart (Compose Canvas), not just a plain-text
  summary, matching iOS's `ProgressReportView`.
- **Forgot PIN recovery** -- `BiometricAuthService` (`androidx.biometric`
  `BiometricPrompt`) lets a grown-up who forgot the PIN reset it after a
  fingerprint/face check, gated on `MainActivity` being a `FragmentActivity`.
- **Friday reminder notifications** (`service/FridayReminderWorker.kt`) --
  a real local notification via `WorkManager`, self-rescheduling every
  Friday at the chosen time (there's no native "every Friday" `WorkManager`
  schedule, so a one-time request reschedules itself on completion), the
  on-device equivalent of iOS's `UNCalendarNotificationTrigger`.
- **Misspelling double-check in Add List** -- `SpellCheckService`
  (Android's on-device `TextServicesManager`/`SpellCheckerSession`, bridged
  to coroutines) flags words not in the system dictionary with a warning
  icon and a "save anyway / review" confirmation, the Android equivalent of
  iOS's `UITextChecker` pass.
- **Letter-tile input modes** -- `PracticeScreen`'s `TileAnswerArea` now
  implements all of Scaffolded/Full tiles/Half & half/Typed from
  `WordInputMode`, tap-to-place/tap-to-return letter tiles (no drag
  gesture, to avoid the extra gesture-handling risk), reading the
  per-weekday mode Settings already stored.
- **Photo import for Add List** -- on-device ML Kit Text Recognition
  (`TextRecognitionService`) via the system camera or gallery picker
  (`ActivityResultContracts.TakePicturePreview`/`GetContent`), the Android
  equivalent of iOS's on-device Vision OCR.
- **Take a Tour onboarding** (`ui/tour/TourScreen.kt`) -- a 10-page,
  skippable `HorizontalPager` walkthrough narrated by Speagle, reachable
  any time from a "Take a Tour" button in Settings, plus a dismissible
  banner on Home for a new install's first two launches
  (`AppLaunchTracker`, DataStore-backed).
- **App icon** -- the legacy `mipmap-xxxhdpi/ic_launcher.png` is the raw
  1024px iOS icon export dropped in as-is (works, but isn't a proper
  Android adaptive icon). Regenerate via Android Studio's Image Asset
  tool (right-click `res` -> New -> Image Asset) once a dedicated
  foreground/background split exists, the same way the iOS README notes
  the launcher icon is swappable.

## What's next

- **iCloud/cross-device sync** -- intentionally out of scope for this
  port; iOS's CloudKit sync has no direct Android equivalent and each
  platform's data stays device-local.
- Known open bug report: the Settings voice "Preview" button was reported
  not working by a user; unconfirmed whether word playback in Practice is
  also affected. Needs a Logcat capture (filtered on "TextToSpeech") to
  diagnose further.
