# Session Handoff Log

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
