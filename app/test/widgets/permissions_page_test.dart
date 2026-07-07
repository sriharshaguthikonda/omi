import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omi/gen/app_localizations.dart';
import 'package:omi/pages/onboarding/permissions/permissions_widget.dart';
import 'package:omi/pages/settings/permissions_page.dart';
import 'package:omi/providers/onboarding_provider.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('uses the onboarding permissions widget for review', (tester) async {
    final provider = OnboardingProvider();

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: PermissionsPage(),
        ),
      ),
    );

    expect(find.byType(PermissionsWidget), findsOneWidget);
  });
}
