# Quill — A free, open-source, cross-platform note-taking app

> *"天下苦 GoodNote 流氓收费已久"* — Quill is a Material 3 note-taking app
> built in Flutter that aims to give you GoodNote's experience without the
> subscription lock-in.

Quill is **iPad-first**: the layout adapts from a phone-sized bottom nav,
to a tablet-sized two-pane NavigationRail view, to a full desktop shell.

## ✨ Features

### Phase 1 — MVP
- 📝 **Rich-text notes** powered by `flutter_quill` (full toolbar: headings,
  lists, check lists, code blocks, quotes, formatting).
- 🗂 **Folders & tags** — drag notes into folders, label them with tags, see
  counts in the sidebar.
- 🔍 **Full-text search** — debounced, title + preview matching, no backend
  required.
- 🌗 **Material You** — full M3 type scale, motion, and components. Dynamic
  color on Android 12+ and iOS where supported.
- 💾 **Local-first storage** — SQLite via Drift, with room to grow to PDF
  and image blobs on the filesystem.
- 📱 **Responsive shell** — `NavigationBar` on phones, `NavigationRail` on
  tablets, side-by-side panes on desktop.
- 🧵 **Auto-save** in the editor — Quill Delta JSON stored in SQLite,
  preview text generated for fast list rendering.
- 🎨 **Brand seed** `#6750A4` (ink violet), with `dynamic_color` override.

### Phase 2 — Handwriting
- ✍️ **Apple Pencil canvas** — pressure-aware, tilt-aware, palm-rejection.
  `perfect_freehand` produces vector strokes that stay crisp at any zoom.
- 🖌 **Brush picker** — pen, pencil, highlighter, eraser · 8 colours ·
  size slider.
- 📓 **Multi-page notebooks** — top-bar page indicator, add / delete /
  navigate. Each page is its own Drift row, so a single notebook scales
  to hundreds of pages without slowing the dashboard.
- 🔀 **Tab switching** — every note has a `kind` (`text` or `drawing`).
  The editor routes to the Quill rich-text view or the notebook canvas.
- 🆕 **New drawing** entry from the dashboard's + menu.

### Phase 3 — Cloud sync
- ☁️ **OneDrive (Microsoft 365 E3 / personal)** — Microsoft Graph API
  via OAuth 2.0 + PKCE (`flutter_appauth`). No client secret required.
  Automatic refresh-token rotation. Per-file `If-Match` etag check.
- 🍎 **iCloud Drive** — file-based via the iOS / macOS ubiquity container.
  Enable *iCloud Drive → Quill* in Settings and the OS handles sync.
- 🔁 **Last-write-wins** reconciliation. Heal-pull repairs torn writes
  automatically when both sides are clean.
- 📊 **Sync badge** in the editor's app bar — `localOnly` / `dirty` /
  `synced` / `syncing`.
- 🛡 **Versioned payload** (`qnote.json` / `qpage.json`) — schema v1,
  forward-compatible.

## 🏗 Architecture

```
lib/
├── app/                # MaterialApp + theming + router
│   ├── theme/          # FlexColorScheme + typography (Inter + Newsreader)
│   ├── router.dart     # go_router with StatefulShellRoute
│   └── app.dart        # Root widget
├── core/
│   ├── providers/      # Riverpod providers (DB, settings, repos, cloud)
│   └── utils/          # Responsive breakpoints, date formats
├── data/
│   └── database/       # Drift DB + DAOs (notes, folders, tags, drawing_pages)
└── features/
    ├── home/           # AppShell (NavigationRail / NavigationBar)
    ├── dashboard/      # Main home screen
    ├── folders/        # Folder detail page
    ├── tags/           # Tag detail page
    ├── search/         # Search results
    ├── editor/         # Rich-text editor + drawing editor dispatch
    ├── canvas/         # Handwriting canvas + brush picker + notebook editor
    ├── cloud/          # CloudProvider (OneDrive, iCloud), SyncEngine
    └── settings/       # Theme + cloud sync + about
```

## 🏗 Architecture

```
lib/
├── app/                # MaterialApp + theming + router
│   ├── theme/          # FlexColorScheme + typography (Inter + Newsreader)
│   ├── router.dart     # go_router with StatefulShellRoute
│   └── app.dart        # Root widget
├── core/
│   ├── providers/      # Riverpod providers (DB, settings, repos)
│   └── utils/          # Responsive breakpoints, date formats
├── data/
│   └── database/       # Drift DB + DAOs (notes, folders, tags)
└── features/
    ├── home/           # AppShell (NavigationRail / NavigationBar)
    ├── dashboard/      # Main home screen
    ├── folders/        # Folder detail page
    ├── tags/           # Tag detail page
    ├── search/         # Search results
    ├── editor/         # Rich-text editor
    └── settings/       # Theme + about
```

**State management:** `flutter_riverpod` (StreamProviders for DB reactivity).

**Persistence:** `drift` (type-safe SQL) with `sqlite3_flutter_libs`. Heavy
artifacts will live on disk in future phases.

**Theming:** `flex_color_scheme` for opinionated M3 sub-themes, layered with
`google_fonts` (Inter body / Newsreader display). `dynamic_color` produces a
fully-harmonized palette on Android 12+.

## 🛠 Getting started

```bash
# 1. Install Flutter 3.44.x or later
# 2. Install the dependencies
flutter pub get

# 3. Generate the Drift code (already committed, but if you change tables):
dart run build_runner build --delete-conflicting-outputs

# 4. Run on Linux / macOS / Windows desktop:
flutter run -d linux

# 5. Run on iOS / Android (requires those toolchains):
flutter run -d <device-id>
```

## 🧪 Testing

```bash
flutter test
```

## 🏗 Building iOS without a Mac

Quill ships three GitHub Actions workflows under `.github/workflows/`:

| Workflow | Runner | Output |
| --- | --- | --- |
| `build.yml` | `ubuntu-22.04` | Linux tarball + Android APK + tests |
| `ios-unsigned.yml` | `macos-14` | Unsigned `.ipa` (sideload via AltStore / Sideloadly) |
| `ios-signed.yml` | `macos-14` | Signed `.ipa` → optional TestFlight upload on tags |

The unsigned workflow runs on every push to `main` and produces an artifact
called `quill-ios-unsigned` you can download straight from the Actions run.

### Sideload onto your iPad (no Apple Developer account required)

1. Wait for the `Build iOS (unsigned)` workflow to finish.
2. Download `quill-ios-unsigned` from the run summary.
3. Install **AltStore** (macOS / Windows) or **Sideloadly** (Windows-only) on a
   borrowed computer — both sign the IPA with your personal Apple ID.
4. Plug in your iPad, drag the `.ipa` onto the app, and trust the developer
   certificate in *Settings → General → VPN & Device Management*.

### Build a signed IPA for TestFlight / App Store

1. In Apple Developer portal, create:
   - An **App Store Connect API key** (`Users → Keys → App Store Connect`)
   - A **Distribution certificate** (.p12) and a **Provisioning profile** for
     bundle id `io.quill.quill`
2. In your GitHub repo go to *Settings → Secrets and variables → Actions*
   and add:
   - `APPSTORE_ISSUER_ID`
   - `APPSTORE_KEY_ID`
   - `APPSTORE_API_KEY_BASE64` — `base64 -i AuthKey.p8 | pbcopy`
   - `IOS_DIST_CERT_BASE64` — `base64 -i dist.p12 | pbcopy`
   - `IOS_DIST_CERT_PASSWORD`
   - `IOS_PROVISIONING_PROFILE_BASE64` — `base64 -i quill.mobileprovision | pbcopy`
   - `IOS_TEAM_ID` (optional)
4. `git tag v0.1.0 && git push --tags` — the workflow uploads the build to
   TestFlight automatically.

### Set up OneDrive sync

1. Go to [portal.azure.com](https://portal.azure.com) → *Microsoft Entra ID*
   → *App registrations* → *New registration*.
2. Pick **Public client (mobile + desktop)** and add the redirect URI
   `msauth.<your-client-id>://auth` under *Authentication*.
4. Add the Quill app's redirect URI: `msauth.<client-id>://auth`.
5. Open the iPad-side Quill → *Settings → Cloud sync → Connect*, paste the
   client id and tap *Connect*. The Microsoft login webview appears once;
   subsequent launches pick up the cached refresh token.

### Set up iCloud Drive sync

1. Open the Apple Developer portal and add the **iCloud** capability to
   the App ID, plus the **iCloud Documents** service.
2. Add `com.apple.developer.icloud-container-identifiers` and
   `com.apple.developer.icloud-services = CloudDocuments` to the app's
   entitlements.
3. On the iPad go to *Settings → Apple ID → iCloud → iCloud Drive* and
   enable *Quill*. The OS will sync the app's ubiquity container
   automatically — no further setup inside Quill is needed.

## 🤝 Contributing

Quill is intentionally small and well-structured — perfect for first-time
contributors. Some ideas:

- A `notes_repository.dart` abstraction so we can swap Drift for an in-memory
  fake during widget tests.
- An Apple Pencil canvas widget that lives alongside `QuillEditor`.
- iCloud / WebDAV sync providers in `core/providers/`.

Pull requests welcome. Keep PRs focused; one feature per PR is the sweet spot.

## 📄 License

GPL-3.0-or-later. See `LICENSE` (TBD).