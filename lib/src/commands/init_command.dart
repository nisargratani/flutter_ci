import 'dart:io';
import 'package:flutter_ci/src/utils/logger.dart';

class InitCommand {
  Future<void> run() async {
    final file = File('flutter_ci.yaml');
    if (file.existsSync()) {
      Logger.info("flutter_ci.yaml already exists.");
      return;
    }

    final content = '''
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
