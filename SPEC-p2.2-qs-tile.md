# SPEC: P2.2 — Quick Settings tile trigger (Android)

## Context
P2.1 (already on this branch, compiles green): `app/lib/services/capture/trigger_router.dart` is the single seam for external capture triggers; `app/lib/utils/audio/foreground.dart` notification buttons send `{trigger_source, trigger_action}` via `FlutterForegroundTask.sendDataToMain`, handled in `app/lib/pages/home/page.dart` (`trigger_action` branch) → `TriggerRouter.handleTrigger`.

## Goal
An Android Quick Settings tile ("Omi capture") that toggles phone-mic recording:
- Tap while app process alive → route `action: 'toggle'`, `source: 'qs_tile'` through the SAME TriggerRouter data path (no new decision logic — the router already resolves toggle vs start vs stop against recording state).
- Tap while app process dead → launch the app (MainActivity) with an intent extra carrying the trigger, handled after boot; if that's disproportionate, launching the app without auto-start is an acceptable v1 — say so in the summary.
- Tile state (active/inactive label) should reflect recording state on a best-effort basis; static label is acceptable for v1 if state sync is disproportionate — note the choice.

## Implementation constraints
- Branch: feature/p2-triggers (this worktree). Commit here; do NOT commit this SPEC file.
- Kotlin `TileService` under the existing Android source tree (find the app's kotlin package dir under `app/android/app/src/main/`); manifest entry with `android.permission.BIND_QUICK_SETTINGS_TILE` intent filter. minSdk is 29 — TileService is API 24+, fine.
- Investigate FIRST how the Flutter side can receive events from a TileService with this app's existing plugins (flutter_foreground_task's send-data APIs, existing MethodChannels, or an intent through MainActivity → home page). Prefer the smallest path that reuses the existing `trigger_action` handling; do not add new plugin dependencies.
- All new user-visible strings: the tile label may be a plain string in Android resources (strings.xml) — that is fine; don't touch Flutter l10n for this.
- Ponytail rules: shortest working diff, reuse the P2.1 seam, mark deliberate v1 ceilings with `// ponytail:` comments.
- One commit for the tile + routing. Keep Dart file formatting at 120 cols.

## Deliverables
- Commit(s) on feature/p2-triggers.
- Summary: how the tile reaches Dart, what happens when the app is dead, tile-state choice, files touched, anything unverifiable locally (no Flutter/Android toolchain here — CI compiles).
