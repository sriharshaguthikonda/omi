# P3 — BT Multi-Device Trigger Matrix ⭐ Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans. Steps use checkbox (`- [ ]`) syntax. Standing rule: Codex CLI implements, Claude orchestrates and corrects.

**Goal:** Any button on any paired BT device can be mapped — at runtime, in-app, nothing hardcoded — to any capture action, per device, persistently (Sri's flagship requirement, Q5/D4).

**Architecture:** Two capture layers feed the P2 `TriggerRouter`: (1) a Media3 `MediaSession` held while "armed" receives classic AVRCP media KeyEvents (play/pause/next/prev, single/double/long press); (2) the existing BLE GATT stack (`OmiBleManager.kt`) subscribes to button characteristics on non-media devices. A Device Registry persists known devices; a learn-mode Mapping Wizard records whatever event the user performs and binds it to an action with an explicit attribution tier. Mappings are data, never code.

**Tech Stack:** Kotlin, Media3 (`androidx.media3:media3-session`), existing BLE plumbing (`OmiBleManager.kt`, `BleCompanionService.kt`), Room (registry + mappings), Pigeon bridge (P2 Task 2), Flutter settings UI.

**Working assumption (Decision D3, open):** 🟢 MediaSession KeyEvents first (works with Sri's existing headsets day one), BLE GATT second. If Sri picks BLE-first, Tasks 3–4 swap order — content unchanged.

**Depends on:** P2 Tasks 1–2 (TriggerRouter + Pigeon bridge) merged.

## Global Constraints

- New code under `app/android/app/src/main/kotlin/com/friend/ios/trigger/bt/` — minimal edits to upstream files.
- Every mapping stores its **attribution tier** and the wizard displays it (D4, closed): `CONFIRMED` (KeyEvent.deviceId resolved) / `INFERRED` (connected-set + audio route) / `AMBIGUOUS` (any device sending this event).
- Armed mode holds session + registry only — mic closed, ~zero battery.
- Mappings export/import as versioned JSON (survive reinstall).
- All strings l10n; ARB via `jq`.
- Platform limits stay visible in UI (buttons that never deliver events → wizard says "this button never reached the app").

## Data model (Room, new file `trigger/bt/TriggerDb.kt`)

```kotlin
@Entity data class BtDevice(
    @PrimaryKey val mac: String, val name: String,
    val kind: String,            // "A2DP" | "BLE_HID" | "BLE_CUSTOM"
    val lastSeenMs: Long, val enabled: Boolean = true)

@Entity data class ButtonMapping(
    @PrimaryKey(autoGenerate = true) val id: Long = 0,
    val deviceMac: String?,      // null = global/ambiguous mapping
    val eventKey: String,        // e.g. "KEYCODE_MEDIA_PLAY_PAUSE:double" or "gatt:<charUuid>:<value>"
    val action: String,          // TriggerAction name, incl. "SWITCH_ACTIVE_DEVICE"
    val attribution: String,     // CONFIRMED | INFERRED | AMBIGUOUS
    val createdMs: Long)
```

---

### Task 1: Device Registry (Room + list UI)

**Files:**
- Create: `app/android/app/src/main/kotlin/com/friend/ios/trigger/bt/TriggerDb.kt` (entities above + DAO + database)
- Create: `app/android/app/src/main/kotlin/com/friend/ios/trigger/bt/DeviceRegistry.kt` (observe `BluetoothManager` connected devices + CompanionDeviceManager presence — pattern donor: `BleCompanionService.kt`)
- Create: `app/lib/pages/settings/trigger_devices_page.dart` (list: name, kind, last-seen, enable toggle)
- Modify: `app/lib/pigeon_interfaces.dart` (registry read/toggle API) + regenerate
- Test: `app/android/app/src/test/kotlin/com/friend/ios/trigger/bt/DeviceRegistryTest.kt` (DAO round-trip with in-memory Room)

- [ ] **Step 1:** Failing DAO tests (insert/upsert on reconnect updates lastSeen; disable persists).
- [ ] **Step 2:** Implement DB + registry listener; run tests → PASS.
- [ ] **Step 3:** Settings page renders live device list (verify on device with 2 BT devices connected).
- [ ] **Step 4: Commit** `feat(bt-trigger): device registry`

### Task 2: Armed-mode MediaSession + KeyEvent capture

**Files:**
- Create: `app/android/app/src/main/kotlin/com/friend/ios/trigger/bt/MediaKeyCaptureService.kt` (Media3 `MediaSessionService`; active only while armed)
- Create: `app/android/app/src/main/kotlin/com/friend/ios/trigger/bt/PressPatternDetector.kt` (single/double/long from raw KeyEvents; window 400 ms double-tap, 600 ms long-press)
- Modify: `app/android/app/src/main/AndroidManifest.xml` (service decl, `FOREGROUND_SERVICE_MEDIA_PLAYBACK` if required)
- Modify: `app/android/app/build.gradle` (media3-session dependency)
- Test: `PressPatternDetectorTest.kt` (JVM: synthetic KeyEvent timings → pattern)

**Interfaces:** emits `TriggerEvent(source=MEDIA_KEY, meta={"eventKey":"KEYCODE_X:double","deviceId":"…","attribution":tier})` into `TriggerRouter.dispatch` (P2 Task 1 signature).

- [ ] **Step 1:** Failing detector tests (5 timing cases incl. triple-tap → treated as double+single, documented).
- [ ] **Step 2:** Implement detector; tests PASS.
- [ ] **Step 3:** Implement session service + attribution resolution chain: `KeyEvent.getDeviceId()` → `InputDevice` lookup → connected-set+audio-route inference → AMBIGUOUS.
- [ ] **Step 4:** On-device probe: armed mode, press headset button, `adb logcat -s TriggerRouter` shows event with tier; music app contention behavior noted in docs.
- [ ] **Step 5: Commit** `feat(bt-trigger): armed-mode media key capture with attribution tiers`

### Task 3: Mapping engine (event → action resolution)

**Files:**
- Create: `app/android/app/src/main/kotlin/com/friend/ios/trigger/bt/MappingEngine.kt`
- Test: `MappingEngineTest.kt`

**Interfaces:** `fun resolve(eventKey: String, deviceMac: String?, attribution: String): TriggerAction?` — precedence: device-scoped mapping > global mapping; unmapped events only logged. Consumed by Task 2 service and Task 5 GATT path.

- [ ] **Step 1:** Failing tests: device-scoped beats global; AMBIGUOUS event matches null-mac mapping; unmapped → null; SWITCH_ACTIVE_DEVICE returns action.
- [ ] **Step 2:** Implement against Room DAO; tests PASS.
- [ ] **Step 3: Commit** `feat(bt-trigger): mapping engine`

### Task 4: Learn-mode Mapping Wizard (Flutter)

**Files:**
- Create: `app/lib/pages/settings/trigger_mapping_wizard.dart` (flow: pick action → "press the button now" → 10 s listen window streams incoming events via Pigeon → user picks the event row → saved; each row shows attribution tier badge)
- Create: `app/lib/pages/settings/trigger_mappings_page.dart` (table: device, event, pattern, action, tier; delete/edit; export/import JSON via share sheet/file picker)
- Modify: `app/lib/pigeon_interfaces.dart` (startLearnMode/stopLearnMode/stream events, CRUD mappings) + regenerate

- [ ] **Step 1:** Wizard captures a real headset button end-to-end on device (event appears < 1 s after press).
- [ ] **Step 2:** Mapping persists across app restart; wizard shows tier badge; unmappable button case shows the honest "never arrived" state after the 10 s window.
- [ ] **Step 3:** Export → uninstall → reinstall → import → mappings restored.
- [ ] **Step 4: Commit** `feat(bt-trigger): learn-mode mapping wizard`

### Task 5: BLE GATT button path (omi wearable / custom peripherals)

**Files:**
- Create: `app/android/app/src/main/kotlin/com/friend/ios/trigger/bt/GattButtonSource.kt` (subscribe to button characteristics; donor plumbing: `OmiBleManager.kt` subscribe/notify path, `BleHostApiImpl.kt` registration)
- Modify (minimal): `OmiBleManager.kt` — expose characteristic-notification hook if none public (few lines, marked `// P3 trigger hook`)

**Interfaces:** emits `TriggerEvent(source=BLE_GATT, meta={"eventKey":"gatt:<charUuid>:<value>","deviceMac":mac,"attribution":"CONFIRMED"})` — GATT events are always device-attributed.

- [ ] **Step 1:** Implement source; learn mode picks up a GATT button event (test with omi wearable if present, else the sibling reference `C:/Android_software/phonebatteryoptimization` BLE peripheral or nRF Connect simulated notify).
- [ ] **Step 2:** Map GATT button → START via wizard; verify capture starts.
- [ ] **Step 3: Commit** `feat(bt-trigger): BLE GATT button source`

### Task 6: Active-device policy + switch action

**Files:**
- Create: `app/android/app/src/main/kotlin/com/friend/ios/trigger/bt/ActiveDevicePolicy.kt` (holds "active capture device"; `SWITCH_ACTIVE_DEVICE` cycles enabled registry devices; optional auto-follow of active audio route via `AudioManager.getDevices`/communication-device APIs)
- Modify: `trigger_devices_page.dart` (active-device indicator + auto-follow toggle)

- [ ] **Step 1:** Switch action cycles devices, visible in settings page + toast; auto-follow flips active device when audio route changes (verify by switching headset).
- [ ] **Step 2: Commit** `feat(bt-trigger): active device policy + switch action`

### Task 7: Compatibility test matrix

**Files:**
- Create: `docs/bt-trigger-compat-matrix.md`

- [ ] **Step 1:** Run matrix: ≥3 device classes (classic play/pause headset, TWS buds, BLE-custom) × press patterns (single/double/long) × (locked / unlocked / screen-off) — record: delivered? tier? latency?
- [ ] **Step 2:** File honest platform-limit notes per failing cell (assistant-routed buttons, single-consumer contention).
- [ ] **Step 3: Commit** `docs: BT trigger compatibility matrix results`

## Verification (phase exit)

- [ ] Sri maps a real button on a real device via the wizard **without any code change** — the definition of done for the flagship.
- [ ] JVM tests + `flutter analyze` green; Codex review pass on full diff, findings fixed.
- [ ] Battery: armed mode overnight drain measured and noted in matrix doc.
- [ ] ROADMAP P3 boxes ticked; merged to fork main → apk-latest refresh; Sri re-tests from prerelease APK.
