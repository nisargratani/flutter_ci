import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:process_run/shell.dart';

/// A service that handles Flutter build operations and shell execution.
class BuildService {
  /// The shell instance used for executing commands.
  final shell = Shell(verbose: true);

  /// Builds the Android artifact (APK or AAB).
  Future<void> buildAndroid({
    String format = 'apk',
    String? buildName,
    int? buildNumber,
    String? extraFlags,
  }) async {
    final nameArg = buildName != null ? " --build-name=$buildName" : "";
    final numberArg = buildNumber != null ? " --build-number=$buildNumber" : "";
    final flags = extraFlags != null && extraFlags.isNotEmpty ? " $extraFlags" : "";

    if (format == 'aab') {
      await shell.run('flutter build appbundle$flags$nameArg$numberArg');
    } else {
      await shell.run('flutter build apk$flags$nameArg$numberArg');
    }
  }

  /// Builds the iOS IPA with the specified export method.
  Future<void> buildIOS({
    String method = 'ad-hoc',
    String? buildName,
    int? buildNumber,
    String? extraFlags,
  }) async {
    final nameArg = buildName != null ? " --build-name=$buildName" : "";
    final numberArg = buildNumber != null ? " --build-number=$buildNumber" : "";
    final flags = extraFlags != null && extraFlags.isNotEmpty ? " $extraFlags" : "";

    // Ensuring we use the correct format for Flutter's export-method flag
    // The methods mapping is:
    // app-store, ad-hoc, development, enterprise
    await shell.run('flutter build ipa --export-method=$method$flags$nameArg$numberArg');
  }

  /// Cleans the Flutter project.
  Future<void> clean() async {
    await shell.run('flutter clean');
  }

  /// Deletes the builds folder specifically.
  Future<void> cleanBuilds() async {
    final buildDir = Directory('builds');
    if (await buildDir.exists()) {
      await buildDir.delete(recursive: true);
      print("Builds folder deleted successfully.");
    } else {
      print("No builds folder found.");
    }
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
