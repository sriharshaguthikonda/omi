# R1 — On-device streaming ASR engine shootout for Android

**Priority: HIGH.** Closes D6 (P5). The biggest capability unknown in the roadmap.

## Context (for the researcher)

Personal Android app that transcribes captured speech **on-device** (no cloud), ideally streaming (live partial transcripts), low battery, decent accuracy for conversational English (multilingual a bonus). Cloud STT exists as fallback; goal is a good offline live path. Phone is a modern mid-to-high-end Android.

## Candidates to compare

- **Moonshine** (Useful Sensors) — Android/Maven artifact, streaming-oriented.
- **sherpa-onnx** — Apache-2.0 toolkit (VAD + KWS + ASR + wake word), many models, Android demos.
- **whisper.cpp** — for **batch** re-transcription of saved low-confidence clips, not the live path.
- Any newer 2025-era on-device streaming option worth adding (e.g. NVIDIA Parakeet ports, Kyutai, other ONNX streaming models).

## Questions to answer (official docs, benchmarks, real Android reports)

1. **Streaming latency** on real Android hardware: first-partial latency and steady-state lag for each engine/model. Cite measured numbers, not marketing.
2. **Accuracy (WER)** for conversational English on realistic (noisy, far-mic) audio; note multilingual quality where relevant.
3. **Battery + thermal**: mWh or %/hour for continuous transcription; CPU vs NNAPI/GPU delegate support on Android.
4. **Model size + RAM footprint** per engine/model tier (tiny/base/small).
5. **Integration effort on Android**: Maven/Gradle availability, native lib size, API ergonomics, streaming API vs chunked.
6. **Licensing** — critical: for each engine **and each model**, the license. Specifically Moonshine's English (MIT?) vs multilingual (community/non-commercial?) split, and sherpa-onnx model licenses. Which are safe for (a) personal use, (b) a possible future public/free app, (c) never-commercial?
7. **Wake-word / KWS**: does any candidate also give an on-device wake-word engine we could reuse for a voice trigger later?

## Desired deliverable

- A **comparison table**: engine × model × {latency, WER, battery, size, Android integration effort, license (code / model)}.
- A **recommendation** for the live path + a hedge, with reasoning, framed as "pick X now, keep Y swappable behind an interface."
- Minimal **Android integration snippets** or links to the official Android sample for the top pick.
- Note any 2025 release that beats all three.

## Why it matters

Closes D6 and sizes P5. Also informs D5 (VAD) if an engine bundles VAD (see R2). We build the ASR behind an `AsrEngine` interface so the loser stays swappable, but we want the right default.
