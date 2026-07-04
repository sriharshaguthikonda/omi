# Q and A — async channel (Sri ⇄ Claude)

Protocol: either side appends. Questions get numbered `Q<n>`. Answers go directly under. Decisions that belong in the roadmap get a pointer to their `D<n>` box in [ROADMAP.md](./ROADMAP.md) instead of being re-argued here. Claude re-reads this file at the start of every session and before finishing long tasks.

---







## Answered

**Q1 (Sri, pre-2026-07-04):** are repo maps serena being used or not...dont burn tokens>!!?

> **A:** Neither burns tokens passively. This repo has **no `.repo-intel/` manifest**, so repo-maps is inert here (its hooks fast-exit). Serena is a deferred MCP — it loads only when explicitly called. Neither was used for the roadmap work (plain file reads were enough). Serena becomes worth invoking at P2/P3 when we edit Kotlin/Dart symbols across files. No action needed to "turn them off".

**Q2 (Sri, pre-2026-07-04):** use codec cli? agents first

> **A:** Yes — standing arrangement: **Codex CLI does the implementation weightlifting, Claude orchestrates and corrects.** Applied from this session onward (Codex drafted the APK workflow; Claude verified it against the repo facts and fixed drift). Exploration goes to cheap subagents first so the main session stays lean.

**Q8 (Sri, 2026-07-04 live):** use codex cli *agents* as well — not just for implementation.

> **A:** Acknowledged + saved to memory as a standing rule. Split from now on: **Codex = implementation AND review/second-opinion passes** (it reviews ROADMAP.md and its own workflow before commit); Claude subagents only where Codex lacks the private conversation context. Each delegation gets announced so it's visible who's lifting.

---






## Open — needs Sri

**Q13 (Claude → Sri, 2026-07-04):** you wrote in D5 "i am training models elsewhere — link that." Drop the link/repo/notes here and I'll wire it into the ROADMAP (D6 ASR + the `AsrEngine` interface) so your trained model is a first-class drop-in candidate alongside Moonshine/sherpa. What is it — a fine-tuned ASR, a VAD, a wake-word, something else? What framework/output format (ONNX? TFLite?)?

**Q12 (Sri, 2026-07-04):** post deep-research areas here; I'll run them through ChatGPT Deep Research. Link a file describing what to research.

> **A:** Done — [docs/research/](./docs/research/README.md) has 6 self-contained, public-safe topic files (paste each whole file as the ChatGPT prompt). Ordered by priority: **R4** (Android 14/15 background-mic constraints — could reshape the trigger design, do first), **R3** (BT media-button reality — flagship P3 feasibility), **R1** (on-device ASR engine), R2 (VAD), R5 (offline sync transport), R6 (self-host backend footprint). Each maps to an open ROADMAP decision (D5/D6/D7/D8) or a phase feasibility question. Bring findings back as a `## Findings` section in the file or a share-link + TL;DR here; I fold accepted answers into the matching decision box.

**Checklist (2026-07-04) — do these while Claude/Codex implement P1:**

1. **Sign-in failure details** (unblocks P1 verification): exact error text or screenshot; which button you tapped (Google / Apple / anything browser-based); where that APK came from (upstream releases page, or the CI artifact zip from run 28690006580?).
2. **Install the new APK when notified** — after P1 merges, the first real build lands at <https://github.com/sriharshaguthikonda/omi/releases/tag/apk-latest>. You'll get a push notification. The sign-in screen footer will show a **build stamp** (version+run+sha) — no stamp = old APK.
3. **Open decision boxes in [ROADMAP.md](./ROADMAP.md)** — answer inline (🔵 line) or drop notes in scratch below: D0b APK shape, D2 trigger scope, D3 BT mechanism order, D5 VAD, D6 ASR engine, D7 sovereignty shape, D8 .memory transport. None block P1; **D2/D3 block P2/P3 execution start** (plans are written: [plans/](./plans/README.md)).
4. **After install:** try sign-in, report stamp text + what happens, per item 1 format.

---

## Answered (2026-07-04, live session)

**Q3:** Enable GitHub Actions on the fork (Actions tab).

Sri: done ! i don't know if you could have done it using gh with authorization.

> **A:** Enabled ✅. And no — the "enable workflows on this fork" button has no public API/gh equivalent; it's a one-time human click by design. Everything after it (dispatch, watch, download) I can drive via `gh`.

**Q4:** OK to push branch `feature/phase0-ci-roadmap`?

Sri: do it, don't ask unnecessary questions

> **A:** Pushed. Standing rule tightened: pushes to feature branches don't need asking; only `main`-touching actions do (repo rule keeps that one).

**Q5:** Which BT devices/buttons should the P3 wizard target?

Sri: we /app should have to decide that at runtime — multiple devices can be used to trigger it; which device, which button, long/single/double press — all decided in the application. how can i tell you now?

> **A:** Agreed, and that's exactly what P3 already specifies — question was redundant, my miss. Locked into ROADMAP P3: **fully runtime-defined mapping** (learn-mode wizard captures whatever device+button+press-pattern you perform, nothing hardcoded). This also effectively answers D4: the ambiguity machinery ships, because we can't assume anything about future devices. Marked in ROADMAP.

**Q6:** Sovereignty deadline?

Sri: if firebase is free for everyone, i will try to research on it a little bit, but if it is not, then we will have to migrate sooner.

> **A:** Fact for your research: Firebase **Spark plan is free** (no card): Auth ~50k monthly active users, Firestore/storage quotas far above personal-capture scale. An own Firebase project costs ₹0 for this use case — the real cost of sovereignty is self-hosting the omi backend (compute) or the P7 local-only surgery, not Firebase. So: no forced early migration on cost grounds; D7 timing stays a choice, not a bill.

**Q7:** Where did the failed APK come from?

Sri: from i think their github repo somewhere in releases i guess

> **A:** Matches the root-cause analysis (upstream release APK = their Firebase/signing, sideloaded without env-baked web-auth). Logged for the P1 write-up; no further action.

**Q9 (Sri, 2026-07-04):** what code changes did you make to test the app? none? / the built version is no different from the old version because there are no code changes done in the actual app.

> **A:** Correct — P0 changed **zero app code**. Only CI workflow + docs. The CI APK differs from upstream's release APK in *baked env only* (web-auth lane, `api.omiapi.com`, community keystore signature) — invisible in the UI, and absent entirely if the APK you installed was upstream's (Q7). **P1 fixes this now:** real app code changes — a visible build stamp (version + run number + git sha + auth-lane) on the sign-in screen and in About, plus sign-in error surfacing — so the next APK is provably ours and diagnosable. Codex is implementing; link lands in ROADMAP P0 when the build is live.

**Q11 (Sri, 2026-07-04):** sync fork failed solve it unless it comes in the way of our plan!

> **A:** Diagnosed: fork is 6 commits ahead, upstream 149 ahead, **zero content conflicts** (checked with `git merge-tree`). GitHub's Sync-fork button fails because upstream's new commits touch `.github/workflows/**` — the web button can't write workflow files on forks. My token can (proved in P0). **Plan: land P1 first** (Codex is mid-edit in the same auth files upstream also changed — syncing now would force a rebase mess), **then immediately sync** via local `git merge upstream/main` → PR → self-merge. Direction is upstream→fork only (Q10 rule intact). ETA: right after the P1 merge, same session.

**Q10 (Sri, 2026-07-04):** hopefully you are not merging with the upstream!!!

> **A:** Never. All PRs/merges stay **inside the fork** `sriharshaguthikonda/omi` (origin). Upstream `BasedHardware/omi` is a read-only donor — no pushes, no PRs to it, ever. The ROADMAP "upstream sync" bullet means *pulling* their code into our fork on our schedule, and even that only when you say so.

---

## Log

- 2026-07-04 — file adopted into the repo (was untracked); Q1/Q2 answered; Q3–Q7 opened. Decisions D0a, D1, repo-privacy timing closed in ROADMAP.md the same day.
- 2026-07-04 — first CI APK build **green** on `feature/phase0-ci-roadmap` (run 28690006580, ~18 min, 86 MB dev APK artifact). Codex drafted the workflow, Claude corrected 4 gaps (CM_* gradle landmine, Flutter 3.41.9 pin, run_number versionCode, stable release asset name), Codex review pass added the tag-move fix. Next: Sri merges the PR whenever ready → `apk-latest` prerelease appears → install + P1 sign-in test.


## user comments (Sri's scratch space — drop raw notes here, Claude folds them into Q&A above)

(1–3 executed: Codex orchestration live, phase0 merged, APK link posted when built. 4 → Q9, 5 → Q10 above. "merge yourself" → standing rule: Claude opens + merges fork PRs autonomously, regular merge, fork main only. Sync-fork → Q11. "codex cli as worker, you orchestrate" → confirmed model, applied: Codex writes P1 code, Claude reviews/corrects (caught + reverted a redundant manifest filter Codex added) + Codex review pass before merge.)



(deep-research request → Q12 above; topics live in docs/research/, ordered R4→R3→R1→R2→R5→R6.)