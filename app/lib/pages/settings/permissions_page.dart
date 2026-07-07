import 'package:flutter/material.dart';

import 'package:omi/backend/preferences.dart';
import 'package:omi/pages/onboarding/permissions/permissions_widget.dart';
import 'package:omi/utils/l10n_extensions.dart';

class PermissionsPage extends StatelessWidget {
  const PermissionsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.primary,
      appBar: AppBar(
        title: Text(context.l10n.permissions),
        backgroundColor: Theme.of(context).colorScheme.primary,
        elevation: 0,
      ),
      body: PermissionsWidget(
        goNext: () {
          SharedPreferencesUtil().permissionsCompleted = true;
          Navigator.of(context).maybePop();
        },
      ),
    );
  }
}
