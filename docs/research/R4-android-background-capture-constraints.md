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
