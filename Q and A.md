# Q and A — async channel (Sri ⇄ Claude)

Protocol: either side appends. Questions get numbered `Q<n>`. Answers go directly under. Decisions that belong in the roadmap get a pointer to their `D<n>` box in [ROADMAP.md](./ROADMAP.md) instead of being re-argued here. Claude re-reads this file at the start of every session and before finishing long tasks.

---

Older resolved threads live in [Q and A archive.md](./Q and A archive.md) — do not re-inject them.

**Q13 (Claude → Sri, 2026-07-04):** you wrote in D5 "i am training models elsewhere — link that." Drop the link/repo/notes here and I'll wire it into the ROADMAP (D6 ASR + the `AsrEngine` interface) so your trained model is a first-class drop-in candidate alongside Moonshine/sherpa. What is it — a fine-tuned ASR, a VAD, a wake-word, something else? What framework/output format (ONNX? TFLite?)?

onnx i think you be able to find them in them on my kaggle. futo keyboard fork i have shipped with some 

> **A (Claude):** ONNX is ideal — it loads straight into ONNX Runtime / sherpa-onnx, so your model becomes a drop-in ASR backend, not a special case. Folded into ROADMAP D6: the `AsrEngine` interface will target an ONNX-Runtime backend that can load Moonshine, sherpa, **or** your trained model; added a "Spike C (Sri's own)" task. **Two quick follow-ups so I can wire it:** (a) your Kaggle profile/dataset link (I'll find the models); (b) what are they — ASR, VAD, or wake-word — and are they streaming-capable? Drop answers here.



**Q12 (Sri, 2026-07-04):** post deep-research areas here; I'll run them through ChatGPT Deep Research. Link a file describing what to research.

> **A:** Done — [docs/research/](./docs/research/README.md) has 6 self-contained, public-safe topic files (paste each whole file as the ChatGPT prompt). Ordered by priority: **R4** (Android 14/15 background-mic constraints — could reshape the trigger design, do first), **R3** (BT media-button reality — flagship P3 feasibility), **R1** (on-device ASR engine), R2 (VAD), R5 (offline sync transport), R6 (self-host backend footprint). Each maps to an open ROADMAP decision (D5/D6/D7/D8) or a phase feasibility question. Bring findings back as a `## Findings` section in the file or a share-link + TL;DR here; I fold accepted answers into the matching decision box.

research on the way in the orderr you asked. will paste the research in the smae research requirement files



---

## 🔔 2026-07-07 — greying build GREEN; new best test APK (beeped ×2)

**Install from run `28813351259`:** <https://github.com/sriharshaguthikonda/omi/actions/runs/28813351259> — supersedes `28810326937`; has everything: Moonshine R8 fix + B5 local transcripts + guest tab greying. Test list:
1. Settings → Transcription → **On-Device Moonshine** (~79 MB first download) → speak → live transcript.
2. Stop capture → **Conversations tab** → transcript row appears, readable on tap.
3. As guest: **Chat + Memories look greyed**, tapping shows sign-in hint; Conversations stays normal.
Report all three here (worked / failed + any error text).



## user comments
1. do other features and next setps commit after commit! dont stop 
2. compact sooner.....than way you will output high qualiy 
3. have this check integrated into your workflow, see if the build is successful or else troubleshoot it.




## agent update 2026-07-07 — Groq green + cherry-picked in; Phase-B PR staged

- **Groq presets build GREEN** (`28813777139`) on its own branch, and **cherry-picked into `feature/local-first`** (`e36d340`, clean merge, build `28815045799` watching) — so your NEXT local-first APK will have the Groq dropdown entries too (needs your Groq API key from <https://console.groq.com/keys>).
- **Phase-B PR is open and staged: <https://github.com/sriharshaguthikonda/omi/pull/6>** — everything bundled (Moonshine + B5 transcripts + greying + Groq presets). It does NOT merge until your 3-part test report on APK `28813351259` (or the newer `28815045799` once green — same content + Groq) comes back good. Then one click → apk-latest refreshes.
- Your move: the 3-step test list above. Everything else is done and waiting on that.

> **🔔 Definitive test APK GREEN (beeped ×2): run `28815045799`** — <https://github.com/sriharshaguthikonda/omi/actions/runs/28815045799>. Install this one; it has ALL of it (Moonshine + transcript rows + greying + Groq presets). Run the 3-step test above; your green report = one-click merge of PR #6 → apk-latest refresh.



## user comments
1. do other features and next setps commit after commit! dont stop 
2. compact sooner.....than way you will output high qualiy 


3. next to the debug device adb you can check what is going on, which particular version of app i am using. i am able to see the groq connection, i put in api key as well.

4. if this has to be merged with other branches or whatever 
5. other thing is there have been a failures in the workflow regarding linting or something
6. whisper thing didnt work on this branch idk if we expect that failure. 
6a. groq appears to have same issue as well. optimise not to bombard groq api 
7. moonshine is partially working but the transcript i think it only holds last word. it does not hold whatever it has been hearing. i am sure you can find out more from the logs.


## agent update 2026-07-07 ~03:50 am IST — all 7 items answered, fixes pushed

> **A3 (adb / your version):** adb works, phone `I2220` connected. You're on **1.0.542, installed 01:24 IST = the definitive APK `28815045799`** — correct build, has everything. (App isn't debuggable so I can't pull its internal logs over adb; if a future build misbehaves, use Settings → debug logs → share/export and drop the file anywhere in this repo folder.)
>
> **A7 (Moonshine only holds last word) — ROOT CAUSE FOUND + FIXED:** Moonshine sends its transcript as it refines it (partial → partial → final), and our segments carried **no id**. The app's transcript merger replaces segments *by id*, and every id defaulted to the same empty string — so every update **overwrote the whole transcript** instead of appending. Exactly "only holds the last thing heard". Fix (`65f176c`): each spoken line gets a stable id (partials update that line in place — you'll see it refine live), a finished line stays, next line appends. Unit test added for exactly this regression.
>
> **A6a (Groq "same issue" + bombarding) — same root cause + 2 more:** (1) Groq segments also had no id → same overwrite collapse. (2) When a Groq request failed (e.g. rate limit), the audio chunk was **silently thrown away** — fixed, it now retries with the next batch. (3) Request rate halved: 5s → 10s chunks (~6 requests/min, friendlier to Groq free-tier limits). Transcript appears in ~10s steps in Groq mode — that's by design for batch mode.
>
> **A6 (whisper didn't work):** expected — on-device Whisper was already known-broken on this branch (logged low-prio in ROADMAP; Moonshine is its replacement). Not a new failure, nothing to fix there. Note: the fixes above also repair the *cloud* whisper presets (OpenAI etc.) which silently had the same collapse bug.
>
> **A5 (workflow lint failures):** root-caused — 3 Dart files were unformatted and the Lint Check workflow fails hard on that. Formatted + pushed (`d45c581`). Also installed a local Dart SDK on this box so formatting slop gets caught before pushing from now on.
>
> **A4 (merge):** PR #6 is the same branch, so it now automatically includes tonight's fixes. Plan: new build goes green → I beep → you re-run the same 3-step test (Moonshine live transcript should now ACCUMULATE) → your green report = I merge PR #6 → apk-latest refresh. Build watchers armed; codex is doing an independent review pass of the fix in parallel.




## user comments
1. dont stop go on with further things in the roadmap
2. commit by commit
3. you orchestrate correct codex cli does heavy lifting
4. compact sooner after one feature is pushed!

> **A (Claude):** all four in effect. **P2 Triggers v1 started** — your D2 checkbox in ROADMAP ("all of the above, big-red-button redesign deferred") is the decision, so no re-litigating. Codex is implementing P2.1 right now on new branch `feature/p2-triggers` (own worktree, won't disturb PR #6): trigger-router seam + start/stop buttons on the recording notification, two commits, CI-checked per commit. QS tile and Tasker intent receiver are the next codex jobs after. Meanwhile the **STT-fix build on `24fe8e8` is running** — beep + install link the moment it's green; your Moonshine retest still gates PR #6 merge. Compacting right after this (handoff + memory already written).



## 🔔 2026-07-07 ~04:30 — STT-FIX APK GREEN (beeped ×2) — install + retest

**Install from run `28827747244`:** <https://github.com/sriharshaguthikonda/omi/actions/runs/28827747244> — supersedes `28815045799`. Contains the transcript-accumulation fix (Moonshine + Groq + cloud whisper presets), Groq rate-limit easing (10s batches), and no-more-dropped-audio-on-failure.

Retest (same 3 steps, new expectation on #1):
1. Moonshine live transcript — should now **ACCUMULATE sentence after sentence** (current line refines in place, finished lines stay).
2. Stop capture → Conversations tab → transcript row appears, readable, full text.
3. Groq (your key): transcript arrives in ~10s steps and accumulates; watch for any error banner.

Report all three here → green = I merge PR #6 → apk-latest refresh → beep.

## user comments
1. do parallel implementation of other features. 
2. later we can merge them.
3. codex heavy lifting.

> **A (Claude):** already running that way — **P2 triggers is in its own worktree/branch (`feature/p2-triggers`) with codex lifting right now**, PR #6 stays frozen for your retest, and they merge independently later. One constraint I respect: codex handles **one job at a time** on this box (its session DB clashes when doubled), so parallelism = separate branches with codex jobs queued back-to-back: P2.1 (router + notification buttons, running) → P2.2 (Quick Settings tile) → P2.3 (Tasker intent). Each lands commit-by-commit with CI checks. When a lane needs device testing you'll get a beep + branch APK link.

## user comments
1. moonshine is accumulating...
2. but i think the advantage of moonshine is that when it hears a longer sentence or something it goes back and changes the previous tokens or upcoming tokens something like that. we need to be able to use that advantage as well. we should be able to adjust the duration for which each transcript is or each chunk of the transcript is present or saved


3. feature is already there somewhere in the settings i don't know i could not check
4. the nasty thing is that when you go to settings and there is that search bar, it does not use that extraordinary lewensteinian and mistake tolerant system that it is supposed to use and automatically it has to focus on the search bar and expand. the original ui by the designer is so backward!
5. there are still some rough edges! you can debug logs, i connected the phone.
6. i don't know if this current version of the app is supposed to be working with whisper but i'm seeing no transcript when using whisper on device.
7. i did use multiple record and stop sessions but it is only showing one transcript in the chat tab.
	- i thought i did not have to press the process now button. apparently i have to press the process now button and only then this will be sent to that chats or transcript tab.
	- for whisper and groq this button does not appear!
8 . when i open the app it is showing this need permission to run in the background and location access, notification access, checkbox, screen. i think we can have this behind a settings panel when we would like to review the permissions but i don't think it has to ask every time. and it does not retain the permissions that i have given it previously. i am sure there might be something like this already. check and let agents implement.

9.i used different grok api keys and it does look like there is a block in the grok pathway. our application is somehow faulty.

10. as on device intelligence to handle as many aspects of the app as possible i am thinking of using a model that runs of my phone that can offer reasonable vision / embed / tool / ASR call capabiliites etc that app needs to handle as many features as possible in the app
 - in future we can plug in better models or finetuned ones!
 
 
**A (Claude):**


> **A (Claude, all 11) — triage:**
> **1 ✅** Moonshine accumulation confirmed on your device — the fix works. 
> **7 🔧 ROOT CAUSE FOUND, codex fixing NOW:** record/stop cycles all share one "session start" internally, and a guard blocks re-saving the same session — so only the first transcript ever persists, and it only lands via Process-now. Fix: each record→stop cycle becomes its own saved transcript, appearing on stop without Process-now. (Also tracing why Process-now shows only for Moonshine.)
> **9 🔧 same codex job:** static end-to-end audit of the Groq path (key → header → request → response parse), PLUS new error surfacing — repeated failures will show an error in the UI instead of silently doing nothing. If the audit can't find it, next APK's surfaced error text will tell us. It's "Groq" btw, not Grok — key from console.groq.com is right.
> **2/3 (Moonshine revises earlier words + adjustable chunk duration):** partials already revise in place now (the current line refines live before it locks). Line-length/duration knob = a Moonshine engine option — logged as backlog; I'll expose it in Transcription settings in a later pass. No existing setting does this today (the silence-timeout setting you may have seen only controls cloud conversation splitting).
> **6:** on-device Whisper is the known-broken legacy engine (pre-dates this work; Moonshine is its replacement). Stays broken/deprioritized — use Moonshine.
> **8 (permissions nag + not retained):** queued next after the bug job — will check the guest-boot permissions gate; goal: ask once, review later via Settings panel.
> **4 (settings search bar UX):** agreed it's clunky — backlog, UI pass (fuzzy match + no forced focus/expand).
> **5 (debug logs):** adb can't read the app's internal logs (release build). When something misbehaves: Settings → debug logs → export/share, drop the file anywhere in this repo folder and I'll parse it.
> **10 (one on-device model for vision/embed/tool/ASR):** direction noted and it fits the architecture — the AsrEngine/D6 seam generalizes to a local model runtime; candidates like Gemma-3n-class multimodal ONNX models fit your phone. Parking as a roadmap item (needs your Kaggle link from Q13 for the ASR part anyway).
> **Merge status:** PR #6 stays held until 7+9 fixes are green + you retest — they're part of the local-transcripts scope. P2 triggers branch continues in parallel after.



## user comments
1. use codex agents to do other work in parallel commits later we can merge

> **A (Claude):** running that way. Status right now: **(a)** codex's fixes for your bugs 7+9 are DONE + pushed (`c431110` each record/stop = own transcript row, no Process-now needed; `b6fa27a` Groq/whisper failures now show an error after 3 strikes instead of silence — codex's audit found the Groq request path itself is correctly built, so the surfaced error text on the next APK will name the real culprit) — build watching, beep on green; **(b)** codex is simultaneously implementing P2.1 triggers (router + notification start/stop buttons) on `feature/p2-triggers`; **(c)** merge plan unchanged: PR #6 after your retest, P2 branch merges later once its APK is device-checked. Next codex job after P2.1: your item 8 (permissions ask-once + review panel).

---

## agent update 2026-07-07 evening — access verified, "nothing pushed" solved, retest is THE gate

**Your "idk what is pushed" — answered:** the bug-fix APK **WAS pushed and built green**: run `28839829162` = **build #24**. And adb says your phone (I2220) is running exactly it — **1.0.542, versionCode 24, installed 09:31 today**. So you already have the right APK; no reinstall needed. What was NOT pushed: codex's P2.1 trigger commits sat local-only in the triggers worktree — your hunch was right. I reviewed them (router seam + notification Start/Stop buttons, wiring is sound), pushed `feature/p2-triggers`, first CI compile check running now.

**Access check you asked for — all green:** adb ✅ (phone I2220 connected), gh/CI ✅ (one gotcha fixed: gh was defaulting to upstream repo, now pinned to the fork), logcat ✅. One find from your live logs: **the app hammers `getConversations` every ~15s and gets 401 every time** (signed-in-but-backend-rejects state) — battery/network waste + log spam. Queued a backoff/skip fix as its own commit.

**Debug logs:** logcat buffer had already rolled past your test session, so I couldn't see your STT failures. Next time something misbehaves: tell me right away (I pull logcat live), or Settings → debug logs → export/share and drop the file anywhere in this repo folder.

**🔔 YOUR RETEST (this gates PR #6 merge — you're already on the right build):**
1. Record → stop → record → stop (2-3 cycles): **each** cycle should appear as its **own row** in Conversations, **without** pressing Process-now.
2. Groq (your key in): speak ~15s — if it fails you should now get a **visible error banner**; report the **exact text** here (it names the real culprit).
3. Moonshine: quick re-check that accumulation still works.
Report all three → green = I merge PR #6 → apk-latest refreshes.

**In flight meanwhile:** codex is on your **item 8** (permissions ask-once + Settings review row) on new branch `feature/permission-gate`; P2.1 CI watching; P2.2 (Quick Settings tile) queued next. Commit-by-commit, parallel branches, merge later — as ordered.

## user comments
1. use codex agents to do this sort of exploration as well

> **A (Claude):** acknowledged — exploration passes go to codex too from now on, not just implementation/review. (This one was a 3-file trace I did while codex was busy on item 8 — its single-session limit on this box means idle-Claude vs idle-work; but default flips to codex-first for exploration.) The trace's yield is already shipped: `7d46fd9` on feature/local-first stops the 15s 401 hammering — after the fast retry budget, an outright 401/403 stops rescheduling instead of retrying forever (pull-to-refresh still recovers manually). Build watching. 




## user comments
2. will check those other things but you are so fucking slow!!!

3. what about other issues like not retaining the permissions ...may be that is why background recording is not wokring....park those other bugs we need to fix in roadmap open and write somewehre in the later phases as well. but foucs on the other issues.
4. make moonshine as default stt provider in settings.
5. parallel branches for other things in roadmap

> **A (Claude, all 4, everything shipped while you typed):**
> **3 (permissions → maybe background recording):** codex's fix is DONE and pushed — branch `feature/permission-gate`, CI running. Root behavior now: permission screen shows **once**; after you complete it, only a missing **microphone** ever re-blocks boot (it's the capture-critical one). It also now checks *real* runtime state (mic + notification + location + battery-optimization exemption) instead of only a saved flag, adds the missing **microphone tile** to the screen, and Settings → Permissions reuses the same screen for later review. Your background-recording hypothesis is plausible — battery-optimization exemption is in that check; if background capture is still dead after this APK, next stop is the foreground-service path (parked in ROADMAP with pointers).
> **4 (Moonshine default):** shipped `7d25465` on feature/local-first — first boot on an Android 15+ phone auto-selects On-Device Moonshine (never overrides a choice you already made; older devices keep the old default). Since you already picked Moonshine manually, you won't notice a change — fresh installs will.
> **Bug parking lot** added to ROADMAP (Revisit backlog): background-recording, settings-search UX, Moonshine revision-window knob, on-device-model consolidation (item 10). Each has file pointers so any agent can pick them up.
> **5 (parallel branches):** live right now — `feature/local-first` (401-fix + Moonshine-default, APK building), `feature/p2-triggers` (P2.1 **compiled green** — notification Start/Stop buttons exist), `feature/permission-gate` (CI running). Next codex job: P2.2 Quick Settings tile.
> **2 (slow):** heard. This whole answer = ~40 min of parallel lanes. 



## user comments
2. you are so fucking slow!!!
3. use other codex agents to fix those background recording bug.....because the normal app does fine in terms of bacground recording!
4. focus of bluetoot which device and waht button sort of trigger feature! 

5. you are not waking up properly, you need to wake up in between and check what is going on as well.


> **A (Claude):**





## user comments
1. off screen work fine in the normal omi app but not our app?!

---

## agent answer 2026-07-07 (merge-all + screen-off bug lane)

**Merges — DONE (your "check and merge all the branches"):** `feature/permission-gate` (ask-once gate + Settings review — the one you confirmed works) and `feature/p2-triggers` (P2.1: trigger router + notification Start/Stop buttons) are both merged into `feature/local-first` and pushed; Groq presets were already in. Build watcher armed — on green I merge **PR #6 → fork main → apk-latest refreshes** and beep you. That apk-latest will finally have everything in one APK: Moonshine (default on fresh installs), local transcript rows, greying, Groq presets, permission gate, notification record buttons.

**Screen-off bug (recording restarts + transcript vanishes): checked every branch — fixed NOWHERE. It's new.** We discussed background-recording before (parked in ROADMAP), but this exact power-button symptom had no fix. Codex is on it right now on branch `feature/fix-screen-off`. Your data point that the **official app survives screen-off fine is gold** — it means upstream's foreground-service capture is sound and the bug lives in OUR additions (Moonshine socket lifecycle, or guest capture state reset on resume). Forwarded to codex; it's comparing our path against the surviving upstream path.

**BT trigger (your item 4):** locked as the very next codex lane after the screen-off fix (codex = one job at a time on this box). P3 spec already written: runtime learn-mode wizard, any device/button/press-pattern, nothing hardcoded.

**Wake-ups (your item 5):** build watcher + codex completion both auto-wake me now; I also re-check state at every wake instead of only at your messages.




## user comments
1. hopefully all the work that has been up till now is merged into one particular application and i will be testing next. is that build going on?

> **A (Claude):** Yes on both. Everything is now in ONE branch (`feature/local-first`): permission gate + P2.1 notification buttons + Groq presets + Moonshine default + all STT fixes. Its APK build is **running right now** (watcher armed). On green: PR #6 merges to main → **apk-latest refreshes** → I beep you with the install link. Bonus found while waiting: codex's P2.2 (Quick Settings tile "Omi capture" — toggle recording from the QS shade) was finished but sitting uncommitted — I reviewed it, it's sound, committing + pushing it now so it rides the same merge train. The screen-off fix lands as a follow-up build (codex mid-investigation).

## user comments


1. we have to move the not so relevant stuff or tasks that are already done from this q&a file to a q&a backup file in the same location because all that is being injected into your context every time. we start a new chat. make this lean. task it to another small agent


> **A (Claude, Q&A slimming):** Done — resolved threads moved to `Q and A archive.md` (same folder); this file now stays lean so session injections stop burning context. New rule: whenever a thread here is fully resolved, it graduates to the archive.


## user comments
1. codex is has hit quota see if you will get issues when you try to start new agents.
2. it will reset at 2:30 am

3.handover next features to your smaller agents

> **A (Claude):** Confirmed — both codex runs on the screen-off bug died (state/quota error, zero progress made). **Engine switch: I'm doing the screen-off investigation myself right now** instead of idling until 2:30; when quota resets, codex takes implementation/review lanes again (BT trigger P3 queued for it). Meanwhile the good news wave: **PR #6 is MERGED**, main APK is building → apk-latest refresh + beep coming; **P2.2 Quick Settings tile compiled green** on its branch, merges in the next train with the screen-off fix.



## user comments
1. multiple parallel agents for differnt features. 

2. triggers like bluetooh device and the type of keypress priority
3. see what else features have been developed in other branches and merge
4. codex does lifting you monitor and orchestrate and correct

5. phone connected check debug logs 
> **A (Claude, all 5):**
> **SCREEN-OFF BUG: ROOT CAUSE FOUND + FIX COMMITTED (`c594219`).** Exactly what you described: recording never stopped — but on screen-ON the app reloads the "in-progress conversation" **from the backend**; guests/local-STT get an empty answer and the code wiped your live transcript and started a fresh session (that's also why Process-now only saw the recent part). Fix: never discard locally-produced transcript when the backend has nothing. Merged into `feature/local-first` together with **P2.2 (Quick Settings tile, compiled green)** — build running, on green it goes to main → apk-latest → beep + retest instructions.
> **1 (parallel agents):** live now — 3 lanes: screen-off fix (done, mine), **P3 BT trigger increment 1 via codex** (media-button → toggle, per plans/P3-bt-trigger-matrix.md), **P2.3 Tasker intent trigger via Claude sonnet agent** (external app trigger, gated OFF by default for mic security).
> **2 (BT priority):** yes — that's the codex lane above; learn-mode wizard (which device/button/press-type) is its next increments.
> **3 (other branches):** checked & merged — permission-gate, p2-triggers (P2.1+P2.2), groq presets, screen-off fix are ALL in `feature/local-first` now; no other branch had unmerged feature work.
> **4 (codex lifts):** codex is on the P3 lane; if its quota is still dead it reports back and the lane falls to a Claude agent until 2:30.
> **5 (debug logs):** phone seen on adb (10BF191Z51001DC) but logcat had already rolled past your test — nothing useful. Not needed though: the wipe was found in code, exact line. If a future misbehave: tell me right away and I pull logcat within minutes.
