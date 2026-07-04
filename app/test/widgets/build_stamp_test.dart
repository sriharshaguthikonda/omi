import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:omi/env/env.dart';
import 'package:omi/widgets/build_stamp.dart';

class _TestEnvFields implements EnvFields {
  @override
  String? get apiBaseUrl => null;

  @override
  String? get googleClientId => null;

  @override
  String? get googleClientSecret => null;

  @override
  String? get googleMapsApiKey => null;

  @override
  String? get intercomAndroidApiKey => null;

  @override
  String? get intercomAppId => null;

  @override
  String? get intercomIOSApiKey => null;

  @override
  String? get openAIAPIKey => null;

  @override
  String? get posthogApiKey => null;

  @override
  String? get stagingApiUrl => null;

  @override
  bool? get useAuthCustomToken => false;

  @override
  bool? get useWebAuth => false;
}

void main() {
  setUpAll(() {
    Env.init(_TestEnvFields());
    PackageInfo.setMockInitialValues(
      appName: 'Omi',
      packageName: 'com.friend.ios',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
      installerStore: null,
    );
  });

  testWidgets('BuildStamp renders local defaults', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: BuildStamp(compact: true))));
    await tester.pumpAndSettle();

    expect(find.textContaining('v1.0.0+1'), findsOneWidget);
    expect(find.textContaining('native-auth'), findsOneWidget);
    expect(find.textContaining('dev@local'), findsOneWidget);
    expect(find.textContaining('run 0'), findsOneWidget);
  });
}
