# R6 — Self-hosting the open-source Omi backend: cost + effort footprint

**Priority: LOW** (P7 is a later phase), but scoping now informs the D7 sovereignty decision.

## Context (for the researcher)

There's an open-source backend for the Omi ecosystem (public MIT repo, `backend/` — Python/FastAPI, uses Firestore, Redis, GCS, plus STT/LLM integrations). Currently my fork's app talks to the community-hosted backend. Eventually I may want sovereignty: run my own backend (or strip to local-only). I need a realistic footprint estimate before committing.

This is about the **public open-source project's** infrastructure shape — no private data involved.

## Questions to answer (from the public repo's docs/Helm charts + general GCP/self-host knowledge)

1. **Dependency footprint**: what external services does the backend actually require to run a single-user instance (Firestore/Redis/GCS/Deepgram/LLM keys)? Which are swappable for local/free equivalents (e.g. Redis local, MinIO for GCS, SQLite/Postgres for Firestore-like)?
2. **Minimal viable deploy**: cheapest way to run it for one user — single VM + docker-compose vs the provided Kubernetes/Helm charts. Rough monthly cost on a small cloud VM, and whether a home server / mini-PC suffices.
3. **The hard dependencies**: is Firestore deeply assumed (hard to swap) or is the data layer abstracted? Same question for GCS blob storage and Cloud Tasks.
4. **STT/LLM cost**: which paid APIs are on the critical path, and can they be pointed at local models (the roadmap already plans on-device ASR) or free/self-hosted LLMs?
5. **Effort estimate**: realistically, days of work to stand up a working single-user self-hosted instance, and the top 3 friction points reported by others who've tried.
6. **Local-only alternative**: how much of the app's value survives if we strip the backend entirely and the phone only syncs to a local database (no conversations/summaries server-side)? What breaks?

## Desired deliverable

- A **dependency table**: service → required? → local/free substitute → effort to swap.
- Two costed **deploy recipes**: (a) minimal self-host VM, (b) local-only strip — with rough $/month and setup days.
- A **recommendation** for D7's three options (own Firebase+self-host backend / local-only strip / hybrid), with the tradeoffs made concrete.

## Why it matters

Closes D7 (sovereignty shape) with real numbers instead of vibes, and tells us whether P7 is a weekend or a month. Also confirms the free-Firebase point (Spark plan) already noted for the auth layer separately.
