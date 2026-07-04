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

(nothing right now)

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

---

## Log

- 2026-07-04 — file adopted into the repo (was untracked); Q1/Q2 answered; Q3–Q7 opened. Decisions D0a, D1, repo-privacy timing closed in ROADMAP.md the same day.
- 2026-07-04 — first CI APK build **green** on `feature/phase0-ci-roadmap` (run 28690006580, ~18 min, 86 MB dev APK artifact). Codex drafted the workflow, Claude corrected 4 gaps (CM_* gradle landmine, Flutter 3.41.9 pin, run_number versionCode, stable release asset name), Codex review pass added the tag-move fix. Next: Sri merges the PR whenever ready → `apk-latest` prerelease appears → install + P1 sign-in test.


## user comments (Sri's scratch space — drop raw notes here, Claude folds them into Q&A above)
