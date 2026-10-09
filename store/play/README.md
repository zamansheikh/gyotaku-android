# Publishing gyotaku on Google Play

What is in this folder, and what is still needed that a file cannot provide.

## In this folder

| File | What it is |
|---|---|
| `listing.md` | App name, short and full description, release notes, category |
| `privacy-policy.md` | The privacy policy text. Published at https://zamansheikh.github.io/gyotaku-android/privacy/ from `docs/privacy/index.html`; change both together |
| `console-answers.md` | Suggested answers for Data safety, content rating and the two permission declarations |
| `icon-512.png` | Store icon |
| `feature-graphic.png` | Feature graphic |
| `screenshots/` | Eight phone screenshots |
| `foreground-service-demo.mp4` | The video the foreground service declaration asks for. Upload it and give Play the link |
| `tools/` | The two scripts that drew the demo content and composed the screenshots |

The app bundle to upload is built with `flutter build appbundle --release` and lands in `build/app/outputs/bundle/release/app-release.aab`. It is signed with the key named in `android/key.properties`, which becomes the upload key.

## Settled with the desktop project's author

Asked in xevrion/gyotaku#9, he prefers the Android app to be its own project: its own repository, its own package name, and a note that it is unofficial. So:

1. **The package name is `com.silifton.gyotaku`.** A package name is permanent once published, so change it now if you want another.
2. **The listing says it is unofficial** and credits the desktop project. He offered to link this app from the gyotaku README and site as a community Android app. He was not asked in so many words about the name "gyotaku" and the fish mark on a store listing; one line to confirm that is worth sending before submitting.
3. **Play App Signing.** Play keeps the real signing key and you keep the upload key. Back up `gyotaku-release.jks` and its password before uploading anything.

## Steps in Play Console

1. Create the app: name, default language, app, free.
2. Set up the store listing from `listing.md` and the graphics here.
3. Enter the privacy policy URL from `listing.md`.
4. Fill in Data safety, content rating, target audience and ads from `console-answers.md`.
5. Submit the photo permission and foreground service declarations, with the video.
6. Upload the app bundle to a closed testing track.
7. Personal developer accounts created since November 2023 must run a closed test with at least 12 testers for 14 days before applying for production.

## Known gaps

- The screenshots show the dark theme only.
- The app has been run on emulators of Android 9, 10, 13 and 17 and on one Pixel 6. Play's pre-launch report will exercise more devices.
- With only Read Bengali on, Hindi text is misread as Bangla. The Bengali reader's scores do not tell the two apart. Turning Read Devanagari on as well fixes it.
