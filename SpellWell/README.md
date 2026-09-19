# SpellWell

A SwiftUI + SwiftData/CloudKit iPad and iPhone app that helps kids ages 6-12
practice spelling words, with a parent PIN gate and a daily/weekly rewards
system. Built from a set of six UI mockups (Home, Word practice, Grown-ups
PIN gate, Add spelling list, Rewards, Settings).

## Requirements

- macOS with Xcode 15 or later
- An Apple Developer account (free tier is enough for local device testing;
  a paid account is required to ship to the App Store)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)

This project was written without access to a macOS/Xcode toolchain, so it
has **not been compiled**. Expect a few small fixes on first build — nothing
structural, but don't be surprised by a typo or an API signature mismatch.

## Setup

1. `cd SpellWell && xcodegen generate` — generates `SpellWell.xcodeproj` from
   `project.yml`.
2. Open `SpellWell.xcodeproj` in Xcode.
3. In **Signing & Capabilities**, set your own Team. Xcode will prompt you to
   fix the bundle identifier (`com.yourcompany.SpellWell`) and the iCloud
   container identifier (`iCloud.com.yourcompany.SpellWell`, in
   `SpellWell/SpellWell.entitlements`) to match your account — replace
   `com.yourcompany` throughout with your real reverse-DNS prefix.
4. Build and run on an iPad or iPhone simulator (or a device signed into
   iCloud, to exercise CloudKit sync).

## What's implemented

- **Home** — greeting, streak pill, a Practice/Test mode toggle, big CTA
  card (labeled "Practice spelling list" or "Take spelling test" to match
  the chosen mode), three secondary cards (Add list / Rewards / Settings)
  gated behind the parent PIN, and a row of four daily grade cards
  (Monday-Thursday) below them.
- **"Take a Tour"** — a dismissible banner between the greeting and the
  streak pill, shown only for the app's first two launches
  (`Services/AppLaunchTracker.swift`, backed by `UserDefaults` so it
  resets on reinstall) or until dismissed early. Pulses continuously
  (scale + purple glow, `.repeatForever`) to draw the eye to it. Opens
  `Views/Tour/TourView.swift`: a swipeable, eight-page walkthrough, in the
  order a new user actually encounters things — Welcome, Setting your PIN
  (the first-run PIN-creation flow), the Settings screen (PIN change,
  voice picker, progress report, sync), Practice vs. Test mode (including
  that retaking a test the same day keeps only the most recent grade —
  see `PracticeAttempt.sessionID` below), Hear it/spell it (the
  letter-tile mechanic), Grades and progress (a grade only counts for the
  day it's taken, no backfilling a missed day), Grown-ups only, and
  Rewards (including the per-day accuracy sliders).
  Pages are large-icon illustrations with a title and a couple of
  sentences, **not real screenshots** — this project has no way to
  capture actual running-app screenshots to ship as static images, so
  this is the honest substitute. Also reachable any time from
  **Settings → "Take a Tour"** (an "App tour" row, not launch-limited),
  for anyone who dismissed it early or wants a refresher.
- **Practice / Test modes** (`PracticeMode` in
  `Views/Practice/PracticeView.swift`) — the letter-tile flow (tap to hear
  the word, tap scrambled letters into blanks, undo a placement, check) is
  shared, but checking a word behaves differently per mode:
  - **Practice** — a wrong answer just flashes red; the child can keep
    editing and rechecking the same word until they get it. No grading at
    the end, just the original "All done for today!" screen.
  - **Test** — checking a word, right or wrong, flashes feedback and
    advances to the next one; there's no retrying a word once checked.
    Ends on `PracticeResultsView.swift`: a letter grade and percentage,
    then every word with a green check or red x for right vs. wrong.

  Every check in either mode is recorded as a `PracticeAttempt`, tagged
  with `mode: "practice"` or `"test"` so the two can be told apart later.
  The mode picker resets to Practice each time Home appears — it isn't
  persisted, so it's a real choice made right before starting, not a
  sticky setting.
- **Daily grade cards** — one card per weekday (Monday-Thursday, matching
  the Rewards screen's day range), each showing that day's grade,
  percentage-based caption ("Excellent!" / "Good Job!" / "Getting Better" /
  "Need More Practice!"), and a gold progress bar. Computed only from that
  day's **Test**-mode attempts (`HomeView.testPercent(onWeekday:)`) —
  Practice-mode attempts are deliberately excluded, since unlimited
  retries would make every day read as 100%. A day with no test taken yet
  shows "No test yet" instead of a grade. If a test is retaken the same
  day, only the most recent attempt counts, not a blend of both — every
  `PracticeAttempt` recorded during one `PracticeView` session shares a
  `sessionID`, and `testPercent` uses only the attempts from whichever
  session has the latest timestamp for that day.
- **Shared grading scale** (`DesignSystem/Grading.swift`) — one place for
  the percent-to-letter-grade logic (A+ through F, standard 97/93/90/…
  cutoffs), used by both the results screen and the daily grade cards so
  the same score never shows as two different grades in two places.
- **Grown-ups PIN gate** — 4-digit PIN pad matching the mockup, backed by
  Keychain (`kSecAttrSynchronizable`, so it follows the parent's iCloud
  Keychain across their own devices, not the child's data).
- **Add spelling list** — word-count stepper, numbered word grid, "Save
  list" writes the words and returns to Home. **"Import a list"** takes or
  picks a photo of a printed or handwritten word list and reads it with
  Apple's on-device Vision OCR (`Services/TextRecognitionService.swift`) —
  no third-party library, no network call, the photo never leaves the
  device. It offers "Take Photo" (via `Views/AddList/CameraCapture.swift`,
  a `UIImagePickerController` wrapper since SwiftUI's own `PhotosPicker`
  can only select existing photos, not capture new ones) and "Choose from
  Library" (SwiftUI's native `PhotosPicker`); recognized words replace the
  current draft. **The Simulator has no camera** — "Take Photo" only
  appears when `UIImagePickerController.isSourceTypeAvailable(.camera)` is
  true, so test the photo import via "Choose from Library" there (drag a
  photo of a word list into the Simulator's Photos app first), and test
  "Take Photo" on a real device.
- **Rewards** — per-weekday reward text + accuracy threshold slider, plus a
  weekly prize card with its own threshold. The whole screen scrolls as one
  unit (`.scrollDismissesKeyboard(.interactively)`) so a text field being
  edited can scroll clear of the keyboard — this and Add List both used to
  wrap only their middle section in a `ScrollView` while the header/footer
  sat fixed outside it, which let the keyboard cover fields in landscape,
  where there's much less vertical room.
- **Settings** — text-size slider with a live preview using a real list word
  ("friend"), a **Voice** picker (see below), light/dark picker, PIN change,
  a Sync row, and a one-line progress summary computed from this week's
  `PracticeAttempt` records, with
  a **"View report"** link into `ProgressReportView.swift` — a full
  week-by-week breakdown (one row per `WeekList`, correct/total and a
  percentage) covering every week the child has had, not just this one.
  Counts every `PracticeAttempt` regardless of Practice/Test mode, since
  it's meant as an activity view rather than a graded score (that's what
  the daily grade cards on Home are for). Reached with a plain
  `NavigationLink` rather than another PIN prompt, since Settings itself is
  already gated to get there. **Tapping a week expands it** (a chevron
  rotates, tracked by `expandedWeekIDs: Set<UUID>` keyed off `WeekList.id`)
  to list every word from that list with a green check/red x/gray dash for
  correct/incorrect/never-attempted, using each word's *most recent*
  attempt so a word retried until right shows as correct rather than
  showing every retry.
- **Voice picker** — a curated shortlist (`SettingsView.allowedVoiceNames`):
  Tessa, Superstar, Samantha, Rishi, Moira, Kathy, Karen, Junior, Fred, and
  Daniel, in that order, filtered down to whichever are actually installed
  on the device (the Simulator ships far fewer voices than a real device,
  so some may not appear there). "Preview" speaks "Spell Well" in the
  selected voice before committing to it. The choice is stored as
  `Child.voiceIdentifier` (an `AVSpeechSynthesisVoice.identifier`, syncing
  like everything else) and used in `PracticeView`'s "tap to hear the word"
  button; empty/unresolvable falls back to the device's default voice
  (`SpeechService.speak(_:customAudioData:voiceIdentifier:)`).
- **Sync status + "Sync now"** — `CloudSyncMonitor` (in
  `Services/CloudSyncMonitor.swift`) observes
  `NSPersistentCloudKitContainer.eventChangedNotification`, the notification
  SwiftData's CloudKit integration posts under the hood, and shows it as
  "Up to date · 2 min ago" / "Syncing…" / "Couldn't sync: …" on the Sync
  row. There's no public API to force CloudKit to *pull* on demand — "Sync
  now" calls `modelContext.save()`, which queues any pending local edits
  for export right away instead of waiting for the system's own schedule.
  Requires the iCloud capability to actually be signed and working (see
  Setup above) to show anything other than "Not synced yet."
- **Data model** — `Child`, `WeekList`, `SpellingWord`, `PracticeAttempt`,
  `DailyReward`, `WeeklyPrize`, all SwiftData `@Model` types configured for
  automatic CloudKit sync (`ModelConfiguration(cloudKitDatabase: .automatic)`
  in `SpellWellApp.swift`).
- **One keypad everywhere** — `PINPad.swift` is the single custom keypad
  matching the mockup (masked dot row + number grid), shared by
  `ParentGateView` (verifying a PIN) and `SetPINView` (setting one). Every
  PIN entry screen in the app now looks identical; nothing falls back to
  the system keyboard/SecureField.
- **First-run PIN creation & "Change PIN"** — the mockups only show PIN
  *entry*; the app also needs a way to set one. `SetPINView.swift` is a
  shared two-step "enter it, then confirm it" flow built on `PINPad`, used
  both in place of the gate the first time any grown-up screen is opened,
  and from Settings' "Change PIN" button.
- **Every visit is gated** — the PIN is checked on every entry into Add
  List, Rewards, or Settings; unlocking one screen never carries over to
  another or to a later visit to the same one (`ParentGate.verify`, called
  fresh each time from `ContentView.requestGatedAccess`).
- **"Forgot your PIN?"** now does something: it's gated by the device's own
  Face ID/Touch ID/passcode (`Services/DeviceAuthService.swift`, Apple's
  LocalAuthentication framework), not just a tap — otherwise a child could
  reset the PIN themselves. Only once that verification succeeds does
  `ContentView` swap the sheet over to `SetPINView` to choose a new PIN. If
  the device has no passcode/biometric set up at all, it shows an alert
  explaining that instead of silently doing nothing.
- **Back button no longer overlaps the custom title** — none of the pushed
  screens (Add List, Rewards, Settings, Progress Report, Edit Name,
  Practice) ever set a `.navigationTitle`, so the system back button had
  no navigation bar to sit in and floated as a bare circle directly over
  each screen's own custom-drawn title text at the top. All six now set
  `.navigationTitle("") .navigationBarTitleDisplayMode(.inline)` so the
  system properly reserves bar space for the back button above the
  content. Practice also sets `.navigationBarBackButtonHidden(true)`
  since it already has its own "< Home" control — otherwise the app
  would show two back buttons stacked there.

## What's stubbed / left for you to finish

- **"Forgot your PIN?"** on the gate screen is a no-op. Needs a real
  recovery flow (e.g. re-verify via the parent's Apple ID/email, or a
  security question set at PIN creation).
- **Voice recording** ("tap a word to record your own voice") — the service
  layer exists (`AudioRecorderService.swift`) but isn't wired into any UI
  control yet. It should attach to each word row on the Add List screen and
  write into `SpellingWord.customAudioData`.
- **Streak logic** — `Child.currentStreak` exists as a field but nothing
  increments it yet. Needs a daily job (e.g. on app launch, check whether
  yesterday's goal was met) to update it.
- **Reward "earned" state** — `DailyReward`/`WeeklyPrize` store thresholds,
  and Home computes a live percentage, but nothing yet marks a specific day
  as earned/unearned for the "Movie night on Friday" style copy shown on the
  mockup's secondary card ("Earned at 80% for the week. You are at 76%.").
- **Apple's kids-category review**: a bare 4-digit PIN is generally fine to
  gate content, but if you ever add purchases or outbound links behind it,
  add an extra "prove you're an adult" step (e.g. a math challenge) — Apple
  scrutinizes plain PINs more closely once money or external links are
  involved.

## Design system

`DesignSystem/Theme.swift` centralizes the visual language pulled from the
mockups: a serif display face (`design: .serif`, i.e. Apple's New York) for
headlines, system sans for body/UI text, an off-white background, and three
accent colors — coral for primary actions, blue for streak/audio/info,
purple for the letter-tile game and reward sliders.
