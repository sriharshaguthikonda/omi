# R5 — Offline-first phone→desktop sync transport for capture bundles

**Priority: MEDIUM.** Closes D8 (P8).

## Context (for the researcher)

Personal setup: an Android app produces capture "bundles" (JSON metadata + transcript text, occasionally small audio clips) that must land on a Windows desktop, where a local ingest script consumes them into a personal database. Requirements: offline-first (phone may be off Wi-Fi for hours), durable (never lose a bundle), battery-friendly, no third-party cloud if avoidable, minimal server surface, idempotent (retries must not duplicate).

## Options to evaluate

- **Syncthing** — folder sync phone↔desktop, P2P, open-source.
- **A local HTTP endpoint** on the desktop the phone POSTs to when on the same LAN (with a durable on-phone outbox + retry).
- **adb pull** on a schedule (desktop-initiated) — crude but zero phone-side network.
- **Cloud drive drop** (Google Drive/Dropbox folder) — simplest, but third-party.
- Any 2025 tool purpose-built for offline-first device→device file/event sync.

## Questions to answer

1. **Reliability + durability**: which options guarantee eventual delivery across app kills, phone reboots, network gaps? How does each handle partial/interrupted transfers?
2. **Battery + background constraints**: does the option survive Android background limits (ties to R4)? Syncthing's Android background behavior on modern Android specifically.
3. **Idempotency**: how to make ingest dedupe on stable bundle IDs regardless of transport retries.
4. **Setup + maintenance cost** for a single-user two-device setup (phone + one Windows PC).
5. **Security**: is data encrypted in transit and at rest for each; LAN-only vs internet exposure.
6. **Latency**: near-real-time vs batched — acceptable is "within minutes when on the same network, eventual otherwise."

## Desired deliverable

- A **comparison table**: transport × {durability, background-survival, idempotency support, setup cost, security, latency}.
- A **recommendation** (the report leans Syncthing/file-drop reusing an existing bulk-ingest lane) with the concrete phone-side outbox pattern (WorkManager + retry + stable IDs).
- Any gotcha with Syncthing on modern Android background restrictions.

## Why it matters

Closes D8, sizes P8 (`.memory` integration transport). We want zero new always-on server and offline-first durability; this confirms or replaces the file-drop default.
