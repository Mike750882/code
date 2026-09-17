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
  the chosen mode), and three secondary cards (Add list / Rewards /
  Settings) gated behind the parent PIN.
- **Practice / Test modes** (`PracticeMode` in
  `Views/Practice/PracticeView.swift`) — the letter-tile flow (tap to hear
  the word, tap scrambled letters into blanks, undo a placement, check) is
  shared, but checking a word behaves differently per mode:
  - **Practice** — a wrong answer just flashes red; the child can keep
    editing and rechecking the same word until they get it. No grading at
    the end, just the original "All done for today!" screen.
  - **Test** — checking a word, right or wrong, flashes feedback and
    advances to the next one; there's no retrying a word once checked.
    Ends on `PracticeResultsView.swift`: a letter grade (A-F on the usual
    90/80/70/60 cutoffs) and percentage, then every word with a green
    check or red x for right vs. wrong.

  Every check in either mode is recorded as a `PracticeAttempt` for
  progress tracking. The mode picker resets to Practice each time Home
  appears — it isn't persisted, so it's a real choice made right before
  starting, not a sticky setting.
- **Grown-ups PIN gate** — 4-digit PIN pad matching the mockup, backed by
  Keychain (`kSecAttrSynchronizable`, so it follows the parent's iCloud
  Keychain across their own devices, not the child's data).
- **Add spelling list** — word-count stepper, numbered word grid, saves into
  a `WeekList`/`SpellingWord` graph.
- **Rewards** — per-weekday reward text + accuracy threshold slider, plus a
  weekly prize card with its own threshold.
- **Settings** — text-size slider with a live preview using a real list word
  ("friend"), light/dark picker, PIN change, a Sync row, and a one-line
  progress summary computed from this week's `PracticeAttempt` records.
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
- **First-run PIN creation** — the mockups only show PIN *entry*; the app
  also needs a way to set the PIN the first time. `CreatePINView` (in
  `ParentGateView.swift`) is shown in place of the gate until a PIN exists.
- **Every visit is gated** — the PIN is checked on every entry into Add
  List, Rewards, or Settings; unlocking one screen never carries over to
  another or to a later visit to the same one (`ParentGate.verify`, called
  fresh each time from `ContentView.requestGatedAccess`).

## What's stubbed / left for you to finish

- **"Forgot your PIN?"** on the gate screen is a no-op. Needs a real
  recovery flow (e.g. re-verify via the parent's Apple ID/email, or a
  security question set at PIN creation).
- **"Import a list"** on Add List is a no-op. Needs a document/CSV picker.
- **Voice recording** ("tap a word to record your own voice") — the service
  layer exists (`AudioRecorderService.swift`) but isn't wired into any UI
  control yet. It should attach to each word row on the Add List screen and
  write into `SpellingWord.customAudioData`.
- **"View report"** on Settings is a no-op. Needs a dedicated week-by-week
  progress screen (the underlying `PracticeAttempt` data is already there to
  build it from).
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
