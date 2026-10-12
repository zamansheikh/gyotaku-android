# Project notes for coding agents

gyotaku for Android: an unofficial community app that makes the screenshots on a phone searchable by the text inside them. It is built on [gyotaku](https://github.com/xevrion/gyotaku), a desktop app by Yash Bavadiya, and uses that project's index, search and readers as Rust crates. This repository is maintained separately by Zaman Sheikh. Read `README.md` first; this file is what the README does not say.

## How it is put together

- `lib/` is the Flutter app. `reader.dart` is the heart: it finds images, reads them and keeps every stage visible. `search_page.dart`, `shot_page.dart`, `settings_sheet.dart`, `folders_page.dart` and `about_page.dart` are the screens. `welcome.dart` holds the page shown before the phone has been asked for photos, and the one shown after a refusal; the system prompt must never appear before the first. `activity.dart` is the progress banner, `ink.dart` the dark veil with matches lit.
- `rust/` is a bridge crate over `gyotaku-core` (index, search) and `gyotaku-ocr` (PP-OCRv6 and the extra script readers on ONNX Runtime), exposed with `flutter_rust_bridge`. `rust/src/api/index.rs` is the index, `rust/src/api/reader.rs` the readers.
- `lib/src/rust/`, `rust/src/frb_generated.rs` and `rust_builder/` are generated. Never edit them; run `flutter_rust_bridge_codegen generate` after changing `rust/src/api`.
- `android/app/src/main/kotlin/com/silifton/gyotaku/` has two files. `ScanService.kt` is the foreground service and notification. `MainActivity.kt` runs the app in one cached Flutter engine that outlives the window.
- `store/play/` is the Play Store kit: listing, privacy policy, form answers, graphics and the two scripts that drew them.
- `docs/` is the site, served by GitHub Pages from `main` at https://zamansheikh.github.io/gyotaku-android/. It is plain HTML with one stylesheet and no build step. `docs/privacy/index.html` is the policy the Play listing links to and repeats `store/play/privacy-policy.md`; change both together. The README's images also live in `docs/`.

Reading is in two passes. ML Kit reads everything first, about a quarter of a second an image. Only while Read Bengali or Read Devanagari is on, `gyotaku-ocr` goes back over each image for the lines ML Kit was not sure of (`Ocr::read_rest`), at seconds an image.

## The crates come from a fork, for now

`rust/Cargo.toml` takes `gyotaku-core` and `gyotaku-ocr` by git from `zamansheikh/gyotaku` at a pinned commit (branch `android-crates`). That fork carries two things not yet upstream:

- xevrion/gyotaku#8: the Bengali reader and the vote that decides between readers when two scripts are on.
- xevrion/gyotaku#10: `read_rest` and `watch_downloads`.

When both are merged, point the dependency at `xevrion/gyotaku` and drop the fork. To change OCR behaviour, change it in the fork (`~/Documents/silifton/gyotaku`, `crates/ocr`), push, then update the `rev` here. Do not copy crate code into this repository.

## Rules

- **Never write to, move or delete a user's images.** The app only reads.
- **Nothing leaves the phone.** The only network use is downloading a reader's model. No analytics, accounts or ads, ever.
- **Fail soft.** No permission, no network, a refused notification, a tiny or broken image: none may crash or leave the app looking empty with no explanation.
- **Say what is happening.** Every wait has words, a count and a bar, in the app and in the notification.
- **Every number in the README or the store listing is measured**, on a real device or emulator, never estimated. Say what was not verified.
- **A behaviour is finished when it has run for real**, on an emulator or phone, in a release build. Debug builds hide release-only failures (see traps).
- **The app is unofficial** and says so in the README, the about page and the listing. Keep that wording when editing any of them.
- **Copy:** clear, plain English, sentence case headings. No em dashes and no unicode arrows anywhere, including code comments and commits. Comments explain why, not what.
- **Design:** the screenshots are the colour; chrome is off white or near black, IBM Plex Sans. Vermilion (`shu`) only ever means "the search found this". Selection is ink. Nothing animates on its own, with one exception asked for by the maintainer: the example search on the welcome page, which stays still where the phone is set to reduce motion.
- **Commits** follow Conventional Commits (`feat(mobile):`, `fix:`, `docs:`), with a body that says why and what was measured.

## Traps already fallen into

- **R8 strips ML Kit in release builds.** Every read then fails with a NullPointerException, and only in release. `android/app/proguard-rules.pro` keeps it. Test release builds from wiped app data, or an old index hides the failure.
- **Photo permission differs by Android version.** Ask for images only (`photoAccess` in `lib/folders.dart`): the plugin's default also asks for videos, and Android 13 then reports the request refused. On Android 9 and earlier the plugin also asks to write, so the state is read again after asking.
- **Folder listings must name a sort order.** Without one the plugin's query is `ORDER BY LIMIT` on Android 10 and every listing fails.
- **Images can have no size in the media library.** Read it from the file; do not skip them.
- **Use the platform's `startForeground`, not `ServiceCompat`.** The library dropped the media processing type and the service failed to start. Android 15 and later run as media processing, 14 and earlier as data sync.
- **The engine must outlive the activity.** With the default engine, swiping the app from recents killed the reader mid-read.
- **Several ML Kit recognizers at once are no faster and lose most lines.** Measured on a Pixel 6. Keep it to one.
- **In the background Android gives fewer and smaller cores.** The reading threads are pinned to the faster cores still allowed; do not also lower their priority there.
- **A recognizer shown a script it does not know still answers confidently.** That is why a reader's score has a floor and two readers are settled by a vote, both in `gyotaku-ocr`.
- **Images under 32 pixels** are recorded as hidden; ML Kit refuses them.
- **Changing the app id or the signing key makes a new app** to Android: it will not install over the old one.

## Commands

```sh
flutter analyze
(cd rust && cargo test && cargo clippy -- -D warnings)
flutter_rust_bridge_codegen generate          # after changing rust/src/api
flutter build apk --release --split-per-abi   # signed if android/key.properties exists
flutter build appbundle --release             # for Play
```

`android/key.properties` names the release keystore and is never committed. Without it a release build is signed with the debug key.

To watch the app on a device: `adb logcat | grep "flutter *: gyotaku"`. The reader logs each pass and its time. `adb shell dumpsys activity exit-info com.silifton.gyotaku` says why the process last ended.

Emulators that exist for testing old Android versions: `gyotaku_api28`, `gyotaku_api29`, `gyotaku_api33`. Start one with `emulator -avd <name> -no-window -port 5556`.
