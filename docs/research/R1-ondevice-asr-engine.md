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







# Android On-Device Streaming ASR Shootout for the Omi Repo

## Bottom line

For a personal Android app that needs **offline live transcription**, live partials, low lag, and a path that can stay swappable behind an `AsrEngine` interface, the best default **today** is **Moonshine Voice v2**, with **Moonshine Streaming Small** as the first thing to try on a modern phone, and **Moonshine Streaming Tiny** as the battery-safe fallback. The main reasons are simple: it is purpose-built for streaming, its public latency data are far better than Whisper-class baselines, the Android path is unusually clean because it ships as a Maven package with an official Android sample, and its **English models are MIT-licensed**, which keeps the future public/free-app path clean. citeturn10view0turn31view0turn37view0turn39search3

The best hedge is **sherpa-onnx**, but not as the default. Treat it as the **swap-in platform** for cases where you later need bundled **VAD**, real **keyword spotting / wake-word**, broader model choice, or vendor-specific NPU paths such as Qualcomm QNN. The tradeoff is that sherpa-onnx is a toolkit, not one clean model family, so latency, quality, app size, and legal safety vary a lot by model. Its code is Apache-2.0, but model licenses range from Apache-2.0 to CC-BY-4.0 to CC-BY-SA to vendor terms, so you have to pick carefully. citeturn30view0turn15view0turn36search2turn36search1

Keep **whisper.cpp** only for **batch re-transcription** of saved, low-confidence clips. It remains very useful for offline second-pass cleanup, but it is still structurally a *worse fit* for the live path: Whisper is not natively streaming, `whisper.cpp`’s Android path is still example- and build-heavy, and public mobile evidence still points to much higher live-update cost than streaming-native engines. citeturn10view0turn44view0turn23search0turn17search4turn29search0turn29academia9

## Comparison table

| Engine | Model | Live path fit | Public latency evidence | Accuracy evidence for real-world English | Battery / thermal evidence | Size / memory evidence | Android integration | License safety |
|---|---|---|---|---|---|---|---|---|
| **Moonshine Voice v2** | **Streaming Tiny** | **True streaming** | Moonshine v2 Tiny measured **50 ms** end-of-utterance response latency on Apple M3; the streaming architecture uses bounded sliding-window attention and the official transcriber updates every **500 ms** by default. Public numeric first-partial timings on Android phones were *not* found in the official docs I reviewed. citeturn10view0turn4view0 | Open ASR average WER **12.01%**; AMI far-field meetings **19.03%**. citeturn10view0 | Moonshine reports compute load **8.03%** in its live benchmark on M3, but I did *not* find public Android mWh/%-per-hour numbers. citeturn10view0 | **34M** params in the v2 model card; repo also says Moonshine goes “down to tiny **26MB** models” for constrained deployments. Public Android RAM figures were *not* published. citeturn39search3turn31view4 | **Best**: official Maven package and official Android sample. citeturn31view0 | Code **MIT**; English model **MIT**. **Safe** for personal use, public/free app, and commercial use. citeturn37view0turn38search0 |
| **Moonshine Voice v2** | **Streaming Small** | **True streaming** | Moonshine v2 Small measured **148 ms** response latency on M3. Same Android caveat: clean Android integration exists, but public per-phone numeric first-partial data are sparse. citeturn10view0turn31view0 | Open ASR average WER **7.84%**; AMI far-field **12.54%**. This is the **best balance** of quality and likely mobile cost in the public Moonshine line. citeturn10view0 | Compute load **17.97%** on M3. No public Android battery numbers found. citeturn10view0 | **123M** params. Official Android RAM footprint not published. citeturn39search3 | **Low effort**: Maven + sample app. citeturn31view0 | Code **MIT**; English model **MIT**. **Safe** across all three scenarios. citeturn37view0turn38search0 |
| **Moonshine Voice v2** | **Streaming Medium** | **True streaming** | Moonshine v2 Medium measured **258 ms** response latency on M3; still dramatically faster than Whisper Large v3 in the same live benchmark. citeturn10view0 | Open ASR average WER **6.65%**; AMI far-field **10.68%**. Best Moonshine accuracy, but likely the heaviest mobile option in this family. citeturn10view0 | Compute load **28.95%** on M3. No public Android battery data found. citeturn10view0 | **245M** params. Public Android RAM figures not published. citeturn39search3 | **Low effort** from the SDK side. Device fit must be tested. citeturn31view0 | Code **MIT**; English model **MIT**. **Safe** across all three scenarios. citeturn37view0turn38search0 |
| **sherpa-onnx** | **Streaming Zipformer / Kroko family** | **True streaming** | Public Android/embedded reports are good enough to show it can run real time: old small bilingual Zipformer on RK3588 CPU reached **RTF 0.10**; on RK3576 issue reports, small bilingual Zipformer reached about **RTF 0.16–0.28** depending on model/config; there are also 2026 Android QNN streaming demos in release notes. I did *not* find a clean official Pixel/Samsung latency table with first partial and lag numbers. citeturn24search3turn24search2turn13search1 | For the newer Kroko community streaming models, I did *not* find a public Apple-to-Apple benchmark table as complete as Moonshine’s. Banafo positions Kroko as fast, lightweight, Android-ready, and streaming; one public sherpa issue using the 2025 English Kroko model reports live use, but not a full WER table. citeturn15view0turn24search1 | No public Android power table found in the official docs I reviewed. Delegate support is **better** than Moonshine’s: CPU, RKNN, and new Qualcomm **QNN** support are in public docs/releases. citeturn13search1turn12search3turn30view0 | Model size varies a lot. Community summaries put INT8 Kroko English variants around **147 MB** each, but this is not the official sherpa doc. citeturn14search4 | **Medium to high effort**: lots of official docs, demos, APKs, and AARs, but more moving parts than Moonshine. citeturn30view0turn32search5 | Code **Apache-2.0**. Kroko community models are **CC-BY-SA**; Banafo also offers commercial/OEM models. **Personal** use is fine; a future public/free app is *less clean* than MIT/Apache because CC-BY-SA brings attribution and share-alike risk. *Never-commercial* is fine. citeturn30view0turn15view0 |
| **sherpa-onnx** | **NVIDIA Parakeet TDT 0.6B v2 / v3 INT8** | **Simulated streaming**, not true low-lag streaming | Sherpa publishes Android APKs and model docs; official docs show the v2 INT8 export at about **631 MB** total files and report **RTF 0.118** on a 7.4 s sample with 2 threads on CPU, plus **RTF 0.088–0.220** on RK3588 Cortex-A76 depending on threads. But this is still a non-streaming transducer being run in simulated-streaming or VAD chunked flows. citeturn34view0turn35view0turn35view2 | Microsoft’s 2026 study found Parakeet TDT-0.6B-v3 very strong in batch mode, but in chunked “streaming-like” use its best average WERs were around **9.22–9.24%** with **~10 second** delay windows, which is *too laggy* for a good live UX. citeturn25view0 | No public Android mWh numbers in sherpa docs. CPU real-time factor is good on strong ARM cores; still much heavier than Moonshine-style edge models. citeturn35view0turn35view2 | Official sherpa docs list v2 INT8 file sizes: encoder **622 MB**, decoder **6.9 MB**, joiner **1.7 MB**. citeturn34view0 | **Moderate**: official Android APK exists through sherpa. citeturn34view0 | Code **Apache-2.0**; Parakeet model **CC-BY-4.0**. **Personal** and public/free app use are generally okay with attribution; commercial use is also allowed, but you must keep the attribution terms straight. citeturn30view0turn36search2turn36search0 |
| **whisper.cpp** | **tiny.en / base.en / small.en** | *Poor live fit*; **good batch hedge** | `whisper.cpp` itself supports Android and ships an Android example, but live/mobile evidence is weak for a pleasant streaming UX. The project’s own benchmark tables in the Moonshine v2 paper put Whisper Tiny at **289 ms**, Whisper Small at **1940 ms**, and Whisper Large v3 at **11286 ms** response latency in a live scenario on M3. A real user report from the Android demo said a Samsung Galaxy S8 took **1 min 25 s** to transcribe the sample audio with the tiny model. citeturn10view0turn23search0 | Whisper remains strong in offline quality, but the Microsoft 2026 on-device streaming study shows chunked faster-whisper small degrading badly in streaming-like use to **24.74%** average WER. citeturn25view0 | Public Android battery numbers are sparse, but a brand-new mobile study shows Whisper-style mobile streaming baselines on a Galaxy S25 CPU spending **2141.7–2832.6 ms** just on encoder execution per update and missing a **2 s** inference interval. citeturn29search0turn29academia9 | Official `whisper.cpp` ggml disk sizes: **75 MiB** tiny, **142 MiB** base, **466 MiB** small, **1.5 GiB** medium, **1.5 GiB** large-v3-turbo. citeturn43view0 | **Higher effort**: Android example exists, but multiple build and device-specific issues remain public, including demo build trouble and Android CLBlast `dlopen` failures. citeturn44view1turn17search0turn17search4 | Code **MIT**; OpenAI Whisper code and model weights are **MIT**; **safe** for personal, public/free app, and commercial use. citeturn42search14turn42search0 |
| **New watchlist** | **NPUsper** | **Promising future live path**, not drop-in today | A 2026 research system for Whisper on mobile NPUs reports up to **33.2×** lower TTFT, up to **4.84×** lower per-word latency, and on Galaxy S25 CPU reduces average encoder execution to **161.6 ms** plus decoder **37.1 ms**, versus Whisper-style CPU baselines that exceed the inference interval. citeturn29academia9turn29search0 | The paper says it keeps comparable transcription accuracy while fixing latency and power. citeturn29academia9 | It also reports up to **88.64% lower average power** than baselines. That is the strongest public mobile power claim I found in this sweep. citeturn29academia9 | Research system; no stable Android SDK or Maven path found in the sources I reviewed. citeturn29academia9 | **High effort / research-only** right now. citeturn29academia9 | License and shipping readiness need separate review before product use. citeturn29academia9 |

## What the evidence says

The clearest thing in the public numbers is this: **streaming-native architectures beat offline Whisper-style architectures for live UX**. Moonshine v2’s public benchmark shows end-of-utterance response latencies of **50 ms**, **148 ms**, and **258 ms** for Tiny, Small, and Medium on Apple M3, versus **289 ms** for Whisper Tiny, **1940 ms** for Whisper Small, and **11286 ms** for Whisper Large v3. That is not a subtle gap. It is the difference between “feels live” and “feels late.” citeturn10view0

Moonshine v2 is also not winning by being a toy model. Its public English WERs are strong: Tiny averages **12.01%**, Small **7.84%**, and Medium **6.65%** across eight Open ASR benchmarks. On **AMI**, which is the closest public proxy here for *messy conversational, far-mic, meeting-like* audio, those scores are **19.03%**, **12.54%**, and **10.68%**. On a modern phone, that makes Small the most sensible default to test first, because it gives a large jump over Tiny on AMI without jumping all the way to Medium’s heavier footprint. citeturn10view0turn39search3

For `sherpa-onnx`, the story is more mixed because “sherpa” is a **runtime plus model zoo**, not one model. The toolkit is strong: it supports streaming and non-streaming ASR, VAD, keyword spotting, APKs, AARs, and now vendor NPU paths such as RKNN and QNN. But the best-documented fast Android-ish results in the public sources I reviewed are mostly **RTF** reports on RK boards and sample commands, not neat phone-side tables with first-partial lag and steady-state lag. That means sherpa is **flexible**, but the burden of choosing and validating the right model stays with you. citeturn30view0turn32search5turn24search3turn24search2turn13search1

Parakeet, when routed through sherpa, is a good example of that tradeoff. The Android path is real, and the INT8 export is documented. But it is still mainly a **chunked / simulated-streaming** answer on Android today, not the same thing as a low-lag true streaming engine. Microsoft’s 2026 study found Parakeet TDT-0.6B-v3 very good in offline quality, but in chunked use its best average WER came with **roughly 10-second** delay windows. That is too much lag for your primary live path, even if it is acceptable for deferred or button-press dictation. citeturn34view0turn25view0

`whisper.cpp` stays in the design, but as the **batch hedge**. The Android example exists, the code is MIT, the model sizes are clearly documented, and it is a strong offline transcriber. But both the official Whisper architecture and the fresh NPUsper results point the same way: Whisper-family live streaming on mobile wastes too much work unless you add special research-grade tricks. That is why it belongs behind your low-confidence clip recheck path, not the always-on live lane. citeturn44view1turn43view0turn29search0turn29academia9

## Licensing and product safety

**Moonshine** is the cleanest answer if your core use case is **English live transcription**. The code is MIT, and the English-language models are also MIT. That makes it **safe** for personal use now, a future public/free app, and commercial use later. The catch is multilingual. Moonshine’s non-English models are under the **Moonshine Community License**, which the project itself describes as *non-commercial*. So if multilingual becomes a product requirement, Moonshine’s legal picture gets *worse* fast unless you stay English-only or negotiate separate terms. citeturn37view0turn38search0

**sherpa-onnx** flips that pattern. The engine code is **Apache-2.0**, which is clean. But the models are a patchwork. NVIDIA Parakeet v2/v3 are **CC-BY-4.0**, which is usually workable for products if you handle attribution correctly. NVIDIA Nemotron Speech Streaming says it is ready for commercial and non-commercial use under the **NVIDIA Open Model License Agreement**. Banafo’s Kroko community models are **CC-BY-SA**, which is okay for personal and hobby work but is a *less comfortable* fit for a future public/free app because of attribution and share-alike baggage. Sherpa’s own docs explicitly warn you to check the selected model’s license. citeturn30view0turn36search2turn36search0turn36search1turn15view0

**whisper.cpp** is legally easy. The runtime is MIT, and OpenAI’s Whisper code and model weights are MIT too. So it is **safe** for personal use, public/free distribution, and commercial use. The reason not to choose it for the live default is not law. It is live UX and power. citeturn42search14turn42search0

A practical legal summary is straightforward. If you want the **lowest-friction path to a future public app**, pick **Moonshine English** first. If you want the **broadest model choice**, sherpa is fine, but lock your chosen model license in the repo docs and in an internal ADR before shipping. If you want a **never-commercial multilingual hobby project**, Moonshine non-English or Kroko community models can make sense, but both are *less safe* for later productization than Moonshine English or Apache/MIT paths. citeturn37view0turn15view0turn30view0

## Android integration reality

Moonshine’s Android story is the cleanest one I found. The project says it publishes an Android package to Maven, shows the version-catalog Gradle wiring, and points to an official `examples/android/Transcriber` sample. That is the sort of setup you want when the goal is to validate product risk, not sink time into JNI glue. citeturn31view0

A minimal official-style dependency setup for the top pick looks like this:

```toml
# gradle/libs.versions.toml
[versions]
moonshineVoice = "0.0.45"

[libraries]
moonshine-voice = { group = "ai.moonshine", name = "moonshine-voice", version.ref = "moonshineVoice" }
```

```kotlin
// app/build.gradle.kts
dependencies {
    implementation(libs.moonshine.voice)
}
```

That exact pattern is what the project documents, and the repo points you to the official Android sample for the rest of the wiring. citeturn31view0

Sherpa-onnx also has a **real** Android path, but it is more of a toolbox. The repo and docs link to prebuilt Android APKs, build docs, Flutter apps, keyword spotting docs, and streaming/simulated-streaming examples. That is powerful, especially if you want one stack that can later cover ASR, VAD, and wake-word. But it is also more work. You will need to choose the model family, check the model license, decide whether you want CPU-only or a vendor delegate, and validate device-specific behavior. Sherpa’s public issue tracker also shows modern Android integration wrinkles, including a Snapdragon 8 Elite / Android 16 crash that needed a newer ONNX Runtime build, plus the new QNN streaming additions arriving only recently in 2026. citeturn30view0turn32search5turn41view2turn41view1turn13search2turn13search1

`whisper.cpp` has an Android example and broad platform support, but the Android path is still more fragile. The repo lists Android support and an `whisper.android` example. At the same time, public issues/discussions show build friction, missing dependency gotchas, and device-specific CLBlast/OpenCL failures. That is acceptable for a batch sidecar or an internal prototype, but it is *not* the path I would pick for a fast-moving app that mostly needs dependable live English captions on one modern phone class. citeturn44view0turn44view1turn17search0turn17search4turn23search0

## Recommendation for the repo

The right framing for the Omi repo is:

**Pick Moonshine now, keep sherpa swappable behind an interface, keep whisper.cpp as the slow-but-strong second pass.** citeturn31view0turn30view0turn42search14

A practical split looks like this:

```kotlin
interface AsrEngine {
    fun start()
    fun pushPcm16(samples: ShortArray, sampleRateHz: Int)
    fun stop()
    fun close()

    interface Listener {
        fun onPartial(text: String)
        fun onFinal(text: String, confidenceHint: Float? = null)
        fun onError(t: Throwable)
    }
}
```

Then wire three implementations:

- `MoonshineAsrEngine` for the **default live path**
- `SherpaAsrEngine` for the **multilingual / VAD / KWS / hardware-delegate hedge**
- `WhisperCppBatchEngine` for **saved low-confidence clip re-checks** after the fact

That gives you the **best** immediate UX and keeps the loser swappable, exactly as your roadmap wants. The repo-level decision I would make is:

**Default:** `Moonshine Streaming Small`  
**Fallback on weak thermals / battery:** `Moonshine Streaming Tiny`  
**Batch cleanup hedge:** `whisper.cpp` with `base.en` or `small.en`, only on saved clips  
**Future feature hedge:** `sherpa-onnx` once you need wake-word, broader language coverage, or QNN/RKNN experiments. citeturn10view0turn31view4turn43view0turn41view1

The reason I would not default to Moonshine Medium first is not accuracy. It is risk. Small already lands at **7.84%** average WER and **12.54%** on AMI far-field, while staying much lighter than Medium. That makes Small the sensible first target for a modern mid-to-high-end Android phone. If your phone handles it comfortably in your own soak tests, great. If not, Tiny is a clean fallback. citeturn10view0turn39search3

## What might beat this next

The most important new thing to watch is **NPUsper**. It is a 2026 research system that makes Whisper much more mobile-friendly on NPUs by cutting redundant compute. Its paper claims up to **33.2×** lower TTFT, up to **4.84×** lower per-word latency, and up to **88.64%** lower average power than its baselines. On a Galaxy S25 CPU, the paper says Whisper-style baselines blow past the update interval, while NPUsper gets the encoder down to **161.6 ms** and decoder to **37.1 ms** per update. If that work turns into a clean Android runtime, it could become a serious future hedge for your batch/live boundary. Right now, though, it looks like **research**, not a ready Android app dependency. citeturn29academia9turn29search0

The other one worth watching is **NVIDIA Nemotron Speech Streaming**. Microsoft’s April 2026 report says their ONNX Runtime rework of **Nemotron Speech Streaming** is the strongest candidate they tested for CPU-only English streaming on constrained hardware, with an **int4** configuration reaching **8.20%** average streaming WER, **0.56 s** algorithmic latency, and a size reduced from **2.47 GB** to **0.67 GB**. That is genuinely strong. The problem is that I did not find the same level of Android-ready packaging, phone-side field reports, or easy SDK path that Moonshine already has. So it is a **watchlist item**, not today’s default. citeturn27view0turn36search1

If you want the shortest product answer: **Ship Moonshine Small first. Keep sherpa behind the same interface. Use whisper.cpp only for second-pass cleanup.** That closes the roadmap unknown with the **lowest** engineering and licensing risk I could support from the public evidence. citeturn31view0turn37view0turn30view0turn42search0







Android On-Device Streaming ASR Shootout for the Omi Repo
Bottom line
For a personal Android app that needs offline live transcription, live partials, low lag, and a path that can stay swappable behind an AsrEngine interface, the best default today is Moonshine Voice v2, with Moonshine Streaming Small as the first thing to try on a modern phone, and Moonshine Streaming Tiny as the battery-safe fallback. The main reasons are simple: it is purpose-built for streaming, its public latency data are far better than Whisper-class baselines, the Android path is unusually clean because it ships as a Maven package with an official Android sample, and its English models are MIT-licensed, which keeps the future public/free-app path clean. 

The best hedge is sherpa-onnx, but not as the default. Treat it as the swap-in platform for cases where you later need bundled VAD, real keyword spotting / wake-word, broader model choice, or vendor-specific NPU paths such as Qualcomm QNN. The tradeoff is that sherpa-onnx is a toolkit, not one clean model family, so latency, quality, app size, and legal safety vary a lot by model. Its code is Apache-2.0, but model licenses range from Apache-2.0 to CC-BY-4.0 to CC-BY-SA to vendor terms, so you have to pick carefully. 

Keep whisper.cpp only for batch re-transcription of saved, low-confidence clips. It remains very useful for offline second-pass cleanup, but it is still structurally a worse fit for the live path: Whisper is not natively streaming, whisper.cpp’s Android path is still example- and build-heavy, and public mobile evidence still points to much higher live-update cost than streaming-native engines. 

Comparison table
Engine	Model	Live path fit	Public latency evidence	Accuracy evidence for real-world English	Battery / thermal evidence	Size / memory evidence	Android integration	License safety
Moonshine Voice v2	Streaming Tiny	True streaming	Moonshine v2 Tiny measured 50 ms end-of-utterance response latency on Apple M3; the streaming architecture uses bounded sliding-window attention and the official transcriber updates every 500 ms by default. Public numeric first-partial timings on Android phones were not found in the official docs I reviewed. 
Open ASR average WER 12.01%; AMI far-field meetings 19.03%. 
Moonshine reports compute load 8.03% in its live benchmark on M3, but I did not find public Android mWh/%-per-hour numbers. 
34M params in the v2 model card; repo also says Moonshine goes “down to tiny 26MB models” for constrained deployments. Public Android RAM figures were not published. 
Best: official Maven package and official Android sample. 
Code MIT; English model MIT. Safe for personal use, public/free app, and commercial use. 
Moonshine Voice v2	Streaming Small	True streaming	Moonshine v2 Small measured 148 ms response latency on M3. Same Android caveat: clean Android integration exists, but public per-phone numeric first-partial data are sparse. 
Open ASR average WER 7.84%; AMI far-field 12.54%. This is the best balance of quality and likely mobile cost in the public Moonshine line. 
Compute load 17.97% on M3. No public Android battery numbers found. 
123M params. Official Android RAM footprint not published. 
Low effort: Maven + sample app. 
Code MIT; English model MIT. Safe across all three scenarios. 
Moonshine Voice v2	Streaming Medium	True streaming	Moonshine v2 Medium measured 258 ms response latency on M3; still dramatically faster than Whisper Large v3 in the same live benchmark. 
Open ASR average WER 6.65%; AMI far-field 10.68%. Best Moonshine accuracy, but likely the heaviest mobile option in this family. 
Compute load 28.95% on M3. No public Android battery data found. 
245M params. Public Android RAM figures not published. 
Low effort from the SDK side. Device fit must be tested. 
Code MIT; English model MIT. Safe across all three scenarios. 
sherpa-onnx	Streaming Zipformer / Kroko family	True streaming	Public Android/embedded reports are good enough to show it can run real time: old small bilingual Zipformer on RK3588 CPU reached RTF 0.10; on RK3576 issue reports, small bilingual Zipformer reached about RTF 0.16–0.28 depending on model/config; there are also 2026 Android QNN streaming demos in release notes. I did not find a clean official Pixel/Samsung latency table with first partial and lag numbers. 
For the newer Kroko community streaming models, I did not find a public Apple-to-Apple benchmark table as complete as Moonshine’s. Banafo positions Kroko as fast, lightweight, Android-ready, and streaming; one public sherpa issue using the 2025 English Kroko model reports live use, but not a full WER table. 
No public Android power table found in the official docs I reviewed. Delegate support is better than Moonshine’s: CPU, RKNN, and new Qualcomm QNN support are in public docs/releases. 
Model size varies a lot. Community summaries put INT8 Kroko English variants around 147 MB each, but this is not the official sherpa doc. 
Medium to high effort: lots of official docs, demos, APKs, and AARs, but more moving parts than Moonshine. 
Code Apache-2.0. Kroko community models are CC-BY-SA; Banafo also offers commercial/OEM models. Personal use is fine; a future public/free app is less clean than MIT/Apache because CC-BY-SA brings attribution and share-alike risk. Never-commercial is fine. 
sherpa-onnx	NVIDIA Parakeet TDT 0.6B v2 / v3 INT8	Simulated streaming, not true low-lag streaming	Sherpa publishes Android APKs and model docs; official docs show the v2 INT8 export at about 631 MB total files and report RTF 0.118 on a 7.4 s sample with 2 threads on CPU, plus RTF 0.088–0.220 on RK3588 Cortex-A76 depending on threads. But this is still a non-streaming transducer being run in simulated-streaming or VAD chunked flows. 
Microsoft’s 2026 study found Parakeet TDT-0.6B-v3 very strong in batch mode, but in chunked “streaming-like” use its best average WERs were around 9.22–9.24% with ~10 second delay windows, which is too laggy for a good live UX. 
No public Android mWh numbers in sherpa docs. CPU real-time factor is good on strong ARM cores; still much heavier than Moonshine-style edge models. 
Official sherpa docs list v2 INT8 file sizes: encoder 622 MB, decoder 6.9 MB, joiner 1.7 MB. 
Moderate: official Android APK exists through sherpa. 
Code Apache-2.0; Parakeet model CC-BY-4.0. Personal and public/free app use are generally okay with attribution; commercial use is also allowed, but you must keep the attribution terms straight. 
whisper.cpp	tiny.en / base.en / small.en	Poor live fit; good batch hedge	whisper.cpp itself supports Android and ships an Android example, but live/mobile evidence is weak for a pleasant streaming UX. The project’s own benchmark tables in the Moonshine v2 paper put Whisper Tiny at 289 ms, Whisper Small at 1940 ms, and Whisper Large v3 at 11286 ms response latency in a live scenario on M3. A real user report from the Android demo said a Samsung Galaxy S8 took 1 min 25 s to transcribe the sample audio with the tiny model. 
Whisper remains strong in offline quality, but the Microsoft 2026 on-device streaming study shows chunked faster-whisper small degrading badly in streaming-like use to 24.74% average WER. 
Public Android battery numbers are sparse, but a brand-new mobile study shows Whisper-style mobile streaming baselines on a Galaxy S25 CPU spending 2141.7–2832.6 ms just on encoder execution per update and missing a 2 s inference interval. 
Official whisper.cpp ggml disk sizes: 75 MiB tiny, 142 MiB base, 466 MiB small, 1.5 GiB medium, 1.5 GiB large-v3-turbo. 
Higher effort: Android example exists, but multiple build and device-specific issues remain public, including demo build trouble and Android CLBlast dlopen failures. 
Code MIT; OpenAI Whisper code and model weights are MIT; safe for personal, public/free app, and commercial use. 
New watchlist	NPUsper	Promising future live path, not drop-in today	A 2026 research system for Whisper on mobile NPUs reports up to 33.2× lower TTFT, up to 4.84× lower per-word latency, and on Galaxy S25 CPU reduces average encoder execution to 161.6 ms plus decoder 37.1 ms, versus Whisper-style CPU baselines that exceed the inference interval. 
The paper says it keeps comparable transcription accuracy while fixing latency and power. 
It also reports up to 88.64% lower average power than baselines. That is the strongest public mobile power claim I found in this sweep. 
Research system; no stable Android SDK or Maven path found in the sources I reviewed. 
High effort / research-only right now. 
License and shipping readiness need separate review before product use. 

What the evidence says
The clearest thing in the public numbers is this: streaming-native architectures beat offline Whisper-style architectures for live UX. Moonshine v2’s public benchmark shows end-of-utterance response latencies of 50 ms, 148 ms, and 258 ms for Tiny, Small, and Medium on Apple M3, versus 289 ms for Whisper Tiny, 1940 ms for Whisper Small, and 11286 ms for Whisper Large v3. That is not a subtle gap. It is the difference between “feels live” and “feels late.” 

Moonshine v2 is also not winning by being a toy model. Its public English WERs are strong: Tiny averages 12.01%, Small 7.84%, and Medium 6.65% across eight Open ASR benchmarks. On AMI, which is the closest public proxy here for messy conversational, far-mic, meeting-like audio, those scores are 19.03%, 12.54%, and 10.68%. On a modern phone, that makes Small the most sensible default to test first, because it gives a large jump over Tiny on AMI without jumping all the way to Medium’s heavier footprint. 

For sherpa-onnx, the story is more mixed because “sherpa” is a runtime plus model zoo, not one model. The toolkit is strong: it supports streaming and non-streaming ASR, VAD, keyword spotting, APKs, AARs, and now vendor NPU paths such as RKNN and QNN. But the best-documented fast Android-ish results in the public sources I reviewed are mostly RTF reports on RK boards and sample commands, not neat phone-side tables with first-partial lag and steady-state lag. That means sherpa is flexible, but the burden of choosing and validating the right model stays with you. 

Parakeet, when routed through sherpa, is a good example of that tradeoff. The Android path is real, and the INT8 export is documented. But it is still mainly a chunked / simulated-streaming answer on Android today, not the same thing as a low-lag true streaming engine. Microsoft’s 2026 study found Parakeet TDT-0.6B-v3 very good in offline quality, but in chunked use its best average WER came with roughly 10-second delay windows. That is too much lag for your primary live path, even if it is acceptable for deferred or button-press dictation. 

whisper.cpp stays in the design, but as the batch hedge. The Android example exists, the code is MIT, the model sizes are clearly documented, and it is a strong offline transcriber. But both the official Whisper architecture and the fresh NPUsper results point the same way: Whisper-family live streaming on mobile wastes too much work unless you add special research-grade tricks. That is why it belongs behind your low-confidence clip recheck path, not the always-on live lane. 

Licensing and product safety
Moonshine is the cleanest answer if your core use case is English live transcription. The code is MIT, and the English-language models are also MIT. That makes it safe for personal use now, a future public/free app, and commercial use later. The catch is multilingual. Moonshine’s non-English models are under the Moonshine Community License, which the project itself describes as non-commercial. So if multilingual becomes a product requirement, Moonshine’s legal picture gets worse fast unless you stay English-only or negotiate separate terms. 

sherpa-onnx flips that pattern. The engine code is Apache-2.0, which is clean. But the models are a patchwork. NVIDIA Parakeet v2/v3 are CC-BY-4.0, which is usually workable for products if you handle attribution correctly. NVIDIA Nemotron Speech Streaming says it is ready for commercial and non-commercial use under the NVIDIA Open Model License Agreement. Banafo’s Kroko community models are CC-BY-SA, which is okay for personal and hobby work but is a less comfortable fit for a future public/free app because of attribution and share-alike baggage. Sherpa’s own docs explicitly warn you to check the selected model’s license. 

whisper.cpp is legally easy. The runtime is MIT, and OpenAI’s Whisper code and model weights are MIT too. So it is safe for personal use, public/free distribution, and commercial use. The reason not to choose it for the live default is not law. It is live UX and power. 

A practical legal summary is straightforward. If you want the lowest-friction path to a future public app, pick Moonshine English first. If you want the broadest model choice, sherpa is fine, but lock your chosen model license in the repo docs and in an internal ADR before shipping. If you want a never-commercial multilingual hobby project, Moonshine non-English or Kroko community models can make sense, but both are less safe for later productization than Moonshine English or Apache/MIT paths. 

Android integration reality
Moonshine’s Android story is the cleanest one I found. The project says it publishes an Android package to Maven, shows the version-catalog Gradle wiring, and points to an official examples/android/Transcriber sample. That is the sort of setup you want when the goal is to validate product risk, not sink time into JNI glue. 

A minimal official-style dependency setup for the top pick looks like this:

toml
Copy
# gradle/libs.versions.toml
[versions]
moonshineVoice = "0.0.45"

[libraries]
moonshine-voice = { group = "ai.moonshine", name = "moonshine-voice", version.ref = "moonshineVoice" }
kotlin
Copy
// app/build.gradle.kts
dependencies {
    implementation(libs.moonshine.voice)
}
That exact pattern is what the project documents, and the repo points you to the official Android sample for the rest of the wiring. 

Sherpa-onnx also has a real Android path, but it is more of a toolbox. The repo and docs link to prebuilt Android APKs, build docs, Flutter apps, keyword spotting docs, and streaming/simulated-streaming examples. That is powerful, especially if you want one stack that can later cover ASR, VAD, and wake-word. But it is also more work. You will need to choose the model family, check the model license, decide whether you want CPU-only or a vendor delegate, and validate device-specific behavior. Sherpa’s public issue tracker also shows modern Android integration wrinkles, including a Snapdragon 8 Elite / Android 16 crash that needed a newer ONNX Runtime build, plus the new QNN streaming additions arriving only recently in 2026. 

whisper.cpp has an Android example and broad platform support, but the Android path is still more fragile. The repo lists Android support and an whisper.android example. At the same time, public issues/discussions show build friction, missing dependency gotchas, and device-specific CLBlast/OpenCL failures. That is acceptable for a batch sidecar or an internal prototype, but it is not the path I would pick for a fast-moving app that mostly needs dependable live English captions on one modern phone class. 

Recommendation for the repo
The right framing for the Omi repo is:

Pick Moonshine now, keep sherpa swappable behind an interface, keep whisper.cpp as the slow-but-strong second pass. 

A practical split looks like this:

kotlin
Copy
interface AsrEngine {
    fun start()
    fun pushPcm16(samples: ShortArray, sampleRateHz: Int)
    fun stop()
    fun close()

    interface Listener {
        fun onPartial(text: String)
        fun onFinal(text: String, confidenceHint: Float? = null)
        fun onError(t: Throwable)
    }
}
Then wire three implementations:

MoonshineAsrEngine for the default live path
SherpaAsrEngine for the multilingual / VAD / KWS / hardware-delegate hedge
WhisperCppBatchEngine for saved low-confidence clip re-checks after the fact
That gives you the best immediate UX and keeps the loser swappable, exactly as your roadmap wants. The repo-level decision I would make is:

Default: Moonshine Streaming Small
Fallback on weak thermals / battery: Moonshine Streaming Tiny
Batch cleanup hedge: whisper.cpp with base.en or small.en, only on saved clips
Future feature hedge: sherpa-onnx once you need wake-word, broader language coverage, or QNN/RKNN experiments. 

The reason I would not default to Moonshine Medium first is not accuracy. It is risk. Small already lands at 7.84% average WER and 12.54% on AMI far-field, while staying much lighter than Medium. That makes Small the sensible first target for a modern mid-to-high-end Android phone. If your phone handles it comfortably in your own soak tests, great. If not, Tiny is a clean fallback. 

What might beat this next
The most important new thing to watch is NPUsper. It is a 2026 research system that makes Whisper much more mobile-friendly on NPUs by cutting redundant compute. Its paper claims up to 33.2× lower TTFT, up to 4.84× lower per-word latency, and up to 88.64% lower average power than its baselines. On a Galaxy S25 CPU, the paper says Whisper-style baselines blow past the update interval, while NPUsper gets the encoder down to 161.6 ms and decoder to 37.1 ms per update. If that work turns into a clean Android runtime, it could become a serious future hedge for your batch/live boundary. Right now, though, it looks like research, not a ready Android app dependency. 

The other one worth watching is NVIDIA Nemotron Speech Streaming. Microsoft’s April 2026 report says their ONNX Runtime rework of Nemotron Speech Streaming is the strongest candidate they tested for CPU-only English streaming on constrained hardware, with an int4 configuration reaching 8.20% average streaming WER, 0.56 s algorithmic latency, and a size reduced from 2.47 GB to 0.67 GB. That is genuinely strong. The problem is that I did not find the same level of Android-ready packaging, phone-side field reports, or easy SDK path that Moonshine already has. So it is a watchlist item, not today’s default. 

If you want the shortest product answer: Ship Moonshine Small first. Keep sherpa behind the same interface. Use whisper.cpp only for second-pass cleanup. That closes the roadmap unknown with the lowest engineering and licensing risk I could support from the public evidence. 


Sources

Activity · 8m

Citations · 25

arxiv.org
arxiv.org

1
Moonshine v2: Ergodic Streaming Encoder ASR for Latency-Critical Speech Applications
+ This is the model card for the Moonshine Streaming automatic speech ... + ### Model sizes. 80. +. 81. + | Size | Parameters ... + | Dataset | Tiny (34M) | Small ( ...

3
Moonshine v2: Ergodic Streaming Encoder ASR for Latency-Critical Speech Applications
1 Mar 2023 — I will try to run it on an old Samsung S9 and see how it goes. Btw, I think that the issue with the build and having to add the examples/whisper ...Read more

4
Moonshine v2: Ergodic Streaming Encoder ASR for Latency-Critical Speech Applications
https://arxiv.org/html/2602.12241v1

15
Pushing the Limits of On-Device Streaming ASR: A Compact, High-Accuracy English Model for Low-Latency Inference
https://arxiv.org/html/2604.14493v2

24
Pushing the Limits of On-Device Streaming ASR: A Compact, High-Accuracy English Model for Low-Latency Inference
5 Jan 2026 — This model is ready for commercial/non-commercial use. License/Terms of Use: Use of the model is governed by the NVIDIA Open Model License ...

16
NPUsper: Eliminating Redundant Computation for Real ...
2 days ago — high-end mobile device. This allows NPUsper to complete each CPU-only streaming update within the inference interval even on the mobile CPU.

20
NPUsper: Eliminating Redundant Computation for Real-Time Whisper on Mobile NPUs
2 days ago — high-end mobile device. This allows NPUsper to complete each CPU-only streaming update within the inference interval even on the mobile CPU.

21
NPUsper: Eliminating Redundant Computation for Real-Time Whisper on Mobile NPUs
https://arxiv.org/abs/2607.01108?utm_source=chatgpt.com
github.com
github.com

2
GitHub - k2-fsa/sherpa-onnx: Speech-to-text, text-to-speech, speaker diarization, speech enhancement, source separation, and VAD using next-gen Kaldi with onnxruntime without Internet connection. Support embedded systems, Android, iOS, HarmonyOS, Raspberry Pi, RISC-V, RK NPU, Axera NPU, Ascend NPU, x86_64 servers, websocket server/client, support 12 programming languages · GitHub
1 May 2025 — This model is ready for commercial/non-commercial use. License/Terms of Use: GOVERNING TERMS: Use of this model is governed by the ...Read more

12
GitHub - k2-fsa/sherpa-onnx: Speech-to-text, text-to-speech, speaker diarization, speech enhancement, source separation, and VAD using next-gen Kaldi with onnxruntime without Internet connection. Support embedded systems, Android, iOS, HarmonyOS, Raspberry Pi, RISC-V, RK NPU, Axera NPU, Ascend NPU, x86_64 servers, websocket server/client, support 12 programming languages · GitHub
You can use this section for both speech-to-text (STT, ASR) and text-to-speech (TTS). The first step is to download and install Android Studio.

13
GitHub - k2-fsa/sherpa-onnx: Speech-to-text, text-to-speech, speaker diarization, speech enhancement, source separation, and VAD using next-gen Kaldi with onnxruntime without Internet connection. Support embedded systems, Android, iOS, HarmonyOS, Raspberry Pi, RISC-V, RK NPU, Axera NPU, Ascend NPU, x86_64 servers, websocket server/client, support 12 programming languages · GitHub
https://github.com/k2-fsa/sherpa-onnx

6
GitHub - moonshine-ai/moonshine-v2 · GitHub
https://github.com/moonshine-ai/moonshine-v2

7
GitHub - moonshine-ai/moonshine-v2 · GitHub
Models for other languages are released under the Moonshine Community License,. which is a non-commercial license. See SECTION 2 for terms.Read more

23
GitHub - moonshine-ai/moonshine-v2 · GitHub
cpp. whisper.cpp · Actions Status License: MIT Conan Center npm. Stable: v1.9.1 / Roadmap. High-performance inference of OpenAI's Whisper automatic speech ...Read more

25
GitHub - moonshine-ai/moonshine-v2 · GitHub
Whisper's code and model weights are released under the MIT License. See LICENSE for further details.Read more

8
Rockchip RK3588上npu推理耗时比cpu长#2515
21 Aug 2025 — ... streaming-zipformer-small-bilingual-zh-en-2023-02-16.tar.bz2 发现RTF差了很多，RTF=0.98 这是为何，相同的权重. Image. ai4in commented on Jan 25.Read more

10
Releases · k2-fsa/sherpa-onnx
Add Android demo for streaming zipformer transducer ASR with QNN by @csukuangfj in #3654 ... Improve Tauri VAD+ASR example: settings UI, bug fixes, and RTF ...Read more

17
whisper.cpp/models/README.md at master · ggml-org/whisper.cpp · GitHub
https://github.com/ggml-org/whisper.cpp/blob/master/models/README.md

18
GitHub - ggml-org/whisper.cpp: Port of OpenAI's Whisper model in C/C++ · GitHub
26 May 2023 — Open new project in Android Studio, navigating to the AndroidStudioProjects/whisper.cpp/examples/whisper.android and opening that folder. Follow ...Read more

22
GitHub - ggml-org/whisper.cpp: Port of OpenAI's Whisper model in C/C++ · GitHub
2 days ago — high-end mobile device. This allows NPUsper to complete each CPU-only streaming update within the inference interval even on the mobile CPU.

19
ggml-org/whisper.cpp
cpp. whisper.cpp · Actions Status License: MIT Conan Center npm. Stable: v1.9.1 / Roadmap. High-performance inference of OpenAI's Whisper automatic speech ...Read more
huggingface.co
huggingface.co

5
Upload README.md · UsefulSensors/moonshine-streaming-tiny ...
+ This is the model card for the Moonshine Streaming automatic speech ... + ### Model sizes. 80. +. 81. + | Size | Parameters ... + | Dataset | Tiny (34M) | Small ( ...

9
Banafo/Kroko-ASR · Hugging Face
... streaming ASR ... Note that we support streaming ASR with non-streaming models. You can find pre-built Android ... Audio duration (s): 33, Real time factor (RTF) ...

11
hudaiapa88/sherpa-stt-onnx
7 Nov 2025 — License Original Model Licenses 🔗. Sherpa ONNX STT Models. Kroko models are high-quality streaming ASR models based on Zipformer2 architecture ...
k2-fsa.github.io
k2-fsa.github.io

14
NeMo transducer-based Models — sherpa 1.3 documentation
https://k2-fsa.github.io/sherpa/onnx/pretrained_models/offline-transducer/nemo-transducer-models.html
Sources scanned · 295

github.com
github.com
Moonshine Voice


Android Maven Central publishing. Example apps for iOS, Android, For Android, examples/android/IntentRecognizer is a self-contained Gradle project you can copy ...

moonshine-ai/moonshine-v2


Moonshine Voice is an open source AI toolkit for developers building real-time voice applications. Everything runs on-device, so it's fast, private, and you don ...

ggml-org/whisper.cpp - vulkan on android build instructions?


20 Aug 2024 — For Vulkan specifically — you'll need the clvk or vulkan-loader packages from Termux, then compile whisper.cpp with cmake -DWHISPER_VULKAN=ON .Read more

[Issue]: 30 ms decoding latency on Mediatek Dimensity 9000


24 Aug 2023 — Describe the bug. On my OnePlus Nord 3 5G (Mediatek Dimensity 9000 high-end SoC) I get around 30 ms of decoding latency with both H.264 and ...Read more

k2-fsa/sherpa-onnx: Speech-to-text ...


A VS Code extension for hands-free voice-activated coding. It uses sherpa-onnx for real-time keyword spotting (KWS) to detect custom wake phrases and trigger VS ...Read more

Natively — Free open-source AI meeting assistant ...


20 hours ago — ... latency. Local Whisper STT (On-Device): 100% on-device speech-to-text using optimized ONNX models (Moonshine-tiny, Moonshine-base, Whisper ...Read more

Choppy video on Android 12 (Pixel 4a 5g) Edit: And other ...


4 Aug 2022 — Describe the bug. Even though moonlight renders at 60 fps, the video feed is very choppy. It happens with all frame pacing options, ...Read more

cactus-compute/cactus at iconpik.com


19 Apr 2026 — Pixel 6a, 70/15, -/15, -/17k+, 1GB. Galaxy A17 5G, 32/10, -/11, -/40k+, 727MB ... moonshine-base │ │ --benchmark use larger models ...Read more

Vulkan HDR on Intel iGPU not working ...


10 Jul 2024 — ... pixel format: 0x9f 00:00:00 - SDL Info (0): Sharing DRM FD with SDL ... Gamescope, moonshine, kodi, nothing. That flatpak error is what ...Read more

moonlight-android/app/src/main/java/com/limelight/binding ...


GameStream client for Android. Contribute to moonlight-stream/moonlight-android development by creating an account on GitHub.

KoljaB/RealtimeSTT


A robust, efficient, low-latency speech-to-text library with advanced voice activity detection, wake word activation and instant transcription ... sherpa-onnx ...Read more

stars/README.md at master · pluja/stars


C. moonshine-ai/moonshine - Very low latency speech to text, intent ... facebookresearch/co-tracker - CoTracker is a model for tracking any point (pixel) on a ...Read more

whisper.cpp/models/README.md at master · ggml-org ...


The original Whisper PyTorch models provided by OpenAI are converted to custom ggml format in order to be able to load them in C/C++.Read more

ggml-org/whisper.cpp


The entire high-level implementation of the model is contained in whisper.h and whisper.cpp. The rest of the code is part of the ggml machine learning library.Read more

Releases · ggml-org/whisper.cpp


Port of OpenAI's Whisper model in C/C++. Contribute to ggml-org/whisper.cpp development by creating an account on GitHub.

ukbodypilot/radio-gateway: Ham radio ...


A full-stack Linux radio gateway that bridges analog and digital two-way radios to the internet: Mumble VoIP, Broadcastify streaming, Winlink email over ...

ecohash-co/dash-voice: Voice assistant for Android tablets ...


Transform any Android tablet into a smart home voice assistant, dashboard, and multiroom speaker. DashVoice is a privacy-focused voice assistant for Android ...Read more

Awesome Privacy - A curated list of services and ...


Moonshine - Fast and accurate automatic speech recognition (ASR) for edge devices. ... The first-party app has good battery saving options. OwnTracks - Location ...Read more

Hark - Open-source voice assistant built on OACP


An open-source voice assistant that discovers and controls Android apps using on-device AI. License · Protocol · Flutter. The name "Hark" means "to listen".

miniLock-android/app/src/main/assets/word_catalog.txt ...


A miniLock porting for Android. Contribute to legarspol/miniLock-android development by creating an account on GitHub.

CHANGELOG_EN.md - BryceWG/BiBi-Keyboard


Parallel Primary-Backup Dual-Engine Recognition: Added parallel primary-backup dual-engine recognition feature to improve speech recognition accuracy and ...

hongbo-miao/hongbomiao.com: A personal research and ...


sherpa-onnx - Real-time, on-device voice activity detector (VAD), speaker diarization, speech recognition (ASR), and text-to-speech (TTS) using ONNX models.Read more

chartlite/README.md at main


Voice-first clinical documentation for primary healthcare. Open-source, offline-first EMR with speech recognition, clinical extraction, CDSS, and encrypted ...

Jai-JAP/starred-repos


moonshine-ai/moonshine - Very low latency speech to text, intent ... Android; tytydraco/Buoy - An extension to the built in Android Battery Saver ...Read more

umitkacar/awesome-ncnn: NCNN Framework: High- ...


Sherpa-NCNN - Next-Gen Speech Recognition · Main Repository · ✨ Key Features · Features · Documentation.Read more

Releases · k2-fsa/sherpa-onnx


Add Android demo for streaming zipformer transducer ASR with QNN by @csukuangfj in #3654 ... sherpa-onnx-1.13.3-rknn.aar. sha256 ...Read more

CHANGELOG.md - k2-fsa/sherpa-onnx


Fix using sherpa-onnx as a cmake sub-project. push to maven center. Provide sherpa-onnx.aar for Android (#1615) Use aar in Android Java demo. Fix building for ...

moonshine/LICENSE at main


Models for other languages are released under the Moonshine Community License,. which is a non-commercial license. See SECTION 2 for terms.Read more

openai/whisper: Robust Speech Recognition via Large- ...


Whisper's code and model weights are released under the MIT License. See LICENSE for further details.Read more

MIT License - openai/whisper


MIT License. A short and simple permissive license with conditions only requiring preservation of copyright and license notices. Licensed works, modifications, ...Read more

Does Whisper come with no cost for enterprise usage?


17 Sept 2023 — License Whisper's code and model weights are released under the MIT License. Whisper's code is the actual Whisper program. It's a very short ...

License - Clarification · openai whisper · Discussion #1216


What is the difference between open AI whisper. which is released in software as a service model only weights are released in MIT,

Python OpenAI Whisper Speech to Text Transcription


This project is licensed under the MIT License - Python script provides a simple interface to transcribe audio files using the OpenAI API's speech-to-text ...

Faster Whisper transcription with CTranslate2


MIT license. More items. CI PyPI version. Faster Whisper transcription with CTranslate2. faster-whisper is a reimplementation of OpenAI's Whisper model using ...Read more

WhisperDesk – A Simple opensource Mac App for Whisper


WhisperDesk is a lightweight macOS desktop app for transcribing audio and video. It's free, MIT-licensed, and available for anyone who wants it. 100% local ...

FunASR/examples/industrial_data_pretraining/whisper ...


# MIT License (https://opensource.org/licenses/MIT) # To install requirements: pip3 install -U openai-whisper from funasr import AutoModel model = AutoModel ...Read more

Questions · openai whisper · Discussion #7


First of all, Thanks for releasing this with MIT license and making it easy to test out. Already tried it out with Finnish language.Read more

RealtimeSTT/docs/licenses.md at master


21 May 2026 — OpenAI Whisper code and model assets are published in the openai/whisper repository under MIT. Generally permissive, subject to preserving MIT ...Read more

XDcobra/react-native-sherpa-onnx


A React Native TurboModule that provides offline and streaming speech processing capabilities using sherpa-onnx. The SDK aims to support all functionalities ...Read more

utensil/awesome-stars: A curated list of my ...


moonshine-ai/moonshine - Very low latency speech to text, intent ... documents into clean, structured formats for language models. Visit our website to ...Read more

Comparision with faster-whisper · Issue #1127 · ggml-org/ ...


20 Jul 2023 — Faster-whisper is faster than whisper.cpp in CPU. For eg. It takes faster-whisper 14seconds with the small.en , whereas with whisper.cpp it's 46seconds.

Set of 📝 with 🔗 to help those building Voice AI agents 🎙️🤖 ...


Mo (Parakeet / Canary): Advanced Moonshine: Tiny on-device ASR. Intermediate Benchmarks and explainers . 60+ ASR models across 11 datasets;

Really Real Time Speech To Text · openai whisper


28 Nov 2022 — Have you noticed any performance issues for longer audio streams? A few solutions I can think of: Transcribing a sliding window of audio chunks, ...

TEN-framework/ten-vad: Voice Activity Detector (VAD) : low ...


/sherpa-onnx, enhanced ASR experience! released and open-sourced the ONNX model. VAD is a real-time voice activity detection system … latency in conversational ...

modelscope/FunASR: Industrial-grade speech recognition ...


Industrial speech recognition. Up to 340x realtime, 26x faster than Whisper. 50+ languages. Speaker diarization · Emotion detection · Streaming · One API call.

ekhodzitsky/phonex


phonex is a Rust CLI + server that transcribes speech using Sherpa-ONNX Zipformer models. Real-time streaming from microphone streaming. Real-time streaming ...

FluidAudio - Transcription, Text-to-speech, VAD, Speaker ...


Real-time, fully on-device transcription with speaker diarization and AI-powered conversation insights. Uses Parakeet and Nemotron streaming ASR and speaker ...Read more

huggingface/distil-whisper: Distilled variant of ...


You are transcribing batches of long audio files, in which case the latency of sequential is comparable to chunked, while being up to 0.5% WER more accurate.

FunAudioLLM/SenseVoice: Multilingual speech ...


SenseVoice is a speech foundation model with multiple speech understanding capabilities, including automatic speech recognition (ASR), spoken language ...Read more

ekhodzitsky/gigastt: Local STT server powered by GigaAM ...


It runs the open GigaAM v3 model fully on-device via ONNX Runtime: no cloud, no API keys. At a glance. Private, on-device, Embeddable + streaming, Accurate ...Read more

QuentinFuxa/WhisperLiveKit: Simultaneous speech-to-text ...


Whisper is designed for complete utterances, not real-time chunks. Processing small segments loses context, cuts off words mid-syllable, and produces poor ...

collabora/WhisperLive: A nearly-live implementation of ...


This project is a real-time transcription application that uses the OpenAI Whisper model to convert speech input into text output.

KWS model response latency when i implement with vad


14 Oct 2025 — To reduce latency and improve real-time detection: Try feeding audio to the KWS model continuously (streaming), not just after VAD detects a ...

Issue #3104 · k2-fsa/sherpa-onnx - Qwen3-TTS?


28 Jan 2026 — For short texts, batch wins on total latency — but streaming still delivers the first audio chunk in ~2 s vs waiting ~5 s for batch to finish.

ASR TTS Merge into one apk #580 - k2-fsa/sherpa-onnx


9 Feb 2024 — The code is shared but the models are different. Also, you can install asr apk, tts apk, and speaker identification apk simultaneously on your ...Read more

Problems with sherpa-onnx-nemo-parakeet-tdt-0.6b-v2- ...


14 May 2025 — This requires a model specifically designed for streaming and code that can handle continuous audio input with low latency.

Unity integration plugin for sherpa-onnx — TTS, ASR, VAD ...


The plugin also handles several Unity-specific platform issues that arise during integration: Android TTS + mic coexistence — AudioSessionBridge sets ...

Lag spikes every 5 minutes. · Issue #885 · moonlight ...


The audio and video stutters heavily, bitrate visibly drops. The spike lasts for about 3 seconds, just to get back to normal performance. Moonlight streaming ...Read more

v3 rewrite · Issue #371 · m1k1o/neko


22 Feb 2024 — https://github.com/hgaiser/moonshine · https ... JPEG can send each pixel independently, which may prove useful for partial screen refreshes.Read more

The transcription speed is much slower than the official demo ...


There might be some steps you need to do to get it optimized. I haven't tried the Android lib yet, but I did follow https://github.com/ggerganov/whisper.cpp/ ...

pipecat/CHANGELOG.md at main


the dependencies to run them from the project's own environment: the cli extra (the pipecat eval command) plus kokoro and moonshine ... pixel modes instead of ...Read more

Efficient-Deep-Learning/README.md at master


2018-NIPS-Moonshine: Distilling with cheap convolutions ... Papers [Interpretability]. 2010-JMLR-How to explain individual classification decisions; 2015-PLOS ONE ...Read more

Exynos handset high latency (30ms)/intermittent stutters ...


30 May 2024 — The issue is the decode latency on my s24+ seems to be around 20-30 ms which introduces intermittent stutters but, the moment you start screen recording at the ...Read more

Legion go wifi 6e signal unstable · Issue #1437


30 Jul 2024 — ... pixel ratio value was stale on window update. Please file a QTBUG w ... Moonshine and Steam Remote Play. I don't believe this is a bug ...Read more

xleliu/mystars: Update my stars by github actions


14 Jun 2026 — moonshine-ai/moonshine - Very low latency speech to text, intent ... pixel of video. ( stars: 73672 , license: mit ); ogulcancelik/herdr ...Read more

ZipVoice zero-shot TTS support for Android TTS Engine ...


29 Mar 2026 — RTF ~1.0 on Pixel 10 Pro (CPU ... Would save significant time on Android where the reference encoding is a noticeable chunk of the RTF.Read more

[Bug] High CPU / Low NPU Usage on RK3576 (Android 14 ...


4 Aug 2025 — ... Android 14 build with full NPU acceleration (~68% load). ... High-performance, NPU-accelerated speech recognition (RTF < 1.0) is achievable on our ...Read more

Qnn SaveBinaryContext failed when init. · Issue #2808


20 Nov 2025 — Issue: Crash on first startup with QNN SenseVoice model in SherpaOnnxSimulateStreamingAsr I am trying to run ...

Offline Mode Returns Empty Transcript Using sherpa_onnx ...


22 Jul 2025 — Bug Report: Offline Mode Returns Empty Transcript Using sherpa_onnx Flutter Package #2415. New issue.Read more

关于TTS模型的初始化和运行性能优化#2820


24 Nov 2025 — Android端实现优化：确保推理部分已开启多线程，合理分配CPU资源。可以 ... RTF/速度差异明显）参考。 目前sherpa-onnx 的优化手段主要是多线程 ...Read more

Issue with building and running sherpa-onnx gpu on ...


14 May 2024 — I am unsure if this is an issue with sherpa-onnx gpu installation or onnxruntime-gpu installation. I am using Windows 11, python 3.10.11.

android 腕表识别率暴跌· Issue #1086 · k2-fsa/sherpa-onnx


7 Jul 2024 — android 腕表识别率暴跌 #1086. New issue. Copy link. New issue. Copy ... 如果RTF > 1, 不管你用什么队列， 最后肯定会overflow 的. 数据是源源 ...Read more

hello, the Chinese onnx model inference seems not right. #9


29 Sept 2022 — While in c++ it needs projector. The code can not make me have a e2e inference result. What have I miss here? (I just want make it get final ASR ...Read more

as_cmake_sub_project · Workflow runs · k2-fsa/sherpa-onnx


android-rknn android-rknn; android-static android ... Fix building Flutter Android APPs (#3559) as_cmake_sub_project #972: Commit 12a79e5 pushed by csukuangfj.

rk3566运行streaming-zipformer模型崩溃#3440


29 Mar 2026 — ... ：sherpa-onnx-rk3566-streaming-zipformer-small-bilingual-zh-en-2023-02-16 aar版本：sherpa-onnx-1.12.34-rknn.aar demo：使用android ... RTF ~1.5，可能 ...Read more

sherpa-onnx/sherpa-onnx/kotlin-api/OnlineRecognizer.kt at ...


Speech-to-text, text-to-speech, speaker diarization, speech enhancement, source separation, and VAD using next-gen Kaldi with onnxruntime without Internet ...

Issue #2814 · k2-fsa/sherpa-onnx - TTS模型咨询


23 Nov 2025 — 它们都可以直接在CPU平台（如树莓派4、x86_64服务器、Android、Windows、macOS等）推理，无需GPU或NPU，效果和音质在同类开源模型中表现不错，支持多说话人和多 ...Read more

[BUG] [Android] SIGILL crash on Snapdragon 8 Elite ...


8 Apr 2026 — k2-fsa / sherpa-onnx Public ... [BUG] [Android] SIGILL crash on Snapdragon 8 Elite + Android 16 — please upgrade ONNX Runtime to 1.24.Read more

Streaming ASR not recognizing repeated digits correctly (e.g., 11 ...


... android/apk-simulate-streaming-asr.html. Others ... streaming-zipformer-en-kroko-2025-08-06/encoder ... (RTF) = 0.62/33 = 0.019 one, one five five ...

GigaAM-v3 Russian ASR (MIT) — model on HF by @ ...


16 May 2026 — We're planning to test the Android native path (arm64-v8a, Snapdragon 8 Gen 2) with the prebuilt sherpa-onnx binary via Termux. Will report ...Read more

使用sherpa-onnx运行zipformer中英版本标准版出现叠词


4 Dec 2025 — ... (RTF) = 4.9/18 = 0.28 嗯ON TIME叫准时IN IN TIME是及时叫他总是 ... │ ASR模型│ sherpa-onnx-rk3576-streaming-zipformer-small-bilingual ...Read more

Documentation: What are the main Java bindings? · Issue #2710


In the main README, there is a "supported platforms" section with a link to the Java bindings. But further in the doc, in the Bindings section, ...

Android run demo by small model · Issue #518 · ggml-org ...


21 Feb 2023 — whisper.cpp. Make sure to use release build and select tiny or base model. clicking the benchmark button in android crashes the app.

Android demo app: Multilingual support? #549


1 Mar 2023 — I'd also like to mention that the README.md file within examples/whisper. ... whisper.android/app/src/main/jni/whisper/jni.c#L8. Basically, idk ...Read more

README.md - whisper.cpp


https://huggingface.co/ggerganov/whisper.cpp. For more details, see the conversion script models/convert-pt-to-ggml.py or models/README.md.Read more

Questions about building CLBlast for android · Issue #2014


1 Apr 2024 — The build instructions in android example readme contains both "CLBlast.so build" and "android application build". So may it makes you ...Read more

Android example app #283 - ggml-org whisper.cpp


Implement a very basic Java application using whisper.cpp. It can be used as an example for running Whisper on Android.Read more

whisper.android: is there anyone who can sucessfully build ...


26 May 2023 — cpp/examples/whisper.android and opening that folder. Follow the instructions in the README.md. You will need to create the folders that are ...Read more

Android: Crashing on Bench marks. · Issue #3340


Crashing inside the cpp when Android hits whisper_bench_memcpy_str. It happens when I call the benchmark. Even though I pass at least 1 thread it reads as ...

v1.3.0 · ggml-org whisper.cpp · Discussion #766


whisper.android: Enable fp16 instrinsics (FP16_VA) which ... Include link to R wrapper in README by @jwijffels in Include link to R wrapper in README #626 ...Read more

Benchmark results · Issue #89 · ggml-org/whisper.cpp


25 Oct 2022 — Encoder Collection of bench results for various platforms and devices. If you want to submit info about your device, simply run the bench ...

Android CLBlast build crashes app with `dlopen failed


17 Mar 2024 — ... whisper.android/README.md?plain=1#L24-L38; Modify android project's gradle.properties following https://github.com/ggerganov/whisper.cpp/blob ...Read more

ggml-org whisper.cpp · Discussions


New open-source app AI Bluetooth Phone Switchboard: using whisper.cpp as a real-time hallucination filter. Benchmark Report: Complete Performance Analysis on ...

v1.5.5 · ggml-org whisper.cpp · Discussion #2064


whisper.android: How to build with CLBlast by @luciferous in whisper.android ... Update README to Recommend MacOS Sonoma for Core ML to avoid ...Read more

v1.1.0 · ggml-org whisper.cpp · Discussion #408


24 Jan 2023 — whisper.android : remove android ABI constraint by @Digipom in ... @ianb made their first contribution in (README) Make first example and stream ...Read more

How to CrossCompile for aarch64 device · Issue #1821


31 Jan 2024 — How to cross compile whisper for aarch64 device? I need to make use opencl gpu support which means i also need to cross compile CLBlast library ...Read more

v1.7.5 · ggml-org whisper.cpp · Discussion #2995


whisper.android.java : update build with ggml source changes by @danbev ... Update README.md by @Page-MS in Update README.md #2946; bindings.javascript ...Read more

Activity · ggml-org/whisper.cpp


Port of OpenAI's Whisper model in C/C++. Contribute to ggml-org/whisper.cpp development by creating an account on GitHub.

index.html


GitHub Gist: instantly share code, notes, and snippets.

awesome-openclaw-skills/README.md at main


OpenClaw is a locally-running AI assistant that operates directly on your machine. Skills extend its capabilities, allowing it to interact with external ...Read more

zxcvbn.js.map - nextcloud/passman


Open source password manager with Nextcloud integration - passman/js/vendor/zxcvbn/zxcvbn.js.map at master · nextcloud/passman.

jxzzlfh/awesome-stars


k2-fsa/sherpa-onnx - Speech-to-text, text-to-speech, speaker diarization, speech enhancement, source separation, and VAD using next-gen Kaldi with ...Read more

PS7.ipynb - luizfsporto/python-basics-info370


1. Load the data. You may drop size, lines, and pagenr. · 2. Ensure that you don't have any missing name, and empty text in your data · 3. Create a summary table ...Read more

stars/README.md at main


TTS Azure Web is an Azure Text-to-Speech (TTS) web application. It allows you to run it locally or deploy it with a single click using your Azure Key. tldraw/ ...Read more

autocompletion/resources/words.md at master


A same problem viewed two ways: list-processing and graph-processing - autocompletion/resources/words.md at master · piotr-yuxuan/autocompletion.

winclaw/CHANGELOG.md at main · itc-ou-shigou ...


3 Mar 2026 — Skills/sherpa-onnx-tts: run the sherpa-onnx-tts bin under ESM ... Android/Voice screen TTS: stream assistant speech via ElevenLabs ...Read more

huggingface.co
huggingface.co
Moonshine v2: Ergodic Streaming Encoder ASR for ...


12 Feb 2026 — Moonshine v2 is an ergodic streaming-encoder ASR model that uses sliding-window self-attention to achieve low-latency inference with ...Read more

Daily Papers


This paper introduces Moonshine, a family of speech recognition models optimized for live transcription and voice command processing. Moonshine is based on an ...

Daily Papers


Flavors of Moonshine: Tiny Specialized ASR Models for Edge Devices · We present the Flavors of Moonshine, a suite of tiny automatic speech recognition (ASR) ...

Daily Papers


Moonshine v2: Ergodic Streaming Encoder ASR for Latency-Critical Speech Applications · Latency-critical speech applications (e.g., live transcription, voice ...

Daily Papers


This report introduces Canary-1B-v2, a fast, robust multilingual model for Automatic Speech Recognition (ASR) and Speech-to-Text Translation (AST). Built with a ...Read more

csukuangfj/sherpa-onnx-streaming-zipformer-en-kroko- ...


6 Aug 2025 — Check out the documentation for more information. See license at https://huggingface.co/Banafo/Kroko-ASR. Downloads last month. -. Downloads ...Read more

Banafo/Kroko-ASR


Flexible licensing – with WebSockets for streaming. Kroko ASR is built on top of Sherpa-ONNX.

csukuangfj/sherpa-onnx-streaming-zipformer-fr-kroko-2025 ...


6 Aug 2025 — Check out the documentation for more information. See license at https://huggingface.co/Banafo/Kroko-ASR. Downloads last month. -. Downloads ...Read more

hudaiapa88/sherpa-stt-onnx


7 Nov 2025 — License Original Model Licenses 🔗. Sherpa ONNX STT Models. Kroko models are high-quality streaming ASR models based on Zipformer2 architecture ...

csukuangfj/sherpa-onnx-streaming-zipformer-es-kroko-2025-08- ...


sherpa-onnx-streaming-zipformer-es-kroko-2025-08-06. File size: 55 Bytes. 20cf7a4. 1 2. See license at https://huggingface.co/Banafo/Kroko-ASR. System theme.

README.md · csukuangfj/sherpa-onnx-streaming-zipformer-es- ...


sherpa-onnx-streaming-zipformer-es-kroko-2025-08-06 ... sherpa-onnx-streaming ... Delete. 55 Bytes. See license at https://huggingface.co/Banafo/Kroko-ASR.

Models


Explore machine learning models. Licenses Other Tasks … 11 R4kSo1997/sherpa-onnx-streaming-zipformer-it-kroko-2025-08-06 Updated May 26

selimc/whisper-large-v3-turbo-turkish · ggml for whispercpp?


9 Jul 2025 — Could you please publish the binary file of this model converted to ggml format so I can try it in whispercpp? See translation.Read more

UsefulSensors/moonshine


21 Oct 2024 — The Moonshine models are trained for the speech recognition task, capable of transcribing English speech audio into English text.Read more

UsefulSensors/moonshine-streaming-tiny


This model card follows the recommendations from Model Cards for Model Reporting (Mitchell et al.). See the paper draft in this repository for full details.Read more

UsefulSensors/moonshine-tiny-uk


2 Sept 2025 — This Moonshine model is trained for the speech recognition task, capable of transcribing Ukranian speech audio into Ukrainian text. Moonshine AI ...Read more

UsefulSensors/moonshine-streaming-medium at main


This model card follows the recommendations from Model Cards for Model Reporting (Mitchell et al.). See the paper draft in this repository for full details ...

Upload README.md · UsefulSensors/moonshine-streaming-tiny ...


+ This is the model card for the Moonshine Streaming automatic speech ... + ### Model sizes. 80. +. 81. + | Size | Parameters ... + | Dataset | Tiny (34M) | Small ( ...

nyadla-sys/whisper-tiny.en.tflite


Configure model parameters and fetch decoder token mappings. 2, Load the Whisper model and run a test transcription (English: LibriSpeech, other languages: ...Read more

Whisper


The decoder allows Whisper to map the encoders learned speech representations to useful outputs, such as text, without additional fine-tuning. Whisper just ...Read more

CohereAsr · Hugging Face


Overview. Cohere ASR, released by Cohere on March 26th, 2026, is a 2B parameter Conformer-based encoder-decoder speech recognition model.Read more

SeamlessM4T-v2


30 Nov 2023 — SeamlessM4T-v2 is a collection of models designed to provide high quality translation, allowing people from different linguistic communities to communicate ...Read more

Daily Papers


We built pre-trained wav2vec 2.0 models covering 1,406 languages, a single multilingual automatic speech recognition model for 1,107 languages, speech synthesis ...Read more

UsefulSensors/moonshine-streaming-medium


13 Feb 2026 — This is the model card for the Moonshine Streaming automatic speech recognition (ASR) models trained and released by Useful Sensors. Moonshine ...Read more

README.md · UsefulSensors/moonshine-streaming-small at main


Instructions to use UsefulSensors/moonshine-streaming-small with libraries, inference providers, notebooks, and local apps. Follow these links to get started.

Immortalizer/moonshine-streaming-small-onnx


21 Oct 2024 — Moonshine Streaming Small — merged-decoder int8 ONNX · What's different from a standard streaming ONNX export · Lineage / attribution · License.Read more

UsefulSensors/moonshine-streaming-medium at ...


Instructions to use UsefulSensors/moonshine-streaming-medium with libraries, inference providers, notebooks, and local apps. Follow these links to get started.Read more

UsefulSensors/moonshine-streaming-medium at main


Use this model. Instructions to use UsefulSensors/moonshine-streaming-medium with libraries, inference providers, notebooks, and local apps.Read more

Mazino0/moonshine-streaming-small-onnx


12 Feb 2026 — License. Moonshine v2 Streaming Small — ONNX INT8. ONNX INT8 (dynamic quantization) export of UsefulSensors/moonshine-streaming-small, a fast ...Read more

Immortalizer/moonshine-streaming-medium-onnx


21 Oct 2024 — Moonshine Streaming Medium — merged-decoder int8 ONNX · What's different from a standard streaming ONNX export · Lineage / attribution · License.Read more

Tiny Specialized ASR Models for Edge Devices


2 Sept 2025 — Our new Moonshine Tiny ASR models support 6 languages, and outperform Whisper Small and Whisper Medium, despite them being 9x-28x larger. They' ...Read more

onnx-community/moonshine-tiny-ar-ONNX


2 Sept 2025 — This is the model card for running the automatic speech recognition (ASR) models (Moonshine models) trained and released by Moonshine AI (f.k.a ...Read more

UsefulSensors/moonshine-tiny


21 Oct 2024 — This is the model card for running the automatic speech recognition (ASR) models (Moonshine models) trained and released by Useful Sensors.Read more

Immortalizer/moonshine-streaming-small-onnx at 64ebc81


24 Jun 2026 — **[Useful Sensors — Moonshine](https://huggingface.co/UsefulSensors/moonshine-streaming-small)**. 60. + — the original model, weights, and ...Read more

Upload model · aiai-laboratory/diffusion-speech-translation ...


22 Jun 2026 — We're on a journey to advance and democratize artificial intelligence through open source and open science.

Daily Papers


4 days ago — To better meet the needs of on-device, streaming ASR use cases we introduce Moonshine v2, an ergodic streaming-encoder ASR model that employs ...

mlm_vocab.txt


... english art director live media election division change moved half land others king total 24 example co # < wrote players better put field council human ...Read more

vocab.txt


... model our it two these data results show using also based have time or between such not one field has paper quantum study energy system models method new ...Read more

33.9 kB


20 Nov 2025 — - **Interact with users in real time**, via streaming ASR and low‑latency TTS. ... streaming Zipformer** models for sherpa‑onnx and sherpa‑ncnn.Read more

Running Whisper ASR on Android Phone/Tablet with Termux


27 Aug 2025 — This guide shows how to install Termux, build Whisper (ggml / whisper.cpp), record audio, and transcribe it — all locally on your Android device ...Read more

nvidia/parakeet-tdt-0.6b-v3


14 Aug 2025 — Long audio transcription, supporting audio up to 24 minutes long with full attention (on A100 80GB) or up to 3 hours with local attention.Read more

nvidia/nemotron-speech-streaming-en-0.6b


5 Jan 2026 — This model is ready for commercial/non-commercial use. License/Terms of Use: Use of the model is governed by the NVIDIA Open Model License ...

nvidia/parakeet-tdt-0.6b-v2


1 May 2025 — This model is ready for commercial/non-commercial use. License/Terms of Use: GOVERNING TERMS: Use of this model is governed by the ...Read more

nvidia/parakeet-tdt-0.6b-v3 · Japanese support plan?


License: cc-by-4.0. Model card Files Files and versions. xet · Community. 45. Deploy ... How to use nvidia/parakeet-tdt-0.6b-v3 with Transformers: # Use a ...Read more

nvidia/nemotron-speech-streaming-en-0.6b


License: nvidia-open-model-license. Instructions to use nvidia/ , notebooks, and local apps. we're planning a multilingual version that will cover German and ...

nvidia/parakeet-tdt-0.6b-v2 · New Language Training


License: cc-by-4.0. Model card Files Files and versions. xet · Community. 70. Deploy ... How to use nvidia/parakeet-tdt-0.6b-v2 with NeMo: import nemo ...Read more

nvidia/parakeet-tdt-0.6b-v3 · Adds files for MLX support


License: cc-by-4.0. Model card Files Files and versions. xet · Community. 45. Deploy ... How to use nvidia/parakeet-tdt-0.6b-v3 with Transformers: # Use a ...Read more

nvidia/nemotron-speech-streaming-en-0.6b


14 Jan 2026 — License: nvidia-open-model-license. Instructions to use nvidia/nemotron-speech-streaming-en-0.6b with libraries, inference providers, notebooks ...

nvidia/parakeet-tdt-0.6b-v2 · Only English is supported?


8 May 2025 — License: cc-by-4.0. Model card Files Files and versions. xet · Community ... I would highly appreciate a German or multilingual version of nvidia/ ...Read more

sonic-speech/parakeet-tdt-0.6b-v3


License: cc-by-4.0. Model card Files ... Weights from mlx-community/parakeet-tdt-0.6b-v3 , converted from NVIDIA's official nvidia/parakeet-tdt-0.6b-v3 .Read more

nvidia/nemotron-speech-streaming-en-0.6b · Discussions


License: nvidia-open-model-license. Instructions to use nvidia/nemotron-speech-streaming-en-0.6b with libraries, inference providers, notebooks, and local apps ...

nvidia/parakeet-tdt-0.6b-v2 · Streaming?


2 May 2025 — License: cc-by-4.0. Model card Files Files and versions. xet · Community ... You can use NVIDIA-Parakeet-TDT-0.6B-v2 without NVIDIA card in ...Read more

nvidia/parakeet-tdt-0.6b-v3 · Discussions


License: cc-by-4.0. Model card Files Files and versions. xet · Community. 45. Deploy ... How to use nvidia/parakeet-tdt-0.6b-v3 with Transformers: # Use a ...Read more

bridge/__init__.py · nvidia/nemotron-speech-streaming-en-0.6b ...


Copyright (c) 2024, NVIDIA CORPORATION. All rights reserved. # # Licensed under the Apache License, Version 2.0 (the "License"); # you may not use this file ...

nvidia/parakeet-tdt-0.6b-v2 · Custom Vocabulary


License: cc-by-4.0. Model card Files Files and versions. xet · Community. 70. Deploy ... By custom vocabulary, I believe you are asking about word boosting. See ...Read more

sonic-speech/parakeet-tdt-0.6b-v3-int8


NVIDIA Parakeet TDT v3 with encoder-only INT8 quantization — the recommended variant for most users. Zero WER degradation, 30% faster, 58% less memory than BF16 ...Read more

nvidia/nemotron-3.5-asr-streaming-0.6b


Use of the model is governed by the OpenMDW-1.1 license. This model is for transcription of multilingual audio.

nvidia/parakeet-tdt-0.6b-v2


13 Jul 2025 — License: cc-by-4.0. Model card Files Files and versions. xet · Community ... How to use nvidia/parakeet-tdt-0.6b-v2 with NeMo: import nemo ...Read more

nvidia/parakeet-tdt-0.6b-v3 at main


License: cc-by-4.0. Model card Files Files and versions. xet · Community. 45. Deploy ... How to use nvidia/parakeet-tdt-0.6b-v3 with Transformers: # Use a ...Read more

nvidia/nemotron-speech-streaming-en-0.6b at 8e6c7a8


19 Jun 2026 — NVIDIA 60.8k Automatic Speech Recognition NeMo PyTorch … 2 license: other 3 license_name: nvidia-open-model-license 4 + license_link: https:// ...

nvidia/parakeet-tdt-0.6b-v2 · Update Readme


GOVERNING TERMS: Use of this model is governed by the [CC-BY-4.0](https://creativecommons.org/licenses/by/4.0/legalcode.en) license.

nvidia/parakeet-tdt-0.6b-v3 · Word boosting


License: cc-by-4.0. Model card Files Files and versions. xet · Community. 45. Deploy ... How to use nvidia/parakeet-tdt-0.6b-v3 with Transformers: # Use a ...Read more

safety.md · nvidia/nemotron-speech-streaming-en-0.6b at ...


Instructions to use nvidia/nemotron-speech-streaming-en-0.6b with libraries, inference providers, notebooks, and local apps. Follow these links to get started.Read more

nvidia/parakeet-tdt-0.6b-v2 · how to load the model from ...


26 May 2025 — License: cc-by-4.0. Model card Files Files and versions. xet · Community ... How to use nvidia/parakeet-tdt-0.6b-v2 with NeMo: import nemo ...Read more

nvidia/parakeet-tdt-0.6b-v3 · Does it support Realtime ?


License: cc-by-4.0. Model card Files Files and versions. xet · Community. 45. Deploy ... How to use nvidia/parakeet-tdt-0.6b-v3 with Transformers: # Use a ...Read more

Commits · nvidia/nemotron-speech-streaming-en-0.6b


18 Jun 2026 — License: nvidia-open-model-license. Instructions to use nvidia/nemotron-speech-streaming-en-0.6b with libraries, inference providers, notebooks ...

nvidia/parakeet-tdt-0.6b-v2 · Please do It for Japanese


1 May 2025 — License: cc-by-4.0. Model card Files Files and versions. xet · Community ... How to use nvidia/parakeet-tdt-0.6b-v2 with NeMo: import nemo ...Read more

nasedkinpv/parakeet-tdt-0.6b-v3-onnx-int8


This model is a converted version of nvidia/parakeet-tdt-0.6b-v3 by NVIDIA. Original Model: NVIDIA Parakeet TDT 0.6B v3. Original License: CC-BY-4.0Read more

nvidia/nemotron-speech-streaming-en-0.6b


8 Jan 2026 — Hi NVIDIA team,. We're using nemotron-speech-streaming-en-0.6b for real-time streaming ASR and have observed that the RNNT decoder ...Read more

reddit.com
reddit.com
Latency in a particular Device : r/MoonlightStreaming


Not all devices are equal with decoding ability. Besides lowering the resolution and bitrate to get working better, there's not much else you ...Read more

Phone Whisper: push-to-talk dictation for Android with local ...


Local mode: runs Whisper on-device via sherpa-onnx. No network requests, no API keys needed. Ships with a model downloader so you pick the model ...Read more

Handy - a simple, open-source offline speech-to-text app ...


A cross-platform speech-to-text app using whisper.cpp that runs completely offline. Press shortcut, speak, get text pasted anywhere.Read more

can someone help me to convert this whisper model ...


Here is a whisper model which is trained well for low resource indic languages which is super usefull for my academic research, but the models are in . ...Read more

Why is on-device Automated Speech Recognition (ASR) ...


I am having a hard time finding anyone do a good job of using Whisper to live transcribe speech to text in a reliable way. I tried to use a pixel along ...

[R] Streaming End-to-end Speech Recognition For Mobile ...


Full on-device ASR, model is 80MB, runs in real-time on mid-range Android devices, 5% error rate when using content biases. Incredible work.Read more

Client-side STT version of Moonshine released


... Moonshine models, including new Spanish versions available under a non-commercial license (English and code are all MIT). The video above ...Read more

openwhispr.com
openwhispr.com
How Whisper AI Works: A Complete Guide


17 Feb 2026 — Faster Whisper is Python-based (unlike whisper.cpp's C/C++) and is a strong choice for server-side batch transcription. It supports CUDA GPUs ...Read more

blog.brightcoding.dev
blog.brightcoding.dev
Sherpa-ONNX: Unified Speech Recognition, Synthesis, and ...


11 Sept 2025 — Sherpa-ONNX: Unified Speech Recognition, Synthesis, and Audio Processing for Every Platform · No network latency · No per-request cost · GDPR / ...Read more

steamcommunity.com
steamcommunity.com
Audio latency on Android version of app only


Effectively the audio latency is consistently around 200-400ms when using any Android version of the app (that is, with my limited test sample of 3 Android ...Read more

kaggle.com
kaggle.com
MedGEM: The Offline, Multimodal Medical AI Companion for ...


ASR (MedAsr via Sherpa-ONNX): Real-Time Factor of ~0.034 (~30x faster than real-time). Transcribes ~44 seconds of audio in under 1.5 seconds. Memory: Peak ...

promptquorum.com
promptquorum.com
Local Voice Assistant Whisper + LLM Phone 2026


8 May 2026 — The iPhone path uses WhisperKit + LLM Farm; the Android path uses Layla (built-in stack) or Termux + whisper.cpp + Ollama; the hybrid path keeps ...Read more

news.ycombinator.com
news.ycombinator.com
OpenAI quietly launched Whisper V2 in a GitHub commit


6 Dec 2022 — whisper.cpp provides similar functionality via the `livestream.sh` script that performs transcription of a remote stream [0]. For example ...Read more

Show HN: Moonshine Open-Weights STT models


... Moonshine Community License, which is a non-commercial license. > The code in core/third-party is licensed according to the terms of the open source ...Read more

It seems like OpenAI are finally living up to their name for ...


Released under MIT License: https://github.com/openai/whisper/blob/main/LICENSE ... (Model weights from https://github.com/openai/whisper/blob/main/whisper ...Read more

raw.githubusercontent.com
raw.githubusercontent.com
raw.githubusercontent.com


Total lines: 135

GGUF - GitHub


GGUF is a binary format that is designed for fast loading and saving of models, and for ease of reading. Models are traditionally developed using PyTorch or ...Read more

arxiv.org
arxiv.org
Moonshine v2: Ergodic Streaming Encoder ASR for ...


by M Kudlur · 2026 · Cited by 1 — Latency-critical speech applications—including live transcription, voice commands, and real- time translation—demand low time-to-first-token.Read more

Moonshine v2: Ergodic Streaming Encoder ASR for Latency-Critical Speech Applications


by M Kudlur · 2026 · Cited by 1 — Abstract page for arXiv paper 2602.12241: Moonshine v2: Ergodic Streaming Encoder ASR for Latency-Critical Speech Applications.

Moonshine v2: Ergodic Streaming Encoder ASR for ...


Table 2 compares the response latency between Moonshine, Moonshine v2, and Whisper models. The Moonshine v2 models demonstrate substantially ...Read more

Pushing the Limits of On-Device Streaming ASR


19 Apr 2026 — Warden, “Moonshine v2: Ergodic Streaming Encoder ASR for Latency-Critical Speech Applications,” https://arxiv.org/abs/2602.12241, 2026.Read more

NPUsper: Eliminating Redundant Computation for Real- ...


2 days ago — Moonshine v2: Ergodic streaming encoder asr for latency-critical speech applications. arXiv preprint arXiv:2602.12241, 2026. Monsoon ...Read more

VibeServe: Can AI Agents Build Bespoke LLM Serving ...


7 May 2026 — Warden (2026) Moonshine v2: ergodic streaming encoder asr for latency-critical speech applications. arXiv preprint arXiv:2602.12241. Cited ...Read more

Can AI Agents Build Bespoke LLM Serving Systems?


by K Kamahori · 2026 — Moonshine v2: Ergodic streaming encoder asr for latency-critical speech applications. arXiv preprint arXiv:2602.12241, 2026. [35] Thomas Kwa ...Read more

aMCfast: automation of fast NLO computations for PDF fits


https://arxiv.org/abs/1406.7693

Complicated Table Structure Recognition


https://arxiv.org/abs/1908.04729

Computation and Language Feb 2026


[725] arXiv:2602.12241 [pdf, html, other]. Title: Moonshine v2: Ergodic Streaming Encoder ASR for Latency-Critical Speech Applications. Manjunath Kudlur, Evan ...Read more

WhisperKit: On-device Real-time ASR with Billion-Scale ...


14 Jul 2025 — Real-time streaming transcription is a challenging ASR task with major commercial applications such as live captioning, dictation, meeting ...Read more

arXiv:2211.00896v2 [eess.AS] 4 Mar 2023


by D Le · 2022 · Cited by 7 — We show how factoring the RNN-T's output distribution can sig- nificantly reduce the computation cost and power consumption for on-device ASR ...Read more

Moonshine: Speech Recognition for Live Transcription and ...


21 Oct 2024 — Toward tackling the challenges faced by on-device, low-latency ASR applications, this paper introduces the Moonshine family of ASR models.Read more

Efficient Whisper on Streaming Speech


Streaming end-to-end speech recognition for mobile devices. In ICASSP 2019-2019 IEEE International Conference on Acoustics, Speech and Signal Processing ...

arXiv:2502.01649v1 [eess.AS] 29 Jan 2025


Our goal is to do ASR on mobile devices that can range from smartphone devices (with 4GB CPU ram) to user in- terface devices such as voice assistants ...

NPUsper: Eliminating Redundant Computation for Real ...


2 days ago — high-end mobile device. This allows NPUsper to complete each CPU-only streaming update within the inference interval even on the mobile CPU.

Pushing the Limits of On-Device Streaming ASR: A Compact, High-Accuracy English Model for Low-Latency Inference


by N Banfic · 2026 · Cited by 1 — We conduct a systematic empirical study of state-of-the-art ASR architectures, encompassing encoder-decoder, transducer, and LLM-based paradigms ...Read more

NPUsper: Eliminating Redundant Computation for Real-Time Whisper on Mobile NPUs


https://arxiv.org/abs/2607.01108

A Language Agnostic Multilingual Streaming On-Device ASR System


https://arxiv.org/abs/2208.13916

ClickAIXR: On-Device Multimodal Vision-Language ...


6 Apr 2026 — This paper presents a novel approach, ClickAIXR, that addresses these limitations through local on-device VLM deployment on XR headsets (Magic ...Read more

A General-Purpose Device for Interaction with LLMs


The device incorporates an offline awakening feature to enhance battery efficiency. Using the ASR PRO technology, the device can be awakened through a wake-up ...Read more

Enhancing Mobile Captioning with Diarization and ...


12 Feb 2025 — By combining SpeechCompass with mobile ASR, we enable legible transcripts by visually separating speech from different directions. We use the ...Read more

WhisperFlow: speech foundation models in real time


by R Wang · 2024 · Cited by 6 — This paper focuses on efficient inference of speech foundation models over streaming inputs, making them suitable for client devices. To this end, we contribute ...Read...

semanticscholar.org
semanticscholar.org
[PDF] Moonshine v2: Ergodic Streaming Encoder ASR for ...


Moonshine v2 is introduced, an ergodic streaming-encoder ASR model that employs sliding-window self-attention to achieve bounded, low-latency inference ...

k2-fsa.github.io
k2-fsa.github.io
APKs for VAD + non-streaming speech recognition


This page lists the VAD + non-streaming speech recognition APKs for sherpa-onnx, one of the deployment frameworks of the Next-gen Kaldi project. The name of an ...

sherpa-onnx — sherpa 1.3 documentation


In the following, we describe how to build sherpa-onnx for Linux, macOS, Windows, embedded systems, Android, and iOS.

Pre-trained models — sherpa 1.3 documentation


In this section, we describe how to download and use all available pre-trained models for speech recognition. Real-time speech recognition from a microphone

Build sherpa-onnx for Android


You can use this section for both speech-to-text (STT, ASR) and text-to-speech (TTS). The first step is to download and install Android Studio.

On-device VAD + ASR (本地非流式语音识别) — sherpa 1.3 ...


This page describes how to build SherpaOnnxVadAsr for on-device non-streaming speech recognition that runs on HarmonyOS. page is NOT for streaming models.

Zipformer CTC models — sherpa 1.3 documentation


This page lists non-streaming Zipformer CTC models from icefall. describe how to download it and use it with sherpa-onnx. Pre-built Android APK APP. Simulated ...

Offline CTC models — sherpa 1.3 documentation


This section lists available offline CTC models. Pre-built Android APK WebAssembly example (ASR from a microphone) Mo to sherpa-onnx Step 1: Export model.onnx ...

NeMo transducer-based Models — sherpa 1.3 documentation


Total lines: 968

Models — sherpa 1.3 documentation


In the following we show how to use omniASR_CTC_300M int8 . Hint. Usage for other models is similar to this one. Download the model . Please use the following ...Read more

Build Android examples — sherpa 1.3 documentation


Please follow Build sherpa-onnx for Qualcomm NPU. In the end, you should get Shared libraries. Copy them to the jniLibs/arm64-v8a directory.

APKs for streaming speech recognition


This page lists the streaming speech recognition APKs for sherpa-onnx, one of the deployment frameworks of the Next-gen Kaldi project. The name of an APK has ...Read more

Pre-trained Models — sherpa 1.3 documentation


9 Sept 2025 — You need to first select the language Chinese+English+Cantonese+Japanese+Korean and then select the model csukuangfj/sherpa-onnx-sense-voice-zh- ...Read more

Zipformer-transducer-based Models - sherpa-onnx


It supports decoding only wave files of a single channel with 16-bit encoded samples, while the sampling rate does not need to be 16 kHz.Read more

APKs for two-pass speech recognition


This page lists the two-pass speech recognition APKs for sherpa-onnx, one of the deployment frameworks of the Next-gen Kaldi project. The name of an APK has the ...Read more

Russian - sherpa-onnx


It supports decoding only wave files of a single channel with 16-bit encoded samples, while the sampling rate does not need to be 16 kHz.Read more

Offline transducer models — sherpa 1.3 documentation


Offline transducer models . This section lists available offline transducer models. Zipformer-transducer-based Models.Read more

Build sherpa-onnx for iOS


This section describes how to build sherpa-onnx for iPhone and iPad. Requirement Warning The minimum deployment requires the iOS version >= 13.0.Read more

Small models — sherpa 1.3 documentation


In this section, we list online/streaming models with fewer parameters that are suitable for resource constrained embedded systems.Read more

Online transducer models — sherpa 1.3 documentation


Online transducer models . This section lists available online transducer models. Zipformer-transducer-based Models.Read more

Hotwords (Contextual biasing) — sherpa 1.3 documentation


Note In the following example, we use a non-streaming model, if you are using a streaming model, you should use sherpa-onnx .

Flutter — sherpa 1.3 documentation


herpa-onnx sherpa-onnx Tutorials. Pre-built Flutter Apps Text to speech (TTS, Speech synthesis) Streaming Speech recognition (STT, ASR)

NeMo — sherpa 1.3 documentation


... sherpa-onnx-nemo-parakeet-tdt-0.6b-v2-int8 (English, 英语) · Android APK for real-time speech recognition · Download the model · Decode wave files · Real-time ...Read more

anaconda.org
anaconda.org
whisper.cpp - anaconda


1 May 2026 — whisper.cpp is a high-performance inference of OpenAI's Whisper automatic speech recognition (ASR) model implemented in C/C++.Read more

medium.com
medium.com
Run Whisper on Windows to Extract Text from Audio


Whisper is an open-source speech recognition model developed by OpenAI. It can transcribe audio into text, handle multiple languages, ...Read more

gitlab.informatik.uni-halle.de
gitlab.informatik.uni-halle.de
README.md - Till-Ole Herbst / Llama.Cpp


It is the main playground for developing new features for the ggml library. Supported platforms: Mac OS; Linux; Windows (via CMake); Docker; FreeBSD. Supported ...Read more

discussion.fedoraproject.org
discussion.fedoraproject.org
Whisper.cpp with GPU support on Fedora 39-41


20 Nov 2024 — I am testing it to convert live sporting commentary to text files. It can be very interesting to record live commentary and then compare the version you have ...Read more

modelslab.com
modelslab.com
Moonshine Vs Whisper Asr Real Time Speech 2026


27 Feb 2026 — Moonshine ASR beats Whisper Large V3 with 107ms latency vs 11286ms for real-time voice apps. Full benchmark comparison, Python code examples ...

voxrt.com
voxrt.com
On-Device ASR Comparison — VoxRT vs Cheetah, Whisper ...


This page compares the on-device options. Whisper.cpp, Vosk, Sherpa-onnx and Moonshine — in plain terms: how accurate they are, how fast they run, and how they ...

allenkuo.medium.com
allenkuo.medium.com
Choosing a Real-Time Whisper Engine | by Allen Kuo (kwyshell)


Testing CT2, TheWhisper, and whisper.cpp for live speech-to-text and why the pipeline mattered as much as the engine.Read more

gist.github.com
gist.github.com
Google Web SMS Private API


"Device is low on battery and will stop sending video frames to conserve battery. Remote side should do the same (symmetric video mute).",. "Local network is ...Read more

betterprogramming.pub
betterprogramming.pub
Whisper Showdown. C++ vs. Native: Speed, cost, YouTube…


20 Apr 2023 — Whisper is a powerful automatic speech recognition (ASR) model. I will share benchmarks and test results. speech recognition (ASR) model ...

aclanthology.org
aclanthology.org
Breaking Down Power Barriers in On-Device Streaming ASR


by Y Li · 2025 · Cited by 5 — Power consumption plays a crucial role in on- device streaming speech recognition, signifi- cantly influencing the user experience. This.Read more

isca-archive.org
isca-archive.org
A Language Agnostic Multilingual Streaming On-Device ...


by B Li · 2022 · Cited by 15 — Our on-device benchmark study showed that it is feasible to run large models in less than real time on a modern mobile device. On the latency side, we.Read more

papers.cool
papers.cool
NPUsper: Eliminating Redundant Computation for Real ...


3 days ago — We present NPUsper, a live transcription system that makes Whisper efficient on mobile NPUs by eliminating redundant computation.

reference-global.com
reference-global.com
Running Automatic Speech Recognition (ASR) Model in the ...


by RC NECULA · 2025 · Cited by 2 — This paper contributes to the field by providing evidence, comparison, statistics, level of accuracy in order to use ASR models in the context of low latency ...Read more

diva-portal.org
diva-portal.org
Performance analysis of ondevice streaming speech ...


by M Köling · 2021 · Cited by 1 — In this thesis, a set of streaming speech recognition models are implemented and experimented with. The main purpose is to increase knowledge of how machine ...Read more

scholar.google.com
scholar.google.com
https://scholar.google.com/citations?view_op=view_...


No information is available for this page.

dev.moonshine.ai
dev.moonshine.ai
@moonshine-ai/moonshine-js


MoonshineJS makes it easy for web developers to build modern, speech-driven web experiences without sacrificing user privacy. We build on three key principles:.Read more

note.com
note.com
[Surpassing Whisper!?] What is Moonshine Voice? A ...


Other language models, including Japanese, are under the Moonshine Community License (non-commercial only). Q. Does it run on Raspberry Pi? A.Read more

discuss.huggingface.co
discuss.huggingface.co
Error 401 Client Error: Unauthorized for url - 🤗Hub


28 Jun 2022 — When using model card of my private speech recognition model with LM, I got this error: 401 Client Error: Unauthorized for url: ...

opensource.stackexchange.com
opensource.stackexchange.com
Legal and Usage Questions about an Extension of Whisper ...


30 Jul 2023 — I recently came across an extension version of the Whisper model from OpenAI on GitHub, (https://github.com/linto-ai/whisper-timestamped) and I'm interested ...

community.openai.com
community.openai.com
Is Whisper open source safe?


27 Oct 2024 — Whisper's code is publicly available on GitHub under the MIT license. This means you can inspect the code yourself, verify its functionality ...Read more

myvoiceinbox.app
myvoiceinbox.app
Open Source Licenses - Voice Inbox


Speech recognition uses OpenAI Whisper model weights (MIT License, Copyright © 2022 OpenAI). ... OpenAI's open-source Whisper release: github.com/openai/whisper.Read more

ycombinator.com
ycombinator.com
GrapheneOS has been ported to Android 17


17 Jun 2026 — > at least at the time, they only supported pixel phones. At the time ... sherpa/onnx/tts/all/index.html · handedness 16 days ago | root ...Read more

facebook.com
facebook.com
Home Assistant voice processing timing analysis


I use sherpa-onnx/SenseVoice for voice detection. It supports english, japanese, korean, chinese mandarin and chinese cantonese. It is ...Read more

Caddx Moonlight Kit latency with VRX and Quest 3


Anyone know of a way to fix this Bluetooth latency issue or is it just not going to work? ... First issue Im having is extreme latency, im ...Read more

picovoice.ai
picovoice.ai
On-device AI Call Assist with Local LLM Reasoning


The lowest-scoring (highest accuracy) model is shown for Moonshine, Vosk, and Whisper.cpp. See the benchmark for the full comparison. English Punctuation Error ...Read more

gbatemp.net
gbatemp.net
Moonlight-NX - Nvidia Game Stream client | Page 4


27 May 2020 — - Video latency is comparable to Android Moonlight. - Audio latency is like 1s. - Audio is on and off often and sometimes completely stop ...Read more

theseus.fi
theseus.fi
Master's Thesis, Larri Jäntti 2025


If instead the app kept up with the speaker, meaning the recognition worked faster than real-time, the assertion passed. ... Sherpa-ONNX project Issue #895 in ...Read more

linkedin.com
linkedin.com
Running Whisper.cpp on Android without Cloud


I got I put debug around debug build around the benchmark because it's like my whisper core. I did that so so it could be only for developers.Read more

iamtypist.dev
iamtypist.dev
10 Best Audio to Text Transcription Free Tools in 2026 - Typist


If you want an easy starting point before trying offline tools like Whisper or whisper.cpp, Typist is a reasonable first stop. ... transcription benchmark study.Read more

gitcode.com
gitcode.com
openclaw/CHANGELOG.md-代码预览


Skills/sherpa-onnx-tts: run the sherpa-onnx-tts bin under ESM (replace ... Android/Voice screen TTS: stream assistant speech via ElevenLabs WebSocket ...Read more

youtubetotext.ai
youtubetotext.ai
The 12 Best Free Transcription Software Tools in 2026


16 Jan 2026 — The 12 Best Free Transcription Software Tools in 2026 · 1. YoutubeToText · 2. OpenAI Whisper (GitHub) · 3. whisper.cpp (GitHub) · 4. Audacity + ...Read more

forasoft.com
forasoft.com
SpeechAnalyzer, WhisperKit & the Full On-Device Playbook


24 Mar 2023 — Standardise on Whisper (WhisperKit on iOS, whisper.cpp on Android) with a single wrapper API. One transcript format, one post-processing ...Read more

Connector sources scanned

No connector sources scanned