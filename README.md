# Z Video Generator

[![Download on the Mac App Store](https://txw.ca/mas-badge.svg)](https://apps.apple.com/ca/app/z-video-generator/id6782761951?mt=12) · [txw.ca/zvg](https://txw.ca/zvg)

A native SwiftUI macOS app that turns a text prompt into a video using the
[Z.AI](https://z.ai) video API. Built for **macOS 26 (Tahoe)** with Apple's
**Liquid Glass** design.

**Bring your own key.** Paste a Z.AI API key once — it's stored in the macOS
Keychain and sent only to `api.z.ai` over HTTPS. There's **no account, no credit
balance, and no middleman**: you pay Z.AI directly at their own rates. No
analytics, no tracking.

> The badge image above is hosted on the project site; if you're reading this
> on GitHub and it doesn't render, the App Store link is
> <https://apps.apple.com/ca/app/z-video-generator/id6782761951?mt=12>.

## Get it

- **Mac App Store** (easiest): [Z Video Generator](https://apps.apple.com/ca/app/z-video-generator/id6782761951?mt=12)
- **Build from source:** clone this repo and follow [Build & run](#build--run).
- **Get a Z.AI key:** <https://z.ai>

## Requirements

- macOS 26 (Tahoe)+
- Xcode 26 (command-line tools build fine; full Xcode only for App Store signing)
- [`xcodegen`](https://github.com/yonaskolb/XcodeGen): `brew install xcodegen`
- A Z.AI API key (format `id.secret`)

## Build & run

```bash
brew install xcodegen            # one-time
xcodegen generate                # regenerate ZVideoGenerator.xcodeproj from project.yml
xcodebuild -project ZVideoGenerator.xcodeproj -scheme ZVideoGenerator \
    -configuration Release -derivedDataPath build build
open build/Build/Products/Release/ZVideoGenerator.app
```

The Release build is ad-hoc signed, so it runs on your Mac without a developer
account. The sandbox + network + user-selected-file entitlements are embedded.

First launch: open **Settings** (⌘,) or the key button, paste your Z.AI key,
write a prompt, and **Generate**. The app polls until the clip is ready, plays it
inline, and saves the `.mp4` via a standard save panel. Up to eight jobs run in
parallel, and in-progress renders resume after a quit-and-relaunch.

### Regenerating the project

`project.yml` is the source of truth. After editing it (or adding a Swift file),
re-run `xcodegen generate`. Don't hand-edit `project.pbxproj`.

## Features

- Up to **8 parallel** generations, throttled to Z.AI's limits
- Resolutions up to **4K**, landscape to portrait, 30 / 60 fps, optional audio
- **Prompt library** — save a prompt with its full settings and reuse it
- **Survives restarts** — in-progress jobs resume after quit / relaunch
- **Demo mode** — try it without a key (plays bundled sample clips)
- Liquid Glass UI, adaptive light/dark

## Privacy

The only network destination is `api.z.ai`. Your API key lives in the macOS
Keychain (`kSecAttrAccessibleWhenUnlocked`, not synced across devices) and is
never logged, bundled, or sent anywhere else. App Sandbox is on; the only
entitlements are outbound network and user-selected file writes (for Save).
Full policy: <https://txw.ca/zvg/privacy>.

## Architecture

```
Sources/
  JWTSigner.swift            HS256 JWT for Z.AI bearer auth (CryptoKit; mirrors the Python SDK)
  ZAIClient.swift            async REST client — POST /videos/generations, GET /async-result/{id}
  VideoModels.swift          Codable request/response models
  KeychainStore.swift        stores the API key in Keychain
  AppModel.swift             @Observable app state, generation + polling, demo mode
  ZVideoGeneratorApp.swift   @main entry
  ContentView.swift          NavigationSplitView shell (Liquid Glass sidebar)
  GenerationView.swift       prompt + parameters form, glass cards
  VideoPlayerView.swift      AVKit playback + save panel
  APIKeySheet.swift          API key entry → Keychain
  SettingsView.swift         default model / aspect / resolution / fps / etc.
  HistoryView.swift          past generations
  LibraryView.swift          saved prompts
```

- Polling runs in a cancellable `Task` on a `@MainActor @Observable` model, so
  all UI state mutations are main-thread safe.
- `JWTSigner` reproduces the Z.AI SDK's HS256 signing exactly (header
  `{"alg":"HS256","sign_type":"SIGN"}`, payload `{api_key, exp, timestamp}` in
  milliseconds).
- State persists as JSON in the sandbox container and re-attaches polling to any
  in-progress job on launch.

A minimal Python CLI example is in [`examples/z.py`](examples/z.py) — set
`ZAI_API_KEY` in your environment first.

## License

Copyright © 2026 Alexander Ruppel. Licensed under the
[GNU Affero General Public License v3.0](LICENSE).

In short: you can use, study, modify, and share this code — but if you
distribute it (including running a modified version as a network service), you
must release your changes under the same license.

The Mac App Store build is distributed by the copyright holder under separate
terms; the AGPL-3.0 applies to the source code in this repository.
