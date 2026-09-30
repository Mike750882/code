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

## What's implemented (first vertical slice)

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
- **Settings** (`ui/settings`) -- color theme picker (4 swatches), voice
  picker + "Preview" (speaks "Spell With Speagle"), per-weekday practice
  schedule (`WordInputMode` chips for Monday-Thursday), hints-during-test
  toggle, Friday reminder toggle (persisted, not yet wired to an actual
  notification -- see below), "Change PIN," and a plain-text progress
  summary (one line per week, correct/total) in place of a chart for now.
- **Multiple profiles support** in the data layer
  (`ActiveChildStore`/`SpellingRepository`, each `Child` fully isolated)
  -- still no switcher/manager *screen* to add or change which profile is
  active (see below).
- **Multiple profiles UI** -- add-a-sibling / switch-profile / remove
  screen (`ProfilesView` on iOS). The data layer already supports it.
- **Letter-tile input modes** -- Practice currently always uses a typed
  field, regardless of what Settings' practice-schedule picker says;
  `WordInputMode` is stored and editable, just not read by Practice yet.
  The scaffolded/full-tiles/half-and-half modes from iOS still need a
  Compose equivalent of the drag-and-drop letter tiles.
- **Friday reminder notifications** -- the toggle in Settings persists
  `Child.fridayNotificationEnabled`, but nothing schedules an actual
  notification yet. `WorkManager` + a notification channel is the natural
  fit (the local, on-device equivalent of iOS's
  `UNCalendarNotificationTrigger`).
- **Photo import for Add List** -- iOS uses on-device Vision OCR;
  CameraX + ML Kit Text Recognition is the Android equivalent, not wired
  up here yet.
- **Progress report chart** -- Settings currently shows a plain per-week
  text summary instead of the graphical chart iOS's `ProgressReportView`
  has.
- **App icon** -- the legacy `mipmap-xxxhdpi/ic_launcher.png` is the raw
  1024px iOS icon export dropped in as-is (works, but isn't a proper
  Android adaptive icon). Regenerate via Android Studio's Image Asset
  tool (right-click `res` -> New -> Image Asset) once a dedicated
  foreground/background split exists, the same way the iOS README notes
  the launcher icon is swappable.
