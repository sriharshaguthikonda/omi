# P5 / Phase B — On-device Moonshine streaming STT

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:subagent-driven-development. Standing rule: Codex CLI implements, Claude orchestrates and corrects. Steps use checkbox (`- [ ]`) syntax.
>
> Master: [ROADMAP.md](../ROADMAP.md) **P5** (D6 closed → Moonshine). Pivot context: [plans/P1-signin.md](./P1-signin.md) Phase B. This is the primary value path of the local-first pivot — live transcript with no cloud.

**Goal:** phone-mic (and Omi BLE) audio produces a **live transcript on-device**, no backend round-trip. Cloud STT stays an optional fallback behind the Omi-cloud toggle.

**Engine (D6):** Moonshine Voice — on-device, streaming-optimized, Android Maven + iOS SPM, tiny≈26 MB, accuracy ≥ Whisper (confirmed 2026-07-06: <https://github.com/moonshine-ai/moonshine>, <https://huggingface.co/blog/UsefulSensors/announcing-moonshine-voice>). Models `moonshine-streaming-{tiny,small,medium}`, start **tiny**.

## B0 reuse-check (done 2026-07-06)
- **No fork to cherry-pick.** Upstream `BasedHardware/omi` PRs/issues: no on-device/offline/Moonshine STT work. Top community forks are old (2024) / unrelated. So Moonshine is a fresh integration.
- **Reuse is in-repo, not a fork:** the streaming-socket seam (`IPureSocket`) and PCM plumbing already exist and are engine-agnostic — Moonshine plugs into them. Do **not** extend the batch on-device Whisper path.
- **License:** English Moonshine models MIT; multilingual are community/non-commercial (fine for personal use — flagged in ROADMAP license ledger). FUTO's moonshine = reference-only (no code copy).

## Verified seam map (Codex read-only pass 2026-07-06, file:line)
- Streaming entrypoint: [capture_controller.dart:609](../app/lib/services/capture/capture_controller.dart) `_initiateWebsocket()` reads `SharedPreferencesUtil().customSttConfig`, calls `ServiceManager.instance().socket.conversation(...)`.
- Socket pool: [sockets.dart:38](../app/lib/services/sockets.dart) delegates custom STT to `TranscriptSocketServiceFactory.createFromCustomConfig(...)`.
- **Plug-in seam:** [pure_socket.dart:13](../app/lib/services/sockets/pure_socket.dart) — `IPureSocket` / `IPureSocketListener`. Moonshine = new `IPureSocket`.
- Factory: [transcription_service.dart:335](../app/lib/services/sockets/transcription_service.dart) — live→`_createStreamingSocket`, polling→`_createPollingSocket`.
- Transcript contract: [transcription_service.dart:201](../app/lib/services/sockets/transcription_service.dart) accepts a JSON list → `TranscriptSegment.fromJson(...)` → UI.
- **Cloud-coupling to AVOID:** [composite_transcription_socket.dart:12](../app/lib/services/sockets/composite_transcription_socket.dart) forwards custom-STT output into the Omi backend socket as `suggested_transcript` — that still needs cloud. Moonshine must **not** be wrapped in the composite by default.
- Wrong seam (do not extend): [pure_polling.dart:28](../app/lib/services/sockets/pure_polling.dart) + [on_device_whisper_provider.dart:14](../app/lib/services/sockets/on_device_whisper_provider.dart) — batch `ISttProvider.transcribe`, temp WAVs, chunked not live.
- PCM: [audio_transcoder.dart:284](../app/lib/utils/audio/audio_transcoder.dart) `AudioTranscoderFactory.createToRawPcm(...)` (16 kHz PCM16). Provider enum: [stt_provider.dart:7](../app/lib/models/stt_provider.dart) (`SttProvider.onDeviceWhisper` exists — add a **separate** `onDeviceMoonshine`).
- Consent gate: `aiConsentGiven` must be checked at capture-start before any on-device inference.

## Global constraints
- No cloud on the default Moonshine path (bypass `CompositeTranscriptionSocket`).
- New Dart in new files under `app/lib/services/sockets/`; minimal edits to upstream files (merge-friendliness).
- Keep an `AsrEngine`-style seam so a **user-supplied streaming ONNX model drops in beside Moonshine** (Q13). ONNX ⇒ ONNX-Runtime / sherpa-onnx backend candidate.
- New user-facing strings: l10n only. `generate: true` in pubspec → CI `flutter build` regenerates `app_localizations*.dart` from ARBs, so new keys are added ARB-only + propagated to all 49 locales (skill `omi-add-missing-language-keys-l10n`); no local flutter needed.
- No purple. `dart format --line-length 120`; Kotlin via pre-commit.
- Verification is CI `flutter build apk` (compile) + the user's device (behavior) — no local Flutter/Android toolchain.

## Increments (ordered so early ones are compile-verifiable in CI; native/device last)

### B1 — provider enum (compile-safe, inert)
- [x] Add `SttProvider.onDeviceMoonshine` (streaming type, label "On-Device Moonshine", models tiny/small/medium, default tiny) in `stt_provider.dart`. Not yet exposed in Settings.
- [x] Verify: CI compile pending; local Flutter/Dart toolchain is unavailable on this Windows host. **Commit** `feat(moonshine): add onDeviceMoonshine stt provider enum`.

### B2 — Dart socket + fake-native test (compile + unit-test-safe)
- [x] `app/lib/services/sockets/on_device_moonshine_socket.dart` — `OnDeviceMoonshineSocket implements IPureSocket`. `connect()` → native `initialize({model,language,sampleRate})`; `send(bytes)` → `AudioTranscoderFactory.createToRawPcm` → native `appendPcm16`; native transcript callback → `jsonEncode([segment])` → listener (same contract as transcription_service.dart:201).
- [x] `TranscriptSocketServiceFactory.createFromCustomConfig(...)`: if `onDeviceMoonshine` → return `TranscriptSegmentSocketService.withSocket(OnDeviceMoonshineSocket(...))` **directly** (no composite).
- [x] Dart unit test with a fake MethodChannel: connect → send bytes → receive segment JSON → stop; assert factory does NOT build `CompositeTranscriptionSocket` for Moonshine.
- [x] Verify: CI compile + `flutter test` pending; local Flutter/Dart toolchain is unavailable on this Windows host. **Commit** `feat(moonshine): dart OnDeviceMoonshineSocket + factory routing (+test)`.

### B3 — Android native bridge (device-verified; needs the user's phone)
- [ ] Android Maven `ai.moonshine:moonshine-voice`; Kotlin `MoonshineSttPlugin` MethodChannel (`initialize`/`appendPcm16`/`stop`/`dispose`) + event channel (partial/final/error) around `moonshine-streaming-tiny`. Model download/bundle strategy (26 MB) decided here.
- [ ] Verify: CI compile (`compileDevDebugKotlin`) + on-device smoke (network off → live transcript). **Commit** `feat(moonshine): android native streaming bridge (tiny)`.

### B4 — settings toggle + consent gate (exposes the feature)
- [ ] Expose Moonshine as the default **local-first** STT in `transcription_settings_page.dart` (Whisper batch → legacy/advanced). New l10n keys via ARB + 49-locale propagation.
- [ ] Gate on-device inference behind `aiConsentGiven` at capture-start.
- [ ] Verify: CI compile; on-device end-to-end. **Commit** `feat(moonshine): settings toggle + consent gate`.

### B5 — iOS parity (deferred until Android proven)
- [ ] iOS SPM `moonshine-swift` + Swift channel mirroring B3. Android-first; iOS after the Android path is proven on-device.

## Blocked / awaiting user
- **Q13 — user's Kaggle ONNX model link.** Needed to wire the user's own model as a drop-in streaming engine beside Moonshine (the `AsrEngine`/ONNX-Runtime backend). Not blocking B1–B4 (Moonshine-first); the seam is built to accept it.

## Phase exit
- [ ] Live transcript on-device with network off, from phone mic (and BLE).
- [ ] No cloud calls on the default Moonshine path.
- [ ] ROADMAP P5 boxes ticked; merged to fork main → apk-latest refresh; user device-confirms.
