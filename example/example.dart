// flutter_ci is primarily a command-line tool. From your Flutter project:
//
//   dart pub global activate flutter_ci
//   flutter_ci init
//   flutter_ci build -p android
//   flutter_ci release --notes --tag
//
// The same commands and services are available as a library, which is
// useful for custom build scripts. Run this example from the root of a
// Flutter project:
//
//   dart run example/example.dart [--build]

import 'dart:io';

import 'package:flutter_ci/flutter_ci.dart';

Future<void> main(List<String> args) async {
  try {
    final versions = VersionService();
    print('${versions.getAppName()} is at version ${versions.getVersion()}');

    final config = ConfigService();
    await config.loadConfig();
    print('Configured platform: ${config.getString('platform') ?? 'both'}');

    if (args.contains('--build')) {
      // Arguments override flutter_ci.yaml, exactly like CLI flags.
      await BuildCommand().run(platform: 'android', shouldBump: false);
      Logger.success('Stored artifacts in builds/v${versions.getVersion()}');
    }
  } on FlutterCiException catch (e) {
    Logger.error(e.message);
    exitCode = 1;
  }
}
