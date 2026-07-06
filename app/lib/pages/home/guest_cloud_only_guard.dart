import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:omi/providers/auth_provider.dart';
import 'package:omi/providers/home_provider.dart';
import 'package:omi/utils/l10n_extensions.dart';

bool isGuestUser(BuildContext context) {
  return !context.read<AuthenticationProvider>().isSignedIn();
}

void showGuestCloudOnlyHint(BuildContext context) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(context.l10n.signInButton),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
}

bool guardGuestCloudOnlyAccess(BuildContext context, {bool clampToConversations = false}) {
  if (!isGuestUser(context)) return false;
  if (clampToConversations) {
    context.read<HomeProvider>().setIndex(HomeProvider.conversationsTabIndex);
  }
  showGuestCloudOnlyHint(context);
  return true;
}

bool redirectGuestCloudOnlyRoute(BuildContext context) {
  if (!guardGuestCloudOnlyAccess(context, clampToConversations: true)) return false;
  final navigator = Navigator.of(context);
  if (navigator.canPop()) {
    navigator.pop();
  }
  return true;
}
