import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:omi/env/env.dart';

class BuildInfo {
  static const String sha = String.fromEnvironment('OMI_BUILD_SHA', defaultValue: 'local');
  static const String run = String.fromEnvironment('OMI_BUILD_RUN', defaultValue: '0');
  static const String branch = String.fromEnvironment('OMI_BUILD_BRANCH', defaultValue: 'dev');

  static String get authLane => Env.useWebAuth ? 'web-auth' : 'native-auth';

  static String get shortSha => sha.length <= 7 ? sha : sha.substring(0, 7);

  static Future<String> line() async {
    final packageInfo = await PackageInfo.fromPlatform();
    return 'v${packageInfo.version}+${packageInfo.buildNumber} · $authLane · $branch@$shortSha · run $run';
  }
}

class BuildStamp extends StatelessWidget {
  final bool compact;

  const BuildStamp({super.key, this.compact = false});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: BuildInfo.line(),
      builder: (context, snapshot) {
        final text = snapshot.data;
        if (text == null || text.isEmpty) return const SizedBox.shrink();

        return Text(
          text,
          textAlign: compact ? TextAlign.center : TextAlign.start,
          style: TextStyle(
            color: compact ? Colors.white.withValues(alpha: 0.45) : Colors.grey.shade500,
            fontSize: compact ? 10 : 13,
            fontFamily: 'Manrope',
          ),
        );
      },
    );
  }
}
