# plans/ — per-phase execution plans

[ROADMAP.md](../ROADMAP.md) is the master index (vision, phase list, decision boxes). Each phase gets a plan file **here** when it enters the active window (current phase + next). Plans are execution-grade: exact files, interfaces, bite-sized tasks, verification commands.

| Plan | Phase | Status |
|---|---|---|
| [P1-signin.md](./P1-signin.md) | P1 — Sign-in → **local-first pivot (P1.2)** | 🔨 P1.2-A merged (apk-latest live) |
| [P2-triggers-v1.md](./P2-triggers-v1.md) | P2 — Triggers v1 (phone-only) | planned (gate: D2) |
| [P3-bt-trigger-matrix.md](./P3-bt-trigger-matrix.md) | P3 — BT multi-device trigger matrix ⭐ | planned (gates: D3 closed-by-default, see file) |
| [P5-moonshine.md](./P5-moonshine.md) | P5 / Phase B — on-device Moonshine STT (pulled fwd) | 📝 planned (B0 reuse-check done) |
| P4 | see ROADMAP task lists | plan file created when phase becomes next |

Current blocker report: [2026-07-05 community build auth investigation](../docs/investigations/2026-07-05-community-build-auth.md).

**Pivot (2026-07-05):** the community cloud lane is structurally closed (#5939 won't-fix). P1 re-scoped to **P1.2 = de-mandatory login + local-first**; Omi cloud becomes optional-in-settings, cloud features gated behind toggles, and **on-device Moonshine STT (P5) is pulled forward**. Work branch: `feature/local-first`. See ROADMAP P1.2 + [P1-signin.md](./P1-signin.md) P1.2 section.

Conventions:
- Checkbox steps (`- [ ]`) tick as work lands; plan updates commit with the code they describe.
- A plan with an open decision gate carries the 🟢 recommended option as its working assumption and says what changes if Sri picks differently.
- Execution split: **Codex CLI implements, Claude orchestrates/corrects** (standing rule, Q2/Q8).
