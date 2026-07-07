# SPEC: P2.3 — Tasker / external-app intent trigger (Android)

## Context
P2.1/P2.2 (already on this branch): `app/lib/services/capture/trigger_router.dart` is the single
seam every trigger source routes through; `TriggerActionBridge` in `MainActivity.kt` forwards a
`{trigger_source, trigger_action}` pair to Dart via MethodChannel when the app is alive, or queues
it as launch-intent extras when it isn't (drained after boot).

## Goal
Let external automation apps (Tasker etc.) start/stop/toggle phone-mic recording via an explicit
broadcast intent, without adding a new plugin dependency, imitating the P2.2 QS-tile pattern.

## Implementation
- `TriggerCaptureReceiver.kt` (new): exported `BroadcastReceiver` for action
  `com.friend.ios.TRIGGER_CAPTURE`, extra `trigger_action` (default `toggle`). Tries
  `TriggerActionBridge.sendTrigger("external_intent", action)`; if the app process is dead, falls
  back to launching `MainActivity` with the same extras (`FLAG_ACTIVITY_NEW_TASK`).
- `AndroidManifest.xml`: registers the receiver, `android:exported="true"` (required — the sender
  is an external app).
- `TriggerRouter.handleTrigger` (Dart): gates `source == 'external_intent'` behind a new
  `SharedPreferencesUtil().externalTriggersEnabled` bool (default `false`). This is the single
  choke point all triggers pass through, so the gate covers both the alive-app and dead-app paths.
- `app/lib/backend/preferences.dart`: `externalTriggersEnabled` get/set, same pattern as
  `vadGateEnabled`.
- `DeveloperModeProvider` + `developer.dart` Experimental section: a toggle row next to VAD
  Gate/Claude Agent to flip the setting.
- l10n: `externalTriggers` / `externalTriggersDescription` keys added to `app_en.arb` and copied
  (English placeholder) into all 48 other `app_*.arb` files.

## Security gate rationale
`TriggerCaptureReceiver` is exported so any installed app can send the broadcast — including one
that starts the microphone. Gating in `TriggerRouter` (not the receiver) means the check applies
uniformly regardless of which path forwarded the intent (live MethodChannel vs. launch-intent
drain), and keeps the receiver itself a dumb forwarder with no security logic to get out of sync.
Default OFF: a user must explicitly opt in from Settings before any external sender can control
recording.

## Test plan (CI compiles; no local Flutter/Android toolchain here)
- Manual, once built: `adb shell am broadcast -a com.friend.ios.TRIGGER_CAPTURE --es
  trigger_action toggle` with the setting OFF (default) — expect no-op, log line in Dart console.
- Same broadcast with the setting ON, app foregrounded — expect recording to toggle.
- Same broadcast with the setting ON, app process killed — expect app to launch and apply the
  trigger after boot (drainPendingTriggers path, same as P2.1/P2.2).
- `flutter gen-l10n` should report zero "untranslated message(s)" warnings for the two new keys.
