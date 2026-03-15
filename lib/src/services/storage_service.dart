import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:flutter_ci/src/utils/logger.dart';

/// A service that handles the collection and storage of build artifacts.
class StorageService {
  /// Scans build directories and copies generated artifacts (.apk, .ipa, .aab)
  /// to a versioned folder in the `builds/` directory, renaming them to
  /// `appname-version` format.
  Future<void> storeArtifacts({
    required String appName,
    required String version,
    String? gitCommit,
  }) async {
    Logger.info("Starting artifact storage...");

    // Naming pattern: builds/v1.2.0+45/
    final folderName = "builds/v$version";
    final destDir = Directory(folderName);

    if (!destDir.existsSync()) {
      destDir.createSync(recursive: true);
    }

    int count = 0;
    final baseFileName = "$appName-$version";

    // 1. Android Scan
    final apkDirPath =
        path.join(Directory.current.path, "build/app/outputs/flutter-apk");
    final apkDir = Directory(apkDirPath);

    if (apkDir.existsSync()) {
      Logger.info("Scanning for Android artifacts in: $apkDirPath");
      for (var entity in apkDir.listSync()) {
        if (entity is File && entity.path.endsWith(".apk")) {
          final ext = path.extension(entity.path);
          final newName = "$baseFileName$ext";
          entity.copySync(path.join(destDir.path, newName));
          Logger.success("Stored Android artifact: $newName");
          count++;
        }
      }
    }

    // 1b. Android AAB Scan
    final aabDirPath =
        path.join(Directory.current.path, "build/app/outputs/bundle/release");
    final aabDir = Directory(aabDirPath);
    if (aabDir.existsSync()) {
      Logger.info("Scanning for Android AAB artifacts in: $aabDirPath");
      for (var entity in aabDir.listSync()) {
        if (entity is File && entity.path.endsWith(".aab")) {
          final ext = path.extension(entity.path);
          final newName = "$baseFileName$ext";
          entity.copySync(path.join(destDir.path, newName));
          Logger.success("Stored Android AAB artifact: $newName");
          count++;
        }
      }
    }

    // 2. iOS Scan
    final ipaDirPath = path.join(Directory.current.path, "build/ios/ipa");
    final ipaDir = Directory(ipaDirPath);
    if (ipaDir.existsSync()) {
      Logger.info("Scanning for iOS artifacts in: $ipaDirPath");
      for (var entity in ipaDir.listSync(recursive: true)) {
        if (entity is File && entity.path.endsWith(".ipa")) {
          final ext = path.extension(entity.path);
          final newName = "$baseFileName$ext";
          entity.copySync(path.join(destDir.path, newName));
          Logger.success("Stored iOS artifact: $newName");
          count++;
        }
      }
    }

    // 3. Generate build_info.json
    try {
      final buildInfo = {
        "version": version,
        "build_time": DateTime.now().toIso8601String(),
        "git_commit": gitCommit ?? "unknown",
        "flutter_version": await _getFlutterVersion(),
      };

      final infoFile = File(path.join(destDir.path, "build_info.json"));
      infoFile.writeAsStringSync(jsonEncode(buildInfo));
      Logger.success("Generated build_info.json");
    } catch (e) {
      Logger.error("Failed to generate build_info.json: $e");
    }

    if (count == 0) {
      Logger.error("No artifacts found in build directories.");
      Logger.info(
          "Check if your build command generated outputs in the standard locations.");
    } else {
      Logger.success("Artifacts stored in $folderName ($count files)");
    }
  }

  Future<String> _getFlutterVersion() async {
    try {
      final result = await Process.run('flutter', ['--version']);
      if (result.exitCode == 0) {
        final firstLines = result.stdout.toString().split('\n');
        return firstLines.isNotEmpty ? firstLines.first.trim() : "unknown";
      }
    } catch (_) {}
    return "unknown";
  }
}
