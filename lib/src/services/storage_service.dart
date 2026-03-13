import 'dart:io';
import 'package:path/path.dart' as path;
import '../utils/logger.dart';

/// A service that handles the collection and storage of build artifacts.
class StorageService {
  /// Scans build directories and copies generated artifacts (.apk, .ipa, .aab)
  /// to a timestamped folder in the `builds/` directory, renaming them to
  /// `appname-version` format.
  Future<void> storeArtifacts({
    required String appName,
    required String version,
  }) async {
    final now = DateTime.now();

    // Formatting: DDMMYY
    final timestamp =
        "${now.day.toString().padLeft(2, '0')}${now.month.toString().padLeft(2, '0')}${now.year.toString().substring(2)}";

    Logger.info("Starting artifact storage...");
    final folderName = "builds/$timestamp";
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

    if (count == 0) {
      Logger.error("No artifacts found in build directories.");
      Logger.info(
          "Check if your build command generated outputs in the standard locations.");
    } else {
      Logger.success("Artifacts stored in $folderName ($count files)");
    }
  }
}
