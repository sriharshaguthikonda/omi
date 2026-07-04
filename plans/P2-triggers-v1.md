# P2 — Triggers v1 (phone-only) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans. Steps use checkbox (`- [ ]`) syntax. Standing rule: Codex CLI implements, Claude orchestrates and corrects.

**Goal:** Start/stop/mark capture without opening the app — notification action buttons, Quick Settings tile, and a locked-down explicit intent, all feeding one Trigger Router.

**Architecture:** A single Kotlin `TriggerRouter` object is the only entry point for every trigger source (now: notification actions, QS tile, explicit intent; later P3: MediaSession KeyEvents, BLE GATT). It resolves `(source, action)` → capture command, logs every event to a ring log (powers the P3 wizard), and calls into Flutter through the existing Pigeon bridge. No new MethodChannels — extend `app/lib/pigeon_interfaces.dart` and regenerate.

**Tech Stack:** Kotlin (Android native), Pigeon codegen bridge, Flutter/Dart capture layer (existing `capture_provider.dart` / `capture_controller.dart`), AndroidX `TileService`.

**Working assumption (Decision D2, open):** 🟢 option — notification actions + QS tile + explicit intent. If Sri picks "notification + tile only", drop Task 5 (intent receiver); nothing else changes.

## Global Constraints

- New code in **new files** under `app/android/app/src/main/kotlin/com/friend/ios/trigger/` — minimal edits inside upstream files (merge-friendliness rule, ROADMAP "Upstream sync").
- Package: `com.friend.ios` (matches existing Kotlin sources).
- Flutter↔native traffic goes through Pigeon (`app/lib/pigeon_interfaces.dart` → regenerate `PigeonCommunicator.g.kt`), never ad-hoc channels.
- Feedback sounds: single soft beep on start, double on stop, optional haptic. **No periodic "still listening" beeps.**
- Every trigger event logged: `(trigger_source, timestamp, resolved_action)` — this log is a P3 dependency, not optional.
- All user-facing strings via l10n (`context.l10n.*`), ARB keys added with `jq` (repo rule, AGENTS.md).
- Formatting: `dart format --line-length 120`, Kotlin via pre-commit hook.

---

### Task 1: Trigger Router core (Kotlin, no UI)

**Files:**
- Create: `app/android/app/src/main/kotlin/com/friend/ios/trigger/TriggerRouter.kt`
- Create: `app/android/app/src/main/kotlin/com/friend/ios/trigger/TriggerEvent.kt`
- Test: `app/android/app/src/test/kotlin/com/friend/ios/trigger/TriggerRouterTest.kt` (JVM unit test — router is pure logic, no Android deps)

**Interfaces:**
- Produces (later tasks + P3 rely on these exact names):
  ```kotlin
  enum class TriggerSource { NOTIFICATION, QS_TILE, INTENT, MEDIA_KEY, BLE_GATT }   // MEDIA_KEY/BLE_GATT reserved for P3
  enum class TriggerAction { START, STOP, TOGGLE, MARK_LAST_BUFFER }
  data class TriggerEvent(val source: TriggerSource, val action: TriggerAction, val timestampMs: Long, val meta: Map<String, String> = emptyMap())

  object TriggerRouter {
      fun dispatch(event: TriggerEvent)                    // resolve + forward + log
      fun setSink(sink: (TriggerEvent) -> Unit)            // capture layer registers here (Pigeon impl in Task 2)
      fun recentEvents(limit: Int = 100): List<TriggerEvent>  // ring log, P3 wizard reads this
  }
  ```
- Consumes: nothing (root of the dependency chain).

- [ ] **Step 1: Write failing JVM tests** — dispatch forwards to sink; TOGGLE resolves against last known state; ring log caps at 100 and returns newest-first; dispatch without sink doesn't throw (logs only).
- [ ] **Step 2: Run** `cd app/android && ./gradlew :app:testDevDebugUnitTest --tests "*TriggerRouterTest*"` — expect FAIL (class missing).
- [ ] **Step 3: Implement `TriggerEvent.kt` + `TriggerRouter.kt`** — synchronized ring buffer (ArrayDeque, max 100), sink nullable, TOGGLE state tracked from last START/STOP dispatched.
- [ ] **Step 4: Re-run tests** — expect PASS.
- [ ] **Step 5: Commit** `feat(trigger): TriggerRouter core with ring log`

### Task 2: Pigeon bridge — router → Flutter capture layer

**Files:**
- Modify: `app/lib/pigeon_interfaces.dart` (add `TriggerHostApi` (Flutter→host: arm/disarm) and `TriggerFlutterApi` (host→Flutter: onTriggerAction))
- Regenerate: `app/android/app/src/main/kotlin/com/friend/ios/PigeonCommunicator.g.kt` + Dart counterpart (run the repo's pigeon codegen command from `app/`)
- Create: `app/lib/services/trigger/trigger_service.dart` (Dart side: receives onTriggerAction, calls capture)
- Modify: `app/lib/providers/capture_provider.dart` (wire start/stop/toggle entry points — reuse existing recording methods, ~10 lines)

**Interfaces:**
- Consumes: `TriggerRouter.setSink` (Task 1).
- Produces: Dart `TriggerService.init()` called from app bootstrap; `onTriggerAction(String source, String action)` reaching `CaptureProvider`.

- [ ] **Step 1: Add Pigeon API definitions + regenerate** (codegen is the test — it must compile both sides).
- [ ] **Step 2: Implement Kotlin glue** — `TriggerRouter.setSink { PigeonTriggerFlutterApi.onTriggerAction(...) }` registered in `MainActivity`/plugin registration next to existing Pigeon setup.
- [ ] **Step 3: Implement `trigger_service.dart`** — map action string → `CaptureProvider.startRecording()/stopRecording()/toggle` (exact method names verified in Task 2 implementation against `capture_provider.dart`; reuse, don't duplicate state).
- [ ] **Step 4: Verify:** `cd app && flutter analyze` clean; `cd app/android && ./gradlew :app:compileDevDebugKotlin` green.
- [ ] **Step 5: Commit** `feat(trigger): pigeon bridge router→capture`

### Task 3: Notification action buttons

**Files:**
- Create: `app/android/app/src/main/kotlin/com/friend/ios/trigger/TriggerNotificationReceiver.kt` (BroadcastReceiver: PendingIntents → `TriggerRouter.dispatch`)
- Modify: notification construction used by the existing foreground service (`OmiBleForegroundService.kt` notification builder — add action buttons Start/Stop/Mark; keep diff minimal, builder helper lives in new file `trigger/TriggerNotificationActions.kt`)
- Modify: `app/android/app/src/main/AndroidManifest.xml` (register receiver, `exported=false`)

**Interfaces:** Consumes `TriggerRouter.dispatch` + `TriggerSource.NOTIFICATION`.

- [ ] **Step 1: Implement receiver + action builder** (3 actions: START, STOP, MARK_LAST_BUFFER; MARK dispatches but capture layer treats as STOP+flag until P4 ring buffer exists — log-only meta `{"pending":"P4"}`).
- [ ] **Step 2: Wire actions onto the foreground notification** (one `.addAction` call per button inside existing builder).
- [ ] **Step 3: Build + install named test APK, tap each button, verify** via `adb logcat -s TriggerRouter` events land + recording starts/stops.
- [ ] **Step 4: Commit** `feat(trigger): notification action buttons`

### Task 4: Quick Settings tile

**Files:**
- Create: `app/android/app/src/main/kotlin/com/friend/ios/trigger/CaptureTileService.kt`
- Modify: `app/android/app/src/main/AndroidManifest.xml` (tile service, `BIND_QUICK_SETTINGS_TILE` permission, icon/label)

**Interfaces:** Consumes `TriggerRouter.dispatch` with `TriggerSource.QS_TILE`, `TriggerAction.TOGGLE`; tile state listens to router's last-state (`TriggerRouter.recentEvents`).

- [ ] **Step 1: Implement `TileService`** (`onClick` → dispatch TOGGLE; `onStartListening` → reflect current state; qsTile state ACTIVE/INACTIVE).
- [ ] **Step 2: Manual verify on device:** add tile from QS editor, toggle with app killed (tile must start the foreground service path), locked screen, unlocked.
- [ ] **Step 3: Commit** `feat(trigger): quick settings capture tile`

### Task 5: Explicit intent entry (Tasker lane) — GATE D2 🟢 assumed

**Files:**
- Create: `app/android/app/src/main/kotlin/com/friend/ios/trigger/TriggerIntentReceiver.kt`
- Modify: `app/android/app/src/main/AndroidManifest.xml` (receiver `exported=true` + custom permission `com.friend.ios.permission.TRIGGER` signature-level)
- Create: `docs/triggers-intent-api.md` (documented extras: `action` = start|stop|toggle|mark, `token` check)

**Interfaces:** Consumes `TriggerRouter.dispatch` with `TriggerSource.INTENT`.

- [ ] **Step 1: Implement receiver** — verify calling package permission OR shared-token extra (token stored in app settings, shown in a settings row); reject + log otherwise.
- [ ] **Step 2: Verify with adb:** `adb shell am broadcast -a com.friend.ios.TRIGGER --es action toggle --es token <t>` starts/stops capture; wrong token rejected in log.
- [ ] **Step 3: Commit** `feat(trigger): explicit intent trigger with token gate`

### Task 6: Feedback sounds + trigger test matrix

**Files:**
- Create: `app/android/app/src/main/kotlin/com/friend/ios/trigger/TriggerFeedback.kt` (ToneGenerator/SoundPool beep + optional `Vibrator` pulse; called from router on START/STOP)
- Create: `docs/trigger-test-matrix.md` (results table)

- [ ] **Step 1: Implement feedback** (single beep start, double stop, haptic behind a settings flag; volume respects notification stream).
- [ ] **Step 2: Run the matrix on-device** — each trigger (notification, tile, intent) × (locked, unlocked, screen-off, after `adb shell am force-stop` + relaunch of service) — record pass/fail in the matrix doc.
- [ ] **Step 3: Commit** `feat(trigger): audio/haptic feedback + test matrix results`

## Verification (phase exit)

- [ ] All matrix cells pass or have a documented platform-limit note.
- [ ] `flutter analyze` + `./gradlew :app:testDevDebugUnitTest` green.
- [ ] CI APK from this branch installs in-place over previous (signature + versionCode monotonic).
- [ ] Codex review pass on the full diff; findings fixed.
- [ ] ROADMAP P2 checkboxes ticked; this plan's boxes ticked; merged to fork main → apk-latest refresh.
