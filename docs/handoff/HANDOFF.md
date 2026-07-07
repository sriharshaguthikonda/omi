# Session Handoff Log

## 2026-07-06 ~22:15 IST — Moonshine R8 crash FIXED (aa42b53, build GREEN, Sri beeped); B5 (local transcript persistence) in-flight via codex exec; merge HELD

**Root causes confirmed on live device (adb, phone I2220/Android 16):**
- **Moonshine broken on B4 APK:** `NoSuchFieldError: no "name" field in TranscriberOption` — `minifyEnabled true` (both build types, `build.gradle:135/140`) + Moonshine JNI resolves fields by exact name → R8 renamed them. **FIX:** proguard keep rules `-keep class ai.moonshine.** { *; }` in `app/android/app/proguard-rules.pro`, commit **`aa42b53`**, build **`28807197810` GREEN**. Sri beeped ×2 to install from that run's artifact + test (Settings→Transcription→On-Device Moonshine, ~79 MB first-run download). Memory: `mem_20260706_omi-android-bug-fix-2026_85c0e5`.
- **Sri's "connection failed primary/secondary" logs:** old whisper-local attempts + Play-services noise. Red herring; whisper stays deprioritized.
- **No transcripts in conversations tab (Sri Q5) — architectural, confirmed:** live segments memory-only (`capture_controller.dart` ~2107-2140); tab merges backend conversations + LocalRecording rows only (`conversations_page.dart:277`, `local_recordings_provider.dart:182/205`). **B5 fix in-flight:** persist finalized guest-mode capture sessions locally, reuse LocalRecording path. Codex exec running in background (spec: scratchpad `b5-spec.md`; do-not-commit; Claude reviews + commits).
- **Tooling gotcha:** `mcp__codex-cli__codex` MCP tool started DROPPING prompt bodies mid-session ("no implementation task included", wrote confused questions into Q and A.md). Workaround: `codex exec --model gpt-5.5 --full-auto -C <repo> "$(cat spec.md)"` via Bash — works. Memory: `mem_20260706_codex-cli-tooling-bug-20_39c0da`.

**New Sri directives (Q&A):** Q4 Groq whisper presets in STT dropdown → own cherry-pickable branch (BYOK, after B5); unrelated work = separate commits/branches, merge later; compact at phase transitions (transfer state to memory first); he's away — beep MULTIPLE times when needed.

**Merge plan:** Phase B (B3+B4+aa42b53) merge to main HELD until Sri confirms Moonshine works on `28807197810` APK. Then merge (regular merge, self-merge authorized) → apk-latest refresh. B5 lands as its own verified increment after. Then greying (P1.2-B), then Groq presets.

## 2026-07-06 ~06:15 IST — B4 landed (Moonshine selectable); B3 compile-GREEN; Sri device-verified local-first; awaiting B4 build to merge Phase B

**Sri directives (Q&A end, this session):** (1) Android **16** → Moonshine minSdk-35 fine, NO sherpa pivot. (2) **Full push+self-merge autonomy** — "remove this rule of not pushing, do all this yourself", "dont stop for my inputs, choose best option + fallback and do." (3) Parallel phases on branches, merge+verify. (4) Codex heavy-lifts, Claude orchestrates+corrects. Saved: `mem_20260706_omi-project-2026-07-06-s_d81437` (autonomy), session row `mem_20260704_omi-fork-session-2026-07_78f542` (refreshed).

**Sri DEVICE TEST (current apk-latest P1.2-A):** ✅ got past sign-in (local-first boots, no login wall), ✅ recorded audio, ❌ on-device Whisper STT broke → logged low-prio in ROADMAP (Moonshine replaces it).

**State:** `feature/local-first` HEAD ~`e641f02e8`. Commits since P1.2-A: B1 `868ad3b6d`, B2 `2d76bca1f`, B3 `a9c253c43`, **B4 `553838ecd`** + docs. Pushed.
- **B3 compile-GREEN** (branch build `28759379198`): Kotlin bridge + `ai.moonshine:moonshine-voice:0.0.65` + minSdk-35 override all build. The big unverified chunk is sound.
- **B4** (`transcription_settings_page.dart`): "On-Device Moonshine" is a top-level `TranscriptionMode`; selecting it persists `customSttConfig.provider=onDeviceMoonshine`, which `transcription_service.dart:354` already routes to `OnDeviceMoonshineSocket`. Codex implemented; Claude corrected 2 drifts (added Android-15+/Android-only device guard in `_switchToOnDevice`; hid the premature model/lang pickers — only tiny-en wired). Build **`28759840329`** in_progress (background watcher `b2u3g1yxj` armed → wakes on finish).
- apk-latest still P1.2-A (108 MB, 2026-07-05).

**Reviewed (no change needed):** Moonshine first-run path (`on_device_moonshine_socket.dart` + `MoonshineSttPlugin.kt`) — errors surface via onError, model download is resumable (per-component `.part`→rename, skips completed), API-35 gated. Sound for a device test. Caveat: ~79 MB download on first `initialize` (no progress UI ~30-60s; audio during download dropped) — "report if annoying", not a blocker.

**Next (in order):**
1. B4 build `28759840329` green ⇒ open PR `feature/local-first`→main, **regular merge (self-merge authorized)** → main APK build → apk-latest refresh → **beep Sri** to flip Settings→Transcription→"On-Device Moonshine" and test on-device STT. Mention the ~79 MB first-run download so it doesn't look frozen. If B4 build RED: fix `transcription_settings_page.dart` from the log (likely a `TranscriptionMode` switch exhaustiveness miss — both `_modeLabel`/`_selectMode` were verified exhaustive).
2. Then **guest cloud-tab greying** (P1.2-B) as next increment on `feature/local-first` (Sri wants it; deprioritized behind Moonshine since Sri didn't flag empty tabs). Seam: home `pages/home/page.dart` `IndexedStack` `_pages` (line ~251/706), `HomeProvider.selectedIndex`, bottom nav. Grey Conversations/Chat/Memories for guests (`!AuthenticationProvider.isSignedIn()`) + "needs cloud" label → 1 new l10n key × 49 locales (skill `omi-add-missing-language-keys-l10n`).
3. Deferred: B4b guest consent gate (`mobile_app.dart:40-43` ponytail note — gate capture-start on `aiConsentGiven` for guests; low value for on-device, do carefully so it can't block capture); whisper-STT debug (low-prio); dev-theme (roadmap last).

**Safety/rules:** apk-latest only refreshes from GREEN compile builds (no local flutter/dart/phone — CI + Sri's device are the only verification). Codex = gpt-5.5 **medium** (NOT xhigh), ONE job at a time (sqlite clash). Answer Sri ONLY at END of `Q and A.md`. Never upstream `BasedHardware/omi`.

---

## 2026-07-06 ~03:00 IST — P1.2-A merged + LIVE (apk-latest); Phase B Moonshine planned + B1/B2 committed (held)

### Where we are
- Branch `feature/local-first` in main repo folder `C:/Android_software/omi` (no worktree). Synced to fork main.
- **P1.2-A MERGED (PR #5)** + main APK build GREEN (run 28750627047) → **apk-latest refreshed** (local-first build, 103 MB, 2026-07-06). Sri notified; awaiting his device report. P1.2-A = boot-to-local-Home for guests + Settings "Connect to Omi Cloud" row (reuses `connectTo` l10n, no new keys) + Sign Out hidden for guests + fix: reset `onboardingCompleted` before guest→cloud sign-in so a fresh cloud account still onboards.
- **Phase B (on-device Moonshine STT) planned:** `plans/P5-moonshine.md` — seam map (file:line), B0 reuse-check (no fork to cherry-pick; reuse in-repo `IPureSocket` seam), increments B1→B5. Linked from ROADMAP P5 + plans/README.
- **B1+B2 committed on branch, NOT merged** (holding so apk-latest stays P1.2-A for Sri's test):
  - `868ad3b6d` B1 — `SttProvider.onDeviceMoonshine` enum (streaming, models tiny/small/medium).
  - `2d76bca1f` B2 — `OnDeviceMoonshineSocket implements IPureSocket` (MethodChannel `com.omi/moonshine_stt`, PCM16 via `AudioTranscoderFactory.createToRawPcm`) + factory routing that **bypasses** the cloud-coupled `CompositeTranscriptionSocket` + fake-channel unit test.
  - Claude verified all compile anchors (9 IPureSocket members, `TranscriptSegmentSocketService.withSocket` sig, transcoder API, `PureSocketStatus`, `BleAudioCodec` path) → compiles. Branch build `28756353578` running as CI compile-check (branch build = artifact only, does NOT refresh apk-latest).

### Immediate next (in order)
1. Branch build `28756353578` green ⇒ B1+B2 compile-verified. If red, fix from the log.
2. Hold the merge until Sri reports the P1.2-A device test. Then merge accumulated (B1+B2) → apk-latest.
3. **B3 = Moonshine Android native bridge** (the big can't-verify-without-device chunk): Kotlin plugin on MethodChannel `com.omi/moonshine_stt` (`initialize`/`appendPcm16`/`stop`/`dispose` + transcript events) around Maven `ai.moonshine:moonshine-voice` + `moonshine-streaming-tiny` (26 MB, download/bundle strategy TBD). Do with Codex + Sri device-test.
4. B4 settings toggle + `aiConsentGiven` capture-gate (new l10n keys OK ARB-only — see l10n fact below).
5. Deferred: P1.2-B guest cloud-feature gating (grey conversations/chat/memories + "needs cloud"); P2 triggers (planned, gate D2).

### Facts / rules learned this session
- **l10n unblocked:** pubspec has `generate: true` → CI `flutter build` regenerates `lib/l10n/app_localizations*.dart` from the ARBs. So NEW keys can be added ARB-only (no local flutter needed to regen); still translate all 49 locales via skill `omi-add-missing-language-keys-l10n`. Prefer reusing an existing key (P1.2-A reused `connectTo('Omi Cloud')`).
- **Compile-verify trick:** push the feature branch → triggers a **branch** APK build (compile check, artifact only). Only a **main** push refreshes apk-latest.
- Disabled scheduled workflow `Auto Release Desktop on Main` (`gh workflow disable`) — it was the red FAIL spam on the Actions tab (cron, upstream desktop-release, nothing to do with our Android APK).
- Codex (gpt-5.5, medium) = implementer; **scope-fence it** — it drifted into `Q and A.md`/`HANDOFF.md`/R5 once; split those out of the feature commit. Claude reviews compile anchors (no local flutter/dart on this Windows box).
- Q13 (Sri's Kaggle ONNX model link) still OPEN — blocks his-own-model-as-STT-engine, not Moonshine.
- `Q and A.md`: answer at the END only (Sri's hard rule).

---

## 2026-07-04T~15:00Z — P0 merged, P1 shipped, P1.1 native-lane sign-in fix merged + building; awaiting Sri install test

### Where we are
- **Branch:** `feature/phase1-signin` in the **main repo folder** `C:/Android_software/omi` (NO worktree — Sri hates them; `omi-phase0` removed this session).
- **Merged to fork main this session:** PR #2 (phase0 CI+roadmap), PR #3 (P1 build stamp + error surfacing), **PR #4 (P1.1 native-lane sign-in fix)**. Regular-merge, fork-only. Standing rule **"merge yourself"**; NEVER upstream `BasedHardware/omi`.
- Codex CLI = worker (impl + review), Claude = orchestrator + corrector.

### THE LIVE THING — sign-in fix verification (P1.1)
- **Root cause CONFIRMED** via P1's surfaced error: `[custom-token] firebase_auth/custom-token-mismatch: The custom token corresponds to a different audience.` OAuth flow works end-to-end; only final `signInWithCustomToken` fails — `api.omiapi.com` mints tokens for a project ≠ app's `based-hardware-dev` config. Config bug.
- **Fix merged (PR #4):** CI `.dev.env` → native lane `USE_WEB_AUTH=false`+`USE_AUTH_CUSTOM_TOKEN=false`. Decisive: shared `debug.keystore` SHA-1 `50f87a68…dab3598` IS a registered Android OAuth cert in `based-hardware-dev`'s `google-services.json` → native sign-in = matching session, no custom token.
- **BUILDING (re-dispatched):** first native-lane run 28709261639 was **CANCELLED** (concurrency `android-apk-refs/heads/main` — a later direct-to-main commit `cbfce784` "docs R5" by Sri at 15:01Z coincided; docs pushes shouldn't trigger APK but the in-flight run died). apk-latest still = old **P1 web-auth** build (06:52Z). Fix IS on main (`USE_WEB_AUTH=false` confirmed at main HEAD). **Re-dispatched via workflow_dispatch: run 28710779623** (in_progress ~15:26Z). Wait **`bke9s5pw4`** armed. Builds run ~40min on the loaded runner. When apk-latest asset timestamp flips past 06:52Z → PushNotification Sri for the two-stage test. **If it cancels again:** consider removing `cancel-in-progress` for main in the workflow (main builds should complete + publish), or re-dispatch.
- Note: **Sri commits directly to main** sometimes (e.g. `cbfce784`) — his repo, fine; but his main pushes can cancel in-flight APK runs via the shared concurrency group.
- **Codex D verdict folded (task `b0nswq6fk`, done):** converges on native lane; backend read (`backend/deploy/runtime_env.yaml`, `auth.py`, `dependencies.py`) says `api.omiapi.com` likely verifies **`based-hardware` (prod)** tokens → **Outcome B (API 401 after native sign-in) is the likely case**. No prod `google-services.json` committed → no shortcut → Outcome B = own-Firebase.
- **DECISION FORK when Sri tests (in plans/P1-signin.md):** **A** signs in + loads data → done. **B** signs in but API 401 → `api.omiapi.com` not on `based-hardware-dev` → pivot to Sri's own Firebase + self-host backend (P7/D7 auth slice early). Stamp reads `native-auth`.

### Immediate next (in order)
1. Build 28709261639 green → PushNotification Sri: install apk-latest, confirm stamp `native-auth`, try Google sign-in, report A or B.
2. Fold **Codex D** verdict (task `b0nswq6fk`; read `…/bfce8b6c-…/scratchpad/codexD-signin-fix.txt`) — may pre-answer A vs B (does `api.omiapi.com` accept `based-hardware-dev` tokens?).
3. Sri report: A → close P1. B → P1.2 own-Firebase (Codex implements).
4. **Then Q11 sync-fork** (DEFERRED till sign-in works; upstream +149, 0 conflicts; local `git merge upstream/main` → PR → self-merge). Bundle disabling fork-noise workflows (`trigger-codemagic`, `Auto Release Desktop on Main` — FAIL every main push).

### Also delivered
- Plans: `plans/{README,P1-signin,P2-triggers-v1,P3-bt-trigger-matrix}.md` (ROADMAP.md = master).
- Closed: **D0b arm64-only** APK, **D5 Silero VAD**.
- Research pack `docs/research/{README,R1..R6}.md` (public-safe); Sri running R4→R3→R1→R2→R5→R6, pasting findings back.
- **Q13 open:** Sri's ONNX models (Kaggle + FUTO keyboard fork) → folded into D6/AsrEngine; need Kaggle link + model type.

### Rules
- `Q and A.md` (repo root) = live channel; Sri edits mid-session, re-read often, fold scratch → numbered Q&A. Terse, act without asking, self-authorized merges.
- No local flutter/phone → APK build green = compile check; Sri does real sign-in. main.yml = issue-sync only (no test CI on push).
- Codex: `codex exec --sandbox read-only|workspace-write --cd <dir> --output-last-message <file> "…"`, background long runs. Quota short-cycles.
- CI landmines: prebuilt+`.dev.env` before build_runner; `CM_KEYSTORE_*`; `--build-number=run_number`; Flutter 3.41.9/Java 21; APK builds only on `app/**` or workflow-file paths.

### Memory rows (project=omi)
- `mem_20260704_omi-fork-session-2026-07_78f542` (updated) — session state + rules.
- `mem_20260704_android-deep-link-intent_c676bc` — hostless `omi://` filter already catches callbacks.
- `mem_20260704_omi-sign-in-bug-root-cau_6f233b` — custom-token-mismatch root cause + fixes.

---

## 2026-07-04T04:59:53Z — Phase-0 CI + roadmap landed; merge + sign-in triage pending

### Current task state
- Branch `feature/phase0-ci-roadmap` (worktree `C:/Android_software/omi-phase0`), pushed to origin. 2 commits:
  - `bd53ec8c6` ci: build installable dev-flavor APK on push (`.github/workflows/android_apk_build.yml` + AGENTS.md CI note)
  - `490ec1f11` docs: phone-capture roadmap v1 + Q&A protocol (`ROADMAP.md`, `Q and A.md`)
- CI **proven green**: run 28690006580, ~18 min, artifact `omi-dev-apk` 86 MB. Old run 28689933172 = cancelled (concurrency), ignore.
- **NEW user instructions (live, in files — not yet executed):**
  1. Q&A scratch: "make Codex CLI work you orchestrate" / **"merge and continue work"** / "i will install when the app is built" → **merge is explicitly authorized**: open PR from `feature/phase0-ci-roadmap` → `main`, **regular merge (never squash)**.
  2. ROADMAP.md P0 (~line 50) user note: "give link here ....i installed one apk that was built but could not sign in. errored out!" → user installed a built APK, **sign-in STILL fails**. Needs P1 triage + a direct download link written into that ROADMAP line.

### Key decisions (closed 2026-07-04, in ROADMAP.md decision boxes)
- D0a: rolling `apk-latest` prerelease on main + branch artifacts.
- D1: community auth lane now (upstream dev Firebase + `https://api.omiapi.com/`, `USE_WEB_AUTH=true` browser OAuth + custom token); sovereignty deferred to P7.
- D4: runtime-defined BT mapping (learn-mode wizard, nothing hardcoded).
- Repo privacy: stay public until P7; fork can't flip private — duplicate repo then.
- Open D-boxes awaiting Sri: D0b APK shape, D2, D3, D5 VAD, D6 ASR, D7 sovereignty shape, D8 .memory transport.

### Modified files (all committed on the branch)
- `.github/workflows/android_apk_build.yml` (new)
- `AGENTS.md` (one CI bullet under "CI/CD & Logs")
- `ROADMAP.md` (full rewrite, P0–P10 + debates) — user added a raw note ~line 50, uncommitted in worktree? CHECK `git -C C:/Android_software/omi-phase0 status` first; user edits files live.
- `Q and A.md` (new tracked; Q1–Q8 answered; scratch section has the 3 new instructions, uncommitted)
- Untracked leftover: `C:/Android_software/omi/Q and A.md` (old 2-line copy in MAIN checkout) — **will block merge checkout; delete it before/when pulling main**.

### Blockers / open questions
- **Sign-in failed again** on an installed APK. Unknown which APK (artifact of green run should have web-auth baked). Triage order (ROADMAP P1): exact error/screenshot from Sri → confirm APK provenance (run 28690006580 artifact?) → check web-auth path exercised (browser OAuth flow vs native Google button — user may have tapped native Google Sign-In which can still throw ApiException:10 if the community keystore SHA isn't registered; web-auth/custom-token path is the supported lane) → verify `USE_WEB_AUTH=true` baked (decompile check or debug log) → backend reachability.
- Codex CLI stdout in this harness: `codex exec ... | tail` captures nothing; use `--output-last-message <file>` and read the file. Reviews can exceed 10 min foreground — run background.

### Next steps (in order)
1. Read `C:/Android_software/omi-phase0/Q and A.md` + `ROADMAP.md` for any newer live user edits.
2. Commit any uncommitted user/live edits on the branch (docs commit), push.
3. `gh pr create --repo sriharshaguthikonda/omi --base main --head feature/phase0-ci-roadmap` then **regular merge** (`gh pr merge --merge`) — authorized by user ("merge and continue work").
4. Post-merge: main push triggers workflow → `apk-latest` prerelease at `https://github.com/sriharshaguthikonda/omi/releases/tag/apk-latest`. Paste that link into ROADMAP P0 line ~50 (user asked "give link here") + into Q&A; push docs update.
5. Delete stale untracked `C:/Android_software/omi/Q and A.md`, then `git -C C:/Android_software/omi pull --ff-only`.
6. P1 sign-in triage with Sri's error details; use Codex CLI for any code changes (user rule: Codex implements + reviews, Claude orchestrates/corrects).
7. Notify Sri via PushNotification when prerelease link is live ("i will install when the app is built").

### Critical context
- Build recipe + landmines: see memory `mem_20260704_omi-fork-sriharshaguthik_eacf03` and ROADMAP P0 "How it works": prebuilt configs `app/setup/prebuilt/`, `.dev.env` BEFORE build_runner (envied), `CM_KEYSTORE_*` env neutralizes `CI=true` gradle branch, Flutter 3.41.9, Java 21, `--build-number=run_number`, tag force-move before softprops release.
- gh API served stale run status mid-run (showed in_progress/cancelled after success) — trust a fresh `gh run view <id> --json status,conclusion` and artifacts list, not watchers.
- User comms: `Q and A.md` = the channel; user edits files live mid-session; check it often. Tone: terse, no unnecessary questions, push feature branches without asking; main-touching needs explicit ask (merge now given).
- Memory rows saved this session: build recipe (world_facts/omi), project state + decisions (world_facts/omi), codex-delegation feedback (beliefs_preferences/global ×2).

### Model summary
- Fork `sriharshaguthikonda/omi` = phone capture endpoint feeding `.memory` (C:/.memory, 13-phase plan; Phase 9 chat-dump ingest = intended P8 transport).
- Deliverable 1 done: push-triggered dev-APK workflow, proven green (18 min, 86 MB artifact).
- Deliverable 2 done: ROADMAP.md P0–P10 checkbox-debate format + Q and A.md channel.
- Sideloaded sign-in root cause: SHA-locked native Google Sign-In + missing env; fix = upstream community web-auth lane baked into CI.
- Codex drafted workflow; Claude fixed 4 gaps (CM_* landmine, Flutter pin, build-number, stable asset name); Codex review added tag-move fix.
- User closed D0a/D1/D4 + privacy timing; several D-boxes await user replies.
- User authorized merge to main ("merge and continue work") — not yet executed.
- User reports sign-in STILL errored on an installed APK → P1 triage is the next real work.
- P3 flagship = runtime-defined multi-device BT button matrix (learn-mode wizard).
- Worktree `C:/Android_software/omi-phase0`; main checkout has stale untracked `Q and A.md` to delete.
- Codex CLI: use `--output-last-message file`; background for >10 min tasks; user demands Codex-first delegation.
- Actions enabled on fork by user; enable button has no API.

### Handoff context (actionable)
1. `cd C:/Android_software/omi-phase0 && git status --porcelain` — commit/push any live user edits first.
2. `gh pr create --repo sriharshaguthikonda/omi --base main --head feature/phase0-ci-roadmap --title "Phase 0: APK CI + roadmap" --body "..."`.
3. `gh pr merge <num> --repo sriharshaguthikonda/omi --merge` (NO squash — repo rule).
4. Watch main run: `gh run list --repo sriharshaguthikonda/omi --limit 3`; on success check `gh release view apk-latest --repo sriharshaguthikonda/omi`.
5. Edit ROADMAP P0 install line: replace user's "give link here ...." note with `https://github.com/sriharshaguthikonda/omi/releases/tag/apk-latest` + note their sign-in error is P1-tracked; move their comment into Q&A as Q9 with answer.
6. Ask Sri (via Q&A file, one entry): exact sign-in error text/screenshot + which button they tapped (Google vs "continue with browser"/other) + APK source.
7. `rm "C:/Android_software/omi/Q and A.md"` (stale untracked) then `git -C C:/Android_software/omi pull --ff-only` after merge.
8. Delegate any code fix to Codex: `codex exec --full-auto --cd <worktree> --output-last-message <scratch>/out.txt "<task>"` (background, then read out.txt).
9. Memory search `project=omi` for build recipe + decisions before re-deriving anything.
10. PushNotification Sri when apk-latest is downloadable.

---

## 2026-07-04T~06:00Z — P1 implemented + reviewed, arm64 build running, merge-on-green pending

### CRITICAL rules (Sri, this session)
- **NO separate worktrees.** Sri was angry about `omi-phase0`. It's DELETED. Work branches in the main repo folder `C:/Android_software/omi` directly. Current branch: `feature/phase1-signin`.
- **"merge yourself"** — Claude self-merges fork PRs autonomously: regular merge (NEVER squash), fork `sriharshaguthikonda/omi` main only. **NEVER touch upstream `BasedHardware/omi`** (Q10).
- **"codex cli as worker, you orchestrate"** — Codex CLI = implementation + review passes; Claude = orchestrate + correct. Announce who's lifting. Codex quota short-cycles (dead ~10:40 IST, back ~10:58 same day) — retry before falling back to Claude subagents.
- Q&A channel = `Q and A.md` at repo ROOT (tracked). Sri edits it LIVE mid-session — re-read the scratch section (bottom) often; fold notes into numbered Q's.

### Current state
- Branch `feature/phase1-signin` pushed, HEAD ~`e6740b52c`. Phase0 already merged to main (PR #2).
- **P1 code DONE** (Codex impl + Claude corrected + Codex review = **SHIP, 0 blockers**). Files:
  - `app/lib/widgets/build_stamp.dart` — `BuildInfo` (dart-define `OMI_BUILD_SHA`/`OMI_BUILD_RUN`/`OMI_BUILD_BRANCH`, defaults local/0/dev) + `BuildStamp` widget.
  - `app/lib/services/auth_error_log.dart` + `app/lib/backend/preferences.dart` (`lastAuthError` get/set) — persist last sign-in failure w/ stage.
  - `app/lib/services/auth_service.dart` — `AuthErrorLog.record('<stage>', e)` on every web-auth failure branch only.
  - `app/lib/providers/auth_provider.dart` — `_authErrorMessage()` appends real error, **dev-gated** via `F.env == Environment.dev`.
  - `app/lib/pages/settings/developer.dart` — "Last sign-in error" row. `about.dart` + `pages/onboarding/auth.dart` — `BuildStamp` mounted.
  - `app/test/widgets/build_stamp_test.dart` — widget test (can't run: no flutter locally, no test-CI on push).
  - `.github/workflows/android_apk_build.yml` — bakes dart-defines + **arm64-only** (`--target-platform android-arm64`, D0b).
  - Manifest: NO change (Claude reverted Codex's redundant `omi://auth` filter — generic `omi://` at `AndroidManifest.xml:172-177` already catches the callback; see memory `mem_20260704_android-deep-link-intent_c676bc`).

### NEXT STEPS (in order) — resume here
1. **Watch arm64 build** run `28697117742` (Monitor task `bjmkv4ecg` armed; may already have fired). Green = compile verification (only path — no local flutter).
2. On green: `gh pr create --repo sriharshaguthikonda/omi --base main --head feature/phase1-signin --title "P1: sign-in build stamp + error surfacing"` → `gh pr merge <n> --repo sriharshaguthikonda/omi --merge` (self-merge authorized).
3. Main push → main APK build → publishes `https://github.com/sriharshaguthikonda/omi/releases/tag/apk-latest`. PushNotification Sri: install, read the build stamp on sign-in footer, try sign-in, report per Q&A checklist item 1.
4. **Then Q11 sync-fork** (deferred until P1 merged): `git fetch upstream main` (upstream remote added; +149 commits, 0 conflicts via merge-tree). Web Sync-fork button fails because upstream touched `.github/workflows/**`. Do it via local `git checkout main && git merge upstream/main` → push branch → PR → self-merge. Direction upstream→fork ONLY.

### Open — needs Sri (non-blocking, in Q&A)
- **Q13:** link to models Sri is "training elsewhere" (wire into D6 ASR + `AsrEngine` interface).
- Sign-in error details (exact text/screenshot, which button, APK source).
- Decisions still OPEN: **D2** (trigger scope) + **D3** (BT mechanism order) — these GATE P2/P3 execution start. Also D6 (ASR), D7 (sovereignty), D8 (transport).
- Closed this session: D0b (arm64), D5 (Silero VAD). Earlier: D0a, D1, D4.

### Artifacts created this session
- Plans: `plans/README.md` + `plans/P1-signin.md` + `plans/P2-triggers-v1.md` + `plans/P3-bt-trigger-matrix.md`.
- Research pack (Sri runs via ChatGPT Deep Research): `docs/research/README.md` + `R1..R6` (priority R4→R3→R1→R2→R5→R6). Public-safe.
- Memory: `mem_20260704_omi-fork-session-2026-07_78f542` (project_state, updated), `mem_20260704_android-deep-link-intent_c676bc` (deep-link lesson).

### Gotchas
- No flutter/dart on PATH locally → cannot run `flutter analyze`/tests/build. CI APK build = the only compile check. Sri exercises real sign-in on device.
- gh run status can lag; trust fresh `gh run view <id> --json status,conclusion`.
- Memory `remember`/`update`: no `→`/unicode arrows (charmap encode error); `update` takes `patch` not `content`; `source_ref` must be under raw_logs/context_packs/hardcopy or omitted.

---

## 2026-07-05 10:22 +0530 — Local-first pivot (session 2)

### Current task state
Pivot from broken Omi-cloud auth to local-first. Planning + all direction docs DONE and
committed. Boot-local core code DONE, committed, codex-reviewed. Branch `feature/local-first`
(2 commits ahead). NOT pushed (no local build env; needs Sri's OK). Sign-in is temporarily
unreachable on the branch until the Settings entry lands (next increment).

### Key decisions
- Community cloud lane is structurally dead: app=based-hardware-dev, api.omiapi.com verifies
  based-hardware, so authed calls 401. Upstream #5939 won't-fix. Stop chasing auth configs.
- P1.2 = remove mandatory login + Omi-cloud-optional-in-settings + gate cloud features (grey).
- On-device STT engine = Moonshine (D6 closed). Path: Moonshine Voice native SDK
  (Android Maven ai.moonshine:moonshine-voice, iOS SPM moonshine-swift) +
  moonshine-streaming-{tiny,small,medium}; wire at IPureSocket streaming seam (NOT ISttProvider).
- Local intelligence = user-provided cheap LLM (Gemini Flash / free chain), not cloud.
- Delegation: codex implements (gpt-5.5, medium, ONE job at a time), Claude corrects/reviews.

### Modified files (committed on feature/local-first)
- 4ead44399 docs: ROADMAP.md, plans/P1-signin.md, plans/README.md, "Q and A.md",
  docs/investigations/2026-07-05-community-build-auth.md
- 26ca975cb code: app/lib/mobile/mobile_app.dart (guest branch -> _PermissionsGate, removed
  device_selection import), app/lib/backend/http/shared.dart (two signed-out guest guards)

### Blockers / open questions
- CANNOT build/test locally: no flutter/adb/dart/emulator on this Windows box. Verify only via
  push -> CI (.github/workflows/android_apk_build.yml) -> apk-latest -> Sri's phone.
- Need Sri's explicit OK to push (AGENTS.md: never push unless asked). Do NOT touch main.
- Sign-in unreachable on branch until the Settings "Connect Omi Cloud" entry is added.

### Next steps (in order)
1. Settings "Connect Omi Cloud" sign-in entry: app/lib/pages/settings/settings_drawer.dart,
   BOTH render paths (searchable list ~L422, section view ~L692). Show when
   !AuthService.instance.isSignedIn(); onTap -> routeToPage(context, const OnboardingWrapper());
   hide "Sign Out" for guests. New l10n key connectOmiCloud across 49 locales
   (skill omi-add-missing-language-keys-l10n; verify flutter gen-l10n = 0 warnings in CI).
2. Cloud-feature gating: grey conversations/chat/memories when guest + "needs cloud" badge;
   reuse preferences.dart getBool/saveBool + Color(0xFF8E8E93)/SwitchListTile.enabled.
3. Widget test for the gate (guest -> _PermissionsGate, not DeviceSelectionPage).
4. Ask Sri to push -> CI -> verify boot-to-Home + sign-in-from-settings on device.
5. Phase B Moonshine: OnDeviceMoonshineSocket implements IPureSocket (MethodChannel PCM in /
   EventChannel transcript out -> TranscriptSegment -> TranscriptSegmentSocketService); add
   SttProvider.onDeviceMoonshine; + AI-consent-at-capture gate. B0 first: check FUTO
   (reference-only per license ledger) + omi forks (gh api repos/BasedHardware/omi/forks) to reuse.

### Critical context
- Gate: app/lib/mobile/mobile_app.dart:18-42 (Consumer<AuthenticationProvider>). _PermissionsGate
  defined same file :47. app_shell.dart:353-382 already gates cloud provider init behind isSignedIn
  -> guest boot fires zero cloud calls (why the diff is tiny).
- Codex flagged HIGH: guest skips aiConsentGiven gate -> deferred to Phase B capture-start (no AI
  processing runs at guest boot); documented as a ponytail comment in mobile_app.dart guest branch.
- docs/research/R5-offline-sync-transport.md has pre-existing trailing-whitespace (fails
  git diff --check) — NOT ours, left unstaged.
- Codex runtime: MCP defaults to retired gpt-5.3-codex (rejected on ChatGPT account) -> MUST pass
  model=gpt-5.5. Background codex jobs clash on .codex sqlite if parallel -> sequential only. Fetch
  detached results: node C:/Users/deletable/.claude/plugins/cache/openai-codex/codex/1.0.5/scripts/codex-companion.mjs status|result <task-id>.
- Session plan file: C:/Users/deletable/.claude/plans/lets-take-next-steps-noble-popcorn.md
- Memories: mem_20260705_codex-cli-runtime-facts_2804fa, mem_20260705_omi-fork-dev-box-c-andro_a8c300

### Model summary
- Sri's on-device test of the native-auth APK failed: Google sign-in ok, then api.omiapi.com 401s
  the based-hardware-dev ID token. Confirmed Outcome B / upstream #5939 (cross-project mismatch).
- Sri's directive: remove mandatory login, keep Omi cloud optional in settings, gate cloud features
  (grey/red), build on-device (Moonshine streaming), resource-aware toggles; no reinventing wheels.
- Explored via 3 Claude Explore agents (auth gate, investigation/research/plans, STT pipeline).
- On-device STT seam already exists (whisper_flutter_new wired) but whisper is chunked, not live;
  Sri confirmed Moonshine streaming instead.
- Codex (gpt-5.5) chose the Moonshine Voice native SDK path and corrected the streaming seam to
  IPureSocket (not the batch ISttProvider transcribe()).
- Updated ROADMAP/plans/Q&A (answered at END of Q&A file — Sri's hard rule); added backlog items
  (custom-dictionary accuracy, data-portability/import-from-official-app).
- Codex enumerated guest-safety; Claude corrected (codex would've skipped the mic-permission gate),
  reduced 5 edits -> 3 root-cause edits, implemented + committed boot-local core.
- No local build env -> verification is CI + Sri's phone; nothing pushed.
- Two follow-on increments (settings sign-in entry, cloud gating) then Phase B Moonshine.

### Handoff context
- On branch feature/local-first, 2 commits ahead (docs + boot-local). Check: git log --oneline -3.
- Do NOT push without Sri's explicit OK. Do NOT touch main. Commit locally by default.
- IMMEDIATE next task = Settings sign-in entry (Next steps #1). Without it a guest can't reach
  sign-in; it MUST land before the branch is pushable.
- All app UI changes are UNVERIFIABLE locally (no flutter). Write carefully; rely on codex
  read-only review (model=gpt-5.5) + CI flutter analyze + Sri's device test.
- Use codex via mcp__codex-cli__codex, model="gpt-5.5", ONE job at a time. Never default to xhigh
  reasoning (Sri's rule) — medium/low.
- l10n: add keys via jq to app/lib/l10n/app_en.arb (never read full ARB), translate all 49 locales
  (skill omi-add-missing-language-keys-l10n), then flutter gen-l10n must emit zero warnings (CI-checked).
- Cloud calls route through app/lib/backend/http/shared.dart (makeApiCall/buildHeaders); guest guards
  already in place there.
- "Q and A.md": Sri appends anytime, a hook injects his edits into context live; ALWAYS answer at the
  END of the file (he is emphatic — do not write mid-file).
- Moonshine: start UsefulSensors/moonshine-streaming-tiny; keep AsrEngine extensibility so Sri's own
  Kaggle ONNX model drops in (Q13 still open — awaiting his Kaggle link).
- Sri is away; beep milestones via PushNotification. He wants codex delegation visibly announced.
- Read the session plan file + plans/P1-signin.md P1.2 section before continuing.

---

## 2026-07-05 23:35 +0530 — Settings cloud sign-in row landed

- Added guest-only "Connect to Omi Cloud" entry in `app/lib/pages/settings/settings_drawer.dart`.
- The entry appears in both Settings search and the normal Settings account section.
- Guests no longer see "Sign Out"; signed-in users still see the existing sign-out flow.
- The connect row closes the drawer and routes via the root navigator to `OnboardingWrapper`, preserving local-first boot while keeping cloud sign-in reachable.
- Local verification remains blocked: no `dart`/`flutter` executable on this Windows host. Static checks only: l10n `connectTo(String appName)` exists, `OnboardingWrapper` import path exists, `git diff --check` clean after removing R5 trailing whitespace.

---

## 2026-07-06 05:10 +0530 — B3 Moonshine Android native bridge landed (+ minSdk 35 blocker)

**Task state:** Phase B **B3 committed** `a9c253c43` on `feature/local-first` (not pushed, not in apk-latest). B1/B2 (Dart socket) already merged. B4 (Settings STT toggle) is BLOCKED pending Sri's Android-version answer.

**Key decisions:**
- Use plain `Transcriber` + `addAudio(float[],int)` (feed app-owned PCM16→float), NOT `MicTranscriber` (would open a 2nd mic stream, can't do BLE audio).
- Model provisioning = **runtime download** of tiny-streaming-en (~79 MB, 8 files) from `https://download.moonshine.ai/model/<id>/quantized/<file>` into `filesDir` (mirrors existing `whisper_flutter_new` pattern). NO Git LFS, NOT bundled in APK/git.
- `moonshine-voice:0.0.65` AAR requires **minSdk 35 / Android 15** (verified via javap on the AAR manifest) + ships **arm64-v8a only**. Kept app installable on minSdk 29 via `<uses-sdk tools:overrideLibrary="ai.moonshine.voice"/>` + runtime API-35 gate that returns a clear error below 35.
- If Sri's phone is <15: pivot engine to **sherpa-onnx** (API 21+ streaming) — same seam, also serves his Kaggle ONNX model (Q13).

**Modified files (staged into `a9c253c43`):**
- `app/android/app/src/main/kotlin/com/friend/ios/MoonshineSttPlugin.kt` (NEW — channel `com.omi/moonshine_stt`)
- `app/android/app/src/main/kotlin/com/example/my_project/MainActivity.kt` (registers plugin)
- `app/android/app/build.gradle` (added `implementation 'ai.moonshine:moonshine-voice:0.0.65'`)
- `app/android/app/src/main/AndroidManifest.xml` (uses-sdk overrideLibrary)
- `Q and A.md` (agent answer at END — unstaged; separate docs commit)

**Blockers / open questions:**
- **Sri's Android version** (gates Moonshine-vs-sherpa + B4).
- Push `feature/local-first` to CI for compile-proof? (asked in Q&A; not done — "never push unless asked").
- Q13 Kaggle ONNX link still open.

**Next steps:**
1. Wait on Sri's Android version → keep Moonshine (15+) or pivot to sherpa-onnx.
2. Guest cloud-greying (independent, unblocked): grey Conversations/Chat/Memories for guests with a "needs cloud" label. Seam = `mobile_app.dart` tabs gated on `AuthenticationProvider.isSignedIn()` ([app_shell.dart:355](app/lib/core/app_shell.dart) delegates to `MobileApp`). Needs 1 new l10n key → 49 locales (skill `omi-add-missing-language-keys-l10n`).
3. Then B4 (Settings toggle in `transcription_settings_page.dart`) + consent gate on `aiConsentGiven`.

**Critical context:**
- No Flutter/dart toolchain on this Windows host → only compile gate is a CI branch build (like B1/B2 `28756353578`). Static verified: braces/parens balanced, compileSdk 36 covers API 35, `mavenCentral()` present, okhttp 4.12.0 already a dep.
- AAR decompiled to `…/scratchpad/aar/` via `curl https://repo1.maven.org/maven2/ai/moonshine/moonshine-voice/0.0.65/moonshine-voice-0.0.65.aar` + javap at `/c/Program Files/Android/Android Studio/jbr/bin/javap.exe`.
- Codex (gpt-5.5 medium via `mcp__codex-cli__codex`) implemented; it drifted (build-time preBuild download → CI risk; dup INTERNET perm; shadowed catch var) — all corrected by Claude.

**Model summary:**
- Read full `Q and A.md`; Sri: "continue, I'll test the final version, go commit by commit."
- Confirmed B3 seam from `plans/P5-moonshine.md` + the merged `on_device_moonshine_socket.dart` Dart contract.
- Web-verified `ai.moonshine:moonshine-voice` real on Maven (0.0.65); fetched README + Android example via ctx tools.
- Found official example uses `MicTranscriber` (wrong for us) → chose plain `Transcriber` manual-feed.
- Delegated B3 Kotlin to Codex with a drift-proof brief; Codex implemented.
- Reviewed Codex output; decompiled the AAR to verify every symbol against real 0.0.65.
- Discovered AAR minSdk=35 + arm64-only — the decision-critical blocker.
- Corrected provisioning (runtime download), removed CI-breaking gradle task, cleaned dup perm + shadowed var.
- Committed `a9c253c43`; updated Q&A at END; beeped Sri; saved memory `mem_20260705_omi-moonshine-on-device_2f1376`.

**Handoff context (actionable):**
- `git -C C:/Android_software/omi log --oneline -3` → top should be `a9c253c43`.
- Branch `feature/local-first`; do NOT switch branches; do NOT push/merge to main without explicit go.
- To compile-verify B3: push branch → CI runs `flutter build apk` (`compileDevDebugKotlin`). ONLY after Sri says push.
- If Sri's phone <15: swap engine to sherpa-onnx; keep the `com.omi/moonshine_stt` channel + Dart socket unchanged, replace the Kotlin `Transcriber` internals.
- Dart socket contract (do not edit): `app/lib/services/sockets/on_device_moonshine_socket.dart` — `initialize{model,language,sampleRate}`→bool, `appendPcm16{pcm16:ByteArray LE PCM16}`, `stop`; native→Dart `onTranscript{text,start,end}`/`onError`/`onClosed`.
- Model download files: adapter.ort, cross_kv.ort, decoder_kv.ort, decoder_kv_with_attention.ort, encoder.ort, frontend.ort, streaming_config.json, tokenizer.bin.
- Codex rules: model `gpt-5.5`, reasoning medium (NOT xhigh), ONE job at a time (sqlite clash on parallel).
- Sri is away — beep milestones/decisions via PushNotification; announce Codex delegation visibly.
- Write to Sri only at the END of `Q and A.md` (hard rule).
- Commit-by-commit; Sri tests final APK and reports issues to fix "back again."

---

## 2026-07-06 23:41 IST — B5 + greying shipped; GREYING BUILD FAILED (troubleshoot next); Groq presets codex job running

### Current task state
- `feature/local-first` HEAD `5f9bb36e8`, all pushed. Commits this session: `aa42b53` (Moonshine proguard fix), `3e55ce2` (B5 local transcript persistence), `70b89ec` (docs), `5f9bb36` (greying Chat+Memories for guests).
- Builds: `28807197810` GREEN (Moonshine fix), `28810326937` GREEN (Moonshine+B5 — **Sri's test APK, beeped**), **`28812646384` FAILED (greying commit `5f9bb36` — TROUBLESHOOT FIRST, Sri flagged it in Q&A)**.
- Codex exec job RUNNING in background (task `bua1nz2x0`, output `C:\Users\DELETA~1\AppData\Local\Temp\claude\C--Android-software-omi\18e8858b-a314-417a-80c8-ecf5ac7b60d3\tasks\bua1nz2x0.output`): Groq whisper presets in worktree `C:/Android_software/omi-groq-presets`, branch `feature/groq-whisper-presets` (off origin/main, cherry-pickable). Spec: scratchpad `groq-spec.md`. Investigate-first; do-not-commit; review+commit is orchestrator's job.

### Key decisions
- Phase B merge to main HELD until Sri device-confirms Moonshine on `28810326937`.
- Greying scope corrected: only Chat+Memories grey for guests; **Conversations stays enabled** (hosts B5 local transcripts).
- Reviewer findings triaged: B5 got atomic sidecar write; greying got 3 guards (post-build redirect in memories initState, mounted checks). Deliberate: guest-era transcripts stay visible after sign-in.
- Codex MCP tool drops prompts → use `codex exec --model gpt-5.5 --full-auto -C <dir> "$(cat spec.md)"` via Bash (memory `mem_20260706_codex-cli-tooling-bug-20_39c0da`).

### Modified files (all committed)
- `app/android/app/proguard-rules.pro` (+moonshine keep rules)
- B5: `app/lib/{models/local_recording.dart, providers/local_recordings_provider.dart, services/capture/capture_controller.dart, pages/conversations/*}` + `app/test/providers/local_recordings_provider_test.dart`
- Greying: `app/lib/{providers/home_provider.dart, pages/home/{page.dart,home_content.dart,guest_cloud_only_guard.dart(new)}, pages/chat/page.dart, pages/memories/page.dart}` + `app/test/providers/home_provider_guest_access_test.dart`

### Blockers / open questions
- **Greying build `28812646384` failed** — get log: `gh run view 28812646384 -R sriharshaguthikonda/omi --log-failed | grep -iE "error" | head -30`. Likely Dart compile error in `5f9bb36` (page.dart/home_content.dart churn or missing import in guards). Fix → commit → push → new build.
- Sri device test of `28810326937` pending (Moonshine + transcript-row) — Phase-B merge gate.
- Q13 (Sri's Kaggle ONNX models) still open.

### Next steps
1. Troubleshoot greying build failure (above command), fix, commit, push, watch build.
2. When codex Groq job finishes: review diff in `C:/Android_software/omi-groq-presets` (cavecrew-reviewer), fix findings, commit on `feature/groq-whisper-presets`, push.
3. On Sri's Moonshine-green report: merge Phase B (`feature/local-first`→main, regular merge, self-merge authorized) → apk-latest refresh → beep Sri.
4. If Sri reports transcript-row missing (B5): debug via adb logcat (`$LOCALAPPDATA/Android/Sdk/platform-tools/adb.exe`, phone I2220 Android 16, works).

### Critical context
- adb: `"$LOCALAPPDATA/Android/Sdk/platform-tools/adb.exe"`; app package `com.friend.ios.dev`; logcat grep tags: `MoonshineSttPlugin`, `flutter`.
- No local Flutter/dart on this box — compile verification = CI APK build on push (`.github/workflows/android_apk_build.yml`, fork `sriharshaguthikonda/omi`).
- Sri directives: don't stop, commit-after-commit; beep MULTIPLE times (mobile push inactive — desktop only); compact sooner; answer inline in `Q and A.md` (write only at END).
- Review loop pattern: codex exec implements (no commit) → cavecrew-reviewer diff pass → Claude triages (reject non-issues with reasons) → minimal guards → commit.

### Model summary
- Session resumed after crash; B4 build was green, Sri had installed it and reported local STT broken + no transcripts in messages tab.
- Codex investigation + live adb logcat pinned Moonshine crash: R8 minification broke JNI field lookup (`TranscriberOption.name`); fixed with proguard keep rules (`aa42b53`), build green, Sri beeped.
- Sri's "connection failed primary/secondary" logs were a red herring (old whisper + Play-services noise).
- Q5 confirmed architectural: transcripts were memory-only; B5 (codex-implemented, reviewed, hardened with atomic writes) persists guest sessions as JSON sidecars shown in Conversations tab (`3e55ce2`); build `28810326937` GREEN = Sri's combined test APK.
- Greying shipped (`5f9bb36`): Chat+Memories greyed for guests with sign-in hint, deep links clamp to Conversations; 3 review guards applied; **its build failed — first thing to fix**.
- Groq whisper presets (Sri Q4): codex exec running in worktree `omi-groq-presets` on branch off main for cherry-pickability; BYOK presets over existing custom-STT path.
- Codex MCP tool unreliable (drops prompts) — direct `codex exec` CLI is the working path; ONE codex job at a time.
- Phase-B merge to main gated on Sri's device confirmation of Moonshine.

### Handoff context
1. Fix greying build: `gh run view 28812646384 -R sriharshaguthikonda/omi --log-failed | grep -iE "error" | head -30`; edit offending file(s) on `feature/local-first`; commit `fix(local-first): ...`; push; `gh run list ... --limit 1` → `gh run watch <id> --exit-status` in background.
2. Answer Sri item 3 in `Q and A.md` (END of file): acknowledge failure + fix status.
3. Check codex Groq result: `Read C:\Users\DELETA~1\...\tasks\bua1nz2x0.output` (tail). If PHASE-1-stop (no custom STT on main), re-target: implement presets on `feature/local-first` instead; tell Sri cherry-pick direction reverses.
4. Review Groq diff with caveman:cavecrew-reviewer agent (same prompt pattern as B5/greying reviews) before committing in the worktree.
5. Push Groq branch only after review+fix; it triggers its own APK build (app/** paths).
6. Merge Phase B ONLY on Sri's green Moonshine report (regular merge, no squash; self-merge authorized memory `mem_20260706_omi-project-2026-07-06-s_d81437`).
7. After merge: apk-latest refreshes from main push; beep Sri ×2+.
8. Whisper-local STT stays deprioritized (ROADMAP backlog).
9. Memory rows this session: `mem_20260706_omi-android-bug-fix-2026_85c0e5` (R8/JNI lesson), `mem_20260706_codex-cli-tooling-bug-20_39c0da` (codex MCP workaround).
10. Worktree cleanup later: `git worktree remove ../omi-groq-presets` after branch merged/pushed.
11. Sri's phone: I2220, Android 16, adb-visible; package `com.friend.ios.dev`.
12. All Q&A writes go at the very END of `Q and A.md`; the qa-nudge hook echoes user edits automatically.

---

## 2026-07-07 ~00:30 IST — delta since 23:41 entry (pre-compaction snapshot)

### State
- `feature/local-first` HEAD `a03459e71`, all pushed. New commits: `38de888` (paren fix in home_content.dart — greying build failure root-caused: extra `)` at :537 broke build_runner), `7cc35ce`/`dd181e5`/`a03459e` (Q&A docs), `06e53f5` (handoff).
- **Builds: greying-fix `28813351259` GREEN** → best all-features test APK (Moonshine fix + B5 transcripts + greying). Sri beeped ×2, 3-step test list at END of `Q and A.md`. Supersedes `28810326937`.
- **Groq presets SHIPPED `b96fe9d`** on branch `feature/groq-whisper-presets` (worktree `C:/Android_software/omi-groq-presets`, off origin/main, cherry-pickable). +45-line diff reviewed clean (presets over existing SttProviderConfig pattern in `app/lib/models/stt_provider.dart`; main already had custom-STT plumbing). Build `28813777139` — watcher `b1qa27ja8` RUNNING, check on wake: green ⇒ tell Sri; red ⇒ `gh run view 28813777139 -R sriharshaguthikonda/omi --log-failed`.

### Workflow now standard (Sri item 3, answered)
- Every push → background `gh run watch <id> --exit-status` → wake → green: proceed/beep; red: `--log-failed` → root-cause → fix → re-push.
- Before push of codex-touched Dart: `python <scratchpad>/balance.py <files>` (bracket balance; scratchpad = `C:\Users\DELETA~1\AppData\Local\Temp\claude\C--Android-software-omi\18e8858b-a314-417a-80c8-ecf5ac7b60d3\scratchpad`).

### Next (in order)
1. Groq build watcher result (`b1qa27ja8`) — handle green/red as above.
2. Sri's 3-part device report on `28813351259` (Moonshine live transcript / transcript row in Conversations / greyed Chat+Memories) → gates Phase B merge: `feature/local-first`→main, REGULAR merge (no squash), self-merge authorized → apk-latest refreshes → beep ×2.
3. If Sri reports B5 row missing: adb logcat (`"$LOCALAPPDATA/Android/Sdk/platform-tools/adb.exe"`, package `com.friend.ios.dev`) around capture stop; sidecar files land next to batch audio dir (`local_transcript_<start>.json`).
4. After Phase B merge: cherry-pick direction for groq branch is INTO feature/local-first or main per Sri; ROADMAP next items in handoff 23:41 section.
5. Beeps: PushNotification ×2 minimum (mobile push inactive — desktop only). All Sri messages at END of `Q and A.md` only.

---

## 2026-07-07 ~01:15 IST — ALL GREEN, PR #6 staged; sole blocker = Sri device report

- `feature/local-first` HEAD `9813c538f`, pushed. New since last entry: `e36d340` (groq cherry-pick, clean), Q&A docs (`bee03a1`, `9813c53`).
- **Definitive test APK: run `28815045799` GREEN** (Moonshine fix + B5 transcripts + greying + Groq presets). Sri beeped ×2; 3-step test list at END of `Q and A.md`.
- **PR #6 open, merge HELD**: <https://github.com/sriharshaguthikonda/omi/pull/6> — on Sri's green 3-part report: `gh pr merge 6 -R sriharshaguthikonda/omi --merge` (regular, NO squash) → main build refreshes apk-latest → beep ×2. On red report: adb logcat (`"$LOCALAPPDATA/Android/Sdk/platform-tools/adb.exe"`, pkg `com.friend.ios.dev`), root-cause, fix, re-push.
- Groq branch `feature/groq-whisper-presets` (`b96fe9d`) green standalone — leave for upstream-style cherry-picks; worktree `C:/Android_software/omi-groq-presets` removable after.
- No watchers running. Nothing unblocked. Next session: read END of `Q and A.md` first for Sri's report.

---

## 2026-07-07 ~04:05 IST — Sri's 7-item report processed; STT id-collapse ROOT-CAUSED + FIXED; new build watching

### Current task state
- Sri device-tested APK `28815045799` (confirmed via adb: v1.0.542, installed 01:24 IST, device `I2220` connected, adb at `"$LOCALAPPDATA/Android/Sdk/platform-tools/adb.exe"`).
- His report (Q&A lines ~542-553): Moonshine partially works but transcript "only holds last word"; Groq "same issue" + bombarding API; lint workflow red; whisper broken (expected); merge question.
- All root-caused and fixed; pushed to `feature/local-first` (PR #6 auto-includes). HEAD `e67aa79`; fix `65f176c`, format `d45c581`.
- **Watchers RUNNING** (task `bgd3ri0vm`): Lint `28827307627` + APK `28827306060` on `d45c581`. NOTE: watcher started before `e67aa79` (docs-only push) — a THIRD run pair on `e67aa79` will exist; check `gh run list --branch feature/local-first` on wake.
- Codex independent review of fix commits: **CLEAN** (static; local test run impossible — no flutter on box).

### Key decisions
- Root cause (bug 7 + 6a): locally-produced STT segments carried no `id` → `TranscriptSegment.fromJson` defaults `''` → `updateSegments` (transcript_segment.dart:104, consumed capture_controller.dart:2148) replaces-by-id → whole transcript collapsed into one overwritten segment. Fixed at producers (NOT in fromJson — avoids blast radius on live cloud providers that emit interims relying on current semantics).
- Moonshine: stable per-line id (`moonshine_<nonce>_<lineIndex>`), native `isFinal` bumps index → partials update in place, finals stick, next line appends. Regression test added (partials-share-id test in on_device_moonshine_socket_test.dart).
- Polling (Groq/OpenAI/local whisper): unique id per segment (`poll_<nonce>_<seq>`); provider failure (null/throw) now RE-QUEUES audio frames (cap 4MB ≈ 2min) instead of silent drop; cloud batch cadence 5s→10s (Groq rate limits).
- Lint red root cause: 3 unformatted files; CI formats SHORT-style (pubspec lower bound 3.0). **Gotcha: local dart 3.12 format MUST use `--language-version=3.0 --line-length 120`** or it tall-style-corrupts clean files (burned once, reverted). Dart SDK lives in session scratchpad `dart-sdk/` (re-download per session: dart-archive stable zip).
- B4b guest consent gate: deliberately SKIPPED (personal fork, single user, engine setup = owner's explicit act). Ponytail note amended in mobile_app.dart:40 — **uncommitted** as of this entry.
- On-device whisper failure = expected/known (ROADMAP low-prio, Moonshine replaces). Cloud whisper presets silently had the same collapse bug — healed by same fix.

### Modified files (committed)
- `app/lib/services/sockets/on_device_moonshine_socket.dart` (ids + isFinal)
- `app/lib/services/sockets/pure_polling.dart` (ids + requeue + cap)
- `app/lib/services/sockets/transcription_service.dart` (10s cadence)
- `app/test/unit/on_device_moonshine_socket_test.dart` (id assertions + new regression test)
- `app/lib/pages/settings/transcription_settings_page.dart`, `app/lib/providers/local_recordings_provider.dart` (format only)
- `Q and A.md` (all 7 answers at END, `e67aa79`)
- UNCOMMITTED: `app/lib/mobile/mobile_app.dart` (comment-only note amendment)

### Blockers / open questions
- Sole gate: Sri's re-test on the NEW green APK (Moonshine transcript must now ACCUMULATE; plus transcript row + greying checks).
- Watcher results pending (lint + APK on `d45c581`/`e67aa79`).

### Next steps
1. On watcher wake: green → beep Sri ×2 with new run URL appended at END of `Q and A.md`; red → `gh run view <id> --log-failed`, root-cause, fix, re-push.
2. Commit `mobile_app.dart` note (ride along with next functional commit or solo before merge).
3. Sri green report → `gh pr merge 6 -R sriharshaguthikonda/omi --merge` (regular, NO squash) → main build refreshes apk-latest → beep ×2.
4. Sri red report → adb logcat live repro (`adb logcat -c` then capture during test; app NOT debuggable, no run-as; in-app Settings→debug-logs export is the fallback).
5. After merge: roadmap essentially drained — dev-theme is last; whisper debug low-prio/superseded.

### Critical context
- Memory saved: `mem_20260706_omi-bug-fix-lesson-2026_8f30b6` (id-collapse pattern + dart format gotcha). Autonomy: full push/self-merge per `mem_20260706_omi-project-2026-07-06-s_d81437` (regular merge, fork main only, NEVER upstream).
- RULE going forward: any new STT producer emitting segment JSON MUST set unique (or deliberately stable per-line) `id`.
- B5 sidecar reload is display-only (no updateSegments) — fix flows through; persisted transcripts now accumulate correctly.
- Codex charmap: memory MCP rejects `→` unicode — use ASCII in remember() content.
- Q&A protocol: answers ONLY at END of `Q and A.md`; beep = PushNotification ×2 (mobile push inactive, desktop only).

### Model summary
- Sri reported 7 items after device-testing definitive APK; all addressed in one session.
- Diagnosed transcript collapse statically: empty-id replace-by-id merge, confirmed at exact consumption line.
- Fix at producers only; live cloud provider semantics untouched.
- Groq additionally suffered silent audio drop on failed requests (non-200 → null → frames already cleared) — now re-queued with cap.
- Cadence halved request rate to respect Groq free-tier limits.
- Lint fixed; discovered + survived dart formatter version/style trap; SDK now local.
- Codex second-opinion review: CLEAN.
- Q&A answered at end of file, Sri beeped ×2, memory + handoff updated.
- Merge of PR #6 still gated on Sri's retest of the new build.
- B4b consent gate consciously deferred with in-code rationale.

### Handoff context (actionable)
- `cd C:/Android_software/omi` — branch `feature/local-first`, HEAD `e67aa79` pushed; only `app/lib/mobile/mobile_app.dart` dirty (comment).
- Check runs: `gh run list --repo sriharshaguthikonda/omi --branch feature/local-first --limit 6`.
- If APK green on latest commit: append pointer at END of `Q and A.md` (install link `https://github.com/sriharshaguthikonda/omi/actions/runs/<id>`), commit, push, beep ×2.
- Retest list for Sri: (1) Moonshine live transcript accumulates across sentences; (2) stop capture → transcript row in Conversations; (3) guest greying Chat+Memories. Groq: expect ~10s batch steps, needs his API key.
- Merge command staged: `gh pr merge 6 -R sriharshaguthikonda/omi --merge`.
- Dart format on this box: download stable SDK zip to scratchpad → `dart format --line-length 120 --language-version=3.0 <files>` (NEVER bare — style trap).
- adb: `"$LOCALAPPDATA/Android/Sdk/platform-tools/adb.exe"`; device `10BF191Z51001DC` (I2220); package `com.friend.ios.dev` (not debuggable).
- Codex invocation that works here: `codex exec --sandbox read-only -C C:/Android_software/omi "<prompt>"` (one job at a time).

### Delta ~04:20 IST — P2 kicked off, definitive build watching
- Lint GREEN on `d45c581` + `e67aa79`; APK on `d45c581` CANCELLED (concurrency-superseded). **Definitive pair on `24fe8e8`: APK `28827747244` + Lint `28827749076`, in progress, watcher armed** → green ⇒ beep Sri ×2 + install link at END of Q&A; his Moonshine-accumulates retest gates PR #6 merge.
- **P2 Triggers v1 STARTED** (Sri: don't stop, commit-by-commit, codex lifts). D2 resolved by Sri's ROADMAP checkbox: all trigger types, big-red-button redesign deferred. Codex running P2.1 (trigger_router.dart seam + flutter_foreground_task notification start/stop buttons, 2 commits, NO push) in worktree `C:/Android_software/omi-p2-triggers`, branch `feature/p2-triggers` off feature/local-first. On completion: review diff, format-check, push branch, watch CI, then queue P2.2 QS tile and P2.3 Tasker intent receiver as next codex jobs.
- Q&A latest answer committed `3729372` (root file — does not trigger app CI, so `24fe8e8` pair stays definitive).

### Delta ~05:00 IST — Sri retest report (11 items) + codex bug job running
- **APK `28827747244` GREEN, Sri installed + retested: Moonshine ACCUMULATION VERIFIED on device (item 1 ✅).** STT id fix confirmed working.
- **Codex P2.1 NO-OPED** — long inline prompt arg fell back to "Reading additional input from stdin", zero commits in `C:/Android_software/omi-p2-triggers`. Lesson: pass long codex prompts via short pointer to a spec FILE. P2.1 re-dispatch PENDING (queued behind bug job; one codex at a time).
- **Codex bug job RUNNING (task `b5wg9k2gn`)** in main worktree, branch feature/local-first, spec at scratchpad `codex-bugjob-spec.md`: Bug1 = record/stop sessions collapse to one transcript (root cause: `_sessionStartSeconds` not rotated + `_lastPersistedLocalTranscriptSessionStart` guard, capture_controller.dart:950; sidecar filename keyed on session start) + Process-now shouldn't be required + report why button provider-dependent. Bug2 = Groq pathway static audit + add failure surfacing (3 consecutive fails → onError).
- Sri's other items triaged in Q&A answer (commit pending): 2/3 Moonshine line-duration knob = backlog; 4 settings-search UX = backlog; 6 whisper = known-broken/won't-fix; 8 permissions re-prompt+not-retained = NEXT job after bug job; 10 on-device multimodal model = roadmap/D6 extension, needs Q13 Kaggle link.
- **PR #6 merge now held on bug 7+9 fixes + Sri re-retest** (B5/Groq scope bugs).
- On codex bug-job wake: review diff, format-check (dart 3.12 `--language-version=3.0 --line-length 120`), push, watch CI, beep Sri with new APK; then re-dispatch P2.1 (spec-file pattern) in omi-p2-triggers worktree.

### Delta ~05:40 IST — bug fixes SHIPPED + pushed; P2.1 re-running; watchers armed
- **Codex bug job DONE, reviewed+approved+pushed**: `c431110` (guest record/stop cycles each persist own sidecar row — `_nextSessionStartSeconds()` monotonic guest ids + `_finishGuestLocalTranscriptSession()` persists+clears state on both stop paths; signed-in flow untouched) and `b6fa27a` (PurePollingSocket counts consecutive failures, emits onError after 3 → existing error UI; resets on success). Head `e9df568` (Q&A status).
- Codex audit findings: Groq request path statically CORRECT (key→Bearer header→polling route→openAI verbose_json parse matches Groq docs) → Sri's Groq failure is runtime-side; next APK's surfaced error text identifies it. Process-now button NOT provider-gated — shows only when segments non-empty.
- **Watcher `bkcn6thtc`**: APK `28839830362`/`28839829162` pair on `b6fa27a` (Q&A push e9df568 is root-only, does NOT cancel it). Green ⇒ beep ×2 + pointer at END of Q&A: retest = (1) two record/stop cycles → two rows, no Process-now; (2) Groq → either transcript or visible error text (report exact text); (3) Moonshine still accumulates. Sri green ⇒ `gh pr merge 6 -R sriharshaguthikonda/omi --merge`.
- **Codex P2.1 re-running (task `bqr665nrg`)** in `C:/Android_software/omi-p2-triggers` via spec file `codex-p2-spec.md` (scratchpad). On wake: review 2 commits (router + notification buttons), format-verify, push branch → CI. Next codex job after: Sri item 8 (permissions ask-once + Settings review panel; guest-boot `_PermissionsGate` in mobile_app.dart).
- Codex prompt lesson CONFIRMED: long inline prompt arg → stdin fallback no-op. Always short pointer prompt + spec file.
- Pre-commit hook prints `xargs: dart: No such file or directory` — non-fatal, hook can't format (no dart on PATH); we format manually with scratchpad SDK.
- Backlog registered in Q&A: Moonshine line-duration knob (items 2/3), settings-search UX (4), on-device multimodal model (10 → D6/Q13).
