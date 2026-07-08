# SPEC — P3 increment 1: BT media-button capture trigger

**Scope:** minimal slice of `plans/P3-bt-trigger-matrix.md` Task 2 — no Room registry, no
attribution tiers, no press-pattern detector, no wizard. Just: opt-in global toggle that
maps a headset's play/pause button to capture toggle.

**What it does:** `BtMediaButtonTrigger` (new, `trigger/bt/`) holds a `MediaSessionCompat`
with a placeholder `STATE_PAUSED` playback state while the app process is alive. Its
`onMediaButtonEvent` callback intercepts `KEYCODE_MEDIA_PLAY_PAUSE` / `PLAY` / `PAUSE` on
`ACTION_DOWN` (first press only, `repeatCount == 0`) and calls
`TriggerActionBridge.sendTrigger("bt_media_button", "toggle")`, which the existing P2
`TriggerRouter` (Dart side, unchanged) resolves into start/stop.

**Gate:** default OFF. `SharedPreferencesUtil().btMediaButtonTriggerEnabled` (Dart) /
`flutter.btMediaButtonTriggerEnabled` (native read, same key the app's own
`FlutterSharedPreferences` file). `BtMediaButtonTrigger.start()` no-ops unless the pref is
true; started/stopped from `MainActivity.configureFlutterEngine` / `onDestroy`.

**Known tradeoff (why default-off):** an active `MediaSessionCompat` competes for
media-button focus system-wide — while enabled it can steal play/pause from whatever music
app the user is actually running. Increment 2 (learn-mode wizard, device registry,
attribution tiers per the full plan) will replace this blunt global switch with per-device
opt-in.

**Not built here:** BLE GATT path, double/long-press patterns, Room-backed mapping engine,
device registry UI, mapping wizard — all later increments/tasks in the plan.

**Known platform caveat (R3 research, unaddressed here):** several reports describe a
paused/idle `MediaSession` losing media-button delivery priority to the system after it
stops being "recently active" (session ranking favors actually-playing sessions). Task 7's
compatibility matrix is where this gets characterized on real devices; no workaround (e.g.
periodic re-activation) is attempted in this increment.

**Debt:** non-English ARB locales got the English string as a placeholder translation for
`btMediaButtonTrigger` / `btMediaButtonTriggerDescription` (49 files); real translation is
outstanding, tracked same as any other untranslated-key debt in this repo.
