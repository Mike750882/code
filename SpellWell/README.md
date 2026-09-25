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

- **App icon** (`Assets.xcassets/AppIcon.appiconset`) — there was no asset
  catalog at all before, so the app used Xcode's default blank icon.
  Added the catalog with a single 1024x1024 universal icon (the modern
  Xcode 14+ format, which generates every other size at build time, so no
  separate 20pt/29pt/40pt/60pt/etc. exports are needed), and
  `ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon` in `project.yml` so Xcode
  actually picks it up as the app's icon. Swap
  `AppIcon.appiconset/AppIcon-1024.png` for a different 1024x1024 PNG
  (no transparency, no pre-rounded corners -- iOS applies the mask
  itself) to change it later.
- **Multiple student profiles on one iPad** — `Child` was always a
  standalone SwiftData model (each with its own `WeekList`s,
  `DailyReward`s, `WeeklyPrize`s, fully isolated), but the UI only ever
  showed `children.first` with no way to add or switch between them. Now:
  - `ContentView.activeChild` resolves which profile is showing, backed by
    `@AppStorage("activeChildID")` — **device-local, not synced**, so a
    family with one iPad per kid can have each default to a different
    student even though every `Child` record itself syncs via CloudKit.
  - First-ever launch (zero children) shows `Views/Profiles/AddChildView.swift`
    directly, no PIN gate — there's nothing to protect yet, and a parent is
    clearly setting the app up for the first time. It replaces the old
    hardcoded "Connor" placeholder.
    **`showsInitialSetupDelay: true`** only on this call site: a brand new
    install briefly has real background work competing for the main
    thread (iCloud provisioning the CloudKit container for the very first
    time), which could make the very first keyboard appearance stutter if
    a child taps straight into the name field. Shows a brief "Just a
    moment..." spinner instead of the interactive field for 3s on appear
    before letting anyone tap in -- an earlier attempt at 1.2s wasn't
    long enough, the field still stuttered on first tap once the spinner
    disappeared, meaning the underlying CloudKit setup was still going.
    3s errs toward safety instead: this only ever happens once per real
    install, never again on a normal cold launch (force-quit and reopen
    without reinstalling), so a few extra seconds here don't cost
    anything in everyday use. Not needed (and not passed) when this same
    view is reused from Settings to add a sibling, since the app is
    already fully up and running by then.
  - **Settings → Student profiles → Manage** opens
    `Views/Profiles/ProfilesView.swift` (no separate PIN gate needed;
    Settings is already gated to get there): lists every profile, tap one
    to switch, "Add a student" to create another (reuses `AddChildView`),
    and a trash icon to remove one (never the last one) with a
    confirmation alert warning it permanently deletes that student's
    lists/rewards/progress via the existing cascade delete rules.
    Switching or removing the active profile pops the navigation stack
    back to Home (`onProfileSwitched`) so the newly active student shows
    immediately.
  - The parent PIN itself stays **shared across all profiles on the
    device** (one Keychain entry) rather than per-child — one parent, one
    PIN, regardless of which kid's data they're editing.
- **Home** — greeting, streak pill, a Practice/Test mode toggle, big CTA
  card (labeled "Practice spelling list" or "Take spelling test" to match
  the chosen mode), three secondary cards (Add list / Rewards / Settings)
  gated behind the parent PIN, and a row of four daily grade cards
  (Monday-Thursday) below them.
  A **"This week's words"** button sits right under the streak pill,
  styled to match it (same capsule/stroke look), deliberately ungated
  (unlike the secondary cards) since it's just a study aid for the child,
  not something that needs a grown-up's PIN. Opens
  `Views/Home/WordListView.swift`: a plain numbered list of this week's
  words, no correct/incorrect info at all -- that lives in the results
  screen and Progress Report, not here.
- **"Take a Tour"** — a dismissible banner between the greeting and the
  streak pill, shown only for the app's first two launches
  (`Services/AppLaunchTracker.swift`, backed by `UserDefaults` so it
  resets on reinstall) or until dismissed early. Pulses continuously
  (scale + purple glow, `.repeatForever`) to draw the eye to it. Opens
  `Views/Tour/TourView.swift`: a swipeable, ten-page walkthrough, in the
  order a new user actually encounters things — Welcome, Setting your PIN
  (the first-run PIN-creation flow), the Settings screen (PIN change,
  voice picker, progress report, sync), More than one student (adding and
  switching profiles from Settings → Student profiles → Manage), This
  week's words (the ungated preview button under the streak pill),
  Practice vs. Test mode (including that retaking a test the same day
  keeps only the most recent grade — see `PracticeAttempt.sessionID`
  below), Hear it/spell it (the letter-tile mechanic), Grades and progress
  (a grade only counts for the day it's taken, no backfilling a missed
  day), Grown-ups only, and Rewards (including the per-day accuracy
  sliders).
  Pages are large-icon illustrations with a title and a couple of
  sentences, **not real screenshots** — this project has no way to
  capture actual running-app screenshots to ship as static images, so
  this is the honest substitute. Also reachable any time from
  **Settings → "Take a Tour"** (an "App tour" row, not launch-limited),
  for anyone who dismissed it early or wants a refresher.
- **Practice / Test modes** (`PracticeMode` in
  `Views/Practice/PracticeView.swift`) — the letter-tile flow (tap to hear
  the word, **tap or drag** scrambled letters into blanks, undo a
  placement, check) is shared, but checking a word behaves differently per
  mode:
  - **Practice** — a wrong answer just flashes red and the child can keep
    editing and rechecking the same word, but a "Skip word" button (mode
    `== .practice` only -- Test never needs it, since checking there
    always advances) means getting it right is never required to move
    on. Only the *first* attempt at each word (right or wrong, whether
    from a check or a skip) counts toward the end-of-session results
    (`recordedFirstAttempt`, reset per word in `setUpWord`), so retries
    afterward don't add duplicate rows, and skipping a word that was
    never checked at all records whatever was arranged/typed so far
    (`skipWord`).
  - **Test** — checking a word, right or wrong, flashes feedback and
    advances to the next one; there's no retrying a word once checked.

  Both modes end on the same `PracticeResultsView.swift`: a letter grade
  and percentage, then every word with a green check or red x, and for
  anything wrong, what the child actually spelled next to the correct
  word. Practice's results are purely a same-session recap, though --
  see below for why they're never saved anywhere.

  Letter placement is slot-indexed (`slotContents: [SlotState]`, one entry
  per blank, `.empty`/`.filled(bankIndex:)`/`.prefilled(Character)` -- see
  "Practice schedule" below), not append-order, so a tile can land in *any*
  blank, not just the next one in line: tapping an unused bank tile fills
  the first empty slot, and a tile can also be dragged straight into a
  specific blank instead, with a purple highlight on whichever slot is
  under the drag.
  Dragging is a plain `DragGesture(minimumDistance: 0)` tracked by hand
  (each slot publishes its frame via a `PreferenceKey`, checked against
  the finger's location) rather than the system `.draggable`/
  `.dropDestination` pair -- those need a brief "hold to lift" press
  before a drag is recognized, which felt sticky for kids just trying to
  slide a tile over. With `minimumDistance: 0` the tile starts moving the
  instant a finger slides, and a tap is handled as the same gesture, just
  one that ends with barely any movement. Tapping a filled slot clears
  just that letter; "Take one back" undoes whichever slot was filled most
  recently (`fillOrder`, a stack of slot indices), regardless of tap vs.
  drag or which slot it was.

  Only **Test** checks are recorded as a `PracticeAttempt` (`mode:
  "test"`) -- Practice never persists anything, since it's just for
  rehearsing and shouldn't follow the child into their permanent progress
  history or count toward any grade; its results screen is built purely
  from this session's local `results` array. The mode picker resets to
  Practice each time Home appears — it isn't
  persisted, so it's a real choice made right before starting, not a
  sticky setting.
- **Practice schedule** — a per-weekday difficulty progression, set by a
  parent in Settings and applied to **both** Practice and Test (they share
  whatever the day says; only the retry/grading behavior above differs
  between the two). Each weekday (`Child.inputMode(forWeekday:)`, same
  Monday-Thursday range as the daily grade cards) picks a `WordInputMode`:
  - **Tiles: some letters given** — about half of each word's letters
    start pre-filled and locked (`SlotState.prefilled`, chosen as a random
    half of that word's positions each time); the letter bank only
    contains the *remaining* letters, so there's exactly one tile per
    still-empty blank.
  - **Tiles: fill in every letter** — today's original behavior, unchanged:
    every blank starts empty, the full word's letters are in the bank.
  - **Half tiles, half typed** — each word is independently and randomly
    resolved to one of the other two treatments (`WordInputMode.
    resolvedForWord`), fresh every time that word comes up, so it's not
    always the same words in each half.
  - **Type from memory** — no letter-tile UI at all; a plain text field
    instead (`typedAnswerField`). "Take one back" hides itself on these
    words since there's nothing to undo tile-by-tile.

  **Case sensitivity** (`PracticeView.isAttemptCorrect`) differs by mode.
  A typed answer must match the stored word *exactly*, case included --
  if a parent capitalized a word entering this week's list (a proper
  noun), that capitalization is part of the correct spelling. Tile-built
  answers still compare case-insensitively: tiles are always *displayed*
  uppercase for legibility regardless of a letter's real case, so a child
  has no way to see or choose a tile's case, and enforcing it there would
  turn any word with the same letter repeated in different cases (e.g.
  "Anna") into a coin flip on which visually-identical tile they happened
  to grab rather than a real test of spelling. Since case now genuinely
  matters, every screen that shows a word for review --
  `PracticeResultsView`'s results list (both the correct word and what the
  child typed/assembled), `ProgressReportView`'s word breakdown, and
  `WordListView`'s "This week's words" preview -- shows it in its exact
  stored/typed case instead of `.capitalized` (which would force the rest
  of a word lowercase and could misrepresent the real spelling, or mask a
  case-only mistake from whoever's reviewing).

  Defaults match the progression a parent would set up for a typical week
  (Monday: some letters given, Tuesday: fill in every letter, Wednesday:
  half tiles/half typed, Thursday: type from memory), stored as four flat
  `Child` fields (`mondayInputMode`, etc.) rather than a dictionary, same
  as every other per-child setting on that model — but every day is
  freely reassignable to any of the four modes from Settings, independent
  of the others. Home's practice card subtitle
  (`WordInputMode.homeCardSubtitle`) reflects today's mode too, so a child
  knows what kind of challenge they're in for before they start.
- **Friday's test** — Friday (weekday 6) isn't one of the four adjustable
  practice-schedule days above; it's always **typed from memory**
  (`Child.inputMode(forWeekday:)` special-cases it, unconditionally, ahead
  of the Monday-Thursday switch). This fixed a real bug: Friday used to
  fall through that switch's `default` case, which meant "fill in every
  letter" tiles instead of a real typed test.
  - **Reminder notification** — Settings → "Friday test reminder" lets a
    parent turn on a local, on-device notification ("Practice For Today's
    Test," `NotificationService`) at a time they choose
    (`Child.fridayNotificationEnabled`/`Hour`/`Minute`), firing every
    Friday via a repeating `UNCalendarNotificationTrigger`. Not a server
    push — no backend involved, just the standard iOS notification
    permission prompt (requested the first time the toggle is turned on;
    a denial shows an inline hint to enable it in iOS Settings instead of
    silently doing nothing).
  - **Review-or-test choice screen** (`FridayTestChoiceView`) — tapping the
    notification, or starting a Test normally from Home on a Friday, both
    land here first rather than going straight into `PracticeView`: review
    this week's words (reuses `WordListView`, same as the ungated "This
    week's words" pill), or jump straight into the test. Wired through two
    new pieces on `ContentView`: `NotificationRouter` (an `ObservableObject`
    singleton `AppDelegate` flips when the notification is tapped, since
    that happens outside any SwiftUI view) and a `FridayTestRoute`
    `NavigationStack` destination that both the router and
    `HomeView.onStartFridayTest` push onto.
- **Daily grade cards** — one card per weekday, Monday through **Friday**
  (five now, not four — Friday's card was added once Friday became a real
  typed test day; the Rewards screen's day range is still Monday-Thursday
  only, unrelated to this), each showing that day's grade,
  percentage-based caption ("Excellent!" / "Good Job!" / "Getting Better" /
  "Need More Practice!"), and a progress bar. Computed only from that
  day's **Test**-mode attempts (`HomeView.testPercent(onWeekday:)`) —
  Practice-mode attempts are deliberately excluded, since unlimited
  retries would make every day read as 100%. A day with no test taken yet
  shows "No test yet" instead of a grade. If a test is retaken the same
  day, only the most recent attempt counts, not a blend of both — every
  `PracticeAttempt` recorded during one `PracticeView` session shares a
  `sessionID`, and `testPercent` uses only the attempts from whichever
  session has the latest timestamp for that day.
  A card with at least one missed word is tappable (`onReviewMissedWords`,
  wired through `ContentView`'s `PracticeRoute.restrictToWordIDs`) and
  shows "Retake N missed words" — starts a **Practice**-mode session
  (`HomeView.missedWords(onWeekday:)` finds them from that same latest
  Test session) containing only those words, via a new
  `PracticeView.restrictToWordIDs` filter on the week's full word list.
  Always Practice, never Test, so retaking a handful of missed words can't
  overwrite that day's already-recorded grade with a score based on just
  those few words.
- **Daily reward status on the results screen** — after a **Test** (not
  Practice — see `PracticeResultsView.todaysReward`, gated on
  `mode == .test`), if a grown-up has set a reward for that weekday
  (`Child.dailyRewards`, keyed by weekday only, same lookup Rewards and
  Home already use), the results screen shows whether that score met the
  day's threshold and what the reward is — "Reward earned!" or "Reward not
  quite earned yet," either way naming the goal percent and the reward
  text. No reward set for that weekday just means the banner doesn't show.
- **Fixed: Practice results wrongly kept a word marked incorrect after a
  successful retry** — Practice records only one `WordResult` per word (so
  the end-of-session results screen has one row per word, not one per
  attempt), added the first time that word is checked. But the code never
  updated that entry afterward — get a word wrong, then get it right on a
  retry (without using "Skip word"), and the results screen still showed
  it as wrong, because the *first* attempt's entry was the only one ever
  recorded. Fixed by tracking *which* index in `results` belongs to the
  current word (`currentResultIndex`, replacing a plain
  `recordedFirstAttempt` bool) so a later correct retry can overwrite that
  same entry to `isCorrect: true` instead of leaving the stale wrong one.
- **Streak** (`Child.currentStreak(asOf:)`) — the "N-day streak" pill on
  Home used to be dead: the field existed but nothing ever wrote to it.
  Replaced with a live computed value instead of a stored counter, so it
  can never drift out of sync with what actually happened. A day counts
  if it has at least one **Test**-mode attempt (any test, regardless of
  score -- Practice doesn't count), and only Monday-Friday days count at
  all, matching the daily grade cards' scope (the reward system is still
  Monday-Thursday only, separately); weekends are skipped over rather
  than breaking the streak. Walks backward day by day from today counting
  consecutive qualifying
  school days, stopping at the first one with no test -- except today
  itself, which doesn't break the streak just for not having a test yet,
  since the day isn't over.
- **Shared grading scale** (`DesignSystem/Grading.swift`) — one place for
  the percent-to-letter-grade logic (A+ through F, standard 97/93/90/…
  cutoffs), used by both the results screen and the daily grade cards so
  the same score never shows as two different grades in two places.
- **Grown-ups PIN gate** — 4-digit PIN pad matching the mockup, backed by
  Keychain, local to this device (not iCloud-synced -- each iPad has its
  own PIN, the same way each iPad keeps its own active student profile).
  It used to be synced via iCloud Keychain, but the very first PIN check
  after a fresh install or device restart had to make a synchronous
  round-trip to iCloud before it could answer, which could freeze the app
  for a long time since the check runs right on the main thread from a
  button tap. Not worth it for a PIN that's really just meant to keep a
  kid out of one shared iPad's grown-up screens.
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
  - **Misspelling double check** (`Services/SpellCheckService.swift`) — as
    a parent types (or after a photo import), any word that isn't in the
    system's English dictionary gets flagged: a warning icon next to its
    field and a highlighted border, using `UITextChecker`, the same
    on-device checker behind the red squiggly underline in Notes/Messages
    — no network call, no API key, nothing leaves the device. It's a
    dictionary check, not a "did you mean" check, so it won't catch a typo
    that happens to land on a different real word ("form" instead of
    "from"), and it will flag legitimate things a spelling list often has
    (names, uncommon words) — a nudge to double check, not a hard block.
    Tapping "Save list" with anything still flagged shows a confirmation
    ("Double check these words") with "Review words" or "Save anyway,"
    rather than saving silently or refusing outright.
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
  showing every retry. **Each week also has a trash icon**, matching the
  same delete pattern as Student profiles: a confirmation alert warning
  it permanently deletes that week's spelling list and progress, then
  `modelContext.delete(weekList)` — the existing cascade delete rules
  clean up its `SpellingWord`s and their `PracticeAttempt`s too. (Rewards
  aren't affected: `DailyReward`/`WeeklyPrize` belong directly to `Child`,
  not to a `WeekList`.) The row's tap-to-expand uses `.onTapGesture`
  rather than wrapping the row in a `Button`, so the trash button can sit
  as a sibling inside it instead of a `Button` nested inside a `Button`.
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
- **Background no longer shrinks to fit sparse content** — a bare
  `VStack`/`ScrollView` sizes itself to its content's own width unless
  something forces it wider, so a screen with little horizontal content
  (most visibly Practice's "All done for today!" and Test-results screens,
  which have almost none) only got a background painted behind that
  narrow column, leaving the rest of the screen showing the system's
  default white instead of `Theme.background`. All seven top-level screens
  (Home, Add List, Rewards, Settings, Progress Report, Edit Name, Practice)
  now explicitly add `.frame(maxWidth: .infinity, maxHeight: .infinity)`
  before their `.background(...)`, so the background always fills the full
  screen regardless of how little content is on it.
- **Fixed: Settings and Progress Report titles pushed off-screen** — the
  fix above didn't specify an `alignment` on that `.frame(...)`, and
  SwiftUI's default is `.center`. For a bare, top-anchored `VStack`
  (header first, then rows, with a trailing `Spacer()` to soak up leftover
  space) that centering happens *after* the VStack has already been sized
  to its padded content height, so the whole block — including the header
  — got shoved down toward the middle of the screen instead of staying
  pinned to the top. Only Settings and Progress Report use that exact
  bare-VStack-with-trailing-Spacer shape, so those were the only two
  affected; the other five screens are unaffected either because they're
  `ScrollView`-based (which always claims full height as its own ideal
  size, so it never gets "shrunk then centered") or because they were
  already meant to be centered (Edit Name, and Practice's empty/complete
  states use a `Spacer()` on both ends). Fixed by adding
  `alignment: .topLeading` to Settings' and Progress Report's `.frame(...)`
  calls.
- **Fixed: Settings unreachable rows** — Settings grew past one screen's
  worth of content (color themes, then the four-row practice schedule)
  while still being a bare `VStack`, not a `ScrollView`, so anything that
  didn't fit was simply drawn off the bottom of the screen with no way to
  reach it -- including "Student profiles" once there was enough above it
  to push it past the fold on some devices/text sizes. Converted to the
  same `ScrollView`-wrapped-`VStack` shape every other long screen already
  uses (Profiles, Home, Add List, Rewards), which also means the
  `alignment: .topLeading` workaround from the fix above is no longer
  needed here -- a `ScrollView` never gets "shrunk to content" and
  centered the way a bare `VStack` does, so it was never actually a fix
  for the *layout*, just a workaround for that one bug.
- **iPhone-adaptive layouts** — this app was designed from iPad mockups,
  and several screens used layouts that assumed iPad-width space: fixed
  220pt (or wider) label columns next to a control in Settings, three or
  four cards side by side on Home, a full row of label + text field +
  slider + percent in Rewards, and (worst of all) fixed-size letter tiles
  in a plain `HStack` in Practice, which for a longer word could genuinely
  run off the edge of an iPhone screen rather than just look cramped.
  Fixed via `@Environment(\.horizontalSizeClass)` (`.compact` on iPhone
  portrait and most iPhone landscape, `.regular` on iPad in both
  orientations) throughout:
  - **Settings** — every row now goes through a shared `SettingsRow`
    wrapper: label beside a fixed-width control on regular width, label
    stacked above a full-width control on compact. The color theme
    swatches sit in a horizontal `ScrollView` rather than assuming they
    all fit in one row.
  - **Home** — the header keeps the streak/word-list pills on the right
    on every device now, not conditioned on `horizontalSizeClass` -- that
    isn't actually a reliable "is this an iPad" check (a large iPhone in
    landscape also reports `.regular`), so branching on it here would
    have left some iPhones with a different layout than others depending
    on orientation. The tour banner is a direct sibling of the
    greeting/pills row, not nested inside a VStack alongside the greeting
    -- nested that way it was still only proposed the same narrow width
    that VStack got from sharing a row with the pills (which claim their
    own space regardless of which row visually contains them), so its own
    content (icon, "Take a Tour," an X) didn't have room to lay out
    normally and got truncated. As a direct sibling it's proposed the
    full row's width instead. The practice card's very
    large iPad-sized fonts (a 60pt title down to 32pt) and padding still
    scale down on compact, and the three secondary cards and four daily
    grade cards switched from fixed-count `HStack`s to `LazyVGrid`s.
    These *do* branch on `isCompact` (unlike the header above) --
    `.adaptive(minimum:)` on compact, so cards wrap down to fewer columns
    instead of squeezing three or four into an iPhone-width row, but
    exactly `count: 3` / `count: 4` equal `.flexible()` columns on
    regular, matching the original fixed-width `HStack`s. A pure
    `.adaptive` grid on a *wide* iPad screen computes room for more
    columns than there are actual cards (its minimum is much smaller than
    a third or a quarter of an iPad's width), so the cards ended up
    bunched on the left with empty space on the right instead of spread
    across the full row like before -- this is the one case where the
    landscape-iPhone/regular-size-class quirk that broke the header
    doesn't matter, since a fixed 3- or 4-column layout looks fine on a
    wide landscape iPhone too, not just iPad.
  - **Practice** — `answerSlots` and `letterBank` always lay a word's
    tiles out in a single row rather than wrapping. Wrapping was tried
    first (tiles wrap fine once you can measure the available width
    correctly -- see below), but a child sounding out a word needs to see
    it as one connected line of blanks; splitting it across stacked rows
    works against that, especially mid-word where the break falls in an
    arbitrary place. Instead, `tileMetrics(availableWidth:tileCount:)`
    computes a tile size, spacing, and font for the *specific* word that
    guarantees all of it fits on one line: at the normal 56x64pt/10pt-gap/
    28pt-font size if it fits, otherwise spacing shrinks first (down to a
    4pt floor), then the tiles themselves shrink (scaling height and font
    to match, so a smaller tile still looks like a smaller version of the
    same tile rather than a squished one) until everything fits. Both
    `answerSlots` and `letterBank` are sized off the *word's* full length
    (not the bank's, which is shorter whenever some letters are already
    prefilled), so a bank tile always matches its answer slot's size.
    Getting the available width right (needed regardless of whether tiles
    wrap or shrink) took three tries. The first two both measured it via a
    *separate* layer -- a `.background(GeometryReader { ... })` +
    `PreferenceKey` (tried both before and after
    `.padding(24)`/`.frame(maxWidth: .infinity)` resolved the view's final
    size) and, next, `onGeometryChange` (iOS 17+) -- and both reported a
    near-zero width on device regardless of where in the chain they sat; a
    full delete-and-reinstall each time ruled out a stale build as the
    cause. The working fix (third try) uses a `GeometryReader` as `body`'s
    top-level container instead of a measurement-only background layer:
    `tileMetrics` is computed directly from that `GeometryReader`'s
    `proxy.size.width` in the same render pass -- no `@State` round-trip,
    no separate layer whose sizing could disagree with the foreground
    content's. (A temporary `#if DEBUG`-only `Text` above the word showed
    the live measured width and chosen tile width on screen while this was
    being tracked down, confirmed working on device, then removed.)
  - **Practice results** (`PracticeResultsView.swift`) — used to be a
    fixed-height (`maxHeight: 320`) `ScrollView` around just the word
    list, sitting under a non-scrolling score card. In landscape on an
    iPhone (much less vertical room than portrait), the score card alone
    could take up nearly all the available height, squeezing the word
    list down to barely any of its own 320pt cap with the rest of the
    words unreachable. The whole screen scrolls now instead -- the score
    card, word list, and button are all one `ScrollView`'s content, so
    there's no fixed sub-region to run out of room.
  - **Add List** — the header (title + word-count stepper) and footer
    (caption + Import/Save buttons) stack on compact instead of forcing
    one wide row; the word grid's column width shrinks from 200pt to
    140pt minimum on compact so more of them fit per row.
  - **Rewards** — the biggest offender: each daily row's fixed 160pt
    label + 180pt slider + 70pt percent text (all beside a text field)
    added up to far more than an iPhone's width. On compact, the label
    and percent share a row, then the text field and slider each get
    their own full-width row below. The weekly prize card and footer
    stack similarly.

## What's stubbed / left for you to finish

- **"Forgot your PIN?"** on the gate screen is a no-op. Needs a real
  recovery flow (e.g. re-verify via the parent's Apple ID/email, or a
  security question set at PIN creation).
- **Voice recording** ("tap a word to record your own voice") — the service
  layer exists (`AudioRecorderService.swift`) but isn't wired into any UI
  control yet. It should attach to each word row on the Add List screen and
  write into `SpellingWord.customAudioData`.
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
headlines, system sans for body/UI text, and a small set of *role-based*
colors (`Theme.background`, `Theme.primary`, `Theme.action`, `Theme.tile`,
`Theme.reward`, etc.) rather than colors named after their hue -- a role
keeps its meaning (`Theme.action` is always "the main kid-facing action
color") even though the actual hex behind it changes per theme. This
followed a parent-supplied theme token spec (role names + hex values per
theme); fonts from that spec (Exo 2/Nunito, Playfair Display/Lora, Alfa
Slab One/Nunito) were intentionally *not* bundled -- every theme still uses
the app's existing serif/system font pairing, colors only.

- **Color themes** — Settings → "Color theme" lets a parent pick a whole
  color set for that student, applied everywhere in the app. Each `Theme`
  color is a computed `static var` that reads from `Theme.currentProfile`,
  a `ColorProfile` (`DesignSystem/Theme.swift`) bundling a background/
  surface/surfaceRaised/hairline/text/textSecondary set (each light+dark
  adaptive) plus five single-value accents: `primary` (navigation,
  progress, Save/Done buttons, lock badges), `action` (the Practice card,
  "Check my word"), `tile` (letter-tile border, reward sliders, decorative/
  Settings icons), `reward` (weekly-prize border and progress fill, plus
  `rewardFill`/`rewardIcon`/`rewardText` for its card background, star
  icon, and label text specifically). Two colors -- `Theme.success` and
  `Theme.error`, for right/wrong feedback -- are fixed constants on `Theme`
  itself rather than part of `ColorProfile`: a child needs "right" vs
  "wrong" to always read the same way regardless of which decorative theme
  is active, and the source token spec didn't define role names for that
  pair at all.
  `Child.colorProfile` stores which one (`ColorProfile.id`) a student has
  picked, defaulting to `"default"` (today's original palette, unchanged --
  the only profile that still adapts to the system's light/dark setting).
  `ContentView.body` applies it each render (`Theme.apply(profileID:)`,
  called as a `let _ =` side effect) and keys `.id()` on the whole tree to
  the profile, since static properties aren't environment-driven and
  nothing already on screen would otherwise know to re-read them when it
  changes — that `.id()` forces a full rebuild so every view picks up the
  new colors immediately, including ones currently visible.
  `ColorProfile.all` currently lists `.default`, `.space` (dark, starry
  blues/purples), `.princess` (soft pink/purple, light), and `.circus`
  (warm carnival-poster reds/blues/teals/golds, light) -- the last three
  each fix their own light/dark values (all their token spec's colors were
  single values to begin with), so their struct fields just repeat the same
  hex for both the light and dark slot. `Happy`, the old `Circus`, and
  `Focus` were retired in the same change; more themes (a parent supplies
  the hex values for each role) get added the same way.
  Borders (`hairline`) are one more simplification: the source spec calls
  for the same hairline hue at three different opacities depending on
  context (12% for row rules, 16% for section rules, 28% for card/field
  borders), but this app doesn't distinguish those contexts anywhere today,
  so `ColorProfile.hairlineOpacity` collapses that to one flat value per
  profile -- 1.0 for Default (whose hairline hexes are already subtle,
  pre-blended colors meant to be drawn solid, unchanged from before this
  token system existed) and 0.28 (the "card/field borders" tier, the
  dominant real usage in this codebase) for Space/Princess/Circus, whose
  spec instead gives one bold hue meant to be washed out with opacity.
