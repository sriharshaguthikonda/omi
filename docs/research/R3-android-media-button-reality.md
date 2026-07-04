# R3 — Bluetooth media-button / MediaSession KeyEvent delivery + device attribution across Android OEMs

**Priority: HIGH.** This determines whether the flagship feature (P3: "any button on any of my BT devices triggers capture") is achievable on real hardware or needs a fallback.

## Context (for the researcher)

Personal Android app. I want any button on any paired Bluetooth device (classic A2DP/AVRCP headsets, TWS earbuds, BLE HID remotes) to trigger an action in my app — start/stop/mark a recording. Plan: hold an active `MediaSession` while "armed" and receive `KeyEvent`s (play/pause/next/prev, single/double/long-press). I need the real-world truth, not the happy-path docs.

## Questions to answer (official docs + real developer/XDA/StackOverflow reports)

1. **Delivery reliability:** When a Bluetooth headset sends AVRCP play/pause/next/prev, does it reliably reach an app's `MediaSession.Callback.onMediaButtonEvent` / `MediaSessionCompat`? What determines whether *our* session receives it vs the current music app? How does Android pick the target session (last-active, audio-focus owner)?
2. **Source-device attribution:** Can the app tell **which** Bluetooth device sent a media button? Is `KeyEvent.getDeviceId()` populated for BT-originated media keys, and does `InputDevice.getDevice(id)` yield the BT device? Real reports say attribution is often absent — quantify: which Android versions / device classes populate it, which don't?
3. **Press-pattern detection:** How do apps reliably detect single vs double vs triple vs long-press on media keys, given AVRCP sends discrete key-down/up? Standard debounce windows? Do some headsets collapse double-tap into a single event before it reaches Android?
4. **Single-consumer contention:** While a music app is playing, can our armed `MediaSession` still receive buttons, or does the active-playback session win? What's the UX escape hatch used by apps that need buttons while music plays?
5. **Buttons that never arrive:** Which common headset buttons (assistant/voice button, vendor "action button" on Sony/Bose/Samsung Buds, call button) are **captured by the OS or vendor app** and never delivered to any third-party app? Give concrete examples per brand.
6. **BLE HID / custom GATT alternative:** For devices that expose buttons as BLE GATT characteristics or HID (not AVRCP), what's the reliable capture path, and is source attribution guaranteed there (it should be, since it's a direct GATT connection)?
7. **Screen-off / locked:** Do media buttons reach the app when the screen is off or the device is locked, assuming an active MediaSession + FGS?

## Desired deliverable

- A **reality matrix**: device class (classic headset / TWS buds / BLE HID) × button type × (delivered to 3rd-party app? source-attributed? works screen-off?) with Android-version and OEM caveats.
- The **canonical modern recipe** (Media3 `MediaSession`) for receiving hardware media buttons in a non-music utility app, with code pointers.
- A ranked list of **which trigger mechanisms are dependable** vs which are best-effort, so we can set user expectations in a "learn mode" wizard.
- Links to open-source apps that map hardware buttons to custom actions (e.g. button-mapper apps) and the APIs they rely on.

## Why it matters

Directly sizes ROADMAP P3 and closes D3 (which button mechanism ships first). If AVRCP attribution is as unreliable as suspected, the design leans on the "ambiguous mapping allowed + learn-mode compatibility probe" path we already sketched (D4), and BLE-GATT devices become the only source-attributed tier.
