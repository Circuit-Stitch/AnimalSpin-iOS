# CLAUDE.md

Guidance for Claude Code (claude.ai/code) when working in this repository.

## What this is

Animal Spin — an offline iOS app for toddlers (1.5+). Tap an animal → a voice speaks its name
(Text-to-Speech) → a random recorded animal sound plays. No internet, no ads, no tracking.
SwiftUI + MVVM, `AVSpeechSynthesizer` for the spoken intro and `AVAudioPlayer` for the recorded
clips. This is a from-scratch iOS port of the Android app at `~/Code/AnimalSpin`
(github.com/Circuit-Stitch/AnimalSpin); that repo is the behavioral reference.

## Commands

The Xcode project is **generated** from `project.yml` by [XcodeGen](https://github.com/yonaskolb/XcodeGen)
(`brew install xcodegen`). `AnimalSpin.xcodeproj` is git-ignored — regenerate it, don't edit it.

```bash
xcodegen generate                 # (re)generate AnimalSpin.xcodeproj from project.yml — run after adding/removing files
# build for a simulator
xcodebuild -project AnimalSpin.xcodeproj -scheme AnimalSpin \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
# run the unit tests
xcodebuild -project AnimalSpin.xcodeproj -scheme AnimalSpin \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test
# build + sign for a connected device (needs a logged-in Apple ID / team — see Environment)
xcodebuild -project AnimalSpin.xcodeproj -scheme AnimalSpin \
  -destination 'generic/platform=iOS' -allowProvisioningUpdates build
# install + launch on a device with devicectl
xcrun devicectl device install app --device <UDID> <AnimalSpin.app>
xcrun devicectl device process launch --device <UDID> com.circuitstitch.toys.animals
```

**Toolchain:** Xcode 26.x, Swift 6 compiler in **Swift 5 language mode** (`SWIFT_VERSION = 5.0`,
`SWIFT_STRICT_CONCURRENCY = minimal`) — chosen deliberately so the AVFoundation delegate callbacks
don't fight strict-concurrency checking. Deployment target **iOS 17.0** (for the Observation
framework `@Observable`, `NavigationStack`, String Catalogs, `scrollBounceBehavior`). Universal
(iPhone + iPad), `TARGETED_DEVICE_FAMILY = 1,2`.

**Bundle id / naming:** `applicationId` is `com.circuitstitch.toys.animals` (matches the Android
app). The Xcode "namespace" is the Swift module `AnimalSpin`. Signing team `GDV76FJJZ5` (the
`com.circuitstitch.*` org, shared with the "deferno" app).

## Architecture

Single-window SwiftUI app. `AnimalSpinApp` (`@main`) configures the audio session for `.playback`
(so a tap makes sound even with the mute switch on) and shows `RootView` full-screen with the
status bar + home indicator hidden (the immersive, hard-to-exit canvas that replaces the Android
fullscreen/no-action-bar window). `RootView` is a `NavigationStack` with two routes — `MainView`
(start) and `SettingsView` — mirroring the Android `NavHost`.

Android → iOS mapping:

| Android | iOS |
|---|---|
| Kotlin / Jetpack Compose | Swift / SwiftUI |
| Navigation-Compose `NavHost` | `NavigationStack` |
| `ViewModel` (MVVM) | `@Observable` classes held by `@State` |
| `TextToSpeech` | `AVSpeechSynthesizer` |
| `MediaPlayer` | `AVAudioPlayer` |
| `SharedPreferences` | `UserDefaults` (`Preferences`) |
| `R.drawable` / `R.raw` | `Assets.xcassets` / bundled `Sounds/*.mp3` |
| `strings.xml` + `values-<lang>/` | `Localizable.xcstrings` (String Catalog) |
| `Announcer` seam (test double) | `Announcer` protocol (test double) |
| `Timber` | `os.Logger` (`Log`) |

**Content is data-driven, not file-driven.** The source of truth mirrors the Android
`models/Animals.kt`:
- `Sources/Models/Animal.swift` — the `Animal` enum (24 active cases, in display order). Each
  case's `rawValue` is its image-asset name; `ttsKey` derives the `tts_<name>_says` string.
- `Sources/Models/AnimalSounds.generated.swift` — `Animal → [clip resource name]`. **Generated**
  by `tools/gen_assets.py`; do not hand-edit.

To add/curate animals, edit the Android source of truth and re-run the generator (below), or add
an `Animal` case + its image asset + `tts_<name>_says` strings + its clip rows.

**Playback flow** (`MainViewModel.play` → `RealAnnouncer.announce`): pick a *random* clip for the
animal → if TTS is enabled, speak the localized name, then on the synthesizer's `didFinish` play
the clip; if TTS is disabled, skip straight to the clip. Settings are re-read from prefs on every
`announce`, so a change saved in Settings takes effect immediately with no lifecycle plumbing (the
design that fixed the Android app's old "Save does nothing" bug). A new tap flushes the previous
utterance (`stopSpeaking(.immediate)`) *and* stops the current clip. Only the single newest
`pendingUtterance`/`pendingClip` pair may play a clip: a superseded utterance whose `didFinish`
arrives late finds no identity match and is dropped — so a rapid re-tap restarts the intro cleanly
instead of the previous clip barking over the new voice. (We can't rely on `didCancel` firing for a
flushed utterance; AVFoundation sometimes delivers `didFinish` instead.) Delegate callbacks hop to
the main thread so this pending state never races with `announce`.

**TTS voice handling.** `SpeechLanguage.resolved()` picks the spoken language: the device language
when we ship a translation for it AND an installed voice can speak it, else English — matching the
Android `resolveTtsLocale`. `Localization.phrase(key, language:)` reads the phrase from that
language's `.lproj` regardless of the UI locale, so the voice and the text never disagree (the iOS
analogue of Android's `createConfigurationContext`). Rate/pitch map from the Android convention
(0.5–2.0 multiplier, 1.0 = normal) onto `AVSpeechUtterance` in `SpeechTuning`: pitch passes
straight through; rate scales around `AVSpeechUtteranceDefaultSpeechRate`. Settings enumerates
installed voices for the spoken language (`AVSpeechSynthesisVoice.speechVoices()`), grouped by
region.

**The parental gate.** Settings has no on-screen button a toddler could tap. It opens when you
**draw a square anywhere** on the main screen — a passive, non-consuming `simultaneousGesture`
drag observer (so animal taps still play and the grid still scrolls). `SquareDetector.isSquare` /
`rectilinearity` are a verbatim math port of the Android `MainScreen` classifier (rotation-invariant,
robust to sloppy corners). To leave Settings: Save, or the navigation back button.

**Persistence.** `Preferences` wraps one `UserDefaults` store; defaults registered up front
(pitch/speed 1.0, TTS on) match the Android `SharedPreferencesProvider`. `selectedVoiceId` (an
`AVSpeechSynthesisVoice.identifier`) defaults to nil = the system default voice for the language.

**Localization.** `Sources/Resources/Localizable.xcstrings` (String Catalog) holds English + 16
translations, generated from the Android `strings.xml` files by `tools/gen_assets.py`. UI strings
use semantic keys (`Text("settings")`); the spoken phrases are looked up per-language via
`Localization.phrase`. RTL (Arabic) works via SwiftUI's automatic layout mirroring.

## Assets & the generator

`tools/gen_assets.py` parses the Android source and produces everything binary/derived:
- copies the 24 active animal images into `Sources/Resources/Assets.xcassets/*.imageset`
- copies the 172 referenced clips into `Sources/Resources/Sounds/*.mp3`
- builds `AppIcon.appiconset` (1024px, upscaled from the Play Store icon)
- writes `Localizable.xcstrings` from all 17 `strings.xml` files
- writes `Sources/Models/AnimalSounds.generated.swift`

Re-run it after changing the Android source of truth: `python3 tools/gen_assets.py`. It reads the
active animal set straight from `Animals.kt`, so commented-out ("on ice"/"ponytail") animals are
excluded automatically.

## Testing

`Tests/AnimalSpinTests` (XCTest, hosted in the app so bundle resources resolve): catalog integrity
(24 animals, 172 unique decodable clips, every image + English phrase present), clip-selection
(`MainViewModel` with a fake `Announcer`), the square-detector (squares pass at any rotation;
circles/lines/taps fail), the announce path without TTS, and the rate/pitch + persistence mapping.

## Environment caveats (this machine)

Two host-specific gotchas surfaced during the port; **neither is a code problem**:

1. **`~/Library/Developer` is symlinked to an external volume** (`/Volumes/Sandisk1TB`). macOS
   blocks the `CoreSimulatorService` daemon from writing there ("Operation not permitted"), which
   breaks (a) creating any simulator and (b) `actool` compiling the AppIcon (it spins up an
   IB-support simulator device). Fixes: grant `CoreSimulatorService` Full Disk Access, or point the
   CoreSimulator device set + `~/Library/Developer/Xcode/UserData/IB Support` at internal storage.
   The verification for this port used a temporary internal redirect of those two disposable dirs.

2. **Device deploy needs the Apple Developer Program License Agreement accepted** for team
   `GDV76FJJZ5` (Xcode → Settings → Accounts, or developer.apple.com). Until then automatic
   signing fails with "PLA Update available". Simulator builds/tests need no signing.
