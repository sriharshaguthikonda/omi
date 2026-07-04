# Deep-research requests — Omi phone-capture fork

Sri runs these through ChatGPT Deep Research and drops findings back. Each `R<n>-*.md` is **self-contained and public-safe** — paste the whole file as the prompt. They cover the open decisions the existing [phone-capture-deep-research-report.md](../../phone-capture-deep-research-report.md) did **not** settle.

**Privacy rule:** these files contain only general Android / ASR / BT / self-hosting questions. No private repo internals, secrets, personal data, or `.memory` contents. Safe to paste into any external tool.

| # | Topic | Unblocks | Priority |
|---|---|---|---|
| [R1](./R1-ondevice-asr-engine.md) | On-device streaming ASR engine shootout | D6 (P5) | high — biggest unknown |
| [R2](./R2-vad-engine.md) | VAD engine choice on Android | D5 (P4) | med |
| [R3](./R3-android-media-button-reality.md) | Media-button / MediaSession KeyEvent delivery + device attribution across OEMs | P3 flagship feasibility | **high — could reshape P3** |
| [R4](./R4-android-background-capture-constraints.md) | Android 14/15/16 foreground-service + background mic constraints | P2/P4 viability | **high — sleeper risk** |
| [R5](./R5-offline-sync-transport.md) | Offline-first phone→desktop sync transport | D8 (P8) | med |
| [R6](./R6-omi-backend-selfhost-footprint.md) | Self-hosting the open-source Omi backend: cost + effort | D7 (P7) | low (later phase) |

**How findings come back:** append a `## Findings (date)` section to the relevant `R<n>` file, or drop the ChatGPT share link + a 3-line TL;DR in [Q and A.md](../../Q%20and%20A.md). Claude folds accepted findings into the matching ROADMAP decision box.

**Answer priority if bandwidth is limited:** R4 first (a hard Android constraint could invalidate the trigger design before we build it), then R3 (flagship feasibility), then R1 (engine pick).
