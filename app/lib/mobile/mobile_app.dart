import 'package:omi/utils/platform/platform_manager.dart';
import 'package:flutter/material.dart';

import 'package:provider/provider.dart';

import 'package:omi/backend/preferences.dart';
import 'package:omi/pages/home/page.dart';
import 'package:omi/pages/onboarding/permissions/permissions_checker.dart';
import 'package:omi/pages/onboarding/wrapper.dart';
import 'package:omi/providers/auth_provider.dart';

bool shouldShowPermissionGate({
  required bool permissionsCompleted,
  required bool allRelevantPermissionsGranted,
  required bool criticalPermissionsGranted,
}) {
  if (!criticalPermissionsGranted) return true;
  return !permissionsCompleted && !allRelevantPermissionsGranted;
}

class MobileApp extends StatelessWidget {
  const MobileApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthenticationProvider>(
      builder: (context, authProvider, child) {
        if (authProvider.isSignedIn()) {
          // Returning users who haven't yet given consent under the new
          // model must see the consent screen before any AI processing
          // begins, even if the server says they completed onboarding
          // previously. OnboardingWrapper renders the consent step in
          // that case and routes them straight to home after Continue.
          if (!SharedPreferencesUtil().aiConsentGiven) {
            return const OnboardingWrapper();
          }
          if (SharedPreferencesUtil().onboardingCompleted) {
            return const _PermissionsGate();
          } else {
            return const OnboardingWrapper();
          }
        } else {
          // Local-first: login is no longer mandatory. Unsigned users boot
          // straight in; Omi-cloud sign-in lives in Settings. Route through the
          // permissions gate so mic access is still granted for capture.
          // ponytail: aiConsentGiven is intentionally NOT gated here — no AI
          // processing runs at guest boot. Phase B decision (2026-07-07): the
          // guest consent gate stays deferred on this personal fork — guests
          // only get STT after explicitly configuring an engine (BYOK key or
          // on-device model download) in Settings, which is a deliberate act
          // by the device owner. Revisit before any public distribution.
          return const _PermissionsGate();
        }
      },
    );
  }
}

/// Checks if permissions are already granted. If so, marks as completed
/// and shows home. Otherwise shows the permissions interstitial.
class _PermissionsGate extends StatefulWidget {
  const _PermissionsGate();

  @override
  State<_PermissionsGate> createState() => _PermissionsGateState();
}

class _PermissionsGateState extends State<_PermissionsGate> {
  bool? _permissionsGranted;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final status = await getPermissionGateStatus();
    final showGate = shouldShowPermissionGate(
      permissionsCompleted: SharedPreferencesUtil().permissionsCompleted,
      allRelevantPermissionsGranted: status.allRelevantPermissionsGranted,
      criticalPermissionsGranted: status.criticalPermissionsGranted,
    );
    if (status.allRelevantPermissionsGranted) {
      SharedPreferencesUtil().permissionsCompleted = true;
    }
    if (mounted) {
      setState(() => _permissionsGranted = !showGate);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_permissionsGranted == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }
    if (_permissionsGranted!) {
      return const HomePageWrapper();
    }
    PlatformManager.instance.analytics.permissionsInterstitialShown();
    return const PermissionsInterstitialPage();
  }
}
