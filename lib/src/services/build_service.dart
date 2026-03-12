import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:process_run/shell.dart';

/// A service that handles Flutter build operations and shell execution.
class BuildService {
  /// The shell instance used for executing commands.
  final shell = Shell(verbose: true);

  /// Builds the Android APK.
  Future<void> buildAndroid() async {
    await shell.run('flutter build apk');
  }

  /// Builds the iOS IPA.
  Future<void> buildIOS() async {
    await shell.run('flutter build ipa');
  }

  /// Cleans the Flutter project.
  Future<void> clean() async {
    await shell.run('flutter clean');
  }

  /// Runs `flutter pub get`.
  Future<void> pubGet() async {
    await shell.run('flutter pub get');
  }

  /// Executes a complex shell command string via a temporary script.
  ///
  /// This ensures that complex chains with flags and directory changes
  /// are handled correctly by the system shell.
  Future<void> execute(String command) async {
    final tempFile =
        File(path.join(Directory.systemTemp.path, 'flutter_ci_step.sh'));
    tempFile.writeAsStringSync("#!/bin/sh\n$command");

    // Make executable
    await shell.run('chmod +x ${tempFile.path}');

    try {
      await shell.run(tempFile.path);
    } finally {
      if (tempFile.existsSync()) {
        tempFile.deleteSync();
      }
    }
  }
}
