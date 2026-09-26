import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:flutter_ci/src/utils/logger.dart';

/// A service that handles the collection and storage of build artifacts.
class StorageService {
  /// Scans build directories and copies generated artifacts (.apk, .ipa, .aab)
  /// to a versioned folder in the `builds/` directory, renaming them to
  /// `appname-version` format.
  ///
  /// Searched locations:
  /// * `build/app/outputs/flutter-apk/` for APKs,
  /// * `build/app/outputs/bundle/` (including flavor folders such as
  ///   `prodRelease/`) for AABs,
  /// * `build/ios/ipa/` for IPAs.
  ///
  /// When [builtAfter] is given, artifacts last modified before it are
  /// ignored, so stale outputs from earlier builds are not stored. If several
  /// artifacts share an extension (for example `--split-per-abi` APKs), each
  /// keeps its original name as a suffix: `appname-version-app-arm64-v8a-release.apk`.
  ///
  /// Also writes `build_info.json` and returns the stored artifact files.
  Future<List<File>> storeArtifacts({
    required String appName,
    required String version,
    String? gitCommit,
    DateTime? builtAfter,
  }) async {
    Logger.info("Starting artifact storage...");

    // Naming pattern: builds/v1.2.0+45/
    final folderName = "builds/v$version";
    final destDir = Directory(folderName);

    if (!destDir.existsSync()) {
      destDir.createSync(recursive: true);
    }

    final baseFileName = "$appName-$version";
    final outputs = path.join(Directory.current.path, 'build');
    final found = [
      ..._scan(path.join(outputs, 'app', 'outputs', 'flutter-apk'), '.apk',
          builtAfter),
      ..._scan(
          path.join(outputs, 'app', 'outputs', 'bundle'), '.aab', builtAfter),
      ..._scan(path.join(outputs, 'ios', 'ipa'), '.ipa', builtAfter),
    ];

    final stored = <File>[];
    for (final artifact in found) {
      final ext = path.extension(artifact.path);
      final unique = found.where((f) => path.extension(f.path) == ext).length;
      final newName = unique == 1
          ? "$baseFileName$ext"
          : "$baseFileName-${path.basenameWithoutExtension(artifact.path)}$ext";
      stored.add(artifact.copySync(path.join(destDir.path, newName)));
      Logger.success("Stored artifact: $newName");
    }

    // Generate build_info.json
    try {
      final buildInfo = {
        "app_name": appName,
        "version": version,
        "build_time": DateTime.now().toIso8601String(),
        "git_commit": gitCommit ?? "unknown",
        "flutter_version": await _getFlutterVersion(),
        "artifacts": [for (final f in stored) path.basename(f.path)],
      };

      final infoFile = File(path.join(destDir.path, "build_info.json"));
      infoFile.writeAsStringSync(
          const JsonEncoder.withIndent('  ').convert(buildInfo));
      Logger.success("Generated build_info.json");
    } on FileSystemException catch (e) {
      Logger.error("Failed to generate build_info.json: ${e.message}");
    }

    if (stored.isEmpty) {
      Logger.warning("No artifacts found in build directories.");
      Logger.info(
          "Check if your build command generated outputs in the standard locations.");
    } else {
      Logger.success(
          "Artifacts stored in $folderName (${stored.length} files)");
    }
    return stored;
  }

  List<File> _scan(String dirPath, String extension, DateTime? builtAfter) {
    final dir = Directory(dirPath);
    if (!dir.existsSync()) return const [];

    // File timestamps can be truncated to whole (or even two) seconds.
    final cutoff = builtAfter?.subtract(const Duration(seconds: 2));
    final files = dir
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith(extension))
        .where((f) => cutoff == null || !f.lastModifiedSync().isBefore(cutoff))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));
    return files;
  }

  Future<String> _getFlutterVersion() async {
    try {
      final result = await Process.run('flutter', ['--version'],
          runInShell: Platform.isWindows);
      if (result.exitCode == 0) {
        final firstLines = result.stdout.toString().split('\n');
        return firstLines.isNotEmpty ? firstLines.first.trim() : "unknown";
      }
    } on ProcessException {
      // Flutter is not on PATH; the version is informational only.
    }
    return "unknown";
  }
}
