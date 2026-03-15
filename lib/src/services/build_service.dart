import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:process_run/shell.dart';

/// A service that handles Flutter build operations and shell execution.
class BuildService {
  /// The shell instance used for executing commands.
  final shell = Shell(verbose: true);

  File? _logFile;

  void setLogFile(File logFile) {
    _logFile = logFile;
  }

  Future<List<ProcessResult>> _run(String cmd) async {
    final results = await shell.run(cmd);
    if (_logFile != null) {
      _logFile!.writeAsStringSync("\n> \$cmd\n", mode: FileMode.append);
      for (var res in results) {
        _logFile!
            .writeAsStringSync(res.stdout.toString(), mode: FileMode.append);
        _logFile!
            .writeAsStringSync(res.stderr.toString(), mode: FileMode.append);
      }
    }
    return results;
  }

  /// Builds the Android artifact (APK or AAB).
  Future<void> buildAndroid({
    String format = 'apk',
    String? buildName,
    int? buildNumber,
    String? extraFlags,
    String? flavor,
  }) async {
    final nameArg = buildName != null ? " --build-name=$buildName" : "";
    final numberArg = buildNumber != null ? " --build-number=$buildNumber" : "";
    final flavorArg = flavor != null ? " --flavor=$flavor" : "";
    final flags =
        extraFlags != null && extraFlags.isNotEmpty ? " $extraFlags" : "";

    if (format == 'aab') {
      await _run('flutter build appbundle$flags$flavorArg$nameArg$numberArg');
    } else {
      await _run('flutter build apk$flags$flavorArg$nameArg$numberArg');
    }
  }

  /// Builds the iOS IPA with the specified export method.
  Future<void> buildIOS({
    String method = 'ad-hoc',
    String? buildName,
    int? buildNumber,
    String? extraFlags,
    String? flavor,
  }) async {
    final nameArg = buildName != null ? " --build-name=$buildName" : "";
    final numberArg = buildNumber != null ? " --build-number=$buildNumber" : "";
    final flavorArg = flavor != null ? " --flavor=$flavor" : "";
    final flags =
        extraFlags != null && extraFlags.isNotEmpty ? " $extraFlags" : "";

    // Ensuring we use the correct format for Flutter's export-method flag
    // The methods mapping is:
    // app-store, ad-hoc, development, enterprise
    await _run(
        'flutter build ipa --export-method=$method$flags$flavorArg$nameArg$numberArg');
  }

  /// Cleans the Flutter project.
  Future<void> clean() async {
    await _run('flutter clean');
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
    await _run('flutter pub get');
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
    await _run('chmod +x ${tempFile.path}');

    try {
      await _run(tempFile.path);
    } finally {
      if (tempFile.existsSync()) {
        tempFile.deleteSync();
      }
    }
  }
}
