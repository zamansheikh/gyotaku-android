# Play Console forms

Suggested answers for the forms Play Console asks for besides the listing. Check each against the app as it is when you submit.

## Data safety

| Question | Answer |
|---|---|
| Does your app collect or share any of the required user data types? | No |
| Is all user data encrypted in transit? | Not applicable, none is collected |
| Do you provide a way to request data deletion? | Not applicable, none is collected |

The images and their text are processed on the device and never leave it, which Play does not count as collection.

## Content rating questionnaire

Category: Utility, Productivity, Communication or Other. Answer No to every question about violence, sexual content, language, controlled substances, gambling and user interaction. Expected rating: Everyone, or PEGI 3.

## Target audience

Age groups: 18 and over is the simplest choice. The app is not designed for children.

## Ads

Contains ads: No.

## Advertising ID

Does your app use an advertising ID: No. The manifest of the 1.2.1 bundle has no `com.google.android.gms.permission.AD_ID`.

## App access

All functionality is available without special access. No login.

## Photo and video permissions declaration

Play asks apps that request `READ_MEDIA_IMAGES` to justify broad access to photos. The app requests no video permission, so only the photo half applies.

Core functionality: yes. The box takes 250 characters at most. This is 248:

```
Core function: gyotaku reads the text in every screenshot on the device and indexes it so the user can search them. It must find new screenshots as they are saved, so a photo picker cannot serve. Images are only read, on the device, never uploaded.
```

The longer version, for a reviewer who asks for more:

```
gyotaku is a screenshot search app. Its core function is to read the text in every screenshot on the device and index it so the user can search their screenshots by content. This requires persistent, broad read access to the user's images: new screenshots must be found and read as they are saved, across the folders the user has enabled, without the user selecting each one. The system photo picker cannot serve this use, because the app must process the whole library and keep it up to date. Images are read on the device only and are never uploaded, modified or deleted. Only READ_MEDIA_IMAGES is requested; the app does not request access to videos.
```

## Foreground service declaration

The app declares one foreground service with two types. Play asks about each.

- **Media processing** is the type used on Android 15 and later.
- **Data sync** is used only on Android 14 and earlier, where media processing does not exist and Android 14 requires some type. Its permission is declared with `maxSdkVersion="34"`.

Suggested description for media processing:

```
When the user's screenshot library is being indexed, the app runs a foreground service so the work the user started can finish after they leave the app. The service reads the text in the user's images on the device. It shows a notification with the progress, a time estimate and a Pause action. Indexing a large library takes from minutes to hours. The service stops as soon as indexing is finished or paused.
```

Suggested description for data sync:

```
The same service as above, on Android 14 and earlier only. Those versions have no media processing type and Android 14 requires a type, so the service runs as data sync there. The permission is limited to those versions with maxSdkVersion 34. On Android 15 and later the service runs as media processing.
```

Play also asks for a link to a short video showing the service in use. `foreground-service-demo.mp4` in this folder is that video, 56 seconds, with a spoken commentary and the same words as captions. Play takes a link, not a file, so it is uploaded here: https://youtube.com/shorts/M3vNU8AQFkA

What it shows, in order: the app opened and reading 163 screenshots; the second pass, Adding Bangla, beginning; the app sent to the background; the notification counting up with the time left and a Pause action; Pause tapped and the notification saying reading is paused; the app opened again showing it paused; Resume tapped and the reading going on.

It was recorded on an Android 17 emulator from the release build of 1.2.1. Every screenshot in it is invented, drawn by `tools/demo.py` and variations of its pages. The voice is the Mac's own (Samantha).

## Government, financial, health and news declarations

None apply. Answer No to each.
