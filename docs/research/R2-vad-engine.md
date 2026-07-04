# R2 — Voice Activity Detection (VAD) engine choice on Android

**Priority: MEDIUM.** Closes D5 (P4).

## Context (for the researcher)

Personal Android app with a rolling audio buffer. Need a VAD to (a) gate the mic in "armed" mode (open capture when speech starts, close on silence) and (b) segment continuous audio into speech chunks. Must be cheap (battery), fast (real-time on one CPU thread), and accurate enough to avoid clipping speech onsets.

## Candidates

- **Silero VAD** (ONNX) — the report's tentative default.
- **WebRTC VAD** — classic, tiny, fast, more false positives.
- **VAD bundled inside an ASR toolkit** (e.g. sherpa-onnx's VAD, or a Moonshine-integrated pipeline) — couples to the R1/D6 choice.

## Questions to answer (docs, benchmarks, Android reports)

1. **Accuracy**: false-accept / false-reject and speech-onset clipping for each, on noisy real-world audio.
2. **Latency + CPU**: per-chunk processing time on a mid-range Android CPU thread; is Silero ONNX truly <1 ms/chunk on-device?
3. **Battery** for always-on armed-mode gating.
4. **Model size + runtime deps** (ONNX Runtime footprint on Android vs WebRTC's tiny native lib).
5. **Integration**: Android/Kotlin usage, ONNX Runtime Android setup, sample rate/frame-size constraints (we produce 16 kHz PCM16 in 10 ms / 320-byte frames).
6. **Licensing** of code and the specific model weights (Silero model card terms).
7. **Two-stage option**: does a WebRTC cheap pre-gate → Silero confirm pattern make sense for battery, and do any apps do this?

## Desired deliverable

- A **comparison table**: engine × {accuracy, latency, CPU, battery, size, license}.
- A **recommendation** with reasoning, and whether to couple VAD to the ASR choice (D6) or keep it independent.
- Minimal Android integration pointer for the top pick.

## Why it matters

Closes D5, sizes P4's VAD gate + segmentation. Keep it independent of D6 unless the ASR engine's bundled VAD is clearly better.
