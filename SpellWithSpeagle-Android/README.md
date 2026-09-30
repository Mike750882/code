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

## What's next

Not yet built -- the natural next rounds, same shape as the iOS feature
list in `../SpellWell/README.md`:

- **Parent PIN gate UI** -- `PinService` exists but nothing calls it yet;
  no PIN-entry pad, no "Settings/Add List/Rewards are gated" enforcement.
- **Add spelling list** screen (word grid, per-word hint field, photo
  import via CameraX/ML Kit text recognition as the on-device OCR
  equivalent of iOS's Vision framework).
- **Rewards** screen (per-weekday reward text + threshold, weekly prize
  editor) -- the data model and Home's read side already exist, just no
  editor UI yet.
- **Settings** screen -- voice picker + preview, color theme picker, PIN
  change, practice-schedule (the four `WordInputMode`s -- already modeled
  in `data/model/WordInputMode.kt` -- aren't wired into Practice's UI yet,
  which currently always shows a plain typed field regardless of
  weekday), Friday reminder toggle (`WorkManager` + a notification channel
  is the natural fit), hints-during-test toggle, progress report chart.
- **Multiple profiles UI** -- `ActiveChildStore`/`SpellingRepository`
  support it (each `Child` is already fully isolated), but there's no
  profile switcher/manager screen yet.
- **Letter-tile input modes** -- Practice currently always uses a typed
  field; the scaffolded/full-tiles/half-and-half modes from iOS still
  need a Compose equivalent of the drag-and-drop letter tiles.
- **App icon** -- the legacy `mipmap-xxxhdpi/ic_launcher.png` is the raw
  1024px iOS icon export dropped in as-is (works, but isn't a proper
  Android adaptive icon). Regenerate via Android Studio's Image Asset
  tool (right-click `res` -> New -> Image Asset) once a dedicated
  foreground/background split exists, the same way the iOS README notes
  the launcher icon is swappable.
