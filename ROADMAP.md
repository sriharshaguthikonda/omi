# ROADMAP — Omi Fork as Phone Capture Endpoint

> **Vision.** This fork turns an Android phone into the primary **capture endpoint** for a personal memory system: trigger-first, local-first, confidence-aware. Speech gets captured on the easiest possible trigger (headset button, tile, notification), transcribed (eventually on-device), scored, queued locally, and synced into the private `.memory` backend (Postgres + pgvector MCP). The upstream Omi ecosystem (backend, wearables, desktop) stays available as scaffolding — we swallow what works, replace what doesn't.
>
> Companion document: [phone-capture-deep-research-report.md](./phone-capture-deep-research-report.md) — evidence base for engine choices, trigger rankings, Android constraints, and licensing. This roadmap operationalizes it.

---

## How we debate (read me first)

- Every open choice is a **Decision box** (`D0`, `D1`, …) with option checkboxes.
- `- [ ]` = proposed, undecided. `- [x]` = **agreed** (with date).
- 🟢 **Claude pick** — my preference + why, written inline.
- 🔵 **Sri pick** — your preference + why. Reply inline under the option or in [Q and A.md](./Q%20and%20A.md).
- A decision closes when one option is `[x]` and both parties have a line under it. Closed decisions move work into the phase task list.
- Principle: **swallow, don't reinvent**. Every feature names its donor repo/file first. Building from scratch needs a justification line.

---

## Phase overview

| Phase | Name | Outcome | Status |
|---|---|---|---|
| P0 | CI foundation | Push → installable dev APK | 🔨 this PR |
| P1 | Sign-in / local-first pivot | Boots to local Home; Omi cloud optional | 🔨 P1.2-A merged |
| P2 | Triggers v1 (phone-only) | Record without opening the app | |
| P3 | **BT multi-device trigger matrix** | Any button on any of your BT devices starts capture | flagship |
| P4 | Local-first capture core | Ring buffer, VAD, mark-last-buffer salvage | |
| P5 | On-device ASR | Live transcript without cloud | |
| P6 | Privacy modes + local queue | Transcript-only default, encrypted clips, durable outbox | |
| P7 | Sovereignty + repo-private gate | Own Firebase/backend or local-only; repo goes private | |
| P8 | `.memory` integration | Captures land in the personal memory system | |
| P9 | Extractors + daily review | Action items, idea inbox, evening digest | |
| P10 | Hardware lane | ESP32 trigger peripherals; EMG/EEG stays research | someday |

Phases are ordered by dependency, not by importance. P3 is the flagship user requirement; P0–P2 exist so P3 has rails to run on.

---

## P0 — CI foundation (this PR)

**Goal:** every push that touches `app/**` produces an installable dev-flavor APK; pushes to `main` refresh a rolling GitHub prerelease so the phone can always download the latest build without logging in.

**Tasks**
- [x] `.github/workflows/android_apk_build.yml` — push + manual trigger, dev flavor, community keystore, artifact upload (this PR)
- [x] Rolling `apk-latest` prerelease on `main` pushes (this PR)
- [x] Enable GitHub Actions on the fork (done by Sri, 2026-07-04 — the enable button has no API/gh equivalent)
- [x] First green run verified (run 28690006580, ~18 min, 86 MB artifact, 2026-07-04)
- [ ] APK installed on phone + sign-in tested — **download: <https://github.com/sriharshaguthikonda/omi/releases/tag/apk-latest>** (live after first `main` build; refreshes on every main push)
  - Sri 2026-07-04: installed one built APK, could not sign in, errored out → tracked as P1; root note: that build had zero app-code changes (see Q9 in Q and A.md), P1 adds a visible build stamp so installed-APK identity is never ambiguous again
- [ ] Optional: build-status badge in README

**How it works (so future-us doesn't re-derive it)**
- Bootstrap mirrors `app/setup.sh android`: prebuilt Firebase configs (`app/setup/prebuilt/`) copied into place, community `debug.keystore` + `key.properties` for a **stable signature** across every CI run *and* identical to local `setup.sh` builds (same signature = in-place APK upgrades both ways), `.dev.env` written with `API_BASE_URL=https://api.omiapi.com/`, `USE_WEB_AUTH=true`, `USE_AUTH_CUSTOM_TOKEN=true` (envied bakes these at `build_runner` time — the env file must exist *before* codegen, not at `flutter build`).
- `CM_KEYSTORE_*` env vars are exported pointing at the same prebuilt keystore: GitHub Actions sets `CI=true`, which flips `app/android/app/build.gradle` into its Codemagic branch and would crash at configuration time (`file(null)`) without them.
- `--build-number=${{ github.run_number }}` → monotonically increasing versionCode → clean in-place upgrades.
- Flutter pinned to `3.41.9` (same as `codemagic.yaml`), Java 21 (`jvmToolchain(21)`).
- Dev flavor only. Prod-flavor release builds are deliberately out of scope (Play-signing lane, Codemagic's job).

**Decision D0a — APK delivery** ✅ closed 2026-07-04
- [x] Rolling `apk-latest` prerelease on main + artifacts on branches
  - 🟢 Claude: phone-browser download with zero login friction; branch artifacts keep experiments off the release page.
  - 🔵 Sri: agreed 2026-07-04.
- [ ] Artifacts only — requires GitHub login + unzip on phone
- [ ] Tagged releases only — manual step per build

**Decision D0b — APK shape** ✅ closed 2026-07-04
- [ ] Fat APK (all ABIs, ~1 file, biggest download)
  - 🟢 Claude: zero pick-the-right-file friction; switch to arm64-only later if build time or size ever hurts.
- [x] `--target-platform android-arm64` only — smaller/faster, covers virtually every modern phone
  - 🔵 Sri: arm64 for now, revisit in future (revisit marker added to P10).
  - 🟢 Claude: applied to the workflow (P1 build, `android_apk_build.yml`) 2026-07-04.
- [ ] `--split-per-abi` — smallest per-file, but the release page grows three files per build

---

## P1 — Sign-in that works

**Goal:** the APK you sideload from the prerelease page signs in successfully, first try.

**Execution plan:** [plans/P1-signin.md](./plans/P1-signin.md) — verified auth-flow facts (file:line) + tasks. P2/P3 plans: [plans/](./plans/README.md). Correction to "mostly verification" below: Sri's Q9 stands — P0 shipped zero app code, so P1 **does** ship real app changes (build stamp, error surfacing, deep-link audit).

**CONFIRMED ROOT CAUSE (2026-07-04, from the stamped APK's surfaced error):**
`[custom-token] [firebase_auth/custom-token-mismatch] The custom token corresponds to a different audience.`
The web-auth OAuth flow works end-to-end (browser → account → `omi://auth/callback` → token exchange succeeds). The **only** failure is the final `FirebaseAuth.signInWithCustomToken` (`app/lib/services/auth_service.dart:362-366`): the app is built for Firebase project **`based-hardware-dev`** (prebuilt `google-services.json`/`firebase_options.dart`, `project_id: based-hardware-dev`), but `api.omiapi.com` mints custom tokens for a **different** project. Repo ships `based-hardware-dev` configs *and* points at `api.omiapi.com` — never a matched pair. **Config bug, not code.** Fix tracked as P1.1 (Codex investigating ranked options; see [plans/P1-signin.md](./plans/P1-signin.md) Post-merge diagnosis).

**LIVE RESULT (2026-07-05, ADB on Sri's phone):** native-auth build `v1.0.542+10 · native-auth · main@cbfce78 · run 10` signs into Firebase, then `GET https://api.omiapi.com/v1/users/onboarding` returns `401 {"detail":"Invalid authorization token"}` after token refresh. This confirms Outcome B: `api.omiapi.com` rejects `based-hardware-dev` ID tokens. Full report: [docs/investigations/2026-07-05-community-build-auth.md](./docs/investigations/2026-07-05-community-build-auth.md).

**Earlier hypotheses (superseded by the confirmed cause above, kept for history):**
1. Native Google Sign-In SHA-not-registered → `ApiException: 10` (this is the *native* lane; we're on web-auth).
2. Empty `API_BASE_URL` when `.dev.env` missing — ruled out; the CI build bakes it and the exchange reaches the backend.
3. The originally-downloaded upstream APK had its own problems (Q7).

**The community lane we ship:** `USE_WEB_AUTH=true` + `USE_AUTH_CUSTOM_TOKEN=true` = browser OAuth + Firebase custom token (`app/lib/services/auth_service.dart:197,362`), signature-independent. Works — *except* the custom token's Firebase project must match the app's. That match is P1.1.

**Tasks**
- [x] Visible **build stamp** (branch + short sha + run number + auth-lane) on sign-in footer + About — done, proven on-device (it's what surfaced the root cause)
- [x] **Surface real sign-in error + stage** (dev flavor) — done, pinpointed `custom-token-mismatch`
- [x] Install CI APK → run web-auth flow → confirmed it reaches `api.omiapi.com` and fails only at Firebase custom-token
- [x] Try native Google Sign-In — native Firebase sign-in succeeds, but backend API rejects `based-hardware-dev` token with 401
- [x] **P1.2 — decided 2026-07-05: de-mandatory login + local-first.** The community lane is structurally dead (api.omiapi.com verifies `based-hardware`; app is `based-hardware-dev`; #5939 won't-fix). Instead of chasing a matching config: **remove the mandatory login gate** → app boots local-only; Omi-cloud sign-in → optional Settings row (re-enable later via self-host, P7/D7); cloud-only features gated behind toggles (greyed + red "needs cloud"). **On-device Moonshine STT (P5) pulled forward** as the primary path; **local-Gemini/free-chain LLM** replaces cloud "intelligence" (Sri, Q&A item 12). Work branch `feature/local-first`. Plan: [plans/P1-signin.md](./plans/P1-signin.md) P1.2 section.
- [x] **P1.2-A shipped** (2026-07-06): boot-to-local-Home + optional "Connect to Omi Cloud" Settings entry (both list + search) + Sign Out hidden for guests — merged to fork main via [PR #5](https://github.com/sriharshaguthikonda/omi/pull/5); `apk-latest` rebuilding. Label reuses existing `connectTo` l10n key (no new translations). Fix folded: reset `onboardingCompleted` before guest→cloud sign-in so a fresh cloud account still onboards.
- [ ] **P1.2-B next:** gate cloud-only surfaces (conversations/chat/memories) for guests — grey + "needs cloud" affordance routing to Connect Omi Cloud.
- [ ] **Then Phase B — on-device Moonshine streaming STT** (pulled forward, see [P5](#p5--on-device-asr) + [plans/P1-signin.md](./plans/P1-signin.md) Phase B).
- [ ] Document the local-first + cloud-optional path in `docs/` once P1.2 lands

**Decision D1 — auth lane going forward** ✅ closed 2026-07-04
- [x] **Community lane now** (upstream dev Firebase + api.omiapi.com), sovereignty deferred to P7 — agreed 2026-07-04
  - 🟢 Claude: working sign-in today with zero infra; the capture/trigger phases (P2–P5) don't care whose backend it is. Accepted tradeoff: captured audio/transcripts transit upstream's dev cloud until P7. Don't speak secrets into it.
  - 🔵 Sri: agreed 2026-07-04.
  - 2026-07-05 investigation update: community lane is blocked unless the app can use Firebase config matching `api.omiapi.com` or the backend accepts `based-hardware-dev` tokens. See [auth investigation](./docs/investigations/2026-07-05-community-build-auth.md). This reopens the practical P1 path, even though D1 records the original preference.
- [ ] Own Firebase + self-hosted backend immediately — days of setup before first working APK; blocks the fun parts
- [ ] Local-only (no auth at all) — biggest surgery; becomes realistic only after P6's local queue exists (revisit inside P7)
	🔵 Sri: may be weill be able to host this is free oracle cloud in future?!
	🔵 Sri: the kaggle dataset where we use the data for training the moonshine and other asr models can be used as cloud storage as well?!

---

## P2 — Triggers v1 (phone-only, greenfield)

**Goal:** start/stop capture without opening the app. Verified fact: the app has **zero** media-button / tile / notification-action code today — this phase builds the trigger rails everything else plugs into.

**Architecture (from the research report — build once, extend forever):**
```
[any trigger] → Trigger Router → Mode resolver (toggle / hold / mark-last-buffer)
             → capture controller (existing) → capture state machine
```
Every later trigger (headset button, BLE GATT, Tasker, wake word, ESP32) is just a new input to the router. The router logs `(trigger_source, timestamp, resolved_action)` for every event — that log powers the P3 mapping wizard.

**Tasks**
- [ ] Trigger Router service (Kotlin, single entry point; Pigeon bridge to Flutter — extend `app/lib/pigeon_interfaces.dart`, don't add ad-hoc channels)
- [ ] Notification action buttons (start/stop/mark) on the existing foreground-service notification
- [ ] Quick Settings tile (`TileService`) — arm/disarm capture
- [ ] Explicit-intent entry (Tasker/automation): exported receiver, locked down (signature/token check), documented intent extras
- [ ] Wire router → existing phone-mic path: `app/lib/providers/capture_provider.dart` / `voice_recorder_provider.dart` / `app/lib/services/capture/capture_controller.dart` (recording state already lives here — reuse, don't duplicate)
- [ ] Feedback: single soft beep on start, double on stop, optional haptic; 
 - ambient noise basesd volume and haptics.
 -  calm settings ...less loud!!! you know
 -  option to toggle periodic "still listening" low volume beeps-  volume should be adjustable in developer settings
- [ ] Trigger test matrix from the research report (locked screen, unlocked, after process death)

**Swallow sources:** upstream foreground-service + notification plumbing (already in repo: `OmiBleForegroundService.kt` patterns, `app/lib/services/notifications.dart`); Android `TileService` is ~100 lines of boilerplate (official docs sample).

**Decision D2 — v1 trigger set scope**
- [ ] Notification action + QS tile only (smallest useful)
- [ ] Notification + tile + explicit intent (Tasker) 🟢
  - 🟢 Claude: the intent receiver is ~50 extra lines and instantly unlocks *every* automation app (Tasker, MacroDroid, KDE Connect) as a trigger source — cheapest leverage in the whole roadmap.
  - 🔵 Sri:
- [x] All of the above + in-app big-red-button redesign — UI polish can wait

---

## P3 — BT multi-device trigger matrix ⭐ (flagship requirement)

**Goal:** *"I might be connected to multiple bluetooth devices, change between them, and trigger recording from multiple different buttons on multiple different devices."* Concretely: any button on any paired BT device can be mapped to any capture action, per-device, persistently.

**Design**

1. **Device Registry** — persistent store (per device: BT MAC, name, type [A2DP headset / BLE HID / BLE custom], last-seen, enabled). Feeds from `BluetoothManager` connected-devices + CompanionDeviceManager presence (pattern already in repo: `BleCompanionService.kt`).
2. **Button capture layer** — two mechanisms, both feeding the P2 Trigger Router:
   - **MediaSession KeyEvents** (classic headsets/earbuds: play/pause/next/prev, single/double/triple-tap, long-press). App holds an active `MediaSession` while armed.
   - **BLE GATT / HID** (omi wearable, smart glasses, custom peripherals): subscribe to button characteristics — GATT plumbing already exists (`OmiBleManager.kt`, `BleHostApiImpl.kt`).
3. **Mapping wizard (learn mode)** — "press the button you want to use" → wizard logs incoming KeyEvents/GATT events for ~10 s → user picks event → assigns action (start / stop / toggle / mark-last-buffer / switch-active-device) → stored per (device, event, press-pattern). **Nothing is hardcoded — every mapping is created at runtime in-app** (Sri, Q5, 2026-07-04); the wizard must handle devices that don't exist yet.
4. **Active-device policy** — mappings can be global or device-scoped; a "switch active capture device" action lets one button hand the mic role between devices; auto-switch option follows the active audio route (SCO/A2DP).

**Honest platform limits (so we don't gaslight ourselves later):**
- AVRCP media KeyEvents often arrive **without reliable source-device attribution** — Android may not tell us *which* headset sent play/pause. Mitigations, in order: `KeyEvent.getDeviceId()` → `InputDevice` lookup when populated; else infer from the connected-device set + active audio route; else the wizard stores the mapping as "ambiguous — applies to any device sending this event". The wizard must *show* which attribution tier a mapping got.
- MediaSession KeyEvents are effectively **single-consumer** — while our session is active and armed, we may contend with music apps for button routing. Armed-mode UX must make this visible (and D2's Tasker lane is the escape hatch).
- Many headsets route some buttons to the voice assistant or vendor apps and never deliver them to a MediaSession. The wizard's learn mode doubles as a compatibility probe — buttons that never arrive simply can't be mapped, and the wizard says so.
- Media buttons only reach us while our MediaSession is active (armed mode) — armed-mode battery cost must stay near zero (no mic open, just session + registry).

**Tasks**
- [ ] Device Registry (Room table + settings UI listing paired/connected devices)
- [ ] MediaSession KeyEvent listener (Media3), single/double/long-press detection, feeding Trigger Router
- [ ] BLE GATT button subscription path for non-media devices (reuse `OmiBleManager` command/subscribe plumbing)
- [ ] Mapping wizard with learn mode + attribution-tier display + per-device mapping table
- [ ] Mapping persistence + export/import (JSON — mappings survive reinstall)
- [ ] "Switch active device" action + auto-follow-audio-route option
- [ ] Test matrix: ≥3 device classes (classic play/pause headset, TWS buds, BLE-custom/omi wearable) × (single/double/long) × (locked/unlocked/screen-off)

**Swallow sources:** repo's own BLE stack (`OmiBleManager.kt`, `BleCompanionService.kt`, `pigeon_interfaces.dart`); Media3 `MediaSessionService` official samples; `C:/Android_software/phonebatteryoptimization` sibling (BT connect/disconnect event handling reference).

**Decision D3 — which button mechanism ships first**
- [x] MediaSession KeyEvents first, BLE GATT second 🟢
  - 🟢 Claude: your existing headsets/earbuds work day one with zero custom hardware; BLE GATT path already exists in-repo for omi wearables so it's a fast follow, not a rewrite.
  - 🔵 Sri: we might have to block that input from going to downstream or be able to modify how it reaches other system processes?!
- [ ] BLE GATT first — only makes sense if your primary trigger device is an omi wearable/custom peripheral today
- [ ] Both in one milestone — more surface, slower first win

**Decision D4 — mapping ambiguity default** ✅ closed 2026-07-04 (via Q5)
- [x] Ambiguous mappings allowed, labeled, user-visible
  - 🟢 Claude: pragmatic — most people run one headset at a time; blocking on perfect attribution kills the feature on most hardware.
  - 🔵 Sri (Q5): everything — device, button, press pattern — is decided **at runtime in the app**, never hardcoded. Wizard captures whatever the user performs.
- [ ] Only allow mappings with confirmed device attribution — strict, but many headsets become unmappable

---

## P4 — Local-first capture core

**Goal:** capture stops being "stream everything to a backend" and becomes "hold a rolling buffer, keep what matters".

**Tasks**
- [ ] 20–30 s **RAM ring buffer** (native Kotlin; PCM from existing `phone_mic_source.dart` framing — 16 kHz PCM16 already flows in 320-byte/10 ms frames)
	- the duration of buffer should be customizable in settings. but the text transcribed can be continuously saved segmentation based on timepoints or intelligent or hybrid segmentation.... defer details to future phases
- [ ] **mark-last-buffer**: any trigger can salvage the *previous* N seconds (the "that thought just happened" button)
- [ ] VAD gate for armed mode (speech starts capture; silence closes segments)
- [ ] Segment finalization → framed local files: **reuse `OmiBatchAudioWriter.kt`** (length-prefixed `.bin`, rotation, fsync, gap finalization — already written, already tested upstream)
- [ ] Capture state machine: Idle → Armed → PreRoll → Capturing → Segmenting → Queue (diagram in research report)
- [ ] Debug screen: live trigger log, VAD score, buffer fill, segment list, battery counters

**Swallow sources:** `OmiBatchAudioWriter.kt` (in-repo), Silero VAD ONNX, WebRTC VAD.

**Decision D5 — VAD** ✅ closed 2026-07-04
- [x] Silero VAD (ONNX) 🟢
  - 🟢 Claude: near-SOTA accuracy, <1 ms/chunk on one CPU thread, ONNX runs everywhere; the report's default pick.
  - 🔵 Sri: agreed as the VAD. Also: **Moonshine-tiny streaming is a future option for sure** (tracked against D6/R1 — Moonshine is already an ASR candidate there), and **Sri is training models elsewhere** — link pending (see Q13). Ties into the `AsrEngine`-interface plan so a Sri-trained model can drop in.
- [ ] WebRTC VAD — smaller/faster, more false positives; fine as a low-power pre-gate later
- [ ] Moonshine integrated pipeline — couples VAD to the ASR choice (see D6); revisit if D6 lands on Moonshine anyway

---

## P5 — On-device ASR

> **Pulled forward 2026-07-05 (P1.2 pivot).** Since the community cloud is dead, on-device ASR is no longer "eventually" — it's the primary near-term path. D6 closed = **Moonshine Voice native SDK** streaming (tiny→small→medium). Cloud STT is now the *optional* fallback (only when the user connects Omi cloud), not the default.

**Goal:** live transcript without cloud round-trip. Cloud STT (upstream backend) is an optional fallback behind the Omi-cloud toggle, not the default.

**Execution plan:** [plans/P5-moonshine.md](./plans/P5-moonshine.md) — B0 reuse-check (done), verified seam map (file:line), compile-verifiable-first increments B1→B5. Moonshine wires at the `IPureSocket` streaming seam, bypassing the cloud-coupled composite socket.

**Tasks**
- [ ] Spike A: Moonshine Android (Maven package) — live latency + battery on your actual phone, 15-min session
- [ ] Spike B (hedge): sherpa-onnx Android demo with a streaming model — same measurements
- [ ] Spike C (Sri's own): Sri has **ONNX models on his Kaggle** + shipped some in a **FUTO keyboard fork** (Q13). ONNX ⇒ drops straight into the ONNX-Runtime / sherpa-onnx path. Evaluate these as a first-class candidate: get the Kaggle link (Q13 follow-up), check task (ASR? VAD? wake-word?), streaming-capable?, size/latency on-device.
- [ ] Pick engine (D6), integrate behind an `AsrEngine` interface — must accommodate a **Sri-supplied ONNX model** as a drop-in, not just Moonshine/sherpa.
- [ ] Confidence score per segment surfaced to the queue (drives retention policy in P6)
- [ ] Later: whisper.cpp as **batch re-checker** for low-confidence saved clips (never the live path)
- [ ] Accuracy strategies: custom dictionary / hotword biasing (per-user vocabulary) — pairs with on-device ASR (Sri, Q&A 2026-07-05 item 2)

**Decision D6 — live ASR engine** ✅ closed 2026-07-05 (Sri confirmed Moonshine; pulled forward into P1.2)
- [x] Moonshine 🟢
  - 🟢 Claude: published streaming latency 34–107 ms vs Whisper-tiny's 277 ms+; Android Maven artifact; one focused SDK. Caveat tracked in license ledger: English models MIT, multilingual models are community-license (non-commercial) — fine for personal use, flagged if this ever ships publicly.
  - 🔵 Sri: **Moonshine, yes** — whisper can't do live transcription; Moonshine streams and is phone-capable, extendable tiny→small→medium. Use whichever artifact is least resource-intensive.
  - **Path (codex research, gpt-5.5):** wrap the **Moonshine Voice native SDK** (Android Maven `ai.moonshine:moonshine-voice`, iOS SPM `moonshine-swift`) + `UsefulSensors/moonshine-streaming-{tiny,small,medium}`; wire at the streaming socket seam (`IPureSocket`), keep the `AsrEngine`-style extensibility so Sri's own ONNX model (Q13) still drops in. sherpa-onnx = fallback only.
- [ ] sherpa-onnx — broadest toolkit (VAD+KWS+ASR+wake word in one, Apache-2.0); more plumbing, more model-choice burden. **Also the natural host for Sri's own ONNX models (Q13).**
- [ ] Both permanently behind the interface — costs double maintenance; only if spikes tie
- 🔵 Sri (Q13): has own ONNX models (Kaggle + FUTO keyboard fork) — wants them usable here. Leans the interface toward an ONNX-Runtime backend that can load Moonshine, sherpa, **or** a Sri-trained model.

---

## P6 — Privacy modes + local queue

**Goal:** the app is trustworthy by construction: transcript-only by default, audio kept only on purpose, everything durable and encrypted at rest.

**Tasks**
- [ ] Privacy modes (independently toggleable, app fully useful in strictest mode):
  - [ ] **Transcript only** (default)
  - [ ] Keep low-confidence audio for review (24 h default expiry)
  - [ ] Keep only clips I manually mark
  - [ ] Training-export opt-in
- [ ] Room schema: sessions, segments, confidence, trigger events, queue state (metadata schema in research report §storage)
- [ ] Encrypted clip store (AndroidX Security / Keystore)
- [ ] WorkManager outbox: text eager; audio Wi-Fi-only default, charging-only option; retries; never-silent-upload in transcript-only mode
- [ ] Deletion UX: one screen, everything visible, delete actually deletes

**Swallow sources:** Room/WorkManager official patterns; retention/consent shape from research report (which itself copies FUTO/notune norms).

---

## P7 — Sovereignty + repo-private gate

**Goal:** cut the umbilical to upstream cloud when *we* choose; take the repo private at the same milestone (this is when personal config/data starts touching the tree).

**Repo-private facts (decided 2026-07-04: later milestone = here):**
- GitHub **cannot flip a fork to private** — path is: bare-clone → new private repo → repoint `origin`, keep upstream as read-only remote. Fork relationship (and easy PRs upstream) is lost.
- Private repo Actions quota: 2 000 free min/month ≈ 100–130 APK builds. Fine for one person; noted so nobody's surprised.

**Tasks**
- [ ] Sovereignty shape decided (D7) and executed
- [ ] Duplicate repo → private; migrate secrets to GitHub Secrets; update remotes; archive/README-stub the public fork
- [ ] Upstream-sync strategy post-detach: periodic `git fetch upstream && git merge` cadence, conflict budget documented
- [ ] Audit history for anything personal *before* the public fork is left behind (it stays public forever)

**Decision D7 — sovereignty shape**
- [ ] Own Firebase project + self-hosted omi backend (repo has `backend/`) 🟢
  - 🟢 Claude: keeps the full feature set (conversations, summaries) while owning every byte; backend is dockerized and documented in-repo; pairs naturally with the `.memory` adapter (P8) running server-side.
  - 🔵 Sri:
- [ ] Local-only strip (no Firebase, no backend — app talks only to local queue + `.memory` sync)
  - honest cost: significant surgery through auth-assuming code paths; becomes cheaper after P6 exists
- [ ] Hybrid: local-first always, self-hosted backend as optional sync target — most aligned with the research report's ideology, most moving parts

---

## P8 — `.memory` integration

**Goal:** captures land in the personal memory system (`C:/.memory`, Postgres + pgvector, 13-phase roadmap: `Mother_of_all_memory_plan.md`; Phase 7 auto-capture and Phase 12 daemonized retrieval active; Phase 9 chat-dump bulk ingest already built).

**Contract (from research report — keep the phone neutral):** the app emits canonical local events; a thin adapter maps them to `.memory`:

| App event | → `.memory` target |
|---|---|
| `session_started` | session/provenance row |
| `segment_final` (text, confidence, trigger, device) | transcript append |
| `memory_candidate` (condensed note, tags) | memory upsert |
| `action_extracted` | action row |
| `clip_retained` | blob ref + link |
| `daily_review_ready` | review-inbox entry |

**Tasks**
- [ ] Define adapter schema (versioned JSON) + write it into `.memory` docs as an ingest contract
- [ ] Transport (D8) implemented end-to-end for `segment_final` first
- [ ] Provenance: every ingested row carries `source=omi-phone`, device id, trigger source (memory system's provenance rules already demand this)
- [ ] Dedup/idempotency: segment ids stable across retries (WorkManager will retry)
- [ ] `.memory` side: register the adapter in the memory roadmap (extends its Phase 7/9 lanes — coordinate, don't fork that roadmap)

**Decision D8 — transport**
- [ ] File-drop ingest: phone syncs JSON/audio bundles to a folder (Syncthing/adb/cloud drive) → `.memory` ingest script consumes (Phase-9 chat-dump pattern) 🟢
  - 🟢 Claude: zero new server surface, works offline-first, reuses the *already built and tested* bulk-ingest lane; transport is swappable later without touching the phone schema.
  - 🔵 Sri:
- [ ] Direct MCP/HTTP endpoint on the memory Postgres — tighter loop, but exposes the memory system to the network and couples phone→DB schemas
- [ ] Via self-hosted omi backend webhook (needs D7 = self-host first)

---

## P9 — Extractors + daily review

**Goal:** captures become useful without re-listening.

- [ ] Two deterministic extractor packs only: **action items**, **idea inbox** (rules first; LLM refinement later)
- [ ] Daily on-device digest (evening notification → review screen: unresolved actions, low-confidence clips to confirm/discard)
- [ ] Feedback loop: accept/reject per extraction, logged for future tuning
- **Not now:** plugin sandboxes, marketplace parity, LLM-first extraction (research report: rules-first is the trust-building move)

---

## P10 — Hardware lane (someday/maybe)

- [ ] ESP32-C3 as tiny BLE trigger peripheral (button + battery + LED) — only after P3 evidence shows existing BT devices aren't enough
- [ ] ESP32-S3 if a custom audio front-end ever matters (vector ops for on-edge DSP)
	- eye glasses which are sleek can be designed with large battery and s3 i think.
	- large antenna is aslo possible with those glasses
	- right and left can work alternatively while one side can charge!
	- wild but .... small solar panels on the sides that can trickle charge
- [ ] EMG / ear-EEG / "brain-triggered capture": **research-only lane.** Current public results = small command vocabularies, fragile placement, session drift. Revisit yearly; keep the Trigger Router extensible so a future exotic trigger is just another input.
- Copy the boring parts of omi's BLE protocol when the day comes (battery svc, device-info svc, one custom trigger/audio svc, codec characteristic, packet numbering — documented upstream).

### Revisit backlog (deferred decisions to reopen later)
- **APK shape (D0b):** currently arm64-only. Revisit fat/`--split-per-abi` if a non-arm64 target device appears or the release page needs multi-arch (Sri, 2026-07-04).
- **Data portability / anti-lock-in (Sri, 2026-07-05):** map how the official Omi app stores conversations/audio and whether it's exportable/importable into our local store — before relying on their storage; guards against a buyout locking Sri out.
- **Dev-build theme / visual distinction (Sri, 2026-07-06, low prio — "roadmap last"):** give the dev flavor a visibly different theme/accent (or a persistent DEV banner) so dev vs prod/official installs stop being confusing side-by-side. Cheapest path: flavor-gated accent/badge behind `F.env == Environment.dev`, no new deps. Brand rule still applies — no purple.
- **On-device Whisper STT broken (Sri device test, 2026-07-06, low prio):** local Whisper (`SttProvider.onDeviceWhisper`) failed to transcribe on Sri's Android 16 phone though audio recording worked. Debug later — NOT priority (Moonshine is the on-device engine replacing it). Start at `transcription_settings_page.dart` `_checkLocalModel`/`_buildOnDeviceWhisperConfig` + the `whisper_flutter_new` plugin (likely model-download/path or ggml runtime).

### Bug parking lot (open, fix in later phases — Sri 2026-07-07 "park those other bugs")
- **Background recording not working (suspected permission retention):** permissions ask-once fix is in flight on `feature/permission-gate`; if background capture is still dead after it lands, debug the foreground-service + mic path next (`app/lib/utils/audio/foreground.dart`, FGS types in AndroidManifest, battery optimization exemption).
- **Settings search bar UX:** search doesn't use the fuzzy/typo-tolerant matcher and force-focuses/expands awkwardly. UI pass: fuzzy match + no forced focus. (Sri: "the original ui by the designer is so backward".)
- **Moonshine chunk/line-duration knob:** expose an engine option in Transcription settings controlling how long a transcript line stays "live" before locking (Moonshine revises recent tokens — let the user tune the revision window).
- **On-device intelligence consolidation (item 10):** one local multimodal model (Gemma-3n-class ONNX) serving vision/embed/tool/ASR behind the AsrEngine/D6 seam; needs Sri's Kaggle ONNX links (Q13) for the ASR lane.

---

## Cross-cutting

### Upstream sync (while still a fork)
- Stay merge-friendly: new code in new files/dirs where possible (`trigger/`, `capture_core/`), minimal edits inside upstream files.
- Periodic `git fetch upstream && git merge upstream/main` on a schedule (monthly or before each phase start). After P7 detach, same command different remote.

### License ledger (swallowed code obligations)
| Source | License | Rule |
|---|---|---|
| upstream omi (this repo) | MIT | free reuse |
| Moonshine code + EN models | MIT | free reuse |
| Moonshine multilingual models | community (non-commercial) | personal use OK; flag before any public distribution |
| sherpa-onnx | Apache-2.0 | free reuse, keep NOTICE |
| whisper.cpp | MIT | free reuse |
| Silero VAD | MIT (verify model card at adoption) | verify then reuse |
| notune android_transcribe_app | MIT (app) + Parakeet model attribution | attribution if model used |
| FUTO Voice Input | source-available product | **reference only, don't copy code** |
| Screenpipe | source-available commercial | **ideas only, don't copy code** |
| VoiceInk | GPL-3.0 | **ideas only** unless we accept GPL |

### Risk table (top 5, full set in research report)
| Risk | Mitigation baked into roadmap |
|---|---|
| Headset buttons never reach the app on some devices | P3 wizard doubles as compatibility probe; never rely on one trigger |
| Battery drain in armed mode | armed = session+registry only, mic closed; measure in P4 debug screen |
| Privacy blowback / trust loss | P6 transcript-only default, visible deletion, no silent upload |
| Community-lane cloud dependency (P0–P6) | accepted consciously in D1; P7 exists to end it; don't capture secrets meanwhile |
| Upstream drift makes merges painful | new-files-first policy; scheduled merges; P7 detach as pressure valve |

### Repo privacy
Decided 2026-07-04: **stay public until P7**, then duplicate → private (fork can't be flipped). Until then: nothing personal in the tree — no real `.env`s, no tokens, no capture data, no `.memory` dumps. CI uses only upstream's already-public community configs.

---

## Appendix — donor map (swallow, don't reinvent)

| Need | Take it from | Status |
|---|---|---|
| BLE lifecycle, companion pairing | `app/android/.../OmiBleForegroundService.kt`, `BleCompanionService.kt`, `OmiBleManager.kt` | in repo ✅ |
| Framed local audio files w/ finalization | `OmiBatchAudioWriter.kt` | in repo ✅ |
| Typed Flutter↔native bridge | `app/lib/pigeon_interfaces.dart` | in repo ✅ |
| Phone-mic PCM framing | `app/lib/services/audio_sources/phone_mic_source.dart` | in repo ✅ |
| Recording state machine | `capture_provider.dart`, `voice_recorder_provider.dart`, `capture_controller.dart` | in repo ✅ |
| Community auth/keystore/Firebase | `app/setup/prebuilt/` + `setup.sh` | in repo ✅, wired into CI (P0) |
| Self-hostable backend | `backend/` | in repo, dormant until P7 |
| Streaming on-device ASR | Moonshine Android / sherpa-onnx | external, P5 spikes |
| VAD | Silero VAD ONNX | external, P4 |
| Batch re-transcription | whisper.cpp | external, P5-later |
| Offline dictation UX norms | FUTO Voice Input, notune app | reference only |
| Local-first pipe/plugin ideas | Screenpipe | ideas only |
| BT device-event handling reference | `C:/Android_software/phonebatteryoptimization` | local sibling |
| Bulk ingest into `.memory` | `.memory` Phase 9 chat-dump lane | built ✅, adapt in P8 |
