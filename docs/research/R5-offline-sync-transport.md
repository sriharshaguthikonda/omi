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





https://chatgpt.com/c/6a4917aa-b1b4-83e8-8322-e186a3d0c183








# R5 — Offline-first phone→desktop sync transport for capture bundles

**Priority:** MEDIUM
**Closes:** D8 / sizes P8 (`.memory` integration transport)
**Decision date:** 2026-07-04
**Target setup:** Android phone → Windows desktop → local personal database + optional `personal_kaggle` export lane

## 1. Decision

Use **Syncthing-Fork + append-only file-drop outbox** as the default transport.

Keep **Local HTTP + durable WorkManager outbox** as the fallback if Android/OEM background killing makes Syncthing-Fork too unreliable on the target phone.

Use **ADB pull** as a debug/manual recovery lane.

Use **cloud drive** only as a break-glass option, because it violates the “avoid third-party cloud” preference.

Do **not** use LocalSend or KDE Connect as the primary transport. They are good manual LAN file-transfer tools, but they are not a durable unattended outbox queue for app-generated capture bundles.

The key architectural point is this: **transport must be dumb and retry-safe; ingest must be idempotent**. Every bundle gets a stable `bundle_id`; the Windows ingest path dedupes by that ID and content hash. Transport retries are then harmless.

## 2. Repository fit: Omi context

The repo is `sriharshaguthikonda/omi`, based on Omi, “a 2nd brain” that captures screen/conversations, transcribes, summarises, and works across desktop, phone, and wearables.

The Android mobile app is Flutter. Existing dependencies already fit a file-drop/outbox design:

- `http` is already present for a future HTTP fallback.
- `uuid` is already present, which fits stable bundle IDs.
- `path_provider` is already present, which fits app-private outbox paths.
- `crypto` is already present, which fits SHA-256 bundle/content hashes.
- `flutter_foreground_task` and `flutter_background_service` are present, but the current Android manifest removes the plugin boot receivers. That means **do not assume the existing Flutter background service will restart after reboot** without adding/keeping a proper native receiver or WorkManager path.
- The Android manifest already requests foreground-service, companion-device, microphone, Bluetooth, battery-optimisation, and wake-lock style permissions. It also has a native BLE foreground service with `stopWithTask="false"`.

Relevant repo paths:

- `README.md`: <https://github.com/sriharshaguthikonda/omi/blob/main/README.md>
- `app/pubspec.yaml`: <https://github.com/sriharshaguthikonda/omi/blob/main/app/pubspec.yaml>
- `app/android/app/src/main/AndroidManifest.xml`: <https://github.com/sriharshaguthikonda/omi/blob/main/app/android/app/src/main/AndroidManifest.xml>

Practical implication: for R5, the **least invasive first implementation** is not to add a new long-running app transport service. Let the Android app write completed bundles into a Syncthing-shared outbox folder. Let Syncthing-Fork move files. Let Windows ingest watch/read that folder.

## 3. What was researched

### Primary/official sources

- Syncthing security docs: <https://docs.syncthing.net/users/security.html>
- Syncthing FAQ: <https://docs.syncthing.net/users/faq.html>
- Syncthing folder types: <https://docs.syncthing.net/users/foldertypes.html>
- Syncthing configuration docs: <https://docs.syncthing.net/users/config.html>
- Android WorkManager / persistent work: <https://developer.android.com/develop/background-work/background-tasks/persistent>
- Android battery/task scheduling guidance: <https://developer.android.com/develop/background-work/background-tasks/optimize-battery>
- Android Doze/App Standby guidance: <https://developer.android.com/training/monitoring-device-state/doze-standby>
- Android Debug Bridge docs: <https://developer.android.com/tools/adb>
- Google Drive resumable upload docs: <https://developers.google.com/workspace/drive/api/guides/manage-uploads>

### Related GitHub implementations

- Official Syncthing Android app, now discontinued/archive: <https://github.com/syncthing/syncthing-android>
- Maintained Syncthing-Fork Android app: <https://github.com/researchxxl/syncthing-android>
- Syncthing-Fork boot receiver: <https://github.com/researchxxl/syncthing-android/blob/acbc22985b5130d099336a28a5038d595f062622/app/src/main/java/com/nutomic/syncthingandroid/receiver/BootReceiver.java>
- Syncthing-Fork Android manifest: <https://github.com/researchxxl/syncthing-android/blob/acbc22985b5130d099336a28a5038d595f062622/app/src/main/AndroidManifest.xml>
- LocalSend: <https://github.com/localsend/localsend>
- KDE Connect: <https://kdeconnect.kde.org/>
- Android Architecture Components samples, including WorkManager sample references: <https://github.com/android/architecture-components-samples>
- Android WorkManager codelab repo: <https://github.com/android/codelab-android-workmanager>

## 4. Comparison table

| Transport | Durability / eventual delivery | Android background survival | Partial / interrupted transfer handling | Idempotency support | Setup + maintenance | Security | Latency | Verdict |
|---|---|---|---|---|---|---|---|---|
| **Syncthing-Fork folder sync** | **Strong** if both devices eventually run. Phone writes completed bundle files locally; Syncthing syncs when phone and PC are online. Syncthing is designed for device-to-device folder sync rather than app-level queueing. | **Medium.** Better than the discontinued official Android app because Syncthing-Fork has boot receiver + foreground-service code, but Android/OEM battery rules can still stop it. Needs battery exemption, notification permission, all-files access, autostart/start-on-boot, and sane run conditions. | **Strong.** Syncthing uses block transfer and temporary partial files. Still use `_READY` markers so Windows never ingests half a multi-file bundle. | **External.** Syncthing does not give app-level exactly-once semantics; ingest dedupes using `bundle_id` + `content_sha256`. | **Moderate first setup, low maintenance.** Install Syncthing-Fork on Android and Syncthing/Syncthing Tray on Windows; pair devices; share one outbox folder. | **Good in transit.** Syncthing device traffic is TLS-protected and device IDs are certificate fingerprints. For LAN-only, disable global discovery/relays and use local discovery/static address. At rest, use Android file-based encryption + Windows BitLocker if needed. | **Seconds to minutes** while both are on same LAN and Syncthing is running; eventual after long offline periods. | **Recommended default.** Best match for zero new server and reusing existing bulk ingest lane. |
| **Local HTTP endpoint + Android WorkManager outbox** | **Strongest app-level durability** if implemented correctly: Room/file outbox persists locally; WorkManager retries until desktop ack; desktop writes atomically. | **High for scheduled/retry work.** WorkManager persists work across app restarts and device reboots and follows Doze/power rules. It is more correct than a hand-rolled background loop. It may defer work under Doze, so it is “eventual”, not always instant. | **Strong if implemented.** Use `PUT /v1/bundles/{bundle_id}` or multipart upload to `.part`, verify hash, atomic rename, then ack. | **Native.** Use `bundle_id` as idempotency key and database unique constraint. HTTP 200/201/204/409 duplicate all count as success. | **Higher.** Need a Windows service/daemon, firewall rule, LAN discovery/static IP, Android native WorkManager integration or a mature Flutter WorkManager plugin. | **Good if LAN-bound.** Bind only to LAN/private profile; use token + HMAC or mutual secret. Use HTTPS if data is sensitive. *Do not expose this port to the internet.* | **Minutes when on LAN** depending on WorkManager scheduling; can be near-real-time with expedited work but that should be reserved for user-visible urgent sync. | **Best fallback** if Syncthing-Fork background reliability is poor or explicit server acks are needed. |
| **ADB pull from Windows** | **Good as manual/recovery lane.** Bundles sit on phone until Windows pulls them. Re-run is safe if filenames/IDs are stable. | **Excellent against Android background limits** because the phone app does not need a network/background sync service. | **Medium.** Re-running `adb pull` works, but partial local files must be handled by script (`.part` then rename). | **External.** Use stable filename + DB unique constraint. | **Low.** Install Android Platform Tools, enable USB debugging, write Task Scheduler script. Annoying for daily use if phone is not always connected. | **Very good over USB.** Wireless debugging is less attractive for unattended use. USB debugging trust prompt/RSA keys protect commands. | **Only when connected.** Fast when plugged in, otherwise no delivery. | **Keep as backup/debug**; not primary because it depends on physical connection. |
| **Cloud drive drop/API** | **Good provider-level durability** if the app/provider queue works. Google Drive supports resumable uploads for interrupted transfers. | **Medium.** Provider apps and app uploads are still subject to Android background rules unless implemented with proper system APIs. | **Good with resumable API**, less controlled if relying on consumer sync clients. | **External.** Stable names/IDs + DB unique constraints. | **Low.** Easiest setup, but adds account/API/provider dependency. | **Third-party storage.** HTTPS + provider at-rest encryption, but data leaves local devices. | **Minutes with internet**, not LAN-only; mobile data policy matters. | **Break-glass only** because “no third-party cloud if avoidable”. |
| **LocalSend** | **Weak for unattended durability.** It is excellent for manual nearby file sharing, not an app-owned durable queue. | **Medium.** App must be running/available; Android background reliability depends on app and OS restrictions. | **Good for manual transfers**, not designed as a persistent outbox. | **External.** Could still dedupe after transfer. | **Low manual setup.** Firewall port 53317 and AP isolation can bite. | **Good local security.** Uses REST API + HTTPS and no external server. | **Fast on LAN** when both apps are open/reachable. | **Do not use as primary.** Useful manual “send this folder now” tool. |
| **KDE Connect** | **Weak for unattended app bundle delivery.** Useful device integration and file browsing, not a durable app queue. | **Medium.** Depends on Android app availability and pairing/network reachability. | **Manual transfer semantics.** | **External.** Dedup after transfer. | **Low/moderate.** Pairing, firewall, same network/VPN. | **Local trusted-device model.** Security depends on paired devices and LAN/VPN exposure. | **Fast on LAN** when connected. | **Manual helper only**, not R5 default. |

## 5. Key findings

### 5.1 Syncthing Android gotcha: official app is dead; use Syncthing-Fork

The official `syncthing/syncthing-android` repository was archived on 2024-12-03 and says the app is discontinued. The README says the last GitHub/F-Droid release happened with the December 2024 Syncthing version and cites lack of active maintenance plus Google Play publishing difficulty.

Use **Syncthing-Fork** (`researchxxl/syncthing-android`) instead. It is an Android wrapper around Syncthing and explicitly positions itself as the maintained path for users switching from the deprecated official app.

Relevant implementation details from Syncthing-Fork:

- It declares permissions for `RECEIVE_BOOT_COMPLETED`, `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`, foreground service, all-files access, local discovery multicast, Wi-Fi state, and notification permission.
- It has a `BootReceiver` that reacts to `BOOT_COMPLETED` / `MY_PACKAGE_REPLACED`, checks the “start service on boot” preference, and starts the Syncthing service.
- On Android O and above, the receiver starts a foreground service.
- The manifest declares `SyncthingService` as a foreground service with special-use wording: continuous file sync, monitor file changes, send/receive changes.

That is **exactly the kind of implementation needed for a file-sync app**, but it is still not magic. Android/OEM battery policy can kill or defer background work. The setup must include battery exemption and autostart/start-on-boot testing on the actual phone.

### 5.2 Syncthing security and LAN-only settings

Syncthing’s official security docs state that device-to-device traffic is protected by TLS and that the device ID is the SHA-256 fingerprint of the device certificate. That is good for in-transit confidentiality.

For a local-only setup:

- disable global discovery,
- disable relays,
- optionally disable NAT traversal/UPnP,
- use local discovery or a static desktop address,
- consider `allowedNetwork` to restrict the desktop device connection to private LAN ranges,
- keep the GUI bound to localhost unless there is a clear reason to expose it,
- use BitLocker on Windows and Android device encryption for at-rest protection.

Syncthing does **not** remove the need for local disk encryption. Once a file lands on either device, it is readable to whoever can read that filesystem.

### 5.3 Syncthing durability and partial files

Syncthing is a folder synchroniser, not a message broker. That is fine for this use case if bundle files are immutable.

Use this rule:

> The app never modifies a bundle after publishing it to the synced folder.

Syncthing transfers files in blocks and uses temporary files for partial downloads. But a capture bundle is usually a directory with multiple files, so the desktop ingest must not consume a directory just because the first file arrived. Use an explicit ready marker.

Correct pattern:

```text
phone app-private build area
└── .building/<bundle_id>/
    ├── manifest.json
    ├── transcript.txt
    └── audio.opus

Syncthing shared outbox
└── pending/<bundle_id>/
    ├── manifest.json
    ├── transcript.txt
    ├── audio.opus
    └── _READY
```

The app builds the bundle outside the synced directory, then moves/copies the complete directory into the Syncthing outbox and writes `_READY` last. The Windows ingest ignores any bundle without `_READY`.

### 5.4 Android background reality

Android’s official guidance is clear: Doze and App Standby restrict network access, defer jobs/syncs, and optimise battery. WorkManager is the right API for durable, scheduled, retryable work that should continue after the app leaves the visible state. WorkManager persists scheduled work in an internal SQLite database and reschedules it across device reboot.

For this project:

- **Syncthing-Fork** gives a ready-made foreground file-sync service. Battery exemption and start-on-boot testing are mandatory.
- **WorkManager** is the correct fallback if the Omi app itself must own delivery and ack state.
- A plain Flutter background loop is *not* enough for “never lose bundle” transport.
- Foreground services should not be abused just to defeat battery policy. Use them only where justified by user-visible continuous capture/Bluetooth/sync behaviour.

### 5.5 Existing Omi Android background configuration needs care

Current Omi Android manifest removes `RECEIVE_BOOT_COMPLETED`, `flutter_foreground_task` reboot receiver, and `flutter_background_service` boot receiver. That is a warning sign for R5: existing Flutter background plugins should not be assumed to restart after reboot.

For the Syncthing file-drop default, this is acceptable because the Omi app only has to write local files when captures happen; Syncthing-Fork handles sync.

For the HTTP fallback, add a proper native WorkManager integration and test:

- app killed,
- force stop (note: Android force-stop blocks future scheduled work until user opens app again),
- phone reboot,
- Wi-Fi lost for hours,
- PC offline for hours,
- desktop server rejects or times out,
- 100 duplicate retries,
- partially uploaded file,
- low battery / Doze.

## 6. Concrete phone-side outbox pattern

### 6.1 Bundle identity

Each bundle must have a stable ID generated once at capture finalisation:

```text
bundle_id = <device_id>_<capture_started_at_utc>_<uuid>
```

Example:

```text
pixel8_2026-07-04T14-18-22Z_018fe4c2-8b51-7cc0-9d9e-1cf02b22b33a
```

Use UUIDv7 if available for sortable IDs; UUIDv4 is acceptable. Store it in both filename/path and manifest.

### 6.2 Manifest schema

```json
{
  "schema_version": 1,
  "bundle_id": "pixel8_2026-07-04T14-18-22Z_018fe4c2-8b51-7cc0-9d9e-1cf02b22b33a",
  "source": "omi-android",
  "device_id": "pixel8",
  "app_version": "1.0.542+970",
  "capture_started_at": "2026-07-04T14:18:22Z",
  "capture_ended_at": "2026-07-04T14:20:03Z",
  "created_at": "2026-07-04T14:20:04Z",
  "files": [
    {
      "path": "transcript.txt",
      "media_type": "text/plain",
      "size_bytes": 4821,
      "sha256": "..."
    },
    {
      "path": "audio.opus",
      "media_type": "audio/opus",
      "size_bytes": 188204,
      "sha256": "..."
    }
  ],
  "bundle_sha256": "...",
  "transport": {
    "preferred": "syncthing_file_drop",
    "retry_safe": true
  }
}
```

### 6.3 Filesystem layout

On Android:

```text
Android/data/com.friend.ios/files/omi_sync/
├── build/                 # not shared; temporary creation area
├── outbox/
│   └── pending/<bundle_id>/
│       ├── manifest.json
│       ├── transcript.txt
│       ├── audio.opus
│       └── _READY
└── ack/                   # optional reverse-sync ack folder
```

On Windows:

```text
D:\OmiSync\phone_outbox\
└── pending\<bundle_id>\...

D:\OmiIngest\
├── archive\<bundle_id>\...
├── failed\<bundle_id>\...
└── logs\
```

### 6.4 Atomic publish rule

1. Write files to app-private `build/<bundle_id>/`.
2. Compute per-file SHA-256 and bundle SHA-256.
3. Write `manifest.json`.
4. Copy/move complete directory into Syncthing-shared `outbox/pending/<bundle_id>/`.
5. Write `_READY` last.
6. Never mutate the bundle again.

For a single-file bundle, a `.tmp` suffix then atomic rename is enough. For multi-file bundles, `_READY` is safer and easier.

### 6.5 Desktop ingest rule

Ingest only directories that contain `_READY`.

Pseudo-SQL:

```sql
CREATE TABLE IF NOT EXISTS capture_bundle (
  bundle_id TEXT PRIMARY KEY,
  bundle_sha256 TEXT NOT NULL,
  source_device TEXT,
  manifest_json TEXT NOT NULL,
  first_seen_at TEXT NOT NULL,
  ingested_at TEXT NOT NULL,
  ingest_status TEXT NOT NULL
);
```

Ingest transaction:

```sql
INSERT INTO capture_bundle (
  bundle_id,
  bundle_sha256,
  source_device,
  manifest_json,
  first_seen_at,
  ingested_at,
  ingest_status
)
VALUES (?, ?, ?, ?, ?, ?, 'ingested')
ON CONFLICT(bundle_id) DO NOTHING;
```

If row count is zero, the bundle was already ingested. Do not import it twice.

For the personal Kaggle lane:

```text
capture_bundle -> local DB -> personal_kaggle/export/capture_bundle.parquet
```

Rules:

- `bundle_id` remains the primary key everywhere.
- `bundle_sha256` is stored in the local DB and in exported dataset metadata.
- Any export job is reproducible from the immutable archive.
- Kaggle/personal dataset export never becomes the source of truth; the local ingest archive and DB are the source of truth.

### 6.6 Acknowledgement and cleanup

Do **not** let Windows delete files inside the phone-origin outbox unless you intentionally want deletes to sync back.

Safer options:

1. **Retention cleanup:** phone keeps uploaded bundles for 30 days or until storage exceeds a threshold. This is simplest.
2. **Separate ack folder:** Windows writes `ack/<bundle_id>.json` into a separate desktop→phone sync folder. The Android app prunes only after seeing the ack.
3. **Manual cleanup:** acceptable for early prototype.

Recommended first version: **retention cleanup + immutable archive**. Add ack folder later if storage becomes a problem.

## 7. Syncthing-Fork configuration

### Android phone

Use Syncthing-Fork, not the archived official Syncthing Android app.

Settings/checklist:

- enable start on boot;
- disable battery optimisation for Syncthing-Fork;
- allow background/autostart in OEM battery manager if present;
- allow notification permission;
- allow all-files access / storage access needed for the chosen folder;
- keep folder small and append-only;
- set run condition to Wi-Fi only unless mobile-data sync is acceptable;
- test after reboot and after screen-off for at least 30–60 minutes.

Folder type:

- Phone outbox folder: **Send Only**
- Windows receiving folder: **Receive Only**

Do not edit received bundle files on Windows inside the synced folder. Copy to ingest archive first.

### Windows desktop

Use Syncthing or Syncthing Tray.

Settings/checklist:

- run at login;
- allow Windows Firewall private-network access;
- keep receiving folder outside the database output folder;
- disable relays/global discovery if LAN-only is required;
- use static device address if local discovery is flaky;
- turn on BitLocker if capture text/audio is sensitive.

### `.stignore` suggestion

```gitignore
(?d).building/
(?d).tmp/
*.tmp
*.part
*.uploading
```

Do not ignore `_READY`.

## 8. Local HTTP fallback design

Use this if Syncthing-Fork proves *too fragile* on the phone or if explicit server-side acknowledgements are required.

### Android

Use native WorkManager rather than a simple background loop.

Room table:

```sql
CREATE TABLE outbox_bundle (
  bundle_id TEXT PRIMARY KEY,
  local_path TEXT NOT NULL,
  bundle_sha256 TEXT NOT NULL,
  status TEXT NOT NULL,
  attempt_count INTEGER NOT NULL DEFAULT 0,
  next_attempt_at TEXT,
  last_error TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);
```

WorkManager:

- `OneTimeWorkRequest` per bundle or one coalesced sync worker.
- constraints: `NetworkType.UNMETERED` for battery-friendly default; `NetworkType.CONNECTED` if LAN sync must happen over any Wi-Fi.
- exponential backoff.
- `Result.retry()` on network errors, timeout, and HTTP 5xx.
- `Result.success()` on 200/201/204 or 409 duplicate-already-present.
- never delete local bundle until the server confirms and the local DB marks it delivered.

### Windows endpoint

Minimal API:

```text
GET  /v1/health
PUT  /v1/bundles/{bundle_id}
GET  /v1/bundles/{bundle_id}
```

Upload rule:

1. authenticate request using bearer token or HMAC header;
2. write request body to `<bundle_id>.part`;
3. verify content length and SHA-256;
4. atomically rename to archive path;
5. insert DB row with `bundle_id` unique;
6. return success even for duplicate same-hash upload.

Do **not** expose this endpoint to the internet. Bind to private LAN or localhost + reverse tunnel only if intentionally configured.

## 9. ADB pull backup lane

Keep a Windows script for recovery/debug:

```powershell
$src = "/sdcard/Android/data/com.friend.ios/files/omi_sync/outbox/pending"
$dst = "D:\OmiSync\adb_pull\pending"

adb devices
adb pull $src $dst
python D:\OmiIngest\ingest.py --source $dst
```

Use Task Scheduler only if the phone is often plugged in. Otherwise use it manually.

ADB is useful when:

- Syncthing is misconfigured;
- phone has many stuck bundles;
- network/firewall is broken;
- you want a known-good one-off extraction.

## 10. Why LocalSend/KDE Connect are not the answer

LocalSend is a good open-source AirDrop-like local file transfer app. It uses REST API + HTTPS, no external server, and works over the local network. But it is mainly a user-driven file transfer tool, not a durable app-level delivery queue.

KDE Connect can share files, browse phone files, pair trusted devices, and work across desktop/phone. It is useful as a manual bridge, not as a reliable unattended sync queue with app-owned retry semantics.

Both are fine as manual rescue tools. Neither closes R5 as the primary transport.

## 11. Failure cases and expected behaviour

| Failure | Expected behaviour |
|---|---|
| Phone offline for hours | Bundle remains in local outbox. Syncthing/HTTP delivers later. |
| Windows PC off | Bundle remains on phone and syncs when PC returns. |
| Android app killed | Bundle already written to disk remains safe. Syncthing-Fork or WorkManager handles later delivery when allowed. |
| Phone reboot | Syncthing-Fork should restart if start-on-boot works; WorkManager persists scheduled work. Existing Omi Flutter boot receivers are currently removed, so do not rely on them. |
| Transfer interrupted | Syncthing temp/partial files or HTTP `.part` files prevent half-ingest. `_READY` marker prevents early ingest. |
| Duplicate retry | DB unique constraint on `bundle_id` prevents duplicate ingestion. |
| Desktop ingest crash | Re-run ingest. It skips already inserted `bundle_id`s. |
| Corrupt file | SHA-256 mismatch moves bundle to `failed/` and does not insert success row. |
| Syncthing conflict | Should be rare if bundles are immutable and phone is Send Only / Windows Receive Only. Treat any conflict file as failed/manual review. |

## 12. Acceptance criteria for D8/P8

R5 is done when:

- [ ] Android app writes immutable bundle directories with `manifest.json`, transcript, optional audio, and `_READY`.
- [ ] Each bundle has stable `bundle_id` and `bundle_sha256`.
- [ ] Windows ingest uses `bundle_id` as a unique key.
- [ ] Windows ingest ignores directories without `_READY`.
- [ ] Syncthing-Fork phone folder is configured Send Only.
- [ ] Windows folder is configured Receive Only.
- [ ] Global discovery and relays are disabled if LAN-only is required.
- [ ] Reboot test passes: create bundle, reboot phone before sync, confirm eventual delivery.
- [ ] Offline test passes: create bundle away from Wi-Fi, return to Wi-Fi, confirm eventual delivery.
- [ ] Duplicate test passes: copy same bundle twice, confirm single DB row.
- [ ] Corruption test passes: modify transcript after manifest hash, confirm failure not ingest.
- [ ] Personal Kaggle export uses same `bundle_id` primary key and can be regenerated from local DB/archive.

## 13. Final recommendation

Default to:

```text
Omi Android capture finalised
  -> immutable file bundle in Android outbox
  -> Syncthing-Fork syncs folder to Windows
  -> Windows watcher/batch ingest
  -> local personal database
  -> optional personal_kaggle export
```

This gives the best balance:

- **no new always-on custom server**,
- **no third-party cloud**,
- **works offline-first**,
- **durable enough for small JSON/text/audio bundles**,
- **simple Windows ingest path**,
- **safe retries through idempotent bundle IDs**.

Add the HTTP + WorkManager route only if the real phone’s battery manager makes Syncthing-Fork unreliable after proper setup.
