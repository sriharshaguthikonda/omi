# R4 — Android 14/15/16 foreground-service + background microphone constraints

**Priority: HIGHEST.** This is a sleeper risk: if modern Android forbids the capture pattern we're designing, we need to know *before* building P2–P4, not after.


https://chatgpt.com/c/6a48a44e-c794-83ee-9ea9-67438fd6cc2a


## Context (for the researcher)

I'm building a personal Android app (targeting recent Android, `targetSdk` 34/35) that must:
- Start audio recording from the microphone **triggered while the app is in the background or the screen is locked** — e.g. from a notification action button, a Quick Settings tile, an incoming Bluetooth media-button press, or a broadcast Intent from an automation app (Tasker).
- Keep a short rolling in-RAM audio buffer while "armed" (mic **not** open) and only open the mic when a trigger fires.
- Run a foreground service for continuous/long capture sessions.

## Questions to answer (with citations to official Android docs + real developer reports)

1. **Foreground-service microphone type:** On Android 14+ (FGS types mandatory), what exactly is required to use `FOREGROUND_SERVICE_MICROPHONE` / the `microphone` FGS type? Manifest declarations, runtime permission state, and the rule that a mic FGS **cannot be started from the background** — what are the exact exemptions (e.g. started from a notification action, from `BOOT_COMPLETED`, while already foreground)?
2. **Starting mic capture from the background:** Can an app **begin** microphone recording when triggered by (a) a notification action button, (b) a `TileService` click, (c) a `BroadcastReceiver` receiving an Intent, (d) a Bluetooth `MediaSession` KeyEvent — while the app has no visible UI? For each, is it allowed, and what is the exact mechanism/exemption that makes it legal? Cite the "while-in-use" permission and background-start restrictions.
3. **Android 15 / 16 changes:** Any new restrictions in Android 15 and the latest preview on background mic, FGS, or `BLUETOOTH_CONNECT`-gated media buttons? What broke for existing recorder/dictation apps?
4. **OEM battery killers:** Samsung, Xiaomi/MIUI, OnePlus/Oppo, Huawei aggressive background-process killing — what do robust background-audio apps (e.g. call recorders, tracker apps) actually do to survive? `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`, manufacturer allowlists, dontkillmyapp.com patterns.
5. **Mic access while another app uses it / audio focus:** If a music/call app holds the mic or audio focus, can we still capture? How does `AudioManager` audio focus + `MediaRecorder`/`AudioRecord` concurrency actually behave on modern Android?
6. **The "armed but mic closed" pattern:** Is holding a foreground service alive with the mic *closed* (just a session + BT listener) cheap and allowed, then opening `AudioRecord` on trigger? Any restriction on opening the mic mid-FGS-session that was started earlier?

## Desired deliverable

- A **capability matrix**: trigger source (notification / tile / intent / BT key) × (app foreground / background / screen-locked / after process death) → allowed? mechanism? Android-version caveats.
- The **exact manifest + permission + service-start recipe** that a working modern background recorder uses.
- A **red-flags list**: patterns that get apps killed or rejected, and the mitigations.
- Links to 2–3 open-source Android recorder/dictation apps that already solve this, with the specific files/APIs to copy.

## Why it matters

Unblocks the entire trigger/capture core (ROADMAP P2 + P4). If background-triggered mic start is heavily restricted, the trigger design shifts toward "arm the FGS while UI is open, background triggers only toggle within an already-running session" — a big architectural fork we want to know now.









# Android Background Microphone Capture on Android 14 to 16

## Bottom line

Your biggest design risk is real: on Android 14 and above, a `microphone` foreground service is tightly tied to the **while-in-use** `RECORD_AUDIO` permission. In plain English, if your app is *in the background* and you try to **create** or newly **upgrade into** a mic foreground service, Android can block it immediately with a `SecurityException`, even if `checkSelfPermission()` says audio permission is granted. That is the single most important rule for your roadmap. citeturn3search2turn2view8turn32view0

That means the architecture with the best odds on modern Android is this: start the long-lived service **while the app is visibly in front** or from one of the narrow documented exemptions, keep that service alive with a user-visible notification, and only then open `AudioRecord` or `MediaRecorder` later when a trigger fires. What is *not* safe is assuming a cold background trigger like a plain broadcast or a dead-process restart can freely start microphone capture on demand. citeturn30search5turn2view8turn32view0

A second hard truth: Quick Settings tiles are now a shaky path for this use case. There are developer reports that starting a foreground service from `TileService.onClick()` broke on Android 14, with workarounds involving a transient dialog or unlocking first. Even if that general bug improves on some builds, microphone use still collides with the Android 14+ while-in-use rule, so tiles are *not* a robust primary trigger for starting fresh mic capture from a cold background state. citeturn24view0turn23view4turn3search2

The third reality is outside AOSP: OEM battery killers still ruin long-running background apps. Android’s own docs say foreground services are for user-noticeable work, not as a generic keep-alive trick, and Google Play limits when you may ask for battery-optimization exemption. In practice, robust recorder and tracker apps still combine proper foreground-service design with vendor-specific user guidance for Samsung, Xiaomi, OnePlus, Oppo, and Huawei devices. citeturn30search18turn15search0turn16search4turn16search5turn16search1turn16search2turn16search6turn16search3

## What Android actually requires

For a recorder targeting Android 14 and above, the service itself must declare `android:foregroundServiceType="microphone"`, the manifest must also include `FOREGROUND_SERVICE_MICROPHONE`, and the app must have runtime `RECORD_AUDIO` permission before the service is promoted to the foreground. Android’s launch flow is still the usual two-step pattern: call `context.startForegroundService(...)`, then inside the service call `ServiceCompat.startForeground(...)` with the matching foreground-service type. If the type passed at runtime was not declared in the manifest, Android throws `IllegalArgumentException`. If the needed permission is missing, Android throws `SecurityException`. citeturn2view8turn17search16turn32view0

There is an important subtle point here. Android 14+ checks the permission state when the service is promoted to the foreground for that type. The docs also say that if you need to add more service types later, you call `startForeground()` again and add those types. For your use case, that means switching a running background service from a non-mic type to `microphone` later is *still* the risky moment, because that is when Android re-checks the prerequisites for the new type. So if you want “armed now, open mic later,” the safer pattern is to start the already-typed mic FGS while the app is visible, not to try a background type escalation later. citeturn32view0turn30search0

Android’s official microphone service-type page is blunt: because `RECORD_AUDIO` is a **while-in-use** permission, you cannot create a `microphone` FGS while the app is in the background, and you cannot launch a microphone FGS from `BOOT_COMPLETED`, except for a narrow set of special cases documented on the background-start page. citeturn2view8turn3search2

For the while-in-use cases, the documented exemptions are narrower than the general “background FGS start” exemptions. Android explicitly lists these as exempt cases: a system component starts the service; the service starts from interacting with an app widget; the service starts from interacting with a notification; the service starts from a `PendingIntent` sent by a different visible app; the app is a device-policy controller in device-owner mode; the app provides `VoiceInteractionService`; or the app holds the privileged `START_ACTIVITIES_FROM_BACKGROUND` permission. General background-start exemptions like alarms or `BOOT_COMPLETED` do *not* automatically make microphone access legal. citeturn2view4turn2view5turn2view7turn3search2

If you ship through Google Play, there is one more policy step: Android’s docs say that apps targeting Android 14 and above must also declare their foreground-service types in the Play Console app-content page. So even if the APK works technically, using the wrong type or using a vague `specialUse` declaration is a review risk. citeturn28view1

### A working manifest recipe

A modern recorder that supports notification-entry, locked-screen continuity, and optional Bluetooth mic routing will usually need something close to this:

```xml
<manifest ...>
    <uses-permission android:name="android.permission.RECORD_AUDIO" />
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE_MICROPHONE" />

    <!-- Practical, not strictly required to create the FGS on Android 13+,
         but needed if you want the notification visible in the drawer -->
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS" />

    <!-- Only if you actively manage Bluetooth / SCO / device state -->
    <uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
    <uses-permission android:name="android.permission.MODIFY_AUDIO_SETTINGS" />

    <!-- Only if you ask the user for exemption -->
    <uses-permission
        android:name="android.permission.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS" />

    <application ...>
        <service
            android:name=".AudioRecordingService"
            android:exported="false"
            android:foregroundServiceType="microphone" />

        <service
            android:name=".MyTileService"
            android:permission="android.permission.BIND_QUICK_SETTINGS_TILE"
            android:exported="true">
            <intent-filter>
                <action android:name="android.service.quicksettings.action.QS_TILE" />
            </intent-filter>
        </service>

        <receiver
            android:name=".BootReceiver"
            android:exported="false">
            <intent-filter>
                <action android:name="android.intent.action.BOOT_COMPLETED" />
                <action android:name="android.intent.action.LOCKED_BOOT_COMPLETED" />
                <action android:name="android.intent.action.MY_PACKAGE_REPLACED" />
            </intent-filter>
        </receiver>
    </application>
</manifest>
```

The key thing in that manifest is not the boilerplate. It is the fact that the main recorder service is declared as `microphone`, and you only try to bring it up in situations where Android considers your app currently allowed to use the while-in-use mic permission. citeturn2view8turn8view1turn29search0turn28view0

### A working start sequence

A high-confidence modern sequence looks like this:

1. While an activity is visible, request and obtain `RECORD_AUDIO`. On Android 13 and above, also request `POST_NOTIFICATIONS` if you want the persistent recorder notification visible in the drawer. Remember that one-time grants and auto-reset exist, so you must re-check every session. citeturn29search11turn29search0turn29search5

2. Start the service with `startForegroundService(...)`, then inside `onStartCommand()` call `ServiceCompat.startForeground(...)` with `FOREGROUND_SERVICE_TYPE_MICROPHONE` and a low-or-higher priority notification. citeturn32view0

3. Keep the service alive in an **armed** state if the user explicitly asked for this mode. Do *not* use `shortService`; that type lasts only about three minutes, does not support sticky behavior, and cannot start other foreground services. citeturn33search9turn6view2

4. On trigger, open `AudioRecord` or `MediaRecorder`. Android’s docs describe those APIs as the actual mechanism that captures audio from the microphone; if the mic is truly “closed,” you are *not* buffering audio. So a true pre-roll audio buffer is impossible unless the mic was already open and capturing. citeturn31view0

5. If you actively control Bluetooth headset mic routing, add `BLUETOOTH_CONNECT` and possibly `connectedDevice` handling only if you are really doing Bluetooth-device interaction rather than just plain recording. Android defines `connectedDevice` for Bluetooth, NFC, IR, USB, or external-device interaction and ties it to permissions such as `BLUETOOTH_CONNECT`. citeturn28view0

## Capability matrix

The table below is the practical answer to your trigger question.

| Trigger | App visible | App background, process alive | Screen locked | After process death | Practical verdict |
|---|---|---|---|---|---|
| Notification action button | **Yes**. This is the cleanest path. Notification interaction is an explicit exemption for while-in-use FGS starts. citeturn2view4turn2view5 | **Yes**, if the user taps your notification action and the `PendingIntent` starts the mic FGS directly or tells an already-running mic FGS to open the mic. citeturn2view4turn3search2 | **Yes** in principle, because lock-screen notification interaction is still notification interaction; UX depends on lockscreen visibility/settings. citeturn2view4turn29search13 | **Sometimes**. If the notification still exists and its `PendingIntent` is valid, Android can relaunch your component. If the user force-stopped the app, Android 15 cancels pending intents in stopped state. citeturn34view0turn34view1 | **Best trigger** |
| Quick Settings tile click | **Often yes** if used to control an already-running service. citeturn8view0turn8view1 | *Unreliable* for starting a fresh mic FGS on Android 14+. Developers reported `ForegroundServiceStartNotAllowedException` from `TileService.onClick()`. citeturn24view0turn22search3turn22search7 | *Worse*. One common workaround needed unlocking or a transient dialog; one report says the tile had to be unavailable while locked. citeturn24view0 | **Tile can wake your app**, but cold-starting fresh mic capture through it is *not a safe primary design*. citeturn24view0turn3search2 | *Do not rely on this as the main path* |
| Plain `BroadcastReceiver` receiving an intent | **Yes** if the app is already visible or the broadcast merely tells an existing mic FGS what to do. citeturn32view0 | *Usually no* for starting new mic capture. A plain broadcast is not one of the mic while-in-use exemptions. `BOOT_COMPLETED` explicitly does not permit microphone FGS. citeturn3search2turn2view7turn2view8 | *No* for a fresh cold mic start unless you chain into a visible activity or another explicit exemption. citeturn3search2 | The receiver can wake the process, but `onReceive()` is short-lived and background mic FGS rules still apply. citeturn25search10turn3search2 | *Unsafe for cold-start mic capture* |
| Bluetooth headset media button via `MediaSession` | **Yes** if your app already owns the active media session or the recorder FGS is already running. Android sends media buttons to the active media session. citeturn8view2turn10search12 | **Yes** for toggling *inside an already-running* recorder FGS with active `MediaSession`. This is exactly how current open-source dictation apps describe it. citeturn20view0turn21search0 | **Yes** with the same caveat: the active media session or already-running service must exist. citeturn8view2turn20view0 | Android can restart an inactive media session by sending `ACTION_MEDIA_BUTTON` to a registered receiver or service, but turning that cold restart into a *fresh* mic FGS still runs into Android 14+ while-in-use limits. citeturn8view2turn3search2 | **Good secondary trigger only when the session is already alive** |

The short version is simple. If you need near-certain background start of microphone capture on modern Android, use a user-tapped **notification action**, or keep a valid mic FGS already running and let other triggers only toggle recording within that active session. That is the architectural fork your prompt anticipated, and the docs support it. citeturn2view4turn3search2turn20view0turn19search1

## What changed in Android 15 and 16

Android 15 does **not** introduce a brand-new official “background mic is now even more banned” rule beyond Android 14’s core microphone while-in-use restriction. The main Android 15 changes that matter to you are around foreground-service ecosystem behavior: more FGS types are blocked from `BOOT_COMPLETED`; `SYSTEM_ALERT_WINDOW` is no longer a broad escape hatch unless you already have a visible overlay; and apps targeting Android 15 must be the top app or already running a foreground service before `requestAudioFocus()` will succeed. citeturn3search3turn13view2turn12search1turn12search3

That audio-focus change matters more than it first looks. If your recorder wants to politely request focus before capture, pause music, or manage mixed-audio behavior, you now need to be **top app** or already in a FGS on Android 15+. If you try to request focus while backgrounded and not already in FGS, `AUDIOFOCUS_REQUEST_FAILED` is the documented result. citeturn13view1turn13view2

Android 16, as publicly documented so far, does *not* show a new microphone-specific FGS restriction. What it does show is more pressure against using WorkManager or background jobs as a hidden long-running substitute. Android 16 says jobs started from a foreground service now count against job quota, and long-running workers that use a foreground service can exhaust quota. So if your plan was “use WorkManager plus foreground mode as the hidden engine for capture,” Android 16 makes that less attractive. For continuous recording or armed waiting, a real foreground service is the cleaner path. citeturn11search1turn11search3turn34view0

Real developer breakage lines up with that reading. Recorder and utility developers reported Android 14 crashes when required FGS types were missing; tile-start flows reporting `ForegroundServiceStartNotAllowedException`; and telecom/voice apps on Android 14 and 15 reporting one-way audio because a backgrounded component tried to start a `microphone` FGS when it should have used a different call-related type. citeturn6view0turn24view0turn27view0

## OEM killing, mic sharing, and audio conflicts

On stock Android, foreground services are meant for work users can see and expect. On many OEM builds, that still is *not* enough. Don’t Kill My App continues to document aggressive vendor behavior from Xiaomi, Samsung, OnePlus, Oppo, and Huawei. The user-side fixes are depressingly consistent: disable battery optimization for the app, allow autostart/background activity, and in some vendors lock the app in Recents. Xiaomi documents “Background autostart”; Samsung documents battery-optimization exclusion; OnePlus documents both battery optimization and locking in Recents; Oppo documents startup manager plus pinning in Recents; Huawei documents PowerGenie killing background apps. citeturn16search1turn16search5turn16search2turn16search6turn16search3turn16search4

Android’s own docs also limit how you should ask for relief. Google says most apps should only open battery-optimization settings, and only apps whose **core function** is harmed may directly request exemption with `ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`. The docs also note that Play policy prohibits direct exemption requests unless the core function is adversely affected. For a recorder or continuous monitor, that can be arguable; for a casual memo button, it is much harder to defend. citeturn15search0turn15search3

As for microphone conflict, Android’s audio-input-sharing docs are clear: when two normal apps capture at the same time, only one usually gets real audio and the other gets silence. If one app uses a privacy-sensitive input source, that app wins and the other gets silence. During a voice call, the call always receives audio; ordinary apps generally do *not* get to capture the call or steal the mic, except for narrow privileged or accessibility cases. So if Spotify is playing, audio focus is one issue; if another recorder, assistant, camera, or call already owns the mic, your app may open `AudioRecord` successfully but receive silence. citeturn13view0

Audio focus and microphone ownership are related but *not* the same thing. Audio focus governs playback behavior. Android 12+ enforces fade-out and muting rules for playback focus changes, and Android 15+ limits who may even request focus. Microphone access is separately governed by capture concurrency rules, privileged roles, and the privacy-sensitive source rules above. citeturn13view1turn13view2turn13view0

## The design that fits the platform

The **allowed** and practical “armed but mic closed” design is this: keep a user-visible foreground service alive, with the mic **closed**, while you hold notification actions, media-session state, or other session logic ready. Later, when a legal trigger fires, open `AudioRecord` or `MediaRecorder` inside that already-running service. Android’s docs do not forbid opening the mic later inside a running mic FGS; the formal restriction is on creating or promoting a microphone FGS from the background. That is why this architecture is the safest reading of the platform rules. citeturn2view8turn32view0

But there are two catches. First, if you are keeping the service alive only as a hidden trick to dodge idle state, Android explicitly says *don’t* do that; foreground services are for work the user expects to run immediately or without interruption. So this “armed” mode needs to be user-driven and obvious in the notification. Second, if you start the service under some other type and later try to add `microphone` from the background, you are back in danger because Android checks the new service-type prerequisites when you call `startForeground()` again. citeturn30search18turn32view0

So the hard recommendation is:

- If the user opens the app and explicitly arms background capture, start the service **already as `microphone`** while the app is visible.
- Keep the mic closed until trigger time.
- Let notification actions and headset-button events only tell that live session to open or close the mic.
- Treat cold-start triggers after process death as *limited* paths that usually need either a notification interaction or a return to visible UI. citeturn2view8turn2view4turn20view0turn19search1

That is the safest fork for ROADMAP P2 and P4.

## Red flags and what to copy

The biggest *red flags* are straightforward.

A plain broadcast from Tasker or any automation app is *not* a dependable way to cold-start fresh microphone capture on Android 14+. The receiver can wake your process, but it does not magically solve the while-in-use mic rule. Use it only to control an already-running armed session, or have it post a notification the user taps. citeturn25search10turn3search2

A Quick Settings tile is *not* a dependable primary trigger for fresh mic start. Developer reports show Android 14 broke direct FGS start from `TileService.onClick()` for some apps, and the workarounds are ugly. Use a tile, if at all, as a front door into a visible UI or as a controller for an already-running service. citeturn24view0turn23view4

Using `shortService` for anything recorder-like is flatly *wrong*. Android documents a roughly three-minute limit, no sticky support, and no starting of other foreground services. One developer report of “works for three minutes then stops” on Android 14 matches that perfectly. citeturn33search9turn6view2

Relying on `BOOT_COMPLETED` to auto-resume a microphone FGS is *not allowed* on Android 14+. The safe pattern is what BabyApp does publicly: post a resume notification on boot and let the user tap it. citeturn2view8turn3search3turn19search1

Assuming “permission was granted once, so I’m done” is also *wrong*. Android 11 introduced one-time mic permission, and Android can auto-reset unused dangerous permissions. Robust apps re-check on every session. citeturn29search11turn29search5

For examples worth reading and borrowing from, three public repos are especially useful.

**BabyApp** is the cleanest public example of modern “always-on-ish” audio under Android 15 constraints. Its README explicitly documents `BabyService.kt` as the mic foreground service, `BootReceiver.kt` as the boot-resume notification pattern, and `MainActivity.kt` as the permission and user-entry point. It also states plainly that it does *not* directly start a mic FGS from boot because Android 14+ forbids that. citeturn19search1turn21search1

**Yunto** is the best public example close to your Bluetooth media-button idea. Its README says the native Android path lives in `modules/headphone-button`, and that it uses a foreground service plus an active `MediaSession` to intercept headset-button presses. It also states the same caveat your design needs: the button works as long as no other audio app holds media-session priority. citeturn20view0turn21search0

**AudioMemo** is a useful modern Kotlin recorder example for manifest and interruption handling. Its README explicitly lists `FOREGROUND_SERVICE_MICROPHONE`, `RECORD_AUDIO`, the persistent notification, Bluetooth headset handling, and `MediaButtonHandler` support for headset/media-button pause and resume. That makes it a good source for service, interruptions, and permission plumbing. citeturn18search0

## Recommended architecture for your app

For `targetSdk` 34 or 35, the safest build is this:

Use a visible activity to obtain `RECORD_AUDIO`, `POST_NOTIFICATIONS`, and any optional Bluetooth permissions. When the user enables “background-ready” mode, start a **mic-typed foreground service immediately** and show a clear persistent notification saying the app is armed. Keep the mic **closed** until a trigger arrives. Let a notification action be the main cold-start trigger. Let Bluetooth media-button presses and automation broadcasts merely control the already-running session. On reboot or package update, *do not* auto-start recording; instead, post a high-visibility “Tap to re-arm” notification. On OEM phones, offer a battery-optimization help screen and only request direct exemption if this really is the app’s essential function. citeturn2view8turn2view4turn19search1turn20view0turn15search0

If you build it this way, the answer to your core question becomes simple:

Background-triggered mic start on modern Android is **possible**, but only on a narrow path. The path that survives Android 14+ rules is either **notification interaction** or **triggering within an already-running mic foreground service**. The path that is most likely to hurt you later is “cold background trigger creates fresh mic capture from nothing.” citeturn3search2turn2view4turn32view0

## Open questions and limitations

The Android docs are clear for notifications, widgets, `BOOT_COMPLETED`, and general while-in-use rules. They are *less* explicit for `TileService` as a microphone-start path, so the tile verdict above relies partly on high-signal developer reports and public issue threads, not only official docs. citeturn24view0turn22search3turn22search7

I also did not have access in this chat to any private GitHub repository of yours, so the repo examples here are public only. If you have an internal Omi branch with an existing Android service stack, the most valuable next comparison would be against these three public patterns: BabyApp’s boot-resume notification, Yunto’s active-`MediaSession` headset-button flow, and AudioMemo’s modern recorder service and interruption handling. citeturn19search1turn20view0turn18search0

















Android Background Microphone Capture on Android 14 to 16
Bottom line
Your biggest design risk is real: on Android 14 and above, a microphone foreground service is tightly tied to the while-in-use RECORD_AUDIO permission. In plain English, if your app is in the background and you try to create or newly upgrade into a mic foreground service, Android can block it immediately with a SecurityException, even if checkSelfPermission() says audio permission is granted. That is the single most important rule for your roadmap. 

That means the architecture with the best odds on modern Android is this: start the long-lived service while the app is visibly in front or from one of the narrow documented exemptions, keep that service alive with a user-visible notification, and only then open AudioRecord or MediaRecorder later when a trigger fires. What is not safe is assuming a cold background trigger like a plain broadcast or a dead-process restart can freely start microphone capture on demand. 

A second hard truth: Quick Settings tiles are now a shaky path for this use case. There are developer reports that starting a foreground service from TileService.onClick() broke on Android 14, with workarounds involving a transient dialog or unlocking first. Even if that general bug improves on some builds, microphone use still collides with the Android 14+ while-in-use rule, so tiles are not a robust primary trigger for starting fresh mic capture from a cold background state. 

The third reality is outside AOSP: OEM battery killers still ruin long-running background apps. Android’s own docs say foreground services are for user-noticeable work, not as a generic keep-alive trick, and Google Play limits when you may ask for battery-optimization exemption. In practice, robust recorder and tracker apps still combine proper foreground-service design with vendor-specific user guidance for Samsung, Xiaomi, OnePlus, Oppo, and Huawei devices. 

What Android actually requires
For a recorder targeting Android 14 and above, the service itself must declare android:foregroundServiceType="microphone", the manifest must also include FOREGROUND_SERVICE_MICROPHONE, and the app must have runtime RECORD_AUDIO permission before the service is promoted to the foreground. Android’s launch flow is still the usual two-step pattern: call context.startForegroundService(...), then inside the service call ServiceCompat.startForeground(...) with the matching foreground-service type. If the type passed at runtime was not declared in the manifest, Android throws IllegalArgumentException. If the needed permission is missing, Android throws SecurityException. 

There is an important subtle point here. Android 14+ checks the permission state when the service is promoted to the foreground for that type. The docs also say that if you need to add more service types later, you call startForeground() again and add those types. For your use case, that means switching a running background service from a non-mic type to microphone later is still the risky moment, because that is when Android re-checks the prerequisites for the new type. So if you want “armed now, open mic later,” the safer pattern is to start the already-typed mic FGS while the app is visible, not to try a background type escalation later. 

Android’s official microphone service-type page is blunt: because RECORD_AUDIO is a while-in-use permission, you cannot create a microphone FGS while the app is in the background, and you cannot launch a microphone FGS from BOOT_COMPLETED, except for a narrow set of special cases documented on the background-start page. 

For the while-in-use cases, the documented exemptions are narrower than the general “background FGS start” exemptions. Android explicitly lists these as exempt cases: a system component starts the service; the service starts from interacting with an app widget; the service starts from interacting with a notification; the service starts from a PendingIntent sent by a different visible app; the app is a device-policy controller in device-owner mode; the app provides VoiceInteractionService; or the app holds the privileged START_ACTIVITIES_FROM_BACKGROUND permission. General background-start exemptions like alarms or BOOT_COMPLETED do not automatically make microphone access legal. 

If you ship through Google Play, there is one more policy step: Android’s docs say that apps targeting Android 14 and above must also declare their foreground-service types in the Play Console app-content page. So even if the APK works technically, using the wrong type or using a vague specialUse declaration is a review risk. 

A working manifest recipe
A modern recorder that supports notification-entry, locked-screen continuity, and optional Bluetooth mic routing will usually need something close to this:

xml
Copy
<manifest ...>
    <uses-permission android:name="android.permission.RECORD_AUDIO" />
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE_MICROPHONE" />

    <!-- Practical, not strictly required to create the FGS on Android 13+,
         but needed if you want the notification visible in the drawer -->
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS" />

    <!-- Only if you actively manage Bluetooth / SCO / device state -->
    <uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
    <uses-permission android:name="android.permission.MODIFY_AUDIO_SETTINGS" />

    <!-- Only if you ask the user for exemption -->
    <uses-permission
        android:name="android.permission.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS" />

    <application ...>
        <service
            android:name=".AudioRecordingService"
            android:exported="false"
            android:foregroundServiceType="microphone" />

        <service
            android:name=".MyTileService"
            android:permission="android.permission.BIND_QUICK_SETTINGS_TILE"
            android:exported="true">
            <intent-filter>
                <action android:name="android.service.quicksettings.action.QS_TILE" />
            </intent-filter>
        </service>

        <receiver
            android:name=".BootReceiver"
            android:exported="false">
            <intent-filter>
                <action android:name="android.intent.action.BOOT_COMPLETED" />
                <action android:name="android.intent.action.LOCKED_BOOT_COMPLETED" />
                <action android:name="android.intent.action.MY_PACKAGE_REPLACED" />
            </intent-filter>
        </receiver>
    </application>
</manifest>
The key thing in that manifest is not the boilerplate. It is the fact that the main recorder service is declared as microphone, and you only try to bring it up in situations where Android considers your app currently allowed to use the while-in-use mic permission. 

A working start sequence
A high-confidence modern sequence looks like this:

While an activity is visible, request and obtain RECORD_AUDIO. On Android 13 and above, also request POST_NOTIFICATIONS if you want the persistent recorder notification visible in the drawer. Remember that one-time grants and auto-reset exist, so you must re-check every session. 

Start the service with startForegroundService(...), then inside onStartCommand() call ServiceCompat.startForeground(...) with FOREGROUND_SERVICE_TYPE_MICROPHONE and a low-or-higher priority notification. 

Keep the service alive in an armed state if the user explicitly asked for this mode. Do not use shortService; that type lasts only about three minutes, does not support sticky behavior, and cannot start other foreground services. 

On trigger, open AudioRecord or MediaRecorder. Android’s docs describe those APIs as the actual mechanism that captures audio from the microphone; if the mic is truly “closed,” you are not buffering audio. So a true pre-roll audio buffer is impossible unless the mic was already open and capturing. 

If you actively control Bluetooth headset mic routing, add BLUETOOTH_CONNECT and possibly connectedDevice handling only if you are really doing Bluetooth-device interaction rather than just plain recording. Android defines connectedDevice for Bluetooth, NFC, IR, USB, or external-device interaction and ties it to permissions such as BLUETOOTH_CONNECT. 

Capability matrix
The table below is the practical answer to your trigger question.

Trigger	App visible	App background, process alive	Screen locked	After process death	Practical verdict
Notification action button	Yes. This is the cleanest path. Notification interaction is an explicit exemption for while-in-use FGS starts. 
Yes, if the user taps your notification action and the PendingIntent starts the mic FGS directly or tells an already-running mic FGS to open the mic. 
Yes in principle, because lock-screen notification interaction is still notification interaction; UX depends on lockscreen visibility/settings. 
Sometimes. If the notification still exists and its PendingIntent is valid, Android can relaunch your component. If the user force-stopped the app, Android 15 cancels pending intents in stopped state. 
Best trigger
Quick Settings tile click	Often yes if used to control an already-running service. 
Unreliable for starting a fresh mic FGS on Android 14+. Developers reported ForegroundServiceStartNotAllowedException from TileService.onClick(). 
Worse. One common workaround needed unlocking or a transient dialog; one report says the tile had to be unavailable while locked. 
Tile can wake your app, but cold-starting fresh mic capture through it is not a safe primary design. 
Do not rely on this as the main path
Plain BroadcastReceiver receiving an intent	Yes if the app is already visible or the broadcast merely tells an existing mic FGS what to do. 
Usually no for starting new mic capture. A plain broadcast is not one of the mic while-in-use exemptions. BOOT_COMPLETED explicitly does not permit microphone FGS. 
No for a fresh cold mic start unless you chain into a visible activity or another explicit exemption. 
The receiver can wake the process, but onReceive() is short-lived and background mic FGS rules still apply. 
Unsafe for cold-start mic capture
Bluetooth headset media button via MediaSession	Yes if your app already owns the active media session or the recorder FGS is already running. Android sends media buttons to the active media session. 
Yes for toggling inside an already-running recorder FGS with active MediaSession. This is exactly how current open-source dictation apps describe it. 
Yes with the same caveat: the active media session or already-running service must exist. 
Android can restart an inactive media session by sending ACTION_MEDIA_BUTTON to a registered receiver or service, but turning that cold restart into a fresh mic FGS still runs into Android 14+ while-in-use limits. 
Good secondary trigger only when the session is already alive

The short version is simple. If you need near-certain background start of microphone capture on modern Android, use a user-tapped notification action, or keep a valid mic FGS already running and let other triggers only toggle recording within that active session. That is the architectural fork your prompt anticipated, and the docs support it. 

What changed in Android 15 and 16
Android 15 does not introduce a brand-new official “background mic is now even more banned” rule beyond Android 14’s core microphone while-in-use restriction. The main Android 15 changes that matter to you are around foreground-service ecosystem behavior: more FGS types are blocked from BOOT_COMPLETED; SYSTEM_ALERT_WINDOW is no longer a broad escape hatch unless you already have a visible overlay; and apps targeting Android 15 must be the top app or already running a foreground service before requestAudioFocus() will succeed. 

That audio-focus change matters more than it first looks. If your recorder wants to politely request focus before capture, pause music, or manage mixed-audio behavior, you now need to be top app or already in a FGS on Android 15+. If you try to request focus while backgrounded and not already in FGS, AUDIOFOCUS_REQUEST_FAILED is the documented result. 

Android 16, as publicly documented so far, does not show a new microphone-specific FGS restriction. What it does show is more pressure against using WorkManager or background jobs as a hidden long-running substitute. Android 16 says jobs started from a foreground service now count against job quota, and long-running workers that use a foreground service can exhaust quota. So if your plan was “use WorkManager plus foreground mode as the hidden engine for capture,” Android 16 makes that less attractive. For continuous recording or armed waiting, a real foreground service is the cleaner path. 

Real developer breakage lines up with that reading. Recorder and utility developers reported Android 14 crashes when required FGS types were missing; tile-start flows reporting ForegroundServiceStartNotAllowedException; and telecom/voice apps on Android 14 and 15 reporting one-way audio because a backgrounded component tried to start a microphone FGS when it should have used a different call-related type. 

OEM killing, mic sharing, and audio conflicts
On stock Android, foreground services are meant for work users can see and expect. On many OEM builds, that still is not enough. Don’t Kill My App continues to document aggressive vendor behavior from Xiaomi, Samsung, OnePlus, Oppo, and Huawei. The user-side fixes are depressingly consistent: disable battery optimization for the app, allow autostart/background activity, and in some vendors lock the app in Recents. Xiaomi documents “Background autostart”; Samsung documents battery-optimization exclusion; OnePlus documents both battery optimization and locking in Recents; Oppo documents startup manager plus pinning in Recents; Huawei documents PowerGenie killing background apps. 

Android’s own docs also limit how you should ask for relief. Google says most apps should only open battery-optimization settings, and only apps whose core function is harmed may directly request exemption with ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS. The docs also note that Play policy prohibits direct exemption requests unless the core function is adversely affected. For a recorder or continuous monitor, that can be arguable; for a casual memo button, it is much harder to defend. 

As for microphone conflict, Android’s audio-input-sharing docs are clear: when two normal apps capture at the same time, only one usually gets real audio and the other gets silence. If one app uses a privacy-sensitive input source, that app wins and the other gets silence. During a voice call, the call always receives audio; ordinary apps generally do not get to capture the call or steal the mic, except for narrow privileged or accessibility cases. So if Spotify is playing, audio focus is one issue; if another recorder, assistant, camera, or call already owns the mic, your app may open AudioRecord successfully but receive silence. 

Audio focus and microphone ownership are related but not the same thing. Audio focus governs playback behavior. Android 12+ enforces fade-out and muting rules for playback focus changes, and Android 15+ limits who may even request focus. Microphone access is separately governed by capture concurrency rules, privileged roles, and the privacy-sensitive source rules above. 

The design that fits the platform
The allowed and practical “armed but mic closed” design is this: keep a user-visible foreground service alive, with the mic closed, while you hold notification actions, media-session state, or other session logic ready. Later, when a legal trigger fires, open AudioRecord or MediaRecorder inside that already-running service. Android’s docs do not forbid opening the mic later inside a running mic FGS; the formal restriction is on creating or promoting a microphone FGS from the background. That is why this architecture is the safest reading of the platform rules. 

But there are two catches. First, if you are keeping the service alive only as a hidden trick to dodge idle state, Android explicitly says don’t do that; foreground services are for work the user expects to run immediately or without interruption. So this “armed” mode needs to be user-driven and obvious in the notification. Second, if you start the service under some other type and later try to add microphone from the background, you are back in danger because Android checks the new service-type prerequisites when you call startForeground() again. 

So the hard recommendation is:

If the user opens the app and explicitly arms background capture, start the service already as microphone while the app is visible.
Keep the mic closed until trigger time.
Let notification actions and headset-button events only tell that live session to open or close the mic.
Treat cold-start triggers after process death as limited paths that usually need either a notification interaction or a return to visible UI. 
That is the safest fork for ROADMAP P2 and P4.

Red flags and what to copy
The biggest red flags are straightforward.

A plain broadcast from Tasker or any automation app is not a dependable way to cold-start fresh microphone capture on Android 14+. The receiver can wake your process, but it does not magically solve the while-in-use mic rule. Use it only to control an already-running armed session, or have it post a notification the user taps. 

A Quick Settings tile is not a dependable primary trigger for fresh mic start. Developer reports show Android 14 broke direct FGS start from TileService.onClick() for some apps, and the workarounds are ugly. Use a tile, if at all, as a front door into a visible UI or as a controller for an already-running service. 

Using shortService for anything recorder-like is flatly wrong. Android documents a roughly three-minute limit, no sticky support, and no starting of other foreground services. One developer report of “works for three minutes then stops” on Android 14 matches that perfectly. 

Relying on BOOT_COMPLETED to auto-resume a microphone FGS is not allowed on Android 14+. The safe pattern is what BabyApp does publicly: post a resume notification on boot and let the user tap it. 

Assuming “permission was granted once, so I’m done” is also wrong. Android 11 introduced one-time mic permission, and Android can auto-reset unused dangerous permissions. Robust apps re-check on every session. 

For examples worth reading and borrowing from, three public repos are especially useful.

BabyApp is the cleanest public example of modern “always-on-ish” audio under Android 15 constraints. Its README explicitly documents BabyService.kt as the mic foreground service, BootReceiver.kt as the boot-resume notification pattern, and MainActivity.kt as the permission and user-entry point. It also states plainly that it does not directly start a mic FGS from boot because Android 14+ forbids that. 

Yunto is the best public example close to your Bluetooth media-button idea. Its README says the native Android path lives in modules/headphone-button, and that it uses a foreground service plus an active MediaSession to intercept headset-button presses. It also states the same caveat your design needs: the button works as long as no other audio app holds media-session priority. 

AudioMemo is a useful modern Kotlin recorder example for manifest and interruption handling. Its README explicitly lists FOREGROUND_SERVICE_MICROPHONE, RECORD_AUDIO, the persistent notification, Bluetooth headset handling, and MediaButtonHandler support for headset/media-button pause and resume. That makes it a good source for service, interruptions, and permission plumbing. 

Recommended architecture for your app
For targetSdk 34 or 35, the safest build is this:

Use a visible activity to obtain RECORD_AUDIO, POST_NOTIFICATIONS, and any optional Bluetooth permissions. When the user enables “background-ready” mode, start a mic-typed foreground service immediately and show a clear persistent notification saying the app is armed. Keep the mic closed until a trigger arrives. Let a notification action be the main cold-start trigger. Let Bluetooth media-button presses and automation broadcasts merely control the already-running session. On reboot or package update, do not auto-start recording; instead, post a high-visibility “Tap to re-arm” notification. On OEM phones, offer a battery-optimization help screen and only request direct exemption if this really is the app’s essential function. 

If you build it this way, the answer to your core question becomes simple:

Background-triggered mic start on modern Android is possible, but only on a narrow path. The path that survives Android 14+ rules is either notification interaction or triggering within an already-running mic foreground service. The path that is most likely to hurt you later is “cold background trigger creates fresh mic capture from nothing.” 

Open questions and limitations
The Android docs are clear for notifications, widgets, BOOT_COMPLETED, and general while-in-use rules. They are less explicit for TileService as a microphone-start path, so the tile verdict above relies partly on high-signal developer reports and public issue threads, not only official docs. 

I also did not have access in this chat to any private GitHub repository of yours, so the repo examples here are public only. If you have an internal Omi branch with an existing Android service stack, the most valuable next comparison would be against these three public patterns: BabyApp’s boot-resume notification, Yunto’s active-MediaSession headset-button flow, and AudioMemo’s modern recorder service and interruption handling. 


Sources

Activity · 6m

Citations · 36

developer.android.com
developer.android.com

1
Restrictions on starting a foreground service from the ...
On Android 14 (API level 34) or higher, there are special situations to be aware of if you're starting a foreground service that needs while-in-use permissions.Read more

2
Restrictions on starting a foreground service from the ...
This document outlines the restrictions on starting foreground services from the background in Android 12 (API level 31) and higher, detailing specific ...

4
Optimize for Doze and App Standby | App quality
28 Jul 2024 — Don't start a foreground service just to prevent the system from determining that your app is idle. The app generates a notification that users ...Read more

31
Optimize for Doze and App Standby | App quality
28 Jul 2024 — Google Play policies prohibit apps from requesting direct exemption from Power Management features—Doze and App Standby—in … ...

5
Foreground service types  |  Background work  |  Android Developers
This document outlines the specific foreground service types required for apps targeting Android 14 (API level 34) and higher, detailing their manifest ...

7
Foreground service types  |  Background work  |  Android Developers
On Android 14 (API level 34) or higher, there are special situations to be aware of if you're starting a foreground service that needs while-in-use permissions.Read more

9
Foreground service types  |  Background work  |  Android Developers
https://developer.android.com/develop/background-work/services/fgs/service-types

10
Foreground service types  |  Background work  |  Android Developers
This document explains the `POST_NOTIFICATIONS` runtime permission introduced in Android 13 (API level 33), detailing how apps should request it, the impact ...

33
Foreground service types  |  Background work  |  Android Developers
Foreground services are automatically exempt from Doze for the work they do; the recording loop is unaffected. For network uploads during Doze, the "Disable ...Read more

34
Foreground service types  |  Background work  |  Android Developers
3 Mar 2026 — Apps that target Android 15 or higher are not allowed to launch a media playback foreground service from a BOOT_COMPLETED broadcast receiver.Read more

6
Launch a foreground service  |  Background work  |  Android Developers
3 Mar 2026 — If the foreground service needs new permissions after you launch it, you should call startForeground() again and add the new service types.

12
Launch a foreground service  |  Background work  |  Android Developers
https://developer.android.com/develop/background-work/services/fgs/launch

8
Restrictions on starting a foreground service from the background  |  Background work  |  Android Developers
On Android 14 (API level 34) or higher, there are special situations to be aware of if you're starting a foreground service that needs while-in-use permissions.Read more

15
Restrictions on starting a foreground service from the background  |  Background work  |  Android Developers
https://developer.android.com/develop/background-work/services/fgs/restrictions-bg-start

16
Restrictions on starting a foreground service from the background  |  Background work  |  Android Developers
This document explains how to handle urgent notifications on Android, covering the necessary permissions, channel creation, and display methods for ...

11
Permissions updates in Android 11
This document outlines significant changes to permissions in Android 11, including the introduction of one-time permissions, auto-reset for unused apps, ...

13
Foreground service types | Background work
Handle user-stopped foreground service · Restrictions on starting a foreground ... Special use. Foreground service type to declare in manifest under; android: ...Read more

14
MediaRecorder overview  |  Android media  |  Android Developers
https://developer.android.com/media/platform/mediarecorder

17
Behavior changes: all apps  |  Android Developers
https://developer.android.com/about/versions/15/behavior-changes-all

18
Create custom Quick Settings tiles for your app  |  Views  |  Android Developers
https://developer.android.com/develop/ui/views/quicksettings-tiles

21
Broadcasts overview | Background work
The system creates a new BroadcastReceiver component object to handle each broadcast that it receives. This object is valid only for the duration of the call to ...Read more

22
Responding to media buttons  |  Legacy media APIs  |  Android Developers
23 Feb 2024 — Media sessions provide a universal way of interacting with an audio or video player. By informing Android that media is playing in an app, ...Read more

24
Responding to media buttons  |  Legacy media APIs  |  Android Developers
https://developer.android.com/media/legacy/media-buttons

25
Responding to media buttons  |  Legacy media APIs  |  Android Developers
On Android 14 (API level 34) or higher, there are special situations to be aware of if you're starting a foreground service that needs while-in-use permissions.Read more

26
Changes to foreground service types for Android 15
3 Mar 2026 — Apps that target Android 15 or higher are not allowed to launch a media playback foreground service from a BOOT_COMPLETED broadcast receiver.Read more

27
Manage audio focus  |  Android media  |  Android Developers
https://developer.android.com/media/optimize/audio-focus

28
Changes to foreground services | Background work
Background jobs started from a foreground service now must adhere to their respective runtime quotas. This includes jobs scheduled directly with JobScheduler

32
Sharing audio input  |  Android media  |  Android Developers
https://developer.android.com/media/platform/sharing-audio-input
stackoverflow.com
stackoverflow.com

3
Start a Foreground Service From a Quick Tile on Android (targetSdkVersion 34 and higher) - Stack Overflow
On Android 14 (API level 34) or higher, there are special situations to be aware of if you're starting a foreground service that needs while-in-use permissions.Read more

19
Start a Foreground Service From a Quick Tile on Android (targetSdkVersion 34 and higher) - Stack Overflow
... mic, location in a foreground service which is started from TileService anymore. And there is no info about such changes between Android 13 and Android 14 ...Read more

20
Start a Foreground Service From a Quick Tile on Android (targetSdkVersion 34 and higher) - Stack Overflow
https://stackoverflow.com/questions/77331327/start-a-foreground-service-from-a-quick-tile-on-android-targetsdkversion-34-and

29
Foreground Service crashing on Android 14 - Stack Overflow
https://stackoverflow.com/questions/76943771/foreground-service-crashing-on-android-14
github.com
github.com

23
GitHub - lovisschmidt/yunto: Voice-first AI companion for Android — hands-free, bring your own keys, no backend. One headphone-button press to talk. · GitHub
Headphone button + BT mic, Native Expo Module (Kotlin) — MediaSession, Foreground Service, SCO control, The only part requiring native Android code. Audio ...

35
The BabyApp is a smart Audio Recorder Android App ...
Foreground services are automatically exempt from Doze for the work they do; the recording loop is unaffected. For network uploads during Doze, the "Disable ...Read more

36
agnihotripushkar/AudioMemo
FOREGROUND_SERVICE, Keep the recording service alive in the background. FOREGROUND_SERVICE_MICROPHONE, Android 14 foreground service type for microphone access.Read more
dontkillmyapp.com
dontkillmyapp.com

30
Xiaomi
On MIUI 14, there is a new permission to start from the background for each app, in Settings > Apps > Your app > App permissions > Background autostart.Read more
Sources scanned · 304

developer.android.com
developer.android.com
Foreground service types are required


3 Mar 2026 — Note: The location runtime permissions are subject to while-in-use restrictions. For this reason, you cannot create a location foreground ...Read more

Manifest.permission | API reference


Notification · Notification.Action · Notification.Action.Builder · Notification.Action.WearableExtender · Notification.BigPictureStyle · Notification.

Restrictions on starting a foreground service from the ...


On Android 14 (API level 34) or higher, there are special situations to be aware of if you're starting a foreground service that needs while-in-use permissions.Read more

R.attr | API reference


The name of an optional View class to instantiate and use as an action view. ... Specify the type of foreground service. static Int. foregroundTint. Tint to ...Read more

Foreground service types | Background work


Call the createScreenCaptureIntent() method before starting the foreground service. Doing so shows a permission notification to the user; the user must grant ...Read more

Manifest.permission | API reference


This permission protects a content provider within home/launcher applications, enabling management of home screen metadata such as shortcut placement, launch ...Read more

Changes to foreground service types for Android 15


3 Mar 2026 — This document outlines the changes and new types introduced for foreground services in Android 15, including a new media processing type and ...

Changes to foreground services | Background work


If an app's foreground services use the camera or microphone, the app must declare the service with the camera or microphone service type, respectively. Android ...Read more

R.attr | API reference


Background drawable to use for action mode UI. int ... Specify the type of foreground service. int, foregroundTint. Tint to apply to the foreground. int ...Read more

Android Developers: Android Mobile App Developer Tools


Discover the latest app development tools, platform updates, training, and documentation for developers across every Android device.

VoiceInteractionService | API reference


23 Jun 2026 — If the service has become a foreground service by calling startForeground(int,Notification) or startForeground(int,Notification,int) ...Read more

Foreground services in Android 11


Android 11 changes when foreground services can access the device's location, camera, and microphone. This helps protect sensitive user data.Read more

AutomaticGainControl | API reference


Automatic Gain Control (AGC) is an audio pre-processor which automatically normalizes the output of the captured signal by boosting or lowering input from the ...Read more

Behavior changes: Apps targeting Android 15 or higher


You can use a mediaProcessing foreground service to make sure the conversion continues even while the app is in the background. The system permits an app's ...Read more

Background audio hardening


18 Jun 2026 — Android 17 introduces stricter restrictions on background audio interactions, requiring foreground services with 'while-in-use' capabilities ...

AudioDeviceInfo | API reference


26 Mar 2026 — A device type describing the audio device associated with a dock. Starting at API 34, this device type only represents digital docks, while ...Read more

Declare foreground services and request permissions


Learn how to declare foreground services in your Android app's manifest, specify their types ... Restrictions on starting a foreground service from the background ...

MockPackageManager | API reference


A mock PackageManager class. All methods are non-functional and throw UnsupportedOperationException . Override it to provide the operations that you need.Read more

Create custom Quick Settings tiles for your app | Views


Your app can provide a custom tile to users through the TileService class, and use a Tile object to track the state of the tile.Read more

Responding to media buttons | Legacy media APIs


5 Jan 2024 — To properly handle media button events in all versions of Android, you must specify FLAG_HANDLES_MEDIA_BUTTONS when you create a media session.Read more

Background playback with a MediaSessionService


To enable background playback, you should contain the Player and MediaSession inside a separate Service. This allows the device to continue serving media even ...Read more

TileService | API reference


A TileService provides the user a tile that can be added to Quick Settings. Quick Settings is a space provided that allows the user to change settings and take ...Read more

MediaSession | API reference


26 Mar 2026 — Allows interaction with media controllers, volume keys, media buttons, and transport controls. A MediaSession should be created when an app ...Read more

Media controls


Media controls in Android are located near the Quick Settings. Sessions from multiple apps are arranged in a swipeable carousel.Read more

Control and advertise playback using a MediaSession


Connecting the media session to the player allows an app to advertise media playback externally and to receive playback commands from external sources.

Building a media browser service | Legacy media APIs


27 May 2026 — The service is created when it is started in response to a media button or when an activity binds to it (after connecting via its MediaBrowser ) ...

API reference


13 Feb 2026 — The key event session is the media session which would receive key event by default, unless the caller has specified the target. The session ...Read more

Android 16 features and changes list


3 Mar 2026 — This document provides a summary of all documented features and behavior changes in Android 16 that may affect app developers.

Media session callbacks | Legacy media APIs


5 Jan 2024 — Your media session callbacks call methods in several APIs to control the player, manage the audio focus, and communicate with the media session and media ...

MediaController | API reference


A MediaController can be created through MediaSessionManager if you hold the "android.permission.MEDIA_CONTENT_CONTROL" permission or are an enabled ...Read more

Media session callbacks | Legacy media APIs


5 Jan 2024 — The media session callbacks are different from the implementation shown for the audio app server/client architecture. There are no service calls.

メディアボタンへの応答 | Legacy media APIs


27 Jul 2025 — Android media-compat ライブラリ ACTION_MEDIA_BUTTON を処理し、受け取ったインテントを適切な MediaSessionCompat.Callback メソッド呼び出し。

Using a media session | Legacy media APIs


23 Feb 2024 — Media sessions provide a universal way of interacting with an audio or video player. By informing Android that media is playing in an app, ...Read more

Bluetooth permissions | Connectivity


This document guides developers on declaring necessary Bluetooth permissions for Android apps, specifying required features, and checking Bluetooth ...

Optimize for Doze and App Standby | App quality


28 Jul 2024 — Doze reduces battery consumption by deferring background CPU and network activity for apps when the device is unused for long periods of time.

Behavior changes: all apps


Starting with Android 12, foreground location (including from a foreground service) can continue to be delivered while Battery Saver is active, even while the ...Read more

Request location permissions | Sensors and location


This document describes the different types of location requirements for Android apps, including foreground and background access, and varying accuracy ...

Define work requests | Background work


In this guide you will learn how to define and customize WorkRequest objects to handle common use cases.Read more

Behavior changes: Apps targeting Android 12


Apps that target Android 12 or higher can't start foreground services while running in the background, except for a few special cases. If an app attempts to ...Read more

Schedule alarms | Background work


Declare foreground services and request permissions · Launch a foreground ... Optimize battery use for task scheduling APIs. Manage device awake state.Read more

Android 8.0 Behavior Changes


20 May 2024 — However, the app must call that service's startForeground() method within five seconds after the service is created. For more information, see ...Read more

ANRs | App quality


19 May 2026 — Application Not Responding (ANR) errors occur when an Android app's UI thread is blocked for too long, causing user frustration.

BroadcastReceiver | API reference


BroadcastReceiver · BroadcastReceiver.PendingResult · ClipboardManager · ClipData · ClipData.Item · ClipData.Item.Builder · ClipDescription · ComponentName ...

Broadcasts overview | Background work


The system creates a new BroadcastReceiver component object to handle each broadcast that it receives. This object is valid only for the duration of the call to ...Read more

Launch a foreground service | Background work


There are two steps to launching a foreground service from your app. First, you must start the service by calling context.startForegroundService() .Read more

Support for long-running workers | Background work


Add a foreground service type to a long-running worker. Declare foreground service types in app manifest; Specify foreground service types at runtime.Read more

Foreground services overview | Background work


Foreground services let you asynchronously perform operations that are noticeable to the user. Foreground services show a status bar notification.Read more

Android 12 features and changes list


3 Mar 2026 — Foreground service launch restrictions. Apps are no longer permitted to start foreground services while running in the background.Read more

Media projection


24 Jan 2025 — Start the media projection service with a call to startForeground() . If you don't specify the foreground service type in the call, the type ...Read more

Behavior changes: all apps  |  Android Developers


Total lines: 637

Handle user-initiated stopping of apps running foreground services  |  Background work  |  Android Developers


Total lines: 566

android.com
android.com
Do More With Google on Android Phones & Devices


Discover more about Android & learn how our devices can help you Do more with Google with hyper connectivity, powerful protection, Google apps & Quick ...

Browse Android's Latest Features


Browse new updates to Android which include improvements to your phones, tablets, smartwatches, and cars. Your Android keeps getting better.

Discover the Newest Android Phones and Features


Explore new Android phones, features, and updates such as flips or foldables, AI features & more to take your mobile experience to the next level.

Why Switch to Android? Get AI features, Protection & More


Experience Android's freedom and innovation, featuring AI (Gemini & Circle to Search), robust device protection, and stay connected with Google Messages.

Explore What's New: Android's Latest Features


Discover the new updates to Android which include improvements to your phones, tablets, smartwatches, and cars.

Android Open Source Project


Read about the Android Open Source Project (AOSP) and learn how to develop, customize, and test your devices.Read more

Troubleshoot foreground services | Background work


When you launch a service by calling context.startForegroundService() , that service has a few seconds to promote itself to a foreground service by calling ...Read more

Services overview | Background work | Android Developers


28 Jan 2025 — A foreground service performs some operation that is noticeable to the user. For example, an audio app would use a foreground service to play an ...Read more

Background Execution Limits


3 Mar 2026 — After the system has created the service, the app has five seconds to call the service's startForeground() method to show the new service's user ...Read more

Foreground service timeouts | Background work


This document details the new foreground service timeout restrictions introduced in Android 15 and higher, specifically for dataSync and mediaProcessing ...

Media3 | Jetpack


Declare "data sync" foreground service type for DownloadService for Android 14 compatibility. When using this service, the app also needs to add dataSync as ...Read more

TileService | API reference | Android Developers


Skip to main content.Read more

android.media.session | API reference


13 Mar 2025 — Allows an app to interact with an ongoing media session. MediaSession. Allows interaction with media controllers, volume keys, media buttons, ...Read more

The Player Interface | Android media


When playing media in the background, you need to house your media session and player within a MediaSessionService or MediaLibraryService that runs as a ...

MediaSession | API reference


Allows interaction with media controllers, volume keys, media buttons, and transport controls. A MediaSession should be created when an app wants to publish ...Read more

MediaSession.Callback | API reference | Android Developers


Receives media buttons, transport controls, and commands from controllers and the system. A callback may be set using #setCallback. Summary. Public constructors.

BluetoothA2dp | API reference


26 Mar 2026 — This class provides the public APIs to control the Bluetooth A2DP profile. BluetoothA2dp is a proxy object for controlling the Bluetooth A2DP ...Read more

Set up Bluetooth | Connectivity


26 Feb 2026 — This document explains how to set up Bluetooth Classic and Bluetooth Low Energy (BLE) in an Android app, covering how to verify Bluetooth ...

BluetoothManager | API reference


permission.BLUETOOTH_CONNECT permission which can be gained with android.app.Activity.requestPermissions(String[],int) . Requires android.Manifest ...Read more

Connect Bluetooth devices


26 Feb 2026 — Make sure you have the appropriate Bluetooth permissions and set up your app for Bluetooth before attempting to find Bluetooth devices.Read more

Bluetooth overview | Connectivity


26 Feb 2026 — Use of the Bluetooth APIs requires declaring several permissions in your manifest file. Once your app has permission to use Bluetooth, your ...

BluetoothStatusCodes | API reference


26 Mar 2026 — Error code indicating that the caller does not have the Manifest.permission.BLUETOOTH_CONNECT permission. Constant Value: 6 (0x00000006) ...Read more

Behavior changes: Apps targeting Android 13 or higher


Granular media permissions. The 2 buttons for the dialog, from top to bottom, are Allow and Don Figure 1. System permissions dialog that ...

BluetoothStatusCodes | API reference


Error code indicating that the caller does not have the android.Manifest.permission#BLUETOOTH_CONNECT permission. static Int. ERROR_PROFILE_SERVICE_NOT_BOUND.Read more

Request runtime permissions | Privacy


This document guides developers on how to request runtime permissions in Android applications, detailing the workflow, explaining user experience principles ...

Transfer Bluetooth data | Connectivity


11 Apr 2026 — This document explains how to transfer data between connected Bluetooth devices using BluetoothSocket, InputStream, and OutputStream, ...

Communicate in the background | Connectivity


26 Feb 2026 — This guide provides an overview of how to support key use cases for communicating with peripheral devices when your app is running in the background.

Permissions on Android | Privacy


This document provides an overview of how Android app permissions work, describing different permission types, the workflow for using them, ...

Android 14 features and changes list


Enforcement of BLUETOOTH_CONNECT permission in BluetoothAdapter. Android 14 enforces the BLUETOOTH_CONNECT permission when calling the BluetoothAdapter ...Read more

Companion device pairing | Connectivity


Companion device pairing performs a Bluetooth or Wi-Fi scan of nearby devices on behalf of your app without requiring the ACCESS_FINE_LOCATION permission.Read more

Behavior changes: all apps


in Android 16, jobs that are executing concurrently with a foreground service will adhere to the job runtime quota.

BluetoothConnectionManager | API reference


10 Feb 2025 — This class is responsible for handling Bluetooth pairing and connections with a remote BluetoothDevice.Read more

Power management resource limits | App quality


19 May 2026 — Execution quota behavior for jobs changed in Android 16. Prior to Android 16 there was no execution limit when the app was running a foreground ...

Behavior changes: all apps


3 Mar 2026 — This document outlines behavior changes introduced in Android 9 (API level 28) that affect all apps, regardless of their target API level, ...

Audio routing API updates in Android 14 for VoIP apps


26 Feb 2026 — Android 14 introduced API updates accompanied by user experience changes to audio routing behavior for Bluetooth LE Audio (LEA) devices, including hearing aids.Read more

Behavior changes: all apps


The Android 14 platform includes behavior changes that might affect your app. The following behavior changes apply to all apps when they run on Android 14.Read more

Manage audio focus | Android media


Only one app can hold audio focus at a time. When your app needs to output audio, it should request audio focus. When it has focus, it can play sound.Read more

Behavior changes: all apps


One-time permissions: Gives users the option to grant more temporary access to location, microphone, and camera permissions. Permission dialog visibility: ...Read more

Connect to a GATT server


26 Feb 2026 — To connect to a GATT server on a BLE device, use the connectGatt() method. This method takes three parameters: a Context object, autoConnect.Read more

App Standby Buckets | App quality


Beginning with Android 16 (API level 36), background jobs have a generous runtime quota if they're started by an app in the active bucket. This includes jobs ...Read more

Sharing audio input | Android media


If one of the apps is privacy-sensitive, it receives audio and the other app gets silence even if it has a UI on top or started capturing more recently. If both ...Read more

Explain access to more sensitive information | Privacy


The permissions related to location, microphone, and camera grant your app access to particularly sensitive information about users.Read more

AudioRecord | API reference


java.util.concurrent. Overview. Interfaces. BlockingDeque · BlockingQueue · Callable · CompletableFuture.AsynchronousCompletionTask · CompletionService ...

Camera • Audio | App quality


10 Apr 2026 — Connect an external audio device, such as headphones or a USB microphone. Use the app's audio switcher to toggle between the device's built-in ...Read more

MediaRecorder overview | Android media


14 Mar 2025 — This document shows you how to use MediaRecorder to write an application that captures audio from a device microphone, save the audio, and play it back.Read more

AudioFocusRequest | API reference


Note: If an app targets Android 15 (API level 35) or higher, it cannot request audio focus unless it's the top app or running a foreground service.

Audio recording | Connectivity


26 Feb 2026 — Audio recorders can be set up using the standard AudioRecord builder. Use the channel mask to select stereo or mono configuration.Read more

Android 15 features and changes list


Apps that target Android 15 must be the top app or running an audio-related foreground service in order to request audio focus. Camera and media, New ...Read more

MicrophoneDirection | API reference


13 Feb 2026 — AudioRecord, MediaRecorder · AudioRecord, The AudioRecord class manages the audio resources for Java applications to record audio from the ...Read more

WebChromeClient.FileChooserParams | API reference


26 Mar 2026 — Returns preference for a live media captured value (e.g. Camera, Microphone). True indicates capture is enabled, false disabled. Use ...Read more

Voice input | Cars


5 Sept 2025 — The voice input feature lets apps access the car's microphone to gather audio input for purposes such as creating an in-app assistant.Read more

Use a projected context to access hardware on audio ...


16 Jun 2026 — To access multiple microphones on the glasses, you must request audio permissions specifically for the projected device. The standard, phone- ...Read more

Audio input focus | AI Glasses


7 Jan 2026 — Audio focus is equivalent to Input on glasses. Apps can request focus to play audio, and duck or pause when another app gains focus. Only one ...Read more

Record from the car microphone


5 Mar 2026 — You can use your car's CarAppService and CarAudioRecord API to grant your app access to the user's car microphone.Read more

MicrophoneInfo | API reference


13 Feb 2026 — Returns A device group id that can be used to group together microphones on the same peripheral, attachments or logical groups. Main body is ...Read more

Core app quality guidelines


20 Mar 2026 — App should request audio focus when audio starts playing and abandon audio focus when playback stops. Audio:Interrupt, T-Audio:Interrupt, App ...Read more

AAudio | Android NDK


6 Mar 2026 — The sharing mode that determines whether a stream has exclusive access to an audio device that might otherwise be shared among multiple streams.Read more

Capture video and audio playback | Android media


An app can record the video or audio that is being played from another app. Such apps must handle the MediaProjection token correctly. This page explains how.Read more

Core app quality guidelines


8 Apr 2026 — App must use a foreground service to prevent the system from killing the app process once the app is no longer visible. The app must also ...Read more

PowerManager | API reference


26 Mar 2026 — Device battery life will be significantly affected by the use of this API. Do not acquire WakeLock s unless you really need them, use the ...Read more

Settings | API reference


You can use PowerManager.isIgnoringBatteryOptimizations() to determine if an application is already ignoring optimizations.

Notification runtime permission | Jetpack Compose


This document explains the `POST_NOTIFICATIONS` runtime permission introduced in Android 13 (API level 33), detailing how apps should request it, the impact ...

Behavior changes: all apps


Starting in Android 13 (API level 33), users can complete a workflow from the notification drawer to stop apps that have ongoing foreground services, as shown ...Read more

Create and manage notification channels | Jetpack Compose


This document explains how to implement notification channels, a feature introduced in Android 8.0 (API level 26), which requires all notifications to be ...

Display time-sensitive notifications | Views


This document explains how to handle urgent notifications on Android, covering the necessary permissions, channel creation, and display methods for ...

en.wikipedia.org
en.wikipedia.org
Android (operating system)


Android is an open-source operating system developed by Google. Android is based on a modified version of the Linux kernel and other free and open-source ...Read more

GitHub


GitHub is a proprietary developer platform that allows developers to create, store, manage, and share their code. It uses Git to provide distributed version ...Read more

Stack (abstract data type)


In computer science, a stack is an abstract data type that serves as a collection of elements with two main operations.Read more

reddit.com
reddit.com
r/Android


r/Android: Android news, reviews, tips, and discussions about rooting, tutorials, and apps. General discussion about devices is welcome.

What are stacks? : r/learnprogramming


I know this is quite a basic question but I haven't managed to find a good definition. Now I just know what a stack array is but am still clueless when ...

Should I ask my app users to disable battery optimization?


My opinion is no, you shouldn't ask for disable optimization because this affect your updates. It is not the core feature of your app, your widget can work ...Read more

DontKillMyApp is a new benchmark for how aggressively ...


DontKillMyApp is a new benchmark for how aggressively your phone kills background apps. Huawei is the worst OEM in killing background apps. ...

github.com
github.com
Amir-yazdanmanesh/TileService


A TileService provides the user a tile that can be added to Quick Settings. Quick Settings is a space provided that allows the user to change settings and take ...Read more

GitHub · Change is constant. GitHub keeps you ahead. · GitHub


From your first line of code to final deployment, GitHub provides AI and automation tools to help you build and ship better software faster. A Copilot chat ...

Adds androidStopForegroundOnCompleted to ...


This PR adds a AudioServiceConfig parameter androidStopForegroundOnCompleted which will stop foreground service when AudioProcessingState == ...

[BUG]: Audio does not record when screen locks #1070


15 Aug 2024 — After going through a lot of documentation & trial and errors, it seems the recording should start by starting a foreground service with a notification.

Task stops working after 3 minutes on android 14 #247


18 Oct 2024 — I'm facing an issue where the microphone stops working when the app is in the background, even though the camera and microphone permissions are ...

Foreground Service behaviour in Android 13 and 14 #958


14 Jan 2024 — Starting in Android 13 (API level 33), users can dismiss the notification associated with a foreground service by default. To do so, users perform a swipe ...Read more

mediasession/explainer.md at main


The MediaSession API gives pages the ability to specify the metadata of the currently playing media. The metadata will be passed to the platform.Read more

Issue #632 · zoontek/react-native-permissions


REQUEST_IGNORE_BATTERY_OPTIMIZATIONS'. Why it is needed. Our app needs the permission to run an infinite background service on android. We implemented a working ...

fe-dudu/expo-ignore-battery-optimizations


isIgnoringBatteryOptimizations() returns: true when the app is already exempt from battery optimizations; false on Android when the exemption is not active ...

REQUEST_IGNORE_BATTERY_...


2 Oct 2016 — An app holding the REQUEST_IGNORE_BATTERY_OPTIMIZATIONS permission can trigger a system dialog to let the user add the app to the whitelist directly, without ...

foreground-service · GitHub Topics


A modern Android work-hours tracker. Features clock in/out with persistent notifications, A library for audio recording at foreground.

agnihotripushkar/AudioMemo


FOREGROUND_SERVICE, Keep the recording service alive in the background. FOREGROUND_SERVICE_MICROPHONE, Android 14 foreground service type for microphone access.Read more

Fossify Voice Recorder


Fossify Voice Recorder empowers you to capture high-fidelity recordings effortlessly, ensuring that every detail is preserved with clarity and precision.Read more

Broadcast Video (and Audio) while on a Foreground ...


13 May 2019 — By using an on-demand foreground service, I can send said service to the foreground while my activities are gone/stopped/destroyed.

landomen/ForegroundServiceSamples: Simple sample ...


This sample app demonstrates how to use the foreground service on Android 16. It is meant as a companion to the Guide to Foreground Services on Android 14 ...Read more

Microphone Not Working in Background on Android Device


26 Jan 2025 — I'm facing an issue where the microphone stops working when the app is in the background, even though the camera and microphone permissions are ...Read more

Stereo recording · Issue #205 · FossifyOrg/Voice-Recorder


20 Aug 2025 — Every proper recording app must be able to take advantage of multiple microphones to achieve realistic bi-natural sound. For example, Audio ...Read more

Vitaliy-B/Audio-Voice-Recorder


While in foreground, service shows notification with media buttons. Recording is performed using MediaRecorder, playback is performed using MediaPlayer.

Showing notification from inside Foreground Service while ...


6 Mar 2023 — When I fire a notification from my Foreground Service while app is in Background, I get a notification "DELIVERED" to my onBackgroundEvent ...Read more

Releases · FossifyOrg/Voice-Recorder


16 Feb 2026 — An easy way of recording any discussion or sounds without ads or internet access - Releases · FossifyOrg/Voice-Recorder.

The BabyApp is a smart Audio Recorder Android App ...


An Android app that runs continuously, listens to ambient sound through the microphone, and uploads short recordings

mediasession · GitHub Topics


Android app blocking the headphone media button (play/pause / headset hook) so messengers like TeamTalk don't toggle the microphone. android kotlin ...

automatic call recording · Issue #559 · FossifyOrg/Phone


6 Sept 2025 — Currently, Fossify Phone does not provide an option for automatic call recording, which means I have to manually remember details or use third- ...Read more

urbandroid-team/android-audio-recorder-foreground-service


Contribute to urbandroid-team/android-audio-recorder-foreground-service development by creating an account on GitHub.

Yunto - Voice-first AI companion for Android


An Android Foreground Service with an active MediaSession intercepts the button. Yunto only captures it when no other audio app (e.g. Spotify) holds ...

cordova-plugin-foreground-service/src/ForegroundService. ...


Foreground service with ongoing notification for Android. Search code, repositories, users, issues, pull requests...

Android 14 requires a foreground service type for ...


7 Oct 2023 — Tasker is foreground if it binds to our service we are foreground too. So the actual real solution is to fix the API to not require foreground ...Read more

Android 14 requires a foreground service type for ...


7 Oct 2023 — As of Android 14, all foreground services need a type. Currently, when targeting 14, you get this exception when running a plugin: E FATAL ...

Android 14/15 (targetSdk 35): one-way audio after ...


26 Aug 2025 — On Android 14/15 with targetSdkVersion 35, TVConnectionService attempts to start a foreground service with FOREGROUND_SERVICE_TYPE_MICROPHONE ...Read more

osmus/tileservice: Central repo for the OSM US vector tile ...


Anyone can access the OSM US-generated tilesets without restrictions by setting up their own custom server using our requester-pays S3 bucket. Running Your Own ...Read more

Android 14 foreground service permission causes app ...


27 Feb 2024 — The app must be in the eligible state/exemptions to access the foreground only permission error. Our app hasn't changed and the only thing we did was updating ...Read more

Restricted foreground service types · Issue #4832


15 Feb 2026 — A production version of your app crashes because it uses BOOT_COMPLETED broadcast receivers to start a restricted foreground service type.

[native code] foreground service is killed and never restarted


21 Jan 2024 — Each time I killed the foreground service and restarted the app, the foreground service always seemed to come back on after about 30 seconds.

Support for background recording on Android with expo ...


11 Nov 2025 — it requires foreground service, would be nice to have something built in into expo audio or mention above in docs.Read more

urbandroid-team/android-audio-recorder-foreground-service


Contribute to urbandroid-team/android-audio-recorder-foreground-service development by creating an account on GitHub.

Recording audio while other app use the microphone


29 Jun 2025 — The guide show you how to allow your app to record audio from the microphone while other app use it. This way you can use microphone at same ...Read more

Hide in-progress recordings · Issue #87 · FossifyOrg/Voice- ...


16 Jan 2025 — Feature description. The app should not show recordings in-progress or at least indicate the same in the UI.Read more

Simple App to demonstrate Foreground Service using ...


Creating a Foreground Service takes the following steps. Start a Service, a Sticky Service that sticks to the Application. Display a notification to let Android ...

zelloptt/android-media-session-sample: A ...


A sample app demonstrating what headset key events are captured with and without the Google app. - zelloptt/android-media-session-sample.

Android-Foreground-Service-Example/app/src/main/java ...


An example related to a foreground service (I've created it for StackOverflow) ...

App doesnt recognise audio files from previous app #24


17 Feb 2024 — Installed both Fossify Voice-Recorder and SMT Voice-Recorder; Recorded audio in both apps; Verified with a file manager that both apps placed ...Read more

Audio-Voice-Recorder/README.md at master


Audio & Voice recorder for android, which uses background / foreground service, that extends MediaBrowserService. Interaction between UI Activity and Service ...

Foreground service types are required since Android 14


4 Jul 2023 — Blocking of foreground services started when the app is visible for those kind of use case without an appropriate solution will trigger issues.Read more

Crash on Android 14+ when CallkitNotificationService ...


29 May 2026 — The plugin unconditionally includes the microphone bit when building the mask, causing startForeground to throw if permission/state is missing.Read more

docs.geotools.org
docs.geotools.org
TileService (Geotools modules 35-SNAPSHOT API)


A TileService represent the class of objects that serve map tiles. TileServices must at least have a name and a base URL.Read more

openstreetmap.us
openstreetmap.us
OSM US Tileservice


24 Sept 2025 — The OpenStreetMap US Tileservice is a free web service which provides vector map tiles and related resources to help people create maps that ...

stackoverflow.com
stackoverflow.com
Launch an activity from TileService for Android 14 is not ...


I have a simple TileService and try to launch an activity by click on the tile. It is works on Android 13 and low but in Android 14 I get an exception: ...

Foreground Service crashing on Android 14


I have an Android application that worked fine until Android 13. After upgrading to Android 14 (Setting targetSdkVersion as 34) my application is Crashing ...

Newest 'foreground-service' Questions


6 May 2026 — How to start a FOREGROUND_SERVICE with microphone access in background on Android 14? I'm developing a child safety app as a pet project. On ...Read more

Recently Active 'foreground-service' Questions


How to start a FOREGROUND_SERVICE with microphone access in background on Android 14? I'm developing a child safety app as a pet project. On the parent's ...Read more

Android foreground service holds microphone access even ...


After I close the app, the microphone is inacessible to other apps, even if the service is killed (the service notification goes away).

Highest scored 'android-14' questions


Foreground Service crashing on Android 14. I have an Android application that worked fine until Android 13. After upgrading to Android 14 (Setting ...Read more

Android is app still showing Bluetooth connect permission ...


I was fiddling around with Bluetooth connections in Java in an app, and once I was done, I removed all the initialization code, and the permissions ...

Newest 'android-15' Questions


Is there a way to change the icon color of the 3-button navigation bar on Android 15 & 16? I've already changed the background color of the status bar, the icon ...Read more

Newest 'android-source' Questions


11 Jun 2026 — I want to build my own Android operating system based on AOSP for a Point of Sale (POS) device, but I am not sure where to start.Read more

Newest 'android-permissions' Questions


27 May 2026 — I am developing an Android app using Health Connect (version 1.1.0-rc01) on a Pixel 9a running Android 15. I'm trying to request Health ...Read more

REQUEST_IGNORE_BATTERY_...


This is a normal permission: an app requesting it will always be granted the permission, without the user needing to approve or see it.

What's the point of a foreground service to record audio in ...


So now my question is: Why would I use a foreground service if it has literally no influence on audio recording on Android 11+? I can just ...Read more

Start a Foreground Service From a Quick Tile on Android ...


Start an Activity from the TileService that in turn starts the Foreground Service. This approach seems to be clunky. Implement the recording ...Read more

Newest 'android-service' Questions - Page 2


So starting from Android 34 TileService doesn't allow to start a foreground service and use location | camera | mic anymore (though no official info about ...

Recently Active 'android-camera2' Questions


5 Aug 2025 — My app process starts a foreground service when it receives. That service is for video recording (dashboard camera app) which uses camera and ...

Newest 'android-broadcast' Questions


I have a BroadcastReceiver that listens for call state changes, and when a call ends, it sends a local broadcast to my Activity. This works most of the time, ...Read more

Context.startForegroundService() did not then call Service. ...


I am using Service Class on the Android O OS. I plan to use the Service in the background. The Android documentation states that If your app targets ...

Newest 'android-bluetooth' Questions


I am trying to send some data to a BLE Device but for some reasion it says data is sent successfully but actually the BLE is not doing any thing where asI ...Read more

docs.kony.com
docs.kony.com
android.service.quicksettings.TileService - Documentation


A TileService provides the user a tile that can be added to Quick Settings. Quick Settings is a space provided that allows the user to change settings and take ...Read more

www2.microstrategy.com
www2.microstrategy.com
TileService (Web API 2021) - MicroStrategy


The tile service reads the tile files and generates the map of tile id and shape ids. By default there is only one tile file named tiles.idx.Read more

play.google.com
play.google.com
GitHub - Apps on Google Play


GitHub for Android lets you move work forward wherever you are. Stay in touch with your team, triage issues, and even merge, right from the app.Read more

Stack – Apps on Google Play


Build the perfect tower again. Stack is improved with polished visuals, smoother controls, and refined features designed for your next high score.Read more

DontKillMyApp: Make apps work


DontKillMyApp is a benchmark tool to see how well does your phone support background processing. You can measure before setting up your phone, then go through ...Read more

gist.github.com
gist.github.com
Record audio on Android in the background (even when ... - Gist


In my app, it seems like what did the trick was triggering the recording-thread-creation and record-starting from the VolumeProvider.onAdjustVolume handler in ...

Record audio on Android in the background (even when ... - Gist


It doesn't matter if you create the thread and/or AudioRecord "from" the foreground-service; the foreground-service (with valid flags and such, as seen above) ...Read more

github.blog
github.blog
The GitHub Blog: Home


Updates, ideas, and inspiration from GitHub to help developers build and design software. across the GitHub ecosystem and the wider industry. over 180 million ...

medium.com
medium.com
Guide to Foreground Services on Android 14


Android 14 includes breaking changes related to foreground services that need to be incorporated if you want to target SDK version 34.

Android permissions for Bluetooth | by Konstantinos Mihelis


In Android 11 you need to request an extra permission for Manifest.permission.ACCESS_BACKGROUND_LOCATION in order for the app to allow you to use Bluetooth ...Read more

Making uploads survive battery optimisations


We can request users to add the app to the whitelist using an ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS intent. For this, the ...

Using BroadcastReceiver in Android | by Ömer Şentürk


Broadcast Receiver is a component that allows us to listen to certain events that occur within the Android operating system or between ...Read more

Foreground Service in Android - by Nicos Nicolaou


First of all, you have to create a broadcast receiver class and add your code there as bellow. Note: I handled it with secure share preferences ...Read more

Understanding MediaSession (Part 2/4)


MediaSession is the middleware that allows outside actors to control the media player in your app (outside of the app's own UI).Read more

x.com
x.com
GitHub (@github) / Posts / X


The AI-powered developer platform to build, scale, and deliver secure software. all on the GitHub platform. you can now obtain your public repo on CD-ROM.

devforum.zoom.us
devforum.zoom.us
Issue with releasing app targeting Android 14 due to ...


11 Jul 2024 — Releasing the app targeting SDK 34 (Android 14) fails with Error 403: You must let us know whether your app uses any Foreground Service.Read more

git-scm.com
git-scm.com
Git


Git is a free and open source distributed version control system designed to handle everything from small to very large projects with speed and efficiency.Read more

youtube.com
youtube.com
Foreground Service in Android 14


In this video we're going to discuss the changes to the functionality of foreground services that Android 14 introduces.

Learn Stack data structures in 10 minutes


stack = LIFO data structure. stores objects into a sort of "vertical tower" 3. backtracking algorithms 4. calling functions (call stack)

Set unrestricted battery optimization programatically in ...


In today's video I will show you how to ask from user to allow permission for ignoring battery optimization for our application.

geeksforgeeks.org
geeksforgeeks.org
Stack Data Structure


20 Jan 2026 — A stack is a linear data structure that follows a particular order in which the operations are performed. The order may be LIFO(Last In First Out) or FILO( ...Read more

Broadcast Receiver in Android With Example


15 Jul 2025 — Broadcast Receivers are used to respond to these system-wide events. Broadcast Receivers allow us to register for the system and application events.Read more

issuetracker.google.com
issuetracker.google.com
Microphone restricted when the app goes into background ...


27 Feb 2024 — When I put the app in the background during a call, the microphone became unaccessible despite I am having a foreground service running with type phoneCall.Read more

ACTION_REQUEST_IGNORE_B...


1. Install a simple Hello World app, which checks whitelist via isIgnoringBatteryOptimizations. If FALSE, it fires android.provider.Settings.ACTION_REQUEST_ ...Read more

Starting foreground service from TileService.onClick is no ...


... mic, location in a foreground service which is started from TileService anymore. And there is no info about such changes between Android 13 and Android 14 ...Read more

Android 15: TileService onClick does not allow ...


5 Nov 2024 — Regression from Android 13 to Android 14 & 15: TileService onClick is not allowed to start a foreground service.Read more

startForeground() method throwing exception. [288530842]


It's the expected behavior. In android 14, you cannot set a service as foreground for microphone/camera/location if it was started from the background. By the ...Read more

docs.oracle.com
docs.oracle.com
Stack (Java Platform SE 8 )


The Stack class represents a last-in-first-out (LIFO) stack of objects. It extends class Vector with five operations that allow a vector to be treated as a ...Read more

w3schools.com
w3schools.com
Introduction to Git and GitHub


What is Git? Git is a popular version control system. It was created by Linus Torvalds in 2005, and has been maintained by Junio Hamano since then.

C++ Stacks


A stack stores multiple elements in a specific order, called LIFO. LIFO stands for Last in, First Out. To vizualise LIFO, think of a pile of pancakes.Read more

programiz.com
programiz.com
Stack Data Structure and Implementation in Python, Java ...


A stack is a linear data structure that follows the principle of Last In First Out (LIFO). This means the last element inserted inside the stack is removed ...Read more

proandroiddev.com
proandroiddev.com
Foreground Services in Android 14: What's Changing?


22 Oct 2023 — Foreground services are kind of services that perform operations providing a notification for the user. Here you can learn more about definition and various ...Read more

What's new in Android 14 for developers | by Kirill Rozov


4 Oct 2023 — Let's examine new restrictions on background mode, changes in Foreground Service, new restrictions on the work of Intent and BroadcastReceiver.Read more

Enhancing Android TV Playback Experience with ...


15 Mar 2023 — A MediaSession is the control center where we can read information about what is currently being played on the Android device and dispatch media control ...Read more

developer.mozilla.org
developer.mozilla.org
MediaSession - Web APIs | MDN


12 Jul 2025 — The MediaSession interface of the Media Session API allows a web page to provide custom behaviors for standard media playback interactions.Read more

w3.org
w3.org
Media Session


5 Jun 2026 — This specification enables web developers to show customized media metadata on platform UI, customize available platform media controls, and access platform ...Read more

android.stackexchange.com
android.stackexchange.com
bluetooth - Control playback using headset media buttons ...


8 May 2022 — Control playback using headset media buttons when using Android Select to Speak functionality · What I ideally want to achieve: TTS for any text ...Read more

support.google.com
support.google.com
Android Help


Official Android Help Center where you can find tips and tutorials on using Android and other answers to frequently asked questions.

blog.google
blog.google
Official Android news and updates


Explore the latest features in Android 17, including enhanced productivity, gaming and security. All the Latest. Let's stay in touch. Get the latest news from ...

web.dev
web.dev
Customize media notifications and playback controls with ...


10 Jun 2024 — A media session action is an action (for example "play" or "pause") that a website can handle for users when they interact with the current ...Read more

samsung.com
samsung.com
What is an Android phone? | Features & Advantages


An Android phone is a smartphone powered by the Android operating system. It's fast, flexible, and open, meaning it works beautifully and lets you personalise ...

android.googlesource.com
android.googlesource.com
media/java/android/media/session/MediaSession.java


* Override to handle requests to prepare a specific media item represented by a URI. * During the preparation, a session should not hold audio focus in order ...Read more

dontkillmyapp.com
dontkillmyapp.com
Don't kill my app! | Hey Android vendors, don't kill my app!


Don't kill apps, make them work! Android manufacturers listed below prefer battery life over proper functionality of your apps. See below on how you can fix it.Read more

Our mission


Communicate these issues with users and provide them with hacks, workarounds and guides to keep their apps working and making their lives easier.Read more

Samsung


On Android 11 Samsung will prevent apps work in the background by default unless you exclude apps from battery optimizations.Read more

Xiaomi


On MIUI 14, there is a new permission to start from the background for each app, in Settings > Apps > Your app > App permissions > Background autostart.Read more

Oneplus


Locking the app in the Recent apps may prevent the app from being killed. Turn off System settings > Battery > Battery optimization, switch to 'All apps' in ...

Huawei


Huawei introduced a new task killer app called PowerGenie which kills everything not whitelisted by Huawei and does not give users any configuration options.Read more

Oppo


Background services are being killed (including accessibility services, which then need re-enabling) every time you turn the screen off.Read more

Vivo | Don't kill my app!


Apps locked in the taskbar are safe from getting terminated when they run in the background. 1. Swipe up the app down while it is open in the background.Read more

General


First check your phone settings whether some background processing is not restricted on your device. See below for general solutions that apply for various ...Read more

Tecno


Aggressive battery setting causes app to be completely halted, like frozen in time, so, timers, services, foreground services, all of them stop working.Read more

Meizu


Enable Device Settings > Apps > your app > Battery > Power-intensive prompt and Keep running after screen off. Security > Permissions > Background processes > ...Read more

Sony


Try to make your app not battery optimized in Phone settings > Battery > Three dots in the top right corner > Battery optimisation > Apps > your app.” Solution ...Read more

Google | Don't kill my app!


Go to Settings > Apps > Your app > Advanced > Battery > Battery optimization · Change view to All apps · Search for your app · Choose Not optimized ...Read more

Realme


On newer versions, the App battery management was moved to system settings → Battery → Power saving settings → App battery management. 1. Open the Battery ...Read more

Motorola


Go to your phone's settings. · Scroll down and tap on 'Apps & notifications'. · Tap on the your app. · Tap on 'Advanced'. · Tap on 'Battery'. · Tap on 'Background ...Read more

docs.sentiance.com
docs.sentiance.com
Battery Optimization on Android


17 Jun 2025 — The Sentiance SDK does not define the REQUEST_IGNORE_BATTERY_OPTIMIZATIONS permission required for this feature. You must therefore ...

androidenterprise.community
androidenterprise.community
https://www.androidenterprise.community/discussion...


No information is available for this page.

9to5google.com
9to5google.com
'DontKillMyApp' measures how Android kills background ...


25 Jun 2020 — This free app is designed to benchmark how your phone treats the background processes on it. The app allows users to run benchmarks between 1 hour and 8 hours.Read more

organicmaps.app
organicmaps.app
Why tracks are not recorded reliably in background on ...


Default battery optimization settings on Samsung, Huawei, Google, Xiaomi, OnePlus, may stop or kill Organic Maps app in the background. listed here: ...

monitor.f-droid.org
monitor.f-droid.org
log: org.fossify.voicerecorder:2


11 Jan 2025 — ... git vcs interface for https://github.com/FossifyOrg/Voice-Recorder.git 2025-01-11 22:44:05,076 DEBUG: Checking org.fossify.voicerecorder:2 ...Read more

topcoder.com
topcoder.com
Android: Broadcast Receiver


19 Apr 2022 — Android OS sends broadcasts to apps when any event happens in the app or in the system. Broadcast receivers helps our app communicate with Android OS and other ...Read more

forum.juce.com
forum.juce.com
Android 14 foreground service


21 May 2024 — If your app targets Android 14, it must specify appropriate foreground service types. services may be of three different kinds: foreground, ...

learn.microsoft.com
learn.microsoft.com
BroadcastReceiver Class (Android.Content)


Base class for code that receives and handles broadcast intents sent by android.content.Context#sendBroadcast(Intent).Read more

linkedin.com
linkedin.com
What Works in 2025 (Android 16 – API 36) | Tashaf Mukhtar


Foreground Service Used for user-visible, ongoing work like music playback, navigation, or fitness tracking. ✅ Requirements: Start with ...

dev.simplu.info
dev.simplu.info
Mastering Foreground Services with Android 14 - DevElevate


26 Feb 2025 — Explore the crucial changes in Android 14's foreground services, including mandatory service types and runtime permissions, to stay ahead in app ...Read more

google.com
google.com
[Android 11 DP/Beta] No permission to access the Microphone ...


I believe a foreground service indicates a usage of the app and hope this is a bug which will be fixed before final release of Android 11. If this is intended ...Read more

Broadcast Receiver App


10 Jul 2023 — Broadcast Receiver App can: ✓ Register or unregister a receiver in either activity context or app context. ✓ Send either sorted or unsorted ...Read more

zoom.us
zoom.us
App update rejected due to Foreground service permissions


1 Feb 2024 — Google rejected the latest app update because I need to provide more information about the foreground service.Read more

f-droid.org
f-droid.org
Fossify Voice Recorder Beta


Fossify Voice Recorder empowers you to capture high-fidelity recordings effortlessly, ensuring that every detail is preserved with clarity and precision.

AndroidMic | F-Droid - Free and Open Source Android App ...


AndroidMic lets you use your Android device as a microphone for your PC. This tool supports multiple connection methods, including TCP, UDP, USB serial, ...Read more

microsoft.com
microsoft.com
MediaSession Class (Android.Media.Session)


A MediaSession should be created when an app wants to publish media playback information or handle media keys. In general an app only needs one session for all ...

argenox.com
argenox.com
What's New in Bluetooth for Android 15 - Argenox


5 May 2025 — Android 15 brings notable upgrades to BLE features, stack architecture, and performance optimizations.Read more

akaver.com
akaver.com
12 - Foreground Service | Native Mobile Applications - Courses


29 Apr 2026 — Foreground services perform operations that are noticeable to the user - music player, tracking location, etc. Showing a status bar notification is mandatory.Read more

samsungknox.com
samsungknox.com
KSP Battery Optimization allowlist policy does not appear ...


26 Jul 2023 — Applications can be exempted from battery optimization using the KSP Device-wide or Work profile policy: Application management policies > ...Read more

forasoft.com
forasoft.com
Android foreground service and deep links implementing ...


6 Mar 2026 — Android 14+ hard-enforces foreground service types. Every startForeground() call needs a declared foregroundServiceType and the matching ...Read more

slideshare.net
slideshare.net
Android - Broadcast Receiver | PPTX


This document discusses BroadcastReceivers in Android. A BroadcastReceiver is an intent-based publish-subscribe system that allows apps to receive system ...

uptodown.com
uptodown.com
Older versions of DontKillMyApp (Android)


Download older versions of DontKillMyApp for Android. All of the older versions of DontKillMyApp have no viruses and are totally free on Uptodown.

cc-mnnit.github.io
cc-mnnit.github.io
Android Development


2. Your app is running a foreground service. When a foreground service is running, the system raises user awareness by showing a persistent notification.Read more

miradore.com
miradore.com
Exclude applications deployed on Samsung devices from ...


12 Dec 2025 — Learn how to exclude applications deployed on Samsung devices from battery optimization using the Knox Service Plugin application.

Connector sources scanned

No connector sources scanned