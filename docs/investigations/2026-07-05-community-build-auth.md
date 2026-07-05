# Community Build Auth Investigation - 2026-07-05

## Result

Native Google sign-in now succeeds, but the community backend rejects the resulting Firebase ID token.

This is not a UI-login problem anymore. It is a Firebase project mismatch:

- App: `com.friend.ios.dev`, Firebase project `based-hardware-dev`
- Backend: `https://api.omiapi.com`, runtime auth verification points at `based-hardware`
- Failure: first authenticated API call returns `401 {"detail":"Invalid authorization token"}`

Conclusion: community `apk-latest` cannot fully work unless the app uses Firebase config matching `api.omiapi.com`, or the backend accepts `based-hardware-dev` tokens. The repo does not contain the matching prod Firebase config.

## Live ADB Evidence

Device:

- `adb devices -l`: one authorized device, `product:I2220T model:I2220`
- Android: vivo I2220, Android 16, SDK 36
- Foreground app: `com.friend.ios.dev/com.friend.ios.MainActivity`

Installed packages:

- `com.friend.ios.dev`: versionName `1.0.542`, versionCode `10`, installed 2026-07-05 05:21:40
- `com.friend.ios`: versionName `1.0.540`, versionCode `949`, installed from Play Store

UIAutomator confirmed the dev APK stamp:

```text
v1.0.542+10 * native-auth * main@cbfce78 * run 10
```

ADB-driven Google sign-in:

1. Cleared logcat.
2. Tapped "Sign in with Google" on `com.friend.ios.dev`.
3. App signed into Firebase successfully.
4. App called `https://api.omiapi.com/v1/users/onboarding`.
5. Backend returned `401 {"detail":"Invalid authorization token"}`.
6. App retried with a refreshed ID token.
7. Backend returned 401 again.
8. `makeApiCall` signed the user out and returned to the sign-in screen.

Sanitized decisive log lines:

```text
User is signed in ... user=<redacted uid>
DEBUG AuthProvider: authStateChanges fired - user=<redacted uid>, isAnonymous=false
DEBUG getUserOnboardingState: calling https://api.omiapi.com/v1/users/onboarding
Token expired on 1st attempt
Token refreshed and request retried
Authentication failed. Please sign in again.
userHasSpeakerProfile: {"detail":"Invalid authorization token"}
DEBUG getUserOnboardingState: response=401, body={"detail":"Invalid authorization token"}
DEBUG AuthProvider: authStateChanges fired - user=null, isAnonymous=null
```

Note: raw logcat printed email/name/UID. Those are not copied here.

## Repo Evidence

Client sign-in path:

- `app/lib/services/auth_service.dart:37-57`
  - `signInWithGoogleMobile()` uses native `GoogleSignIn`, creates a Firebase credential, calls `FirebaseAuth.instance.signInWithCredential(credential)`, then `_updateUserPreferences`.
- `app/lib/services/auth_service.dart:473-487`
  - `_updateUserPreferences` immediately calls `_restoreOnboardingState`.
- `app/lib/backend/http/api/users.dart:613-616`
  - `getUserOnboardingState()` calls `${Env.apiBaseUrl}v1/users/onboarding`.
- `app/lib/backend/http/shared.dart:143-184`
  - `makeApiCall()` refreshes ID token after first 401 and signs out after second 401.

Backend auth path:

- `backend/routers/users.py:268-275`
  - `/v1/users/onboarding` depends on `auth.get_current_user_uid`.
- `backend/utils/other/endpoints.py:31-56`
  - `verify_token()` calls `firebase_admin.auth.verify_id_token(token)`.
- `backend/utils/other/endpoints.py:59-84`
  - invalid Firebase token becomes `401 "Invalid authorization token"`.
- `backend/main.py:91-104`
  - Firebase Admin initializes from `SERVICE_ACCOUNT_JSON` or default credentials.

Firebase project evidence:

- `app/setup/prebuilt/google-services.json`
  - `project_id`: `based-hardware-dev`
  - includes Android client for `com.friend.ios.dev`
  - includes shared debug keystore SHA-1 `50f87a68e0496a85d6644d54426406866dab3598`
- `app/setup/prebuilt/firebase_options.dart:47`
  - `projectId: 'based-hardware-dev'`
- `backend/deploy/runtime_env.yaml:5-6`
  - dev metadata: `gcp_project: based-hardware-dev`, but `runtime_gcp_project: based-hardware`
- `backend/deploy/runtime_env.yaml:61-62`
  - Cloud Run backend env: `GOOGLE_CLOUD_PROJECT: based-hardware`
- `backend/deploy/runtime_env.yaml:97-98`
  - backend uses `SERVICE_ACCOUNT_JSON` secret

Workflow evidence:

- `.github/workflows/android_apk_build.yml:62`
  - CI now bakes `API_BASE_URL=https://api.omiapi.com/`
  - `USE_WEB_AUTH=false`
  - `USE_AUTH_CUSTOM_TOKEN=false`
- `.github/workflows/android_apk_build.yml:78-82`
  - versionCode from `github.run_number`
  - build stamp from sha/run/branch

## Public Upstream Evidence

This was already reported upstream:

- BasedHardware/omi issue #5939: <https://github.com/BasedHardware/omi/issues/5939>
- State: closed as not planned
- Body says `app/setup.sh` uses `based-hardware-dev` Firebase credentials while `api.omiapi.com` verifies tokens against `based-hardware`.
- The issue describes the exact same flow: app signs into `based-hardware-dev`, sends token to `api.omiapi.com`, backend verifies with `based-hardware`, verification fails with 401.
- No linked PR/fix was found.

Related but not the primary root cause:

- BasedHardware/omi issue #7631: <https://github.com/BasedHardware/omi/issues/7631>
- That issue covers stale cached tokens when refresh fails. Our live run refreshed and still got 401, so this is not the main blocker. It explains why the app signs out after repeated auth failure.

## What This Rules Out

- Not the old web-auth custom-token symptom alone. Native-auth bypassed custom tokens and still failed on backend API token verification.
- Not the deep link. Native-auth does not use the browser callback, and Firebase sign-in completed.
- Not missing `.dev.env`. The visible stamp and API call prove the CI-baked env is active.
- Not unregistered debug SHA for native Google sign-in. Native Firebase sign-in succeeded.
- Not user error. ADB reproduced the full flow directly.

## Options From Here

1. Get matching Firebase config for `based-hardware`.
   - Would let community backend accept app tokens.
   - Requires upstream/prod Firebase access.
   - Not available in this repo.

2. Own Firebase + minimal backend shim, then self-host more backend as needed.
   - Guaranteed matched signer/app/backend.
   - Smallest first target: implement login/onboarding/profile/state endpoints that unblock the app.
   - Moves P7/D7 auth slice forward without requiring the entire Omi backend on day one.

3. Backend accepts both Firebase projects.
   - Would require control of `api.omiapi.com` or upstream accepting a change.
   - Upstream issue #5939 was closed not planned.

4. Strip cloud auth and go local-only.
   - Larger surgery.
   - Better after local queue/capture pieces exist, unless auth remains the hard blocker.

## Recommendation

Stop trying flag combinations against `api.omiapi.com`. The live failure is project-scoped token verification, not a build flag.

Next investigation track should compare:

- smallest own-Firebase plus backend-shim/self-host path, likely on Oracle Cloud or another cheap VM,
- local-only strip path,
- any obtainable matching `based-hardware` Firebase config path.
