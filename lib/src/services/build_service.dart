import 'dart:io';
import 'package:flutter_ci/src/utils/process_runner.dart';
import 'package:process_run/shell.dart';

/// A service that handles Flutter build operations and shell execution.
///
/// Every method streams command output to the console (and to the log file
/// set with [setLogFile]) and throws a `FlutterCiException` if the command
/// exits with a non-zero code.
class BuildService {
  /// The shell instance used for executing commands.
  @Deprecated('No longer used by flutter_ci. Will be removed in 1.0.0.')
  final shell = Shell(verbose: true);

  final ProcessRunner _runner = ProcessRunner();

  /// Sets the log file for capturing build output.
  ///
  /// Output is appended as it is produced, including the output of commands
  /// that fail.
  void setLogFile(File logFile) {
    _runner.logFile = logFile;
  }

  /// Builds the Android artifact (APK or AAB).
  ///
  /// [dartDefines] entries have the form `KEY=VALUE` and are passed as
  /// `--dart-define` arguments. [extraFlags] is split on whitespace (quotes
  /// are honoured) and appended to the command.
  Future<void> buildAndroid({
    String format = 'apk',
    String? buildName,
    int? buildNumber,
    String? extraFlags,
    String? flavor,
    List<String> dartDefines = const [],
  }) {
    return _flutterBuild(
      [format == 'aab' ? 'appbundle' : 'apk'],
      buildName: buildName,
      buildNumber: buildNumber,
      extraFlags: extraFlags,
      flavor: flavor,
      dartDefines: dartDefines,
    );
  }

  /// Builds the iOS IPA with the specified export [method]
  /// (`ad-hoc`, `development`, `app-store` or `enterprise`).
  ///
  /// See [buildAndroid] for [dartDefines] and [extraFlags].
  Future<void> buildIOS({
    String method = 'ad-hoc',
    String? buildName,
    int? buildNumber,
    String? extraFlags,
    String? flavor,
    List<String> dartDefines = const [],
  }) {
    return _flutterBuild(
      ['ipa', '--export-method=$method'],
      buildName: buildName,
      buildNumber: buildNumber,
      extraFlags: extraFlags,
      flavor: flavor,
      dartDefines: dartDefines,
    );
  }

  Future<void> _flutterBuild(
    List<String> target, {
    required String? buildName,
    required int? buildNumber,
    required String? extraFlags,
    required String? flavor,
    required List<String> dartDefines,
  }) {
    return _runner.run('flutter', [
      'build',
      ...target,
      if (extraFlags != null) ...splitArguments(extraFlags),
      for (final define in dartDefines) '--dart-define=$define',
      if (flavor != null) '--flavor=$flavor',
      if (buildName != null) '--build-name=$buildName',
      if (buildNumber != null) '--build-number=$buildNumber',
    ]);
  }

  /// Cleans the Flutter project.
  Future<void> clean() => _runner.run('flutter', ['clean']);

  /// Deletes the `builds/` folder specifically.
  Future<void> cleanBuilds() async {
    final buildDir = Directory('builds');
    if (await buildDir.exists()) {
      await buildDir.delete(recursive: true);
      print("Builds folder deleted successfully.");
    } else {
      print("No builds folder found.");
    }
  }

  /// Fetches package dependencies using `flutter pub get`.
  Future<void> pubGet() => _runner.run('flutter', ['pub', 'get']);

  /// Runs `flutter test --coverage`.
  Future<void> testWithCoverage() =>
      _runner.run('flutter', ['test', '--coverage']);

  /// Executes a shell command string such as `cd app && flutter build apk`.
  ///
  /// The command runs through `/bin/sh -c` (or `cmd /c` on Windows), so
  /// pipes, `&&` chains and directory changes work. [display] replaces the
  /// echoed command line, for example to hide secret values.
  Future<void> execute(String command, {String? display}) =>
      _runner.runShell(command, display: display);
}
