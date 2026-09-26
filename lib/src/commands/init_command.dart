import 'dart:io';
import 'package:flutter_ci/src/utils/logger.dart';

/// The command responsible for generating the default configuration file.
class InitCommand {
  /// Runs the initialization process to create `flutter_ci.yaml`.
  Future<void> run() async {
    final file = File('flutter_ci.yaml');
    if (file.existsSync()) {
      Logger.info("flutter_ci.yaml already exists.");
      return;
    }

    final content = '''
# flutter_ci configuration. Run `flutter_ci yaml-guide` for every option.
# Command-line flags override the values in this file.
version_bump: true
platform: both

android:
  format: apk

ios:
  method: ad-hoc
''';

    await file.writeAsString('${content.trim()}\n');
    Logger.success("Created flutter_ci.yaml\n");
    print("Generated config:\n");
    print(content.trim());
  }
}
