# Animal Spin (iOS)

Tap the picture of an animal to hear its name and the sound it makes.

A simple, offline educational app for children ages 1.5+, letting them listen to the noises
different animals make. Text-to-Speech introduces each animal. This is the **iOS/SwiftUI port**
of the [Android Animal Spin app](https://github.com/Circuit-Stitch/AnimalSpin).

## Features

- 24 animals — a tap-and-listen interface of full-screen photos
- Offline only — no internet connection required
- So simple a 1-year-old can use it
- Text-to-Speech voice customization (voice, pitch, speed presets) — and TTS can be turned off
- Immersive full-screen UI (status bar + home indicator hidden) to avoid accidental exits
- A hidden **parental gate** — draw a square anywhere to reach Settings (no button a toddler can tap)
- Speaks in the device language (17 languages), falling back to English
- No advertising, no tracking
- Plays even with the ring/silent switch off (it's a soundboard toy)

## Requirements

- Xcode 26+ / iOS 17+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)

## Build & run

```bash
xcodegen generate     # generate AnimalSpin.xcodeproj from project.yml
open AnimalSpin.xcodeproj
# or from the CLI:
xcodebuild -scheme AnimalSpin -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test
```

See [CLAUDE.md](CLAUDE.md) for the full architecture, the `tools/gen_assets.py` asset pipeline,
and build/signing notes.

## Content ownership & licensing

All audio and images have a free-to-use origin (Creative Commons or Public Domain); see
[`asset-credits.csv`](asset-credits.csv). Source code is under the same license as the upstream
project ([LICENSE](LICENSE)). Privacy policy: [PRIVACY.md](PRIVACY.md).

If you are the owner of any of the audio or photo content included in this project and wish that it be removed, please open an issue or <a href="mailto:dmca@circuitstitch.com?subject=Content takedown request for Animal Spin App!">send me an email</a> about it with proof of ownership and I'll have it removed promptly.
