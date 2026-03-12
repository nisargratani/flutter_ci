import 'dart:io';
import 'package:path/path.dart' as path;
import '../utils/logger.dart';

/// A service that handles the collection and storage of build artifacts.
class StorageService {
  /// Scans build directories and copies generated artifacts (.apk, .ipa)
  /// to a timestamped folder in the `builds/` directory.
  Future<void> storeArtifacts() async {
    final now = DateTime.now();

    // Formatting: YYYY-MM-DD_HHMM
    final timestamp =
        "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}";

    Logger.info("Starting artifact storage...");
    final folderName = "builds/$timestamp";
    final destDir = Directory(folderName);

    if (!destDir.existsSync()) {
      destDir.createSync(recursive: true);
    }

    int count = 0;

    // 1. Android Scan
    final apkDirPath =
        path.join(Directory.current.path, "build/app/outputs/flutter-apk");
    final apkDir = Directory(apkDirPath);
    Logger.info("Scanning for Android artifacts in: $apkDirPath");

    if (apkDir.existsSync()) {
      for (var entity in apkDir.listSync()) {
        if (entity is File && entity.path.endsWith(".apk")) {
          final fileName = path.basename(entity.path);
          entity.copySync(path.join(destDir.path, fileName));
          Logger.success("Stored Android artifact: $fileName");
          count++;
        }
      }
    } else {
      Logger.error("Android build directory not found: $apkDirPath");
    }

    // 2. iOS Scan
    final ipaDir = Directory("build/ios/ipa");
    if (ipaDir.existsSync()) {
      for (var entity in ipaDir.listSync(recursive: true)) {
        if (entity is File && entity.path.endsWith(".ipa")) {
          final fileName = path.basename(entity.path);
          entity.copySync(path.join(destDir.path, fileName));
          Logger.info("Stored iOS artifact: $fileName");
          count++;
        }
      }
    }

    if (count == 0) {
      Logger.error("No artifacts (.apk or .ipa) found in build directories.");
    } else {
      Logger.success("Artifacts stored in $folderName ($count files)");
    }
  }
}
