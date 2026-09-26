import 'dart:io';
import 'package:flutter_ci/src/utils/logger.dart';

/// The command responsible for diagnostic environment checks.
class DoctorCommand {
  /// Runs the diagnostic check.
  ///
  /// Checks for Flutter, Dart and Git (required) and for the Android SDK,
  /// Xcode (macOS only) and the Firebase CLI (optional). Returns `true` when
  /// every required tool was found.
  Future<bool> run() async {
    Logger.info("🩺 flutter_ci doctor\n");

    final results = [
      await _check("Flutter SDK", "flutter", ["--version"]),
      await _check("Dart SDK", "dart", ["--version"]),
      await _check("Android SDK", "sdkmanager", ["--version"], optional: true),
      if (Platform.isMacOS)
        await _check("Xcode", "xcodebuild", ["-version"], optional: true),
      await _check("Git", "git", ["--version"]),
      await _check("Firebase CLI", "firebase", ["--version"], optional: true),
    ];

    print("");
    return results.every((ok) => ok);
  }

  /// Returns `false` only when a required tool is missing.
  Future<bool> _check(String name, String executable, List<String> args,
      {bool optional = false}) async {
    try {
      final result = await Process.run(executable, args, runInShell: true);
      if (result.exitCode == 0) {
        final output = '${result.stdout}${result.stderr}'.trim();
        final versionMatch = RegExp(r'(\d+\.\d+(\.\d+)?)').firstMatch(output);
        final version = versionMatch?.group(1) ?? '';
        print("  \x1B[32m✓\x1B[0m $name $version".trimRight());
        return true;
      }
    } on ProcessException {
      // Treated the same as a non-zero exit code below.
    }
    _printError(name, optional);
    return optional;
  }

  /// Prints an error message based on the [optional] flag.
  void _printError(String name, bool optional) {
    if (optional) {
      print("  \x1B[33m!\x1B[0m $name (Not found or not in PATH)");
    } else {
      print("  \x1B[31m✗\x1B[0m $name (Missing!)");
    }
  }
}
