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
