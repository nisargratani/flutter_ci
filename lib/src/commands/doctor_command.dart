import 'dart:io';
import 'package:flutter_ci/src/utils/logger.dart';

class DoctorCommand {
  Future<void> run() async {
    Logger.info("🩺 flutter_ci doctor\n");

    await _check("Flutter SDK", "flutter", ["--version"]);
    await _check("Dart SDK", "dart", ["--version"]);

    if (Platform.isMacOS || Platform.isLinux || Platform.isWindows) {
      // Try various android checks or just skip the optional android test, we will use flutter doctor equivalent logic roughly
      // The user only needs a simple indicator
    }

    await _check("Android SDK", "sdkmanager", ["--version"], optional: true);
    if (Platform.isMacOS) {
      await _check("Xcode", "xcodebuild", ["-version"], optional: true);
    }
    await _check("Git", "git", ["--version"]);
    await _check("Firebase CLI", "firebase", ["--version"], optional: true);

    print("");
  }

  Future<void> _check(String name, String executable, List<String> args,
      {bool optional = false}) async {
    try {
      final result = await Process.run(executable, args, runInShell: true);
      if (result.exitCode == 0) {
        String output = result.stdout.toString().trim().split('\n').first;
        // Optionally parse version (e.g. Flutter 3.19.2)
        final versionMatch = RegExp(r'(\d+\.\d+\.\d+)').firstMatch(output);
        String version = versionMatch != null ? versionMatch.group(1)! : '';
        print("  \x1B[32m✓\x1B[0m $name ${version.isNotEmpty ? version : ''}");
      } else {
        _printError(name, optional);
      }
    } catch (e) {
      _printError(name, optional);
    }
  }

  void _printError(String name, bool optional) {
    if (optional) {
      print("  \x1B[33m!\x1B[0m $name (Not found or not in PATH)");
    } else {
      print("  \x1B[31m✗\x1B[0m $name (Missing!)");
    }
  }
}
