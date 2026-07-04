# P1 — Sign-in That Works Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans. Steps use checkbox (`- [ ]`) syntax. Standing rule: Codex CLI implements, Claude orchestrates and corrects.

**Goal:** The sideloaded prerelease APK signs in first try — and when it doesn't, the app tells us exactly why and exactly which build it is.

**Architecture:** Three thin changes, no auth redesign: (1) a `BuildStamp` sourced from `--dart-define` at CI build time, shown on the sign-in footer + About page — kills "which APK is this?" forever; (2) sign-in error surfacing — real exception text stored + shown (dev flavor), not the generic snackbar; (3) deep-link verification — the web-auth browser flow must return via `omi://auth/callback`, so the manifest intent-filter must exist in the dev flavor.

**Tech Stack:** Flutter/Dart, `String.fromEnvironment` (dart-define; no envied/codegen coupling), existing `package_info_plus` dep, GitHub Actions workflow edit.

## Verified auth-flow facts (Explore pass 2026-07-04, file:line)

- `app/lib/providers/auth_provider.dart:87-96,116-125` — `Env.useWebAuth==true` routes **both** Google and Apple buttons through `AuthService.authenticateWithProvider(provider)` (browser OAuth) instead of native plugins. Same buttons render either way → **no visible difference between lanes** (Sri's Q9 complaint confirmed).
- `app/lib/services/auth_service.dart:196-308` — browser opens `${Env.apiBaseUrl}v1/auth/authorize` (PKCE), waits on deep link `omi://auth/callback` with 5-min timeout; exchange at `${Env.apiBaseUrl}v1/auth/token` (:319); `USE_AUTH_CUSTOM_TOKEN=true` → `signInWithCustomToken` (:351-353).
- `app/lib/env/dev_env.dart:20` — `API_BASE_URL` is `obfuscate: true`, **no defaultValue** → null when `.dev.env` absent → authorize URL literally `"nullv1/auth/authorize"`. `USE_WEB_AUTH`/`USE_AUTH_CUSTOM_TOKEN` default **false** (:48,:52) → an APK built without `.dev.env` is native-Google-only → `ApiException: 10` on foreign keystores. This is the upstream-APK failure Sri hit (Q7).
- `app/lib/providers/auth_provider.dart:100-186` — **every** failure path shows a generic localized snackbar ("Authentication failed. Please try again."); raw exception only in `Logger.debug`. 10+ distinct failure modes, one user-visible string.
- `app/pubspec.yaml:86` — `package_info_plus: ^8.0.1` already a dependency; version shown in settings drawer (`settings_drawer.dart:103-122`); `about.dart` shows no version at all.

## Global Constraints

- No auth-logic redesign — surface + stamp only. Web-auth lane stays the supported path (D1 closed).
- New user-facing strings via l10n where they're sentences; raw technical payloads (sha, error text) are data, not copy — no l10n.
- Formatting: `dart format --line-length 120`. No purple in UI (repo rule).
- Stamp must work in local builds too: every dart-define has a default (`local`/`0`/`dev`).
- Minimal diffs inside upstream files; new logic in new files.

---

### Task 1: BuildStamp module + sign-in footer + About row

**Files:**
- Create: `app/lib/widgets/build_stamp.dart`
- Modify: `app/lib/pages/onboarding/auth.dart` (footer area, ~lines 135-162: add `BuildStamp(compact: true)`)
- Modify: `app/lib/pages/settings/about.dart` (add Build Info tile after existing tiles, ~line 59)

**Interfaces (produced):**
```dart
class BuildInfo {
  static const String sha = String.fromEnvironment('OMI_BUILD_SHA', defaultValue: 'local');
  static const String run = String.fromEnvironment('OMI_BUILD_RUN', defaultValue: '0');
  static const String branch = String.fromEnvironment('OMI_BUILD_BRANCH', defaultValue: 'dev');
  static String get authLane => Env.useWebAuth ? 'web-auth' : 'native-auth';
  /// e.g. "v1.0.542+970 · web-auth · main@3cace2c · run 42" (version from package_info_plus)
  static Future<String> line();
}
class BuildStamp extends StatelessWidget { final bool compact; ... } // FutureBuilder over BuildInfo.line()
```

- [ ] **Step 1:** Implement `build_stamp.dart` (BuildInfo + BuildStamp; compact = single grey 10pt centered line for the auth footer; full = About tile subtitle).
- [ ] **Step 2:** Mount in `auth.dart` footer + `about.dart` tile.
- [ ] **Step 3:** Verify: `cd app && flutter analyze` clean on touched files; stamp renders `v…+… · web-auth|native-auth · dev@local · run 0` in local build (or via widget test `app/test/widgets/build_stamp_test.dart`: pump BuildStamp, expect text contains 'local').
- [ ] **Step 4: Commit** `feat(p1): visible build stamp on sign-in + about`

### Task 2: Surface real sign-in errors

**Files:**
- Create: `app/lib/services/auth_error_log.dart` (tiny: `record(String stage, Object e)` → keeps last error + stage in SharedPreferences via the existing `SharedPreferencesUtil` pattern; `String? get last`)
- Modify: `app/lib/services/auth_service.dart` (in `authenticateWithProvider` + `_exchangeCodeForOAuthCredentials` catch/branch points: `AuthErrorLog.record('stage', e)` — stages: launch, callback-timeout, no-code, state-mismatch, token-exchange:<status>, custom-token, firebase-credential)
- Modify: `app/lib/providers/auth_provider.dart` (catch blocks :105-109, :136-139, :152-155, :170-186: append `\n${AuthErrorLog.last}` to the snackbar text **when flavor == dev** (`F.env`/existing flavor check), keep prod generic)
- Modify: developer settings page (`app/lib/pages/settings/developer.dart`): read-only "Last sign-in error" row showing stage + text + timestamp

**Interfaces (consumed):** existing `SharedPreferencesUtil` string getter/setter pattern; existing `AppSnackbar.showSnackbarError`.

- [ ] **Step 1:** Implement `auth_error_log.dart` + wire `record()` into every enumerated failure point (the 10 rows of the P1 failure-mode table in this plan's Verified facts section).
- [ ] **Step 2:** Wire snackbar append (dev flavor only) + developer-settings row.
- [ ] **Step 3:** Verify: `flutter analyze` clean; force a failure locally (empty API_BASE_URL run) → snackbar shows real cause; developer row persists it.
- [ ] **Step 4: Commit** `feat(p1): sign-in failures surface real error + stage`

### Task 3: Deep-link intent-filter audit (web-auth return path)

**Files:**
- Inspect: `app/android/app/src/main/AndroidManifest.xml` (+ dev flavor overlays if any) for `omi://auth/callback` scheme intent-filter; `app_links` package registration
- Modify (only if missing): add `<intent-filter>` with `<data android:scheme="omi" android:host="auth"/>` on the main activity

- [x] **Step 1:** Grepped manifests. **Verdict: no change needed.** `app/android/app/src/main/AndroidManifest.xml:172-177` already has a generic `omi://` intent-filter (scheme, no host) on `.MainActivity` (`launchMode=singleTask`) — it already catches `omi://auth/callback`. Codex first added a redundant host-scoped duplicate; Claude reverted it (a host-specific filter is a strict subset of the existing generic one, same activity → zero functional gain, violates minimal-diff rule). **Deep link was never the sign-in failure cause.**
- [x] **Step 2:** Evidence recorded above.
- [x] **Step 3:** No commit — manifest unchanged from upstream.

### Task 4: CI passes stamp values

**Files:**
- Modify: `.github/workflows/android_apk_build.yml` build step:
```yaml
      - name: Build dev release APK
        working-directory: app
        run: >
          flutter build apk --release --flavor dev --build-number=${{ github.run_number }}
          --dart-define=OMI_BUILD_SHA=${{ github.sha }}
          --dart-define=OMI_BUILD_RUN=${{ github.run_number }}
          --dart-define=OMI_BUILD_BRANCH=${{ github.ref_name }}
```
(sha shortened in-app to 7 chars by `BuildInfo.line()`.)

- [ ] **Step 1:** Edit workflow.
- [ ] **Step 2: Commit** `ci(p1): bake build stamp dart-defines into dev APK`

### Task 5: Land + prove

- [ ] **Step 1:** Codex review pass on full branch diff; findings fixed.
- [ ] **Step 2:** Push branch → CI builds branch APK artifact (paths filter matches). Confirm green.
- [ ] **Step 3:** PR → fork main, regular merge (authorized: "merge yourself"). Main run publishes first real <https://github.com/sriharshaguthikonda/omi/releases/tag/apk-latest>.
- [ ] **Step 4:** Update ROADMAP P0/P1 checkboxes + Q&A; PushNotification Sri: install + read stamp + report per checklist item 1.
- [ ] **Step 5:** Sri verification: stamp visible on sign-in screen; sign-in attempt; if failure → error text now tells us the failing stage → targeted fix next.

## Phase exit

- [ ] Sri signs in successfully from a stamped prerelease APK, or the surfaced error pinpoints the failing stage and the targeted fix is queued.
- [ ] ROADMAP P1 boxes ticked; this plan archived as executed.
