# Publishing gyotaku on Google Play

Everything Play Console asks for, in the order it asks. Prepared for version 1.2.1 (version code 7) on 10 October 2026. Nothing has been uploaded yet.

## In this folder

| File | What it is |
|---|---|
| `listing.md` | App name, short and full description, release notes, category, the three web addresses |
| `privacy-policy.md` | The privacy policy text. Published at https://zamansheikh.github.io/gyotaku-android/privacy/ from `docs/privacy/index.html`; change both together |
| `console-answers.md` | Answers for Data safety, content rating, advertising ID and the two permission declarations |
| `icon-512.png` | Store icon |
| `feature-graphic.png` | Feature graphic |
| `screenshots/` | Eight phone screenshots |
| `foreground-service-demo.mp4` | The video the foreground service declaration asks for. Upload it and give Play the link |
| `tools/` | The two scripts that drew the demo content and composed the screenshots |

The app bundle is built with `flutter build appbundle --release` and lands in `build/app/outputs/bundle/release/app-release.aab`. The newest is `~/Desktop/gyotaku-playstore/gyotaku-1.2.6.aab` (version code 12), which adds the welcome page shown before the photo prompt and the page shown after a refusal. The folder also still holds the earlier bundles; a new upload must have a higher version code than the last one Play was given.

## Checked on the 1.2.1 bundle

| | |
|---|---|
| Package name | `com.silifton.gyotaku` |
| Version | 1.2.1, version code 7 |
| Signed by | CN=Silifton, O=Silifton, C=BD, SHA-256 `A1:3F:9E:57 ... CC:96:73:58` |
| Target API level | 36 (Android 16). Minimum 24 (Android 7.0) |
| 16 KB page size | The release build ran on a 16 KB page emulator of Android 17 |
| Advertising ID permission | Not in the manifest |
| Listing text | Name 26 of 30 characters, short description 75 of 80, full description 2,432 of 4,000, release notes 160 of 500 |
| Graphics | Icon 512 x 512, feature graphic 1024 x 500, screenshots 1242 x 2208, none with transparency |

Permissions in the manifest: internet, network state, foreground service (media processing, and data sync up to Android 14), notifications, wake lock, read images (`READ_MEDIA_IMAGES`, `READ_MEDIA_VISUAL_USER_SELECTED`, and `READ_EXTERNAL_STORAGE` up to Android 12).

## Settled with the desktop project's author

Asked in xevrion/gyotaku#9, he prefers the Android app to be its own project: its own repository, its own package name, and a note that it is unofficial. All three are done.

On 10 October 2026 he told the maintainer privately that the app may go on Play under the gyotaku name and fish mark. That agreement is not written in the public thread. The listing, the app's about page and the site all say the app is unofficial and credit the desktop project; keep that wording.

The two upstream pull requests the app's crates wait on (xevrion/gyotaku#8 and #10) are not merged yet. That does not hold up a Play release: the app builds from a pinned commit of the fork, and the source is public either way.

## Before you open Play Console

Four things only you can do.

1. **Decide the package name for good.** It is `com.silifton.gyotaku`. Play never lets a published package name change. If you want another, say so before the first upload: the bundle has to be rebuilt.
2. **Back up the upload key.** `gyotaku-release.jks` and `keystore.properties` are in `~/Documents/silifton/Docs-Files-IMPORTANT/gyotaku-android-signing/` and nowhere else. Put a copy somewhere off this machine.
3. **Choose the contact email.** Play shows it publicly on the listing. The privacy policy itself points to the issue tracker, so it needs no change.
4. **Upload the video.** Put `foreground-service-demo.mp4` somewhere it can be watched, an unlisted YouTube video for one, and keep the link for step 6. Play it once first: the voice is a computer's and has not been listened to.

## Steps in Play Console

1. **Create the app.** Name `gyotaku: Screenshot Search`, default language English (United States), App, Free. Accept the declarations.
2. **Store listing.** Paste the short and full description from `listing.md`. Upload `icon-512.png`, `feature-graphic.png` and the eight files in `screenshots/` as phone screenshots.
3. **Store settings.** Category Tools, tags and contact details from the table in `listing.md`. Website `https://zamansheikh.github.io/gyotaku-android/`.
4. **Privacy policy.** `https://zamansheikh.github.io/gyotaku-android/privacy/`
5. **App content.** From `console-answers.md`: app access, ads, content rating, target audience, data safety, advertising ID, and No to the government, financial, health and news declarations.
6. **Permission declarations.** Play asks for these once the bundle is uploaded, so they may appear after step 7. Photo and video permissions: the text in `console-answers.md`. Foreground service: the two descriptions there, and the video link.
7. **Upload the bundle** to a closed testing track: `gyotaku-1.2.1.aab`, with the release notes from `listing.md`. Accept Play App Signing. Play then keeps the real signing key and yours becomes the upload key.
8. **Testers.** Personal developer accounts created since November 2023 must run a closed test with at least 12 testers opted in for 14 days in a row before applying for production. Add the testers' Google accounts and send them the opt in link.
9. **Send for review.**

## What may be questioned in review

- **Broad photo access.** Play allows `READ_MEDIA_IMAGES` only where reading the whole library is the app's core use. Searching every screenshot is that, and the declaration says so, but a reviewer may still ask for more or point to the photo picker.
- **The foreground service.** The video and the two descriptions cover it. Media processing is the type on Android 15 and later.
- **The name.** The listing says it is unofficial. If Play asks about the relation to the desktop project, the answer is in the section above.

## Known gaps

- The screenshots show the dark theme only.
- The app has been run on emulators of Android 9, 10, 13 and 17 and on one Pixel 6. Version 1.2.1 itself has only run on the Android 17 emulator. Play's pre-launch report will exercise more devices.
- With only Read Bengali on, Hindi text is misread as Bangla. The Bengali reader's scores do not tell the two apart. Turning Read Devanagari on as well fixes it.
- On Android 8 and earlier a HEIF photo cannot be given a second pass, because the system has no decoder for it.
- The newest build on GitHub Releases is 1.2.0, which does not have the HEIF fix.
