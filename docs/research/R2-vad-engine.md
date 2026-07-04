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









# Android VAD Engine Choice for the Omi App

## Bottom line

For the Omi Android app, the best default is **standalone Silero VAD via ONNX Runtime**, kept **independent** from the ASR choice. It gives the strongest public evidence for noisy-audio quality among the candidates, it is still very fast on one CPU thread, and it keeps your VAD gate and segmentation logic separate from whatever ASR stack you choose later. WebRTC VAD is still worth keeping around as a **fallback** or as a **cheap first-pass gate** if you later prove that battery is a real problem, but it should *not* be the only detector if you care about missed speech starts and false triggers in noise. citeturn41view0turn10view0turn42view0turn30view0turn21view0

The short answer to your main practical question is this: Silero’s official claim of **under 1 ms per 30+ ms chunk** on one CPU thread is plausible, and public Android reports are consistent with that, but I did *not* find a Silero-maintained benchmark on a named mid-range Android SoC. So the right reading is **“likely true enough to use”**, not **“proven on your exact phone class.”** citeturn24view0turn42view0turn34view0

## What the evidence says about accuracy

Silero has the strongest open evidence here. In Silero’s own quality wiki, at 16 kHz and 31.25 ms evaluation windows, **Silero v6** scores **0.97** ROC-AUC on its multi-domain validation set versus **0.73** for WebRTC, and its 31.25 ms chunk accuracy is **0.92** versus **0.74** for WebRTC. On the noisy-only sets, the gap is even clearer: on “Private noise,” WebRTC scores **0.15** entire-audio accuracy, while Silero v6 scores **0.71**. On the MSDWild real-world set, WebRTC chunk accuracy is **0.83**, versus **0.86** for Silero v6. Silero’s own summary is blunt: WebRTC is extremely fast and good at noise-versus-silence, but *poor* at speech-versus-noise. citeturn41view0

A newer independent Google-authored 2026 paper on diverse real-world digital audio streams reaches the same ranking: **Silero > WebRTC > RMS**. At a typical 50 ms operating setup, the paper reports peak Matthews Correlation Coefficient of **0.72** for Silero and **0.41** for WebRTC; adding hysteresis helps WebRTC a bit, taking it to **0.47**, but does not materially improve Silero. That matters for your use case because it means a simple state machine can rescue WebRTC somewhat, but it does *not* close the gap. citeturn10view0

For onset clipping, there is less clean vendor-neutral data than for overall detection quality. Still, the practical picture is clear. Moonshine’s own transcriber docs explicitly warn that raising the VAD threshold too much can break speech into smaller chunks and clip real speech, and they add a default **8192-sample look-behind** to prepend audio before the threshold crossing. Silero wrappers expose the same basic idea through speech padding. That is exactly the right pattern for a rolling-buffer Android recorder: keep a short pre-roll and prepend it when speech starts. citeturn39view1turn29search3

A competitor benchmark should be treated cautiously, but it does line up with the rest of the evidence: at **5% false positive rate**, Picovoice reports **50% TPR** for WebRTC and **87.7% TPR** for Silero; in a one-hour call example, they estimate roughly **62** speech cut-offs for WebRTC versus **9–10** for Silero. I would not use those numbers as the main proof, but they support the same design conclusion: WebRTC is more likely to *clip* and *miss* speech in noisy real use. citeturn27view0

## Latency, CPU, and battery reality

Silero’s official repo says one audio chunk of **30+ ms** takes **less than 1 ms** on a single CPU thread, and its performance wiki gives a harder reference point: **189 microseconds** for a **31.25 ms** chunk for **V5 ONNX** on one x86 CPU thread, versus **207 microseconds** for V4 ONNX. That is *not* an Android number, but it is a solid sign that the model itself is small enough that the compute budget is not crazy. citeturn24view0turn42view0

On Android, the best public report I found is not an official benchmark but an Android library that ships both WebRTC and Silero. Its maintainer states that Silero on ONNX Runtime Mobile gives **exceptional accuracy** and processing time **very close to WebRTC**, and another Android-oriented Silero page reports **sub-millisecond latency** for **32 ms** chunks with **RTF < 0.01**. Those are useful signals, but they are still *community* reports, not a formal cross-device benchmark. citeturn25view3turn34view0

WebRTC remains the speed and battery king. It is a tiny C VAD with no ML runtime, and it only needs 10, 20, or 30 ms frames. A higher aggressiveness mode increases precision but also increases missed speech. Internally, higher sample rates are downsampled, and the core processing is built for very low complexity. If your goal were **absolute minimum battery drain** and you could tolerate more false rejects or more tuning pain, WebRTC would win. citeturn31view0turn30view0turn21view0

Battery is the weakest part of the public evidence. I did *not* find a good Android always-on battery shootout for Silero versus WebRTC on the same handset. So the honest answer is qualitative: **WebRTC should be best for battery**, **Silero should still be cheap enough for armed mode on a phone**, and the real question is whether the accuracy gain is worth the extra runtime and binary cost. For your use case, I think it is. citeturn30view0turn24view0turn25view3

## Dependencies, size, integration, and licensing

Your current audio format is **16 kHz mono PCM16 in 10 ms frames**, which is a very good fit for WebRTC. WebRTC accepts **16-bit mono PCM** at **8, 16, 32, or 48 kHz**, and frame lengths must be **10, 20, or 30 ms**. At 16 kHz that means **160, 320, or 480 samples**. So your current **320-byte / 10 ms** frame drops straight in. citeturn30view0turn21view0

Silero is slightly more awkward but still fine. Official and community Silero integrations document that at **16 kHz** the expected frame sizes are **512, 1024, or 1536 samples**; on Android the common default is **512 samples**, and Silero maintainers discussing Android usage recommend working with **small chunks** and a **sliding window / buffering** approach. In plain terms: keep your 10 ms recorder loop, but aggregate into a rolling **512-sample** inference window for Silero. citeturn21view0turn29search3turn6view0

For runtime footprint, WebRTC is **tiny**. A widely used Android wrapper reports the WebRTC native lib at **158 KB**. Silero’s model itself is around **2 MB**, but the real footprint question is the runtime: standard `onnxruntime-android` supports ordinary ONNX models but is **larger** than `onnxruntime-mobile`; the mobile package is size-optimized, but official ONNX Runtime docs say it expects **ORT format** models and a reduced operator set. So the easiest path for Silero on Android is usually the **full Android ORT package**, while the smallest path needs extra conversion or a custom build. citeturn21view0turn24view0turn13view0turn32view0turn33view2

Licensing is mostly **good**, with one annoying caveat. WebRTC source is under a **BSD-style** license with an additional patents file. Silero’s official repo has an actual **MIT LICENSE** file, and the repo README also says Silero is published under a permissive **MIT** license. But the README page still shows a stale badge text that says **“CC BY-NC 4.0”** even though it links to the MIT license. I did *not* find a separate restrictive model-card license for the official VAD weights in this pass, and sherpa-onnx’s own docs also say `silero-vad` uses **MIT**. So the practical read is **MIT**, but if you are shipping commercially, archive the exact model file, LICENSE file, and commit hash you ship. citeturn30view0turn23view0turn24view0turn38view0

## Comparison table

| Engine | Accuracy on noisy real-world audio | Onset clipping risk | Latency and CPU | Battery for armed mode | Size and deps | License | Android fit |
|---|---|---|---|---|---|---|---|
| **Silero VAD ONNX** | **Best of these open options**. Silero v6 multi-domain ROC-AUC **0.97** vs WebRTC **0.73**; chunk accuracy **0.92** vs **0.74**; private-noise accuracy **0.71** vs **0.15**. Google 2026 paper also ranks Silero well above WebRTC. citeturn41view0turn10view0 | **Lower** if you use pre-roll / padding. Thresholds still need tuning. Moonshine’s docs show why look-behind matters; Silero wrappers expose the same idea. citeturn39view1turn29search3 | Official claim: **<1 ms** for 30+ ms chunk on 1 CPU thread. Official x86 number: **189 µs** for 31.25 ms V5 ONNX chunk. Android reports say **sub-ms** and near-WebRTC speed, but *no solid named-SoC benchmark found*. citeturn24view0turn42view0turn34view0turn25view3 | **Good**, but *not the best*. Likely acceptable for a personal app, higher cost than WebRTC. *No good public same-device Android battery test found.* citeturn24view0turn25view3 | Model about **2 MB**; easiest runtime is `onnxruntime-android`, which is *bigger* than `onnxruntime-mobile`; mobile package wants **ORT format** and reduced ops. citeturn24view0turn13view0turn32view0 | **MIT**, though the README badge text is inconsistent and appears stale. citeturn23view0turn24view0turn38view0 | **Good fit**, but you must aggregate your 10 ms frames into **512-sample** windows. citeturn21view0turn29search3turn6view0 |
| **WebRTC VAD** | **Clearly weaker in noise**. Multi-domain chunk accuracy **0.74**; private-noise accuracy **0.15**; Google 2026 paper MCC **0.41**, or **0.47** with hysteresis. citeturn41view0turn10view0 | **Higher** unless you add your own hysteresis and pre-roll. More aggressive modes raise missed-detection risk. citeturn31view0turn10view0 | **Fastest** and simplest. Pure C, no ML runtime, built for 10/20/30 ms frames. citeturn30view0turn31view0 | **Best** of the three for always-on gating. citeturn30view0turn21view0 | About **158 KB** in a popular Android wrapper; no ONNX Runtime needed. citeturn21view0 | **BSD-style** plus patents file. citeturn30view0turn31view0 | **Perfect fit** for your current **10 ms / 320-byte** frames. citeturn30view0turn21view0 |
| **sherpa-onnx bundled VAD** | If you use sherpa’s Silero path, quality is basically the Silero story, not a separate win. Sherpa also supports `ten-vad`, but that is a different model and license. citeturn38view0 | Depends on which bundled VAD you choose and how sherpa post-processes it. No clear public Android onset benchmark better than standalone Silero found. citeturn38view0 | *Heavier* packaging. Typical static-link Android AARs published around **28–35 MB**. Sherpa’s current Silero support was still v4/v5 in April 2026, and an issue shows the bundled Silero path expects **16 kHz**. citeturn15search2turn15search8turn15search7turn17view1turn17view0 | *Worse than standalone WebRTC; probably not better than standalone Silero for just gating.* citeturn15search2turn17view1 | Big native bundle plus model files. Good if you already live in sherpa; *overkill* if you only need VAD. citeturn15search2turn38view0 | Sherpa code is Apache-2.0; bundled VAD model license varies. Sherpa docs say `silero-vad` is **MIT** and `ten-vad` uses a modified Apache-2.0 license. citeturn38view0 | **Only makes sense** if sherpa-onnx is already your ASR base. citeturn38view0turn17view1 |
| **Moonshine integrated pipeline VAD** | Convenient, but *not well benchmarked as a standalone VAD*. Docs expose threshold, window averaging, and look-behind, but I did *not* find public FAR/FRR or Android CPU numbers just for its VAD. citeturn39view1 | Has explicit controls to reduce clipping: default threshold **0.5**, **0.5 s** averaging window, and **8192-sample** look-behind. citeturn39view1 | VAD runs every **30 ms** inside a larger ASR pipeline. Quality may be fine, but you are coupling segmentation to a much larger stack. citeturn39view1 | Hard to justify for gating alone because you pull in ASR too. citeturn39view0turn39view1 | Android sample bundles a small English streaming ASR model and uses `ai.moonshine:moonshine-voice`; smallest streaming model family is **34M** parameters. citeturn39view0turn35search15 | *Not verified in this pass* for the exact app artifact and weight terms. citeturn39view0 | **Good only if you already choose Moonshine** and want its segmentation tied to transcription. citeturn39view1 |

## Recommendation

The best call for R2 is:

**Pick Silero VAD ONNX as the default engine. Keep VAD independent of D6. Keep WebRTC available as an optional low-power mode or first-pass gate.** citeturn41view0turn10view0turn42view0turn30view0

Why this is the right trade:

Silero gives the **best quality evidence** in noise, which is what matters most for an app with a rolling buffer where clipped onsets are painful. It is also still **fast enough** that you are not buying that quality with some absurd CPU bill. WebRTC is **smaller** and **cheaper**, but the false-trigger and missed-speech trade is materially worse in the exact sort of messy audio a phone sees. Sherpa-onnx does *not* buy you a clear VAD advantage over standalone Silero, and Moonshine’s integrated VAD is useful only if you already want Moonshine’s whole speech stack. citeturn41view0turn10view0turn42view0turn17view1turn39view1

So I would close D5 this way:

Use **Silero** for both armed-mode mic gating and speech segmentation. Implement it with a **short pre-roll ring buffer** and a simple state machine, because the real product feel comes as much from the post-processing as from the classifier. Only couple VAD to ASR if D6 ends up selecting Moonshine **and** you decide you actively want Moonshine’s built-in segmentation rules to define user turns. Otherwise, keep them separate. citeturn39view1turn21view0turn10view0

### What about a two-stage WebRTC then Silero design

Yes, it **can** make sense. WebRTC is so cheap that it can act as a first wake-up gate, and Silero can then confirm speech or do final segmentation. The evidence supports the logic: WebRTC is **tiny** and **fast**, while Silero is **more accurate** in noise. Also, the 2026 paper shows that WebRTC benefits from hysteresis more than Silero does, which makes it a reasonable rough first-stage detector. citeturn21view0turn30view0turn10view0turn41view0

That said, I would *not* start there. For a personal app on a phone, the extra complexity is only worth it if your own profiling shows Silero gating hurts battery more than you can accept. I did *not* find a well-documented Android app publicly describing a WebRTC → Silero stack specifically, so this remains a sensible engineering pattern, not a well-proven default in open Android examples. The simplest **good** design is still one-stage Silero with a ring buffer and sane thresholds. citeturn24view0turn25view3turn10view0

## Minimal Android integration pointer for the top pick

Use **direct ONNX Runtime on Android**, not an ASR-coupled VAD stack. Official ONNX Runtime Android setup is straightforward: add Maven Central, then add `com.microsoft.onnxruntime:onnxruntime-android` to your Gradle dependencies. The full Android package runs standard ONNX models; the reduced `onnxruntime-mobile` path is only for ORT-format models and reduced-op builds. citeturn33view2turn13view0turn32view0

For your exact audio path, do this:

- Keep `AudioRecord` delivering your existing **16 kHz PCM16 10 ms** frames. citeturn30view0turn21view0
- Maintain a rolling **pre-roll buffer** so you can prepend audio when speech starts. Moonshine documents this same idea with a default **8192-sample** look-behind, and Silero tools expose speech padding for the same reason. citeturn39view1turn29search3
- Aggregate incoming 10 ms packets into a **512-sample** Silero inference window at 16 kHz. Because your native packet is only 160 samples, use a ring buffer and run the model on the latest 512-sample slice once enough samples exist. Silero Android examples and related wrappers use **512 samples** as the normal 16 kHz setting. citeturn21view0turn29search3turn6view0
- Start with a **minimum speech duration** around **50 ms** and an **end-of-speech silence** around **300 ms**. Those are the default starting values used in a real Android VAD library for both WebRTC and Silero. citeturn21view0
- If you want the shortest path to a working prototype, use an existing Android wrapper first, then swap to direct ORT if you need tighter control. Silero’s repo links community Java examples, and the `android-vad` project shows Kotlin setup for both WebRTC and Silero. citeturn24view0turn21view0

The practical product rule is simple: **do not trust raw VAD edges alone**. Always combine the per-window score with **pre-roll**, **minimum speech time**, and **minimum trailing silence**. That matters more to user-perceived clipping than shaving another fraction of a millisecond off inference. citeturn39view1turn10view0

## Open questions and limitations

I found **good** evidence on relative quality and **good enough** evidence on speed, but there are still gaps:

There is *no* high-confidence public benchmark here for **Silero v6 ONNX on a named mid-range Android CPU thread**. The best support is the official under-1-ms claim, official x86 microbenchmarks, and Android community reports. citeturn24view0turn42view0turn34view0

I did *not* find a trustworthy **same-device Android battery comparison** for always-on armed mode between Silero and WebRTC. So the battery recommendation is qualitative, not measured. citeturn30view0turn25view3

I did *not* find a strong public standalone benchmark for **Moonshine’s integrated VAD** against Silero or WebRTC on noisy mobile audio. Moonshine documents the controls well, but not the detector as a separately evaluated engine. citeturn39view1

I did verify that Silero’s official repo license file is **MIT**, but because the repo page still shows a stale **CC BY-NC 4.0** badge text, I would archive the exact shipped commit and license files in your repo when you vendor the model. citeturn23view0turn24view0









Android VAD Engine Choice for the Omi App
Bottom line
For the Omi Android app, the best default is standalone Silero VAD via ONNX Runtime, kept independent from the ASR choice. It gives the strongest public evidence for noisy-audio quality among the candidates, it is still very fast on one CPU thread, and it keeps your VAD gate and segmentation logic separate from whatever ASR stack you choose later. WebRTC VAD is still worth keeping around as a fallback or as a cheap first-pass gate if you later prove that battery is a real problem, but it should not be the only detector if you care about missed speech starts and false triggers in noise. 

The short answer to your main practical question is this: Silero’s official claim of under 1 ms per 30+ ms chunk on one CPU thread is plausible, and public Android reports are consistent with that, but I did not find a Silero-maintained benchmark on a named mid-range Android SoC. So the right reading is “likely true enough to use”, not “proven on your exact phone class.” 

What the evidence says about accuracy
Silero has the strongest open evidence here. In Silero’s own quality wiki, at 16 kHz and 31.25 ms evaluation windows, Silero v6 scores 0.97 ROC-AUC on its multi-domain validation set versus 0.73 for WebRTC, and its 31.25 ms chunk accuracy is 0.92 versus 0.74 for WebRTC. On the noisy-only sets, the gap is even clearer: on “Private noise,” WebRTC scores 0.15 entire-audio accuracy, while Silero v6 scores 0.71. On the MSDWild real-world set, WebRTC chunk accuracy is 0.83, versus 0.86 for Silero v6. Silero’s own summary is blunt: WebRTC is extremely fast and good at noise-versus-silence, but poor at speech-versus-noise. 

A newer independent Google-authored 2026 paper on diverse real-world digital audio streams reaches the same ranking: Silero > WebRTC > RMS. At a typical 50 ms operating setup, the paper reports peak Matthews Correlation Coefficient of 0.72 for Silero and 0.41 for WebRTC; adding hysteresis helps WebRTC a bit, taking it to 0.47, but does not materially improve Silero. That matters for your use case because it means a simple state machine can rescue WebRTC somewhat, but it does not close the gap. 

For onset clipping, there is less clean vendor-neutral data than for overall detection quality. Still, the practical picture is clear. Moonshine’s own transcriber docs explicitly warn that raising the VAD threshold too much can break speech into smaller chunks and clip real speech, and they add a default 8192-sample look-behind to prepend audio before the threshold crossing. Silero wrappers expose the same basic idea through speech padding. That is exactly the right pattern for a rolling-buffer Android recorder: keep a short pre-roll and prepend it when speech starts. 

A competitor benchmark should be treated cautiously, but it does line up with the rest of the evidence: at 5% false positive rate, Picovoice reports 50% TPR for WebRTC and 87.7% TPR for Silero; in a one-hour call example, they estimate roughly 62 speech cut-offs for WebRTC versus 9–10 for Silero. I would not use those numbers as the main proof, but they support the same design conclusion: WebRTC is more likely to clip and miss speech in noisy real use. 

Latency, CPU, and battery reality
Silero’s official repo says one audio chunk of 30+ ms takes less than 1 ms on a single CPU thread, and its performance wiki gives a harder reference point: 189 microseconds for a 31.25 ms chunk for V5 ONNX on one x86 CPU thread, versus 207 microseconds for V4 ONNX. That is not an Android number, but it is a solid sign that the model itself is small enough that the compute budget is not crazy. 

On Android, the best public report I found is not an official benchmark but an Android library that ships both WebRTC and Silero. Its maintainer states that Silero on ONNX Runtime Mobile gives exceptional accuracy and processing time very close to WebRTC, and another Android-oriented Silero page reports sub-millisecond latency for 32 ms chunks with RTF < 0.01. Those are useful signals, but they are still community reports, not a formal cross-device benchmark. 

WebRTC remains the speed and battery king. It is a tiny C VAD with no ML runtime, and it only needs 10, 20, or 30 ms frames. A higher aggressiveness mode increases precision but also increases missed speech. Internally, higher sample rates are downsampled, and the core processing is built for very low complexity. If your goal were absolute minimum battery drain and you could tolerate more false rejects or more tuning pain, WebRTC would win. 

Battery is the weakest part of the public evidence. I did not find a good Android always-on battery shootout for Silero versus WebRTC on the same handset. So the honest answer is qualitative: WebRTC should be best for battery, Silero should still be cheap enough for armed mode on a phone, and the real question is whether the accuracy gain is worth the extra runtime and binary cost. For your use case, I think it is. 

Dependencies, size, integration, and licensing
Your current audio format is 16 kHz mono PCM16 in 10 ms frames, which is a very good fit for WebRTC. WebRTC accepts 16-bit mono PCM at 8, 16, 32, or 48 kHz, and frame lengths must be 10, 20, or 30 ms. At 16 kHz that means 160, 320, or 480 samples. So your current 320-byte / 10 ms frame drops straight in. 

Silero is slightly more awkward but still fine. Official and community Silero integrations document that at 16 kHz the expected frame sizes are 512, 1024, or 1536 samples; on Android the common default is 512 samples, and Silero maintainers discussing Android usage recommend working with small chunks and a sliding window / buffering approach. In plain terms: keep your 10 ms recorder loop, but aggregate into a rolling 512-sample inference window for Silero. 

For runtime footprint, WebRTC is tiny. A widely used Android wrapper reports the WebRTC native lib at 158 KB. Silero’s model itself is around 2 MB, but the real footprint question is the runtime: standard onnxruntime-android supports ordinary ONNX models but is larger than onnxruntime-mobile; the mobile package is size-optimized, but official ONNX Runtime docs say it expects ORT format models and a reduced operator set. So the easiest path for Silero on Android is usually the full Android ORT package, while the smallest path needs extra conversion or a custom build. 

Licensing is mostly good, with one annoying caveat. WebRTC source is under a BSD-style license with an additional patents file. Silero’s official repo has an actual MIT LICENSE file, and the repo README also says Silero is published under a permissive MIT license. But the README page still shows a stale badge text that says “CC BY-NC 4.0” even though it links to the MIT license. I did not find a separate restrictive model-card license for the official VAD weights in this pass, and sherpa-onnx’s own docs also say silero-vad uses MIT. So the practical read is MIT, but if you are shipping commercially, archive the exact model file, LICENSE file, and commit hash you ship. 

Comparison table
Engine	Accuracy on noisy real-world audio	Onset clipping risk	Latency and CPU	Battery for armed mode	Size and deps	License	Android fit
Silero VAD ONNX	Best of these open options. Silero v6 multi-domain ROC-AUC 0.97 vs WebRTC 0.73; chunk accuracy 0.92 vs 0.74; private-noise accuracy 0.71 vs 0.15. Google 2026 paper also ranks Silero well above WebRTC. 
Lower if you use pre-roll / padding. Thresholds still need tuning. Moonshine’s docs show why look-behind matters; Silero wrappers expose the same idea. 
Official claim: <1 ms for 30+ ms chunk on 1 CPU thread. Official x86 number: 189 µs for 31.25 ms V5 ONNX chunk. Android reports say sub-ms and near-WebRTC speed, but no solid named-SoC benchmark found. 
Good, but not the best. Likely acceptable for a personal app, higher cost than WebRTC. No good public same-device Android battery test found. 
Model about 2 MB; easiest runtime is onnxruntime-android, which is bigger than onnxruntime-mobile; mobile package wants ORT format and reduced ops. 
MIT, though the README badge text is inconsistent and appears stale. 
Good fit, but you must aggregate your 10 ms frames into 512-sample windows. 
WebRTC VAD	Clearly weaker in noise. Multi-domain chunk accuracy 0.74; private-noise accuracy 0.15; Google 2026 paper MCC 0.41, or 0.47 with hysteresis. 
Higher unless you add your own hysteresis and pre-roll. More aggressive modes raise missed-detection risk. 
Fastest and simplest. Pure C, no ML runtime, built for 10/20/30 ms frames. 
Best of the three for always-on gating. 
About 158 KB in a popular Android wrapper; no ONNX Runtime needed. 
BSD-style plus patents file. 
Perfect fit for your current 10 ms / 320-byte frames. 
sherpa-onnx bundled VAD	If you use sherpa’s Silero path, quality is basically the Silero story, not a separate win. Sherpa also supports ten-vad, but that is a different model and license. 
Depends on which bundled VAD you choose and how sherpa post-processes it. No clear public Android onset benchmark better than standalone Silero found. 
Heavier packaging. Typical static-link Android AARs published around 28–35 MB. Sherpa’s current Silero support was still v4/v5 in April 2026, and an issue shows the bundled Silero path expects 16 kHz. 
Worse than standalone WebRTC; probably not better than standalone Silero for just gating. 
Big native bundle plus model files. Good if you already live in sherpa; overkill if you only need VAD. 
Sherpa code is Apache-2.0; bundled VAD model license varies. Sherpa docs say silero-vad is MIT and ten-vad uses a modified Apache-2.0 license. 
Only makes sense if sherpa-onnx is already your ASR base. 
Moonshine integrated pipeline VAD	Convenient, but not well benchmarked as a standalone VAD. Docs expose threshold, window averaging, and look-behind, but I did not find public FAR/FRR or Android CPU numbers just for its VAD. 
Has explicit controls to reduce clipping: default threshold 0.5, 0.5 s averaging window, and 8192-sample look-behind. 
VAD runs every 30 ms inside a larger ASR pipeline. Quality may be fine, but you are coupling segmentation to a much larger stack. 
Hard to justify for gating alone because you pull in ASR too. 
Android sample bundles a small English streaming ASR model and uses ai.moonshine:moonshine-voice; smallest streaming model family is 34M parameters. 
Not verified in this pass for the exact app artifact and weight terms. 
Good only if you already choose Moonshine and want its segmentation tied to transcription. 

Recommendation
The best call for R2 is:

Pick Silero VAD ONNX as the default engine. Keep VAD independent of D6. Keep WebRTC available as an optional low-power mode or first-pass gate. 

Why this is the right trade:

Silero gives the best quality evidence in noise, which is what matters most for an app with a rolling buffer where clipped onsets are painful. It is also still fast enough that you are not buying that quality with some absurd CPU bill. WebRTC is smaller and cheaper, but the false-trigger and missed-speech trade is materially worse in the exact sort of messy audio a phone sees. Sherpa-onnx does not buy you a clear VAD advantage over standalone Silero, and Moonshine’s integrated VAD is useful only if you already want Moonshine’s whole speech stack. 

So I would close D5 this way:

Use Silero for both armed-mode mic gating and speech segmentation. Implement it with a short pre-roll ring buffer and a simple state machine, because the real product feel comes as much from the post-processing as from the classifier. Only couple VAD to ASR if D6 ends up selecting Moonshine and you decide you actively want Moonshine’s built-in segmentation rules to define user turns. Otherwise, keep them separate. 

What about a two-stage WebRTC then Silero design
Yes, it can make sense. WebRTC is so cheap that it can act as a first wake-up gate, and Silero can then confirm speech or do final segmentation. The evidence supports the logic: WebRTC is tiny and fast, while Silero is more accurate in noise. Also, the 2026 paper shows that WebRTC benefits from hysteresis more than Silero does, which makes it a reasonable rough first-stage detector. 

That said, I would not start there. For a personal app on a phone, the extra complexity is only worth it if your own profiling shows Silero gating hurts battery more than you can accept. I did not find a well-documented Android app publicly describing a WebRTC → Silero stack specifically, so this remains a sensible engineering pattern, not a well-proven default in open Android examples. The simplest good design is still one-stage Silero with a ring buffer and sane thresholds. 

Minimal Android integration pointer for the top pick
Use direct ONNX Runtime on Android, not an ASR-coupled VAD stack. Official ONNX Runtime Android setup is straightforward: add Maven Central, then add com.microsoft.onnxruntime:onnxruntime-android to your Gradle dependencies. The full Android package runs standard ONNX models; the reduced onnxruntime-mobile path is only for ORT-format models and reduced-op builds. 

For your exact audio path, do this:

Keep AudioRecord delivering your existing 16 kHz PCM16 10 ms frames. 
Maintain a rolling pre-roll buffer so you can prepend audio when speech starts. Moonshine documents this same idea with a default 8192-sample look-behind, and Silero tools expose speech padding for the same reason. 
Aggregate incoming 10 ms packets into a 512-sample Silero inference window at 16 kHz. Because your native packet is only 160 samples, use a ring buffer and run the model on the latest 512-sample slice once enough samples exist. Silero Android examples and related wrappers use 512 samples as the normal 16 kHz setting. 
Start with a minimum speech duration around 50 ms and an end-of-speech silence around 300 ms. Those are the default starting values used in a real Android VAD library for both WebRTC and Silero. 
If you want the shortest path to a working prototype, use an existing Android wrapper first, then swap to direct ORT if you need tighter control. Silero’s repo links community Java examples, and the android-vad project shows Kotlin setup for both WebRTC and Silero. 
The practical product rule is simple: do not trust raw VAD edges alone. Always combine the per-window score with pre-roll, minimum speech time, and minimum trailing silence. That matters more to user-perceived clipping than shaving another fraction of a millisecond off inference. 

Open questions and limitations
I found good evidence on relative quality and good enough evidence on speed, but there are still gaps:

There is no high-confidence public benchmark here for Silero v6 ONNX on a named mid-range Android CPU thread. The best support is the official under-1-ms claim, official x86 microbenchmarks, and Android community reports. 

I did not find a trustworthy same-device Android battery comparison for always-on armed mode between Silero and WebRTC. So the battery recommendation is qualitative, not measured. 

I did not find a strong public standalone benchmark for Moonshine’s integrated VAD against Silero or WebRTC on noisy mobile audio. Moonshine documents the controls well, but not the detector as a separately evaluated engine. 

I did verify that Silero’s official repo license file is MIT, but because the repo page still shows a stale CC BY-NC 4.0 badge text, I would archive the exact shipped commit and license files in your repo when you vendor the model. 


Sources

Activity · 7m

Citations · 15

github.com
github.com

1
Quality Metrics · snakers4/silero-vad Wiki · GitHub
https://github.com/snakers4/silero-vad/wiki/Quality-Metrics

2
GitHub - snakers4/silero-vad: Silero VAD: pre-trained enterprise-grade Voice Activity Detector · GitHub
https://github.com/snakers4/silero-vad

4
GitHub - moonshine-ai/moonshine: Very low latency speech to text, intent recognition, and text to speech, for building voice agents and interfaces · GitHub
speech_pad_ms: Final speech chunks are padded by speech_pad_ms each side. Perform speech diarization on given audio files using the silero VAD model

13
GitHub - moonshine-ai/moonshine: Very low latency speech to text, intent recognition, and text to speech, for building voice agents and interfaces · GitHub
https://github.com/moonshine-ai/moonshine

14
GitHub - moonshine-ai/moonshine: Very low latency speech to text, intent recognition, and text to speech, for building voice agents and interfaces · GitHub
Model sizes. Size, Parameters, Encoder / Decoder layers, Encoder dim, Decoder dim. Tiny, 34M, 6 / 6, 320, 320. Small, 123M, 10 / 10, 620, 512. Medium, 245M, 14 ...Read more

6
GitHub - gkonovalov/android-vad: Android Voice Activity Detection (VAD) library. Supports WebRTC VAD GMM, Silero VAD DNN, Yamnet VAD DNN models. · GitHub
https://github.com/gkonovalov/android-vad

9
GitHub - gkonovalov/android-vad: Android Voice Activity Detection (VAD) library. Supports WebRTC VAD GMM, Silero VAD DNN, Yamnet VAD DNN models. · GitHub
speech_pad_ms: Final speech chunks are padded by speech_pad_ms each side. Perform speech diarization on given audio files using the silero VAD model

7
libfvad/include/fvad.h at master · dpirch/libfvad · GitHub
https://github.com/dpirch/libfvad/blob/master/include/fvad.h

10
silero-vad/LICENSE at master · snakers4/silero-vad · GitHub
https://github.com/snakers4/silero-vad/blob/master/LICENSE
arxiv.org
arxiv.org

3
Window Size Versus Accuracy Experiments in Voice Activity Detectors
https://arxiv.org/abs/2601.17270
picovoice.ai
picovoice.ai

5
Best Voice Activity Detection 2026: Cobra vs Silero vs WebRTC VAD
https://picovoice.ai/blog/best-voice-activity-detection-vad/
chromium.googlesource.com
chromium.googlesource.com

8
common_audio/vad/webrtc_vad.c - external/webrtc/stable/webrtc - Git at Google
https://chromium.googlesource.com/external/webrtc/stable/webrtc/%2B/master/common_audio/vad/webrtc_vad.c
k2-fsa.github.io
k2-fsa.github.io

11
VAD — sherpa 1.3 documentation
https://k2-fsa.github.io/sherpa/onnx/vad/index.html
huggingface.co
huggingface.co

12
android/aar/1.12.17/sherpa-onnx-static-link-onnxruntime- ...
csukuangfj. /. sherpa-onnx-libs. like 7. License: apache-2.0. Model card ... sherpa-onnx-libs. File size: 133 Bytes. 4651b63 e1f634d. 1 2 3 4. version https ...Read more
onnxruntime.ai
onnxruntime.ai

15
Install ONNX Runtime | onnxruntime
https://onnxruntime.ai/docs/install/
Sources scanned · 267

github.com
github.com
Silero VAD: pre-trained enterprise-grade Voice Activity ...


Silero VAD has excellent results on speech detection tasks. Fast. One audio chunk (30+ ms) takes less than 1ms to be processed on a single CPU thread.

Moonshine Voice


The Moonshine API is designed to take care of the details around capturing and transcribing live speech, giving application developers a high-level API focused ...Read more

Questions / Help / Support · snakers4 silero-vad


11 Dec 2025 — Environment • Platform: Android • Runtime: ONNX Runtime (ORT) • VAD Version: v5 / v6 • Sample Rate: 16,000 Hz Context I am building a wake ...

Mobile / Edge / ARM / ONNX Use Cases #331


30 May 2024 — the VAD (especially the micro one) was explicitly designed for IOT / edge / mobile use cases, provide instructions for corresponding ARM / mobile builds for ...

❓ VAD robustness to noise-only signals in ONNX v3 vs. v4 ...


11 Sept 2023 — I've been doing some experiments with the 16 kHz ONNX models in order to establish a baseline on noisy-speech as well as on non-speech-at-all ...Read more

Mobile / Edge / ARM / ONNX Use Cases · Issue #37


19 Feb 2021 — Hello, when I use the new models Running silero-vad on Android - https://github.com/bgubanov/VadExample , there are still errors about ...Read more

wiseman/py-webrtcvad: Python interface to the WebRTC ...


A frame must be either 10, 20, or 30 ms in duration: # Run the VAD on 10 ms of silence. The result should be False. sample_rate = 16000 frame_duration = 10 ...

Quality Metrics · snakers4/silero-vad Wiki


WebRTC VAD algorithm is extremely fast and pretty good at separating noise from silence, but pretty poor at separating speech from noise.Read more

[Mobile] Support 16 KB page sizes · Issue #26228


2 Oct 2025 — Android 16 will require 16 KB page sizes, shared library 'libonnxruntime4j_jni.so' does not have a 16 KB page size. Please inform the authors of ...

gfreezy/libfvad: vad from webrtc


... frame. * * `frame` is an array of `length` signed 16-bit samples. Only frames with a * length of 10, 20 or 30 ms are supported, so for example at 8 kHz ...Read more

libfvad/include/fvad.h at master


* Changes the VAD operating ("aggressiveness") mode of a VAD instance. *. * A more aggressive (higher mode) VAD is more restrictive in reporting speech.Read more

Quality Benchmarks Between audiotok / webrtcvad ...


31 Jan 2021 — We have compared 4 easy-to-use off-the-shelf instruments for voice activity / audio activity detection with off-the-shelf parameters.Read more

k2-fsa/sherpa-onnx: Speech-to-text ...


React Native wrapper and demo app for validating sherpa-onnx on iOS, Android, and Web, including ASR, TTS, VAD, KWS, speaker ID, diarization, language ID, ...Read more

Performance Metrics · snakers4/silero-vad Wiki


Silero VAD Performance Metrics. All speed test were run on AMD Ryzen Threadripper 3960X using only 1 thread and batch size equal to 1, 16000 sampling rate.Read more

FAQ · snakers4/silero-vad Wiki


Our models support both 8000 and 16000 Hz. Although other values are not directly supported, multiples of 16000 (eg 32000 or 48000 ) are cast to 16000 inside ...Read more

Home · snakers4/silero-vad Wiki


Table of Contents · Examples and Dependencies · Other Models · Performance Metrics · Quality Metrics · Version history and Available Models · FAQ ...Read more

Examples and Dependencies · snakers4/silero-vad Wiki


13 Nov 2024 — Silero VAD: pre-trained enterprise-grade Voice Activity Detector - Examples and Dependencies · snakers4/silero-vad Wiki.

snakers4 silero-vad Ideas · Discussions


NodeJS support? · Performance metrics with whisperX · Tensorflow or Tensorflow Lite model of Silero VAD · Feature request - Control the Distribution about Length ...Read more

onnxruntime/java/build-android.gradle at main


This package contains the Android (aar) build of ONNX Runtime with the QNN Execution Provider.' + 'It includes support for all types and operators, for ONNX ...Read more

Expected sample rate 16000. Given: 8000 · Issue #1447


19 Oct 2024 — Wr only support the 16000Hz silero vad. Please resample your audio.before sending them to silero vad in sherpa-onnx. Sign up for free to ...Read more

Add pyannote vad (segmentation) model #1197


31 Jul 2024 — I would like to use sherpa-onnx for speaker diarization. However the current vad modal (silero) doesn't works well and doesn't detect speech ...

[FEATURE] Support Silero VAD v6 · Issue #3528


19 Apr 2026 — Describe the feature Currently sherpa-onnx support Silero VAD v4 and v5: sherpa-onnx/sherpa-onnx/csrc/silero-vad-model.cc Lines 77 to 80 in ...

Deploy in Android App · microsoft onnxruntime


10 May 2021 — I'm trying to create an Android App that incorporates a Machine Learning Model. I had an onnx model, along with a Python script file, two json files with the ...Read more

gkonovalov/android-vad: Android Voice Activity Detection ...


WebRTC VAD is lightweight (only 158 KB) and provides exceptional speed in audio processing, but it may exhibit lower accuracy compared to DNN models. WebRTC VAD ...Read more

TEN-framework/ten-vad: Voice Activity Detector (VAD) : low ...


TEN VAD is a real-time voice activity detection system designed for enterprise use, providing accurate frame-level speech activity detection. ... The precision- ...Read more

Licensing and Tiers · snakers4/silero-models Wiki


Silero Models: pre-trained text-to-speech models made embarrassingly simple - Licensing and Tiers · snakers4/silero-models Wiki. ... License: CC BY-NC 4.0. header ...Read more

speech_pad_ms may cause start position to be a negative ...


12 Jul 2024 — If you want to annotate the entire audio file use the get_speech_timestamps method. VADIterator is a good example boilerplate for real time streaming.Read more

moonshine-ai/moonshine-v2


Moonshine Voice is an open source AI toolkit for developers building real-time voice applications. Everything runs on-device, so it's fast, private, and you don ...Read more

Moonshine Streaming - huggingface/transformers


Moonshine Streaming is a streaming variant of the Moonshine speech recognition model, optimized for real-time transcription with low latency.Read more

Issues · moonshine-ai/moonshine


Very low latency speech to text, intent recognition, and text to speech, for building voice agents and interfaces - Issues · moonshine-ai/moonshine.

Releases · k2-fsa/sherpa-onnx


Speech-to-text, text-to-speech, speaker diarization, speech enhancement, source separation, and VAD using next-gen Kaldi with onnxruntime without Internet ...

Need for setting input sample rate different than ...


12 Apr 2024 — I've found that audio input passed to the OnlineRecognizer in the Java API can only be at sample rate of model or at default 16000.

webrtc.org
webrtc.org
WebRTC


With WebRTC, you can add real-time communication capabilities to your application that works on top of an open standard. It supports video, voice, and generic ...

Software License


25 May 2021 — Redistribution and use in source and binary forms, Google hereby grants to you a perpetual, worldwide, non-exclusive, no-charge, irrevocable ...

developer.mozilla.org
developer.mozilla.org
WebRTC API - MDN Web Docs - Mozilla


26 Jun 2025 — WebRTC (Web Real-Time Communication) is a technology that enables Web applications and sites to capture and optionally stream audio and/or video media.Read more

k2-fsa.github.io
k2-fsa.github.io
VAD — sherpa 1.3 documentation


We support silero-vad and ten-vad for voice activity detection. Download models files Android examples WebAssembly. Read the Docs.

sherpa-onnx — sherpa 1.3 documentation


In the following, we describe how to build sherpa-onnx for Linux, macOS, Windows, embedded systems, Android, and iOS. Step 1: Download the model and Silero VAD ...

sherpa-onnx-kws-zipformer-zh-en-3M-2025-12-20 ...


It supports decoding only wave files of a single channel with 16-bit encoded samples, while the sampling rate does not need to be 16 kHz. The following code ...Read more

Build sherpa-onnx for Android


You can use this section for both speech-to-text (STT, ASR) and text-to-speech (TTS). ... The build scripts mentioned in this section run on both Linux and macOS.Read more

arxiv.org
arxiv.org
Moonshine: Speech Recognition for Live Transcription and ...


by N Jeffries · 2024 · Cited by 18 — This paper introduces Moonshine, a family of speech recognition models optimized for live transcription and voice command processing.Read more

Voice Activity Detection (VAD) in Noisy Environments


10 Dec 2023 — This paper details the development and implementation of a VAD system, specifically engineered to maintain high accuracy in the presence of various ambient ...Read more

Window Size Versus Accuracy Experiments in Voice Activity Detectors


Total lines: 124

On the emergence of preferred structures in quantum theory


by A Soulas · 2025 · Cited by 4 — Abstract:We assess the possibilities offered by Hilbert space fundamentalism, an attitude towards quantum physics according to which all ...Read more

Window Size Versus Accuracy Experiments in Voice ...


We analyze the impact of window size on the accuracy of three VAD algorithms: Silero, WebRTC, and Root Mean Square (RMS) across a set of diverse ...Read more

Exactly Solvable Topological Phase Transition in a ...


by L Shou · 2026 · Cited by 1 — We consider a family of generalized Rokhsar-Kivelson (RK) Hamiltonians, which are reverse-engineered to have an arbitrary edge-weighted ...Read more

Uncovering Hidden Systematics in Neural Network Models ...


by L Flek · 2026 — Abstract. Neural networks (NNs) are inherently multidimensional classifiers that learn complex, non- linear relationships among input ...Read more

Planted Solutions in Quantum Chemistry: Generating Non- ...


by L Wang · 2025 · Cited by 1 — Generating large, non-trivial quantum chemistry test problems with known ground-state solu- tions remains a core challenge for benchmarking electronic ...Read more

Generalized structures of ten-dimensional supersymmetric ...


by A Tomasiello · 2011 · Cited by 63 — View a PDF of the paper titled Generalized structures of ten-dimensional supersymmetric solutions, by Alessandro Tomasiello. View PDF · TeX ...Read more

Introduction to string field theory


https://arxiv.org/abs/hep-th/0107094

Iron Oxide Surfaces


https://arxiv.org/abs/1602.06774

Nearly-Linear Time Algorithms for Graph Partitioning, Graph Sparsification, and Solving Linear Systems


https://arxiv.org/abs/cs/0310051

DocLayNet: A Large Human-Annotated Dataset for Document-Layout Analysis


https://arxiv.org/abs/2206.01062

Window Size Versus Accuracy Experiments in Voice ...


24 Jan 2026 — We analyze the impact of window size on the accuracy of three VAD algorithms: Silero, WebRTC, and Root Mean Square (RMS) across a set of diverse ...Read more

Moonshine v2: Ergodic Streaming Encoder ASR for ...


12 Feb 2026 — Moonshine v2 models employ sliding-window attention in a position-free encoder to enable low-latency streaming inference while maintaining state ...Read more

Tiny Specialized ASR Models for Edge Devices


2 Sept 2025 — We adopt the Moonshine Tiny variant (27M parameters), which is small enough to be deployed in resource-constrained environments. Table 2 ...Read more

Moonshine v2: Ergodic Streaming Encoder ASR for ...


by M Kudlur · 2026 · Cited by 1 — Our models achieve state of the art word error rates across standard bench- marks, attaining accuracy on-par with models 6x their size while ...Read more

[1908.10992] Two-Pass End-to-End Speech Recognition


by TN Sainath · 2019 · Cited by 193 — This work aims to bring the quality of an E2E streaming model closer to that of a conventional system by incorporating a LAS network as a second-pass component.Read more

Adaptive, Iterative, and Reasoning-based Frame Selection ...


6 Oct 2025 — It dynamically identifies and samples candidate frames around potential events based on query-frame similarity and controls the output frames ...Read more

en.wikipedia.org
en.wikipedia.org
WebRTC


WebRTC (Web Real-Time Communication) is a free and open-source project providing web browsers and mobile applications with real-time communication (RTC)Read more

Confusion matrix


A confusion matrix, also known as error matrix, is a specific table layout that allows visualization of the performance of a person or an algorithm on a ...Read more

Android (operating system)


Android is an open-source operating system developed by Google. Android is based on a modified version of the Linux kernel and other free and open-source ...Read more

medium.com
medium.com
Sherpa-ONNX VAD Settings


I have spent some time experimenting with the VAD settings in Sherpa-ONNX and noticed improvements when the parameters were adjusted from their default values.

SileroVAD : Machine Learning Model to Detect Speech ...


SileroVAD (VAD stands for Voice Activity Detector) is a machine learning model designed to detect speech segments.Read more

How to Implement High-Speed Voice Recognition in ...


Silero-VAD: A lightweight, efficient voice activity detector from Snakers4. Loaded once using PyTorch Hub, it processes 32ms audio chunks to ...Read more

ONNX Runtime on Android: The Ultimate Guide to ...


Create Session: Set up an inference session. Prepare Input Tensor ... Here are some practical examples of where ONNX Runtime on Android shines:.Read more

Optimizing Speech Pipelines Using Voice Activity Detection


WebRTC VAD splits audio into short frames (typically 10–30 ms) and applies signal processing techniques to determine whether each frame contains ...Read more

The Emergence of More Capable Small Language Models


Microsoft recently unveiled the Phi-3 family of small language models, a groundbreaking series designed to deliver robust AI capabilities in a more compact ...Read more

Building a Real-Time AI Call Audit System: Speech-to-Text, ...


Two-pass PII redaction: Pass 1: Fast regex for structured PII (card numbers, NI, phone) Pass 2: Presidio NER for unstructured PII (names ...Read more

Getting Started with WebRTC: A Practical Guide ...


WebRTC (Web Real-Time Communication) is a collection of open-source technologies that enable real-time communication over the internet directly ...Read more

yuv.ai
yuv.ai
Moonshine: 5x Faster Speech Recognition for Edge Devices


5 Mar 2026 — Moonshine is an open-source speech recognition toolkit designed specifically for streaming and real-time voice interfaces.Read more

w3.org
w3.org
WebRTC: Real-Time Communication in Browsers


13 Mar 2025 — This document defines a set of ECMAScript APIs in WebIDL to allow media and generic application data to be sent to and received from another ...

youtube.com
youtube.com
Moonshine: Real-Time Speech-To-Text on your laptop


In this video, we're going to learn about Moonshine, a series of models optimized for real-time ASR (Automatic Speech Recognition).

On-device Training with ONNX Runtime


In this episode we will dive into how to train machine learning models on a device. On-Device Training refers to the process of training a ...

GitHub - k2-fsa/sherpa-onnx: Speech-to-text, text-to-speech ...


https://github.com/k2-fsa/sherpa-onnx Speech-to-text, text-to-speech, and speaker recongition using next-gen Kaldi with onnxruntime without ...

GitHub - snakers4/silero-vad: Silero VAD: pre-trained ...


GitHub - snakers4/silero-vad: Silero VAD: pre-trained enterprise-grade Voice Activity Detector. @githubtrendfeed2 likes574 views1 year ago

The key to realtime voice chat - Silero VAD


how to implement real-time Voice Activity Detection (VAD) in your web applications using Silero VAD. In this tutorial, I show you how to ...

huggingface.co
huggingface.co
generate-vad.py · csukuangfj/sherpa-onnx-apk at ...


13 Jul 2024 — This page lists the <strong>VAD</strong> APKs for /sherpa-onnx">sherpa-onnx</a>, You can download all supported models from

TEN-framework/ten-vad · Hugging Face


TEN VAD is a real-time voice activity detection system designed for enterprise use, providing accurate frame-level speech activity detection.Read more

csukuangfj/android-onnxruntime-libs


Libraries in this repository are intended for use in https://github.com/k2-fsa/sherpa-onnx. They are downloaded from https://mvnrepository.com/artifact/com. ...Read more

android/aar/1.12.11/sherpa-onnx-static-link-onnxruntime- ...


sherpa-onnx-libs. like 7. License: apache-2.0. Model card Files Files and ... sherpa-onnx-libs. File size: 133 Bytes. cd3f7f6 112c03f. 1 2 3 4. version https ...Read more

upload sherpa-onnx-1.10.45.aar


22 Feb 2025 — We're on a journey to advance and democratize artificial intelligence through open source and open science.

android/aar/sherpa-onnx-static-link-onnxruntime-1.10.36.aar


csukuangfj. /. sherpa-onnx-libs. like 7. License: apache-2.0. Model card ... sherpa-onnx-libs. File size: 133 Bytes. 14b2136 4ab53e0. 1 2 3 4. version https ...Read more

android/aar/1.12.17/sherpa-onnx-static-link-onnxruntime- ...


csukuangfj. /. sherpa-onnx-libs. like 7. License: apache-2.0. Model card ... sherpa-onnx-libs. File size: 133 Bytes. 4651b63 e1f634d. 1 2 3 4. version https ...Read more

android/aar/1.11.4/sherpa-onnx-static-link-onnxruntime- ...


csukuangfj. /. sherpa-onnx-libs. like 7. License: apache-2.0. Model card Files ... sherpa-onnx-libs. File size: 133 Bytes. 037e457. 1 2 3 4. version https://git ...Read more

android/aar/1.12.14/sherpa-onnx-static-link-onnxruntime- ...


csukuangfj. /. sherpa-onnx-libs. like 7. License: apache-2.0. Model card ... sherpa-onnx-libs. File size: 133 Bytes. 834ad3c 4de970f. 1 2 3 4. version https ...Read more

android/aar/sherpa-onnx-1.11.5-rknn.aar · csukuangfj/ ...


csukuangfj. /. sherpa-onnx-libs. like 7. License: apache-2.0. Model card ... sherpa-onnx-libs. File size: 133 Bytes. cef6640 8515bc7. 1 2 3 4. version https ...Read more

csukuangfj/sherpa-onnx-libs at main


14 Jan 2026 — We're on a journey to advance and democratize artificial intelligence through open source and open science.

android/aar/sherpa-onnx-1.10.35.aar · csukuangfj/sherpa- ...


csukuangfj. /. sherpa-onnx-libs. like 7. License: apache-2.0. Model card ... sherpa-onnx-libs. File size: 133 Bytes. 3255dc7 7564e07. 1 2 3 4. version https ...Read more

android/aar/1.10.46/sherpa-onnx-static-link-onnxruntime- ...


csukuangfj. /. sherpa-onnx-libs. like 7. License: apache-2.0. Model card ... sherpa-onnx-libs. File size: 133 Bytes. 3fea977 618150e. 1 2 3 4. version https ...Read more

android/aar/1.11.0/sherpa-onnx-static-link-onnxruntime- ...


csukuangfj. /. sherpa-onnx-libs. like 7. License: apache-2.0. Model card Files ... sherpa-onnx-libs. File size: 133 Bytes. 9d1d11f. 1 2 3 4. version https://git ...Read more

README.md · TEN-framework/ten-vad at refs/pr/3


20 May 2025 — The precision-recall curves comparing the performance of WebRTC VAD (pitch-based), Silero VAD, and TEN VAD are shown below. The evaluation is ...Read more

runanywhere/silero-vad-v5


vad silero runanywhere on-device License: VAD v5 — a lightweight voice activity detection model in ONNX format, packaged for use with the RunAnywhere SDK.

aufklarer/Silero-VAD-v5-MLX


The original Silero VAD model is released under the MIT License. This model isn't deployed by any Inference Provider.

inference4j/silero-vad


VAD, a lightweight and fast voice activity detection model. This model is licensed under the MIT License. Original model by Silero Team.

everyscribe/silero-vad


Published under permissive license (MIT) Silero VAD has zero strings attached - no telemetry, no keys, no registration, no built-in expiration, no keys or ...

Remove project-specific framing; generic model card


15 Jun 2026 — Remove project-specific framing; generic model card ; 37. | Original model | [snakers4/silero-vad](https://github.com/snakers4/silero-vad) ( ...Read more

FluidInference/silero-vad-coreml


10 Jul 2025 — License: MIT. Parent Model: silero-vad. This is how the model performs against the silero-vad v6.0.0 basline Pytorch JIT version. graphs ...

mlx-community/silero-vad-v6


License MIT (matching the upstream Silero VAD license). ero VAD: pre-trained enterprise-grade Voice Activity

LICENSE · mijuanlo/silero-vad-onnx at ...


17 hours ago — silero vad audio License: verified in about 12 hours Raw. Permission is hereby granted, free of charge, to any person obtaining a copy of this ...

onnx-community/silero-vad


We're on a journey to advance and democratize artificial intelligence through open source and open science.

deepghs/silero-vad-onnx


We're on a journey to advance and democratize artificial intelligence through open source and open science.

modules/vad/silero_vad.py · LAP-DEV/Demo at main


4 Jun 2025 — """This method is used for splitting long audios into speech chunks using silero VAD. containing begin and end samples of each speech chunk. ...

UsefulSensors/moonshine-streaming-tiny


This is the model card for the Moonshine Streaming automatic speech recognition (ASR) models trained and released by Useful Sensors. Moonshine Streaming pairs a ...Read more

Small Language Models (SLM): A Comprehensive Overview


22 Feb 2025 — While large language models have hundreds of billions—or even trillions—of parameters, SLMs typically range from 1 million to 10 billion ...Read more

UsefulSensors/moonshine-streaming-small


Model sizes. Size, Parameters, Encoder / Decoder layers, Encoder dim, Decoder dim. Tiny, 34M, 6 / 6, 320, 320. Small, 123M, 10 / 10, 620, 512. Medium, 245M, 14 ...Read more

Daily Papers


... two-pass models like UnitY and Translatotron 2 in both translation quality and decoding speed. When there is no parallel speech data, ComSpeech-ZS lags ...

android/aar/1.12.25/sherpa-onnx-static-link-onnxruntime- ...


journey to advance and democratize artificial intelligence through open source and open science. herpa-onnx-libs. File size: 133 Bytes df71b8d

Enjoy the Power of Phi-3 with ONNX Runtime on your device


22 May 2024 — In this blog, we will show how to harness ONNX Runtime to run Phi-3-mini on mobile phones and in the browser.Read more

android/aar/1.12.20/sherpa-onnx-static-link-onnxruntime- ...


to advance and democratize artificial intelligence through open source and open science. File size: 133 Bytes b9dc457 b078cae 1 2 3 4 version … size 28684832 ...

android/aar/1.12.31/sherpa-onnx-static-link-onnxruntime- ...


journey to advance and democratize artificial intelligence through open source and open science. File size: 133 Bytes cd7cd41 1 2 3 4 version … size 34749207 ...

Running Large Transformer Models on Mobile and Edge ...


4 Nov 2025 — The size of the ONNX model file is similar to the original PyTorch/TensorFlow weight file size; it will be smaller if you have quantized it.Read more

Document source revision and export/quant provenance in ...


15 Jun 2026 — - Silero VAD is language-agnostic and works across a wide range of languages. 49. -. 50. - ## Runtime Notes.

android/aar/1.10.46/sherpa-onnx-static-link-onnxruntime- ...


We're on a journey to advance and democratize artificial intelligence through open source and open science.

pre-downloaded libs · csukuangfj/android-onnxruntime- ...


23 Feb 2023 — aar. 15. + mv onnxruntime-android-1.14.0.aar onnxruntime-android-1 . ... + size 20863206.

picovoice.ai
picovoice.ai
Android Speech Recognition in 2026: The Complete Guide


18 Aug 2023 — Voice Activity Detection (VAD) on Android classifies audio frames as speech or non-speech in real time, without transcribing content. VAD can be ...Read more

Best Voice Activity Detection 2026: Cobra vs Silero ...


12 Nov 2025 — WebRTC VAD: Detects 28,125 frames, misses 28,125 frames, resulting in approximately 62 speech cut-offs with frequent interruptions and a ...

Voice Activity Detection (VAD): The Complete 2026 Guide ...


12 Nov 2025 — VAD is a binary classifier, to measure the accuracy. False Positive Rate (FPR): Percentage of non-speech frames incorrectly identified as ...

petewarden.com
petewarden.com
Announcing Moonshine Voice - Pete Warden's blog


13 Feb 2026 — Today we're launching Moonshine Voice, a new family of on-device speech to text models designed for live voice applications, and an open ...Read more

web.dev
web.dev
Get started with WebRTC | Articles


WebRTC is available on desktop and mobile in Google Chrome, Safari, Firefox, and Opera. A good place to start is the simple video chat app at appr.tc.Read more

onnxruntime.ai
onnxruntime.ai
Deploy on mobile | onnxruntime


ONNX Runtime gives you a variety of options to add machine learning to your mobile application. This page outlines the flow through the development process.

Build for Android | onnxruntime


The SDK and NDK packages can be installed via Android Studio or the sdkmanager command line tool. Android Studio is more convenient but a larger installation.

ONNX Runtime | Home


Cross-platform accelerated machine learning. Built-in optimizations speed up training and inferencing with your existing technology stack.

Install ONNX Runtime | onnxruntime


Download the onnxruntime-android AAR hosted at MavenCentral, change the file extension from .aar to .zip , and unzip it. for creating a custom Android package.

Get Started with ORT for Java


Here is simple tutorial for getting started with running inference on an existing ONNX model for a given input data. The model is typically trained using any of ...Read more

android.com
android.com
Do More With Google on Android Phones & Devices


Discover more about Android & learn how our devices can help you Do more with Google with hyper connectivity, powerful protection, Google apps & Quick ...

webrtc.googlesource.com
webrtc.googlesource.com
webrtc/common_audio/vad/vad_core.c - src - Git at Google


// Thresholds for different frame lengths (10 ms, 20 ms and 30 ms). ... int16_t speechWB[480]; // Downsampled speech frame: 960 samples (30ms in SWB).

wiki.aalto.fi
wiki.aalto.fi
Voice activity detection (VAD) - Introduction to Speech ...


12 Aug 2020 — VAD performance in terms of percentage of true positives and true negatives (left) and false negatives and false positives (right).

central.sonatype.com
central.sonatype.com
onnxruntime-mobile - Maven Central


The ONNX Runtime Mobile package is a size optimized inference library for executing ONNX (Open Neural Network Exchange) models on Android.

com.microsoft.onnxruntime:onnxruntime-android:1.17.0


This package contains the Android (aar) build of ONNX Runtime. It includes support for all types and operators, binary size and memory usage will be larger ...

com.bihe0832.android:lib-speech-recognition - Maven Central


Discover lib-speech-recognition in the com.bihe0832.android namespace. Explore metadata, contributors, the Maven POM file, and more.

com.microsoft.onnxruntime:onnxruntime-mobile:1.13.1


The ONNX Runtime Mobile package is a size optimized inference library for executing ONNX (Open Neural Network Exchange) models on Android.Read more

wiki.agentvoiceresponse.com
wiki.agentvoiceresponse.com
Overview: Noise and VAD


26 Aug 2025 — Neural VAD (Silero) and noise control manage false positives and interruptions. continuously analyzes the audio stream to detect when a user is ...

opensource.microsoft.com
opensource.microsoft.com
Introducing ONNX Runtime mobile – a reduced size, high ...


12 Oct 2020 — ONNX Runtime mobile can execute all standard ONNX models. The size of the runtime package varies depending on the models you wish to support. As ...

malaya-speech.readthedocs.io
malaya-speech.readthedocs.io
Voice Activity Detection - Malaya-Speech's documentation!


For Google WebRTC, we need to split by every 10, 20 or 30 ms. For deep learning,. vggvox-v1 , vggvox-v2 and speakernet , we trained on 30 ms, 90 ms.

developers.google.com
developers.google.com
Classification: Accuracy, recall, precision, and related metrics


12 Jan 2026 — True and false positives and negatives are used to calculate several useful metrics for evaluating models. The false positive rate (FPR) is the ...

ijcrt.org
ijcrt.org
VOICE ACTIVITY DETECTION


Voice activity detection (VAD) is the task of recognizing which parts of an audio contains speech and background noise. It is an important and must step to ...

pytorch.org
pytorch.org
Silero Voice Activity Detector


VAD: pre-trained enterprise-grade Voice Activity Detector (VAD). it suffers from many false positives. Additional Examples and Benchmarks

kaggle.com
kaggle.com
VAD With WebRTC


VAD uses various methods to detect speech: Energy-based: Differentiates speech from noise based on energy levels. Statistical: Uses models like Gaussian Mixture ...

chromium.googlesource.com
chromium.googlesource.com
common_audio/vad/webrtc_vad.c - external/webrtc/stable/ ...


Use of this source code is governed by a BSD-style license * that can be found in the LICENSE file in the root of the source * tree.

common_audio/vad/webrtc_vad.c - external/webrtc


Use of this source code is governed by a BSD-style license * that can be found in the LICENSE file in the root of the source * tree.

stackoverflow.com
stackoverflow.com
python webrtc voice activity detection is wrong


The WebRTC VAD is a very simple, real-time oriented model. It is not a good choice if false positives from things like music, birdsong or other voice-like ...Read more

Google's WebRTC VAD algorithm (esp. "aggressiveness")


I know Google's WebRTC VAD algorithm uses a Gaussian Mixture Model (GMM), but my math knowledge is weak, so I don't really understand what that means. ...

How to use onnxruntime with .ort model in Android Studio


I'm trying to create an Android App that incorporates a Machine Learning Model. I had an onnx model, along with a Python script file, two json files ...

Import ONNX into Android


For a small software project i need to use a trained Neural Network within an Android app. The network was trained in Matlab and exported as ONNX. Now i ...

cs230.stanford.edu
cs230.stanford.edu
Voice activity detection for low-resource settings


by A Sahoo · Cited by 7 — Using the WebRTC VAD, we generated predictions on VCTK original and noisy audio versions and compared against the ground truth labels. The optimizing metric is ...Read more

docs.rs
docs.rs
Vad in webrtc_vad - Rust


Only frames with a length of 10, 20 or 30 ms are supported, so for example at 8 kHz, length must be either 80, 160 or 240. Returns : Ok(true) - (active voice), ...Read more

silero_vad_rs/ lib.rs


1//! Silero Voice Activity Detection (VAD) - Rust Implementation 2//! 3//! This crate provides a Rust implementation of the [Silero Voice Activity Detection ...

VADIterator in silero_vad_rs::vad - Rust


This struct provides a convenient interface for processing audio streams and detecting speech segments. Padding to add to speech segments

mathworks.com
mathworks.com
Google WebRTC Voice Activity Detection (VAD) module


WebRTC is a project providing real-time communication capabilities for many different applications. Source code available in the repository here. View License ...

community.r-multiverse.org
community.r-multiverse.org
Package 'audio.vadwebrtc' reference manual


Detect the location of active voice in audio. The Voice Activity Detection is implemented using a Gaussian Mixture Model from the webrtc framework.Read more

arunbaby.com
arunbaby.com
Voice Activity Detection (VAD) - Arun Baby


VAD is the gatekeeper of all speech systems, classifying audio frames as speech or non-speech in under 5ms. Energy-based approaches work in quiet environments ...Read more

Voice Activity Detection (VAD) - Arun Baby


Deep dive into Voice Activity Detection – from energy-based methods to Silero VAD and semantic end-of-turn prediction with LLMs.

cocoapods.org
cocoapods.org
VoiceActivityDetector


VAD operating "aggressiveness" mode. .quality The default value; normal voice detection mode. Suitable for high bitrate, low-noise data. May classify noise ...Read more

forum.qorvo.com
forum.qorvo.com
Frame lengths are way too big - Ultra-Wideband


22 Dec 2022 — The time it takes for the frame to be sent seems ridiculously wrong. With this configuration I should expect my frame length to be around 155us.Read more

soniqo.audio
soniqo.audio
Silero VAD — Android — Soniqo Docs


Silero VAD v5 runs on Android, embedded Linux, and Windows via ONNX Runtime, providing streaming voice activity detection with sub-millisecond latency. It ...Read more

pypi.org
pypi.org
silero-vad-fork


Silero VAD has excellent results on speech detection tasks. Fast. One audio chunk (30+ ms) takes less than 1ms to be processed on a single CPU thread.Read more

webrtcvad-wheels 2.0.14


A frame must be either 10, 20, or 30 ms in duration: # Run the VAD on 10 ms of silence. The result should be False. sample_rate = 16000 frame_duration = 10 ...

silero-vad-lite


1 Oct 2024 — Silero VAD Lite is a lightweight Python wrapper for the high-quality Silero Voice Activity Detection (VAD) model using ONNX Runtime. Simple ...Read more

blog.stackademic.com
blog.stackademic.com
Silero VAD: The Lightweight, High‑Precision Voice Activity ...


20 Jul 2025 — High accuracy & low latency: Processes ~30 ms chunks of audio in under 1 ms on a CPU, and even faster using ONNX or GPU acceleration. Tiny ...Read more

docs.pipecat.ai
docs.pipecat.ai
SileroVADAnalyzer


Uses ONNX runtime for efficient inference · Automatically resets model state every 5 seconds to manage memory · Runs on CPU by default for consistent performance ...Read more

mohitmayank.com
mohitmayank.com
Voice Activity Detection - A Lazy Data Science Guide


Silero-VAD is another voice activity detection model that stands out for its stellar accuracy and speed. The model can process an audio chunk of over 30 ...Read more

reddit.com
reddit.com
[P] Silero VAD: One voice detector to rule them all : r ...


Supports 30, 60 and 100 ms chunks. Trained on 100+ languages, generalizes well. One chunk ~ 1ms on a single thread. ONNX up to 2-3x faster. Repo.

How do you handle background noise & VAD for real-time ...


I’ve been experimenting with building a voice agent using real-time STT, but I’m running into the classic issue: the transcriber happily picks up everything ...

[D] 14.5M-15M is the smallest number of parameters I ...


The ELECTRA paper introduces a small version that has around 15M parameters. MobileBERT and TinyBERT also have around the same number of parameters. Are ...

Unlimited Speech to Speech using Moonshine and Kokoro, ...


To give you an idea of the benefits: Moonshine processes 10-second audio segments 5x faster than Whisper while maintaining the same (or better!)Read more

r/Android


r/Android: Android news, reviews, tips, and discussions about rooting, tutorials, and apps. General discussion about devices is welcome. Please…

git.citory.tech
git.citory.tech
silero-vad


15 Dec 2020 — Time between receiving new audio chunks and getting results is shown in picture: Batch size, Pytorch model time, ms, Onnx model time, ms. 2, 9 ...Read more

silero-vad


... License: CC BY-NC 4.0](https://img.shields.io/badge/License-MIT-lightgrey.svg?style=for-the-badge)](https://github.com/snakers4/silero-vad/blob/master/LICENSE).Read more

blog.brightcoding.dev
blog.brightcoding.dev
Sherpa-ONNX: Unified Speech Recognition, Synthesis, and ...


11 Sept 2025 — A practical deep-dive into the open-source project that lets you run modern ASR, TTS, VAD, and more on Android, iOS, Windows, Linux, macOS, ...Read more

researchgate.net
researchgate.net
Window Size Versus Accuracy Experiments in Voice Activity ...


PreprintPDF Available. Window Size Versus Accuracy Experiments in Voice Activity Detectors. January 2026. DOI:10.48550/arXiv.2601.17270. License; CC BY 4.0.

Support Vector Machine based Voice Activity Detection


On a small vocabulary task, we show this two pass scheme outperforms MMI (maximum mutual information) trained HMMs. Using system combination we also obtain ...

Unified Streaming and Non-streaming Two-pass End-to- ...


10 Dec 2020 — In this paper, we present a novel two-pass approach to unify streaming and non-streaming end-to-end (E2E) speech recognition in a single ...Read more

semanticscholar.org
semanticscholar.org
[PDF] Window Size Versus Accuracy Experiments in Voice ...


24 Jan 2026 — This work analyzes the impact of window size on the accuracy of three VAD algorithms: Silero, WebRTC, and Root Mean Square across a set of ...

mvnrepository.com
mvnrepository.com
com.microsoft.onnxruntime » onnxruntime-mobile


The ONNX Runtime Mobile package is a size optimized inference library for executing ONNX (Open Neural Network Exchange) models on Android.Read more

com.microsoft.onnxruntime » onnxruntime-android


This package contains the Android (aar) build of ONNX Runtime. It includes support for all types and operators, for ONNX format models.

lib-sherpa-onnx - com.bihe0832.android


Latest Versions ; 6.22.x. 6.22.3. 1. Jan 07, 2025 ; 6.22.x · 6.22.2. 1. Jan 06, 2025.Read more

Maven Repository: com.github.gkonovalov.android-vad


Android Voice Activity Detection (VAD) library. Supports WebRTC VAD GMM, Silero VAD DNN, Yamnet VAD DNN models. Last Release on Jan 14, 2025.Read more

repo1.maven.org
repo1.maven.org
https://repo1.maven.org/maven2/com/microsoft/ ...


As such the binary size and memory usage will be larger than the onnxruntime-mobile package.</description> <url>https://microsoft.github.io/onnxruntime ...Read more

libraries.io
libraries.io
com.microsoft.onnxruntime:onnxruntime-android-qnn


25 Oct 2024 — This package contains the Android (aar) build of ONNX Runtime with ... Repository size: 1.44 GB; SourceRank: 14. Releases. 1.26.0: May 8 ...Read more

pub.dev
pub.dev
sherpa_onnx_android_armeabi changelog | Flutter package


15 Jun 2026 — Support 16KB page size for Android (#2520); Split sherpa-onnx ... Provide sherpa-onnx.aar for Android (#1615); Use aar in Android Java ...Read more

sherpa_onnx | Flutter package


React Native wrapper and demo app for validating sherpa-onnx on iOS, Android, and Web, including ASR, TTS, VAD, KWS, speaker ID, diarization, language ID, ...Read more

vad | Flutter package


VAD is a cross-platform Voice Activity Detection system, allowing Flutter applications to seamlessly handle various VAD events using Silero VAD v4/v5 ...

decibri.com
decibri.com
Sherpa-ONNX | decibri docs


1. Configuration. Define the paths to your model files and set the sample rate. Sherpa-ONNX streaming models typically expect 16 kHz mono audio.Read more

pkg.go.dev
pkg.go.dev
sherpa_onnx package - github.com/k2-fsa/sherpa-onnx/ ...


15 Jun 2026 — sampleRate is the actual sample rate of the input audio samples. If it is different from the sample rate expected by the feature extractor, we ...Read more

docs.m5stack.com
docs.m5stack.com
sherpa-onnx - m5-docs


9 Dec 2025 — Current sample rate: 16000 Recording started! Use recording device: plughw:2,0 Started. Please speak 0: hello 1: how are you ^C Caught Ctrl ...Read more

sherpa-onnx - m5-docs


9 Dec 2025 — The reference docs for M5Stack products. Quick start, get the detailed information or instructions such as IDE,UIFLOW,Arduino.

Silero-vad - m5-docs


Silero VAD (Voice Activity Detection) is a model used to detect whether human speech is present in an audio stream. It is suitable for application scenarios

scribd.com
scribd.com
Sherpa-ONNX Hotwords Biasing Guide | PDF | We Chat


The following Python code shows how to use sherpa-ncnn Python API to recognize a wave file. Caution: The sampling rate of the wave file has to be 16 kHz. Also, ...Read more

Unified Two-Pass Model for Speech Recognition | PDF


The proposed two-pass architecture is shown in Figure 1. It t + 1, t + 2 ... faster and more accurate. also propose a dynamic chunk based strategy to ...Read more

devblogs.microsoft.com
devblogs.microsoft.com
Bringing ONNX models to Android - Surface Duo Blog


16 Feb 2023 — Examples using the ONNX runtime mobile package on Android include the image classification and super resolution demos.

oliviajain.github.io
oliviajain.github.io
ORT format models - onnxruntime


The ORT format is the format supported by reduced size ONNX Runtime builds. Reduced size builds may be more appropriate for use in size-constrained ...Read more

builds.shipilev.net
builds.shipilev.net
New cr-examples/onnx/src/main/java/oracle/code ...


... Creating ONNX session " + domainName); 532 // cached session must be created under its own auto arena 533 Session session = (options != null) ? 534 ...Read more

learn.arm.com
learn.arm.com
Build an Android chat application with ONNX Runtime API


This is an advanced topic for software developers interested in learning how to build an Android chat app with ONNX Runtime and ONNX Runtime Generate() API.Read more

theten.ai
theten.ai
TEN VAD | TEN Framework


Low-latency, high-performance Voice Activity Detector for real-time speech detection. ... TEN VAD delivers exceptional precision compared to industry alternatives ...Read more

thegradient.pub
thegradient.pub
One Voice Detector to Rule Them All


19 Feb 2022 — What is a VAD and what defines a good VAD? · High quality. · Low user perceived latency, i.e. CPU latency + audio chunk size. · Good generalization ...Read more

dev.to
dev.to
How to measure performance of Voice Activity Detection ...


2 Feb 2023 — It's more accurate than its predecessor, making it much more accurate than webRTC VAD. That's why on day 24 we'll discuss how to measure VAD ...Read more

qed42.com
qed42.com
Voice activity detection in text-to-speech: how real-time ...


1 Sept 2025 — Call centres get 95% accuracy. Hospitals cut documentation time by 40% using Silero VAD. Banks achieve 99.5% accuracy for voice transactions.. ...

assets.amazon.science
assets.amazon.science
A comprehensive empirical review of modern voice activity ...


by M Sharma · 2022 · Cited by 39 — WebRTC VAD [35] is an example of GMM based VAD model with input features as log energies of six frequency bands between 80 Hz and 4000 Hz. It uses fixed point ...Read more

creativecommons.org
creativecommons.org
Deed - Attribution-NonCommercial 4.0 International


This deed highlights only some of the key features and terms of the actual license. It is not a license and has no legal value.Read more

catalog.ngc.nvidia.com
catalog.ngc.nvidia.com
Multilingual Silero VAD - NGC Catalog - NVIDIA


11 Dec 2024 — Description: This model can be used for Voice Activity Detection (VAD), and serves as the first step for Automatic Speech Recognition (ASR).Read more

docs.livekit.io
docs.livekit.io
Silero VAD plugin


Overview. The Silero VAD plugin provides voice activity detection (VAD) that contributes to accurate turn detection in voice AI applications.Read more

Module livekit.plugins.silero


Sample rate for the inference (only 8KHz and 16KHz are supported). ... This method allows you to update the VAD options after the VAD object has been created.

teammates.ai
teammates.ai
VAD voice activity detection for clearer agent calls


13 Feb 2026 — The Quick Answer. VAD voice activity detection is the component that decides when someone is speaking and when they stopped.Read more

docs.videosdk.live
docs.videosdk.live
Silero VAD | Video SDK


3 Jun 2026 — Learn how to use Silero's VAD with the VideoSDK AI Agent SDK. This guide covers model configuration, related events.

Silero VAD


14 Mar 2026 — The Silero VAD (Voice Activity Detection) provider enables your agent to detect when users start and stop speaking. prefix_padding_duration. ...

cocoa.ethz.ch
cocoa.ethz.ch
VADLite: An Open-Source Lightweight System for Real- ...


by G Boateng · 2019 · Cited by 14 — In this work, we present VADLite, an open-source, lightweight, system that performs real-time VAD on smartwatches. It extracts mel-frequency cepstral coeffi-.Read more

rajatpandit.com
rajatpandit.com
How to use Silero VAD for real-time voice activity detection


26 Feb 2026 — The Fast VAD (Silero/WebRTC): Evaluates every 20ms frame. Identifies gaps. The Intermediate Trigger: If the VAD detects 500ms of contiguous ...Read more

discuss.huggingface.co
discuss.huggingface.co
I built an open source VAD that beats Silero, Pyannote, and ...


21 Jun 2026 — I built an open source VAD that beats Silero, Pyannote, and WebRTC on noisy audio with 93% accuracy — no GPU required ; Silero VAD, 87.0%, : ...

javadoc.io
javadoc.io
VoiceActivityDetector (Spokestack Library for Android 3.0.1 ...


VoiceActivityDetector is a speech pipeline component that implements Voice Activity Detection (VAD) using the webrtc native component.Read more

mlrun.org
mlrun.org
Silero vad


:param sampling_rate: Currently, silero VAD models support 8000 and 16000 sample rates. :param min_speech_duration_ms: Final speech chunks shorter ...

mlrun.github.io
mlrun.github.io
silero_vad.silero_vad


speech_pad_ms: Final speech chunks are padded by speech_pad_ms each side. Perform speech diarization on given audio files using the silero VAD model

docs.dotsimulate.com
docs.dotsimulate.com
Vad Silero Operator


7 May 2026 — Speech Pad (ms) — extra padding added to the start and end of detected speech segments. Useful for capturing the onset of words that begin ...Read more

docs.knovvu.com
docs.knovvu.com
VAD Silero


10 Dec 2025 — After the end of speech is detected VAD takes a little more data after the detected end just in case a low energy voice happens to be there.Read more

linkedin.com
linkedin.com
Open Source Speech to Text Models for Live Applications


Today I'm proud to launch Moonshine Voice, a new family of on-device speech to text models designed for live voice applications, ...

news.ycombinator.com
news.ycombinator.com
Show HN: Moonshine Open-Weights STT models


Implemented this to transcribe voice chat in a project and the streaming accuracy in English on this was unusable, even with the medium streaming model.Read more

northflank.com
northflank.com
Best open source speech-to-text (STT) model in 2026 (with ...


6 Jan 2026 — Moonshine targets mobile and embedded deployment with models as small as 27 million parameters. Despite compact size, achieves competitive ...

pub.towardsai.net
pub.towardsai.net
How 10 B-Parameter Models Are Outperforming 100 B Giants


10 Nov 2025 — Complementing MoE is the growing prominence of Small Language Models (SLMs) — models typically under 10 billion parameters, fine-tuned for ...Read more

modelnova.ai
modelnova.ai
Moonshine Tiny Speech To Text | Models


Moonshine Tiny is an ultra-efficient speech-to-text model built for low-power edge devices, offering real-time streaming with minimal latency. Model Size 1x80x ...

gigazine.net
gigazine.net
Moonshine Voice is a free, open-source AI toolkit ...


25 Feb 2026 — Moonshine Voice is an open source AI toolkit that allows you to create applications that handle voice in real time. GitHub ...

onresonant.com
onresonant.com
Best Local Speech-to-Text Models in 2026 - Resonant


25 Feb 2026 — At 245M parameters, it's roughly 6x smaller than Whisper Large v3 ... Moonshine's smallest model runs comfortably on modern laptops without a ...Read more

kdnuggets.com
kdnuggets.com
Best Small Language Models on Hugging Face Right Now!


21 May 2026 — For the purposes of this article, "small" means under 7 billion parameters — models that can run on a single consumer GPU, a laptop, or even a ...Read more

isca-archive.org
isca-archive.org
Two-Pass End-to-End Speech Recognition


by TN Sainath · 2019 · Cited by 193 — Specifically, we explore a two-pass architecture in which an RNN-T decoder and a LAS decoder share an encoder net- work. Sharing the encoder allows us to reduce ...Read more

research.google
research.google
Deliberation Model Based Two-Pass End-to-End Speech ...


by K Hu · Cited by 120 — To further improve the quality of an E2E model, two-pass decoding has been proposed to rescore streamed hypotheses using a non-streaming E2E model while ...Read more

repository.kulib.kyoto-u.ac.jp
repository.kulib.kyoto-u.ac.jp
Fast and Low-Latency End-to-End Speech Recognition and ...


external VAD model. Moreover, it outperforms cascading VAD and ASR models in ... applied to two-pass E2E architectures in the ... refinement model while ...

ai.gopubby.com
ai.gopubby.com
How I Improved Speech-to-Text Accuracy with a 2-Pass ...


9 Apr 2026 — How I Improved Speech-to-Text Accuracy with a 2-Pass LLM Pipeline. A post-processing method that reduced speech-to-text errors across multiple ...Read more

formulae.brew.sh
formulae.brew.sh
homebrew-core


Two-pass large vocabulary continuous speech recognition engine. juman, 7.01 ... Reboot of ML, unifying its core and (now first-class) module layers.Read more

dl.acm.org
dl.acm.org
Compressed, Real-Time Voice Activity Detection with Open ...


11 Oct 2023 — This paper proposes a real-time voice activity detection (VAD) system that utilizes a compressed convolutional neural network (CNN) model.Read more

lib.rs
lib.rs
Audio — list of Rust libraries/crates ...


A lossless, format-preserving, two-pass Vorbis optimization and repair library ... Automatic Gain Control 2 (AGC2) with RNN VAD for WebRTC Audio Processing.Read more

googlesource.com
googlesource.com
webrtc/common_audio/vad/include/webrtc_vad.h


// - mode [i] : Aggressiveness mode (0, 1, 2, or 3). //. // returns : 0 - (OK),. // -1 - (NULL pointer, mode could not be set or the VAD instance. // has not ...Read more

sonatype.com
sonatype.com
com.kimlulu:tts-engine:1.0.0 - Maven Central


Discover tts-engine in the com.kimlulu namespace. Explore metadata, contributors, the Maven POM file, and more.

ycombinator.com
ycombinator.com
Hi, I built the client UI for this and... yea, I really wanted to ...


27 Jun 2024 — Silero runs via onnx-runtime (with wasm). Whilst it sort-of-kinda works in Firefox, the VAD seems to misfire more than it should, causing ...Read more

videosdk.live
videosdk.live
WebRTC Voice Activity Detection: Real-Time Speech ...


The core of the algorithm analyzes short frames of audio (typically 10-30ms), extracting features like energy levels, zero-crossing rate, and spectral ...Read more

aalto.fi
aalto.fi
8.1. Voice Activity Detection (VAD)


In speech enhancement, where we want to reduce or remove noise in a speech signal, we can estimate noise characteristics from non-speech parts (learn/adapt) and ...Read more

nvidia.com
nvidia.com
VAD Segmentation | NeMo Curator


Lower thresholds keep more borderline audio (potentially more false positives); higher thresholds keep only confident speech (potentially missing quieter ...Read more

maven.org
maven.org
com/microsoft/onnxruntime/onnxruntime-android/1.14.0


Central Repository: com/microsoft/onnxruntime/onnxruntime-android/1.14.0 ・ android-1.14.0-javadoc.jar ・ onnxruntime-android-1.14.0-sources.jar.asc.md...

fs-eire.github.io
fs-eire.github.io
Install ONNX Runtime (ORT)


Download the onnxruntime-training-android (full package) AAR hosted at Maven Central. Change the file extension from .aar to .zip , and unzip it. Include the ...Read more

Build for Android | onnxruntime


Build Android Archive (AAR). Android Archive (AAR) files, which can be imported directly in Android Studio, will be generated in your_build_dir/java/build/ ...Read more

google.com
google.com
MoonShine - Speech to Text – Apps on Google Play


19 Mar 2026 — Optimized for mobile and desktop, MoonShine transcribes your speech in real-time without draining your battery or slowing down your device.Read more

Android Help


Official Android Help Center where you can find tips and tutorials on using Android and other answers to frequently asked questions.

webrtc-developers.com
webrtc-developers.com
Comparison of WebRTC Codecs for Video and Screen Sharing


16 Apr 2025 — In this article, I'll compare video and screen-sharing performance across Windows and Mac platforms, detailing some of the issues encountered with particular ...Read more

jarcasting.com
jarcasting.com
onnxruntime-android » 1.11.0 - aar download


This package contains the Android (aar) build of ONNX Runtime. It includes support for all types and operators, for ONNX format models. Browse Apache Maven

nuget.org
nuget.org
EchoSharp.Onnx.SileroVad 0.1.0


26 Dec 2024 — SileroVad is a Voice Activity Detection (VAD) component that uses Silero VAD to distinguish between speech and non-speech segments in audio ...Read more

habr.com
habr.com
Modern Portable Voice Activity Detector Released


14 Jan 2021 — WebRTC though starts to show its age and it suffers from many false positives. ... VAD Quality Benchmarks. We use random 250 ms audio chunks ...Read more

nosub.net
nosub.net
Cmake编译sharpa-onnx - Nosub技术博客


3 Apr 2025 — Sherpa-ONNX 提供以下核心功能：. 语音活动检测(VAD)：通过Silero VAD 模型检测音频中的语音片段，减少背景噪声干扰。 非流式和 ...

daily.co
daily.co
What is a WebRTC PaaS? - Daily.co


Using a WebRTC PaaS simplifies the development process for video, audio, screen sharing, and related features. Just as a software engineer might leverage a ...Read more

ruoqijin.com
ruoqijin.com
ASR in 2025-2026: A Deep Dive into Speech Recognition ...


13 Apr 2026 — ... two-pass architecture). AISHELL-1 CER 4.63%, accuracy is no longer ... WebRTC VAD. A lightweight VAD released early by Google, BSD ...Read more

gitee.com
gitee.com
superlee/libfvad


This is a fork of the VAD engine that is part of the WebRTC Native Code package (https://webrtc.org/native-code/), for use as a standalone library independent ...Read more

sciencedirect.com
sciencedirect.com
A comprehensive empirical review of modern voice activity ...


by M Sharma · 2022 · Cited by 40 — In this paper, we provide a comprehensive empirical analysis of various deep neural models [23], [24] for the task of VAD when applied to DEC.Read more

cloudflare.com
cloudflare.com
How WebRTC works: What is WebRTC used for?


WebRTC is a protocol for peer-to-peer data exchange. Because it has very little latency by design, it is often used for live video streaming.Read more

bloggeek.me
bloggeek.me
ML in WebRTC: The noise suppression gold rush


31 Aug 2020 — Communication vendors are waking up to the need to invest in ML/AI in media processing. The challenge will be to get ML in WebRTC.

projectnaomi.com
projectnaomi.com
WebRTCVAD - Voice Activity Detection - Project Naomi


aggressiveness: how aggressively to filter out non-speech. 0 is the least aggressive and 3 is the most aggressive. The options under webrtc_vad are all ...Read more

codesota.com
codesota.com
Voice Activity Detection Benchmarks - Audio


Background music and TV speech can trigger false positives — distinguishing target speech from played-back audio. Whispered and quiet speech near the noise ...Read more

Connector sources scanned

No connector sources scanned









