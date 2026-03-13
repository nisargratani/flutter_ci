import '../services/build_service.dart';
import '../services/version_service.dart';
import '../services/storage_service.dart';
import '../utils/logger.dart';

/// The command responsible for the complete CI build lifecycle.
class BuildCommand {
  /// The service for executing shell commands and Flutter builds.
  final buildService = BuildService();

  /// The service for managing application versioning.
  final versionService = VersionService();

  /// The service for storing and organizing build artifacts.
  final storageService = StorageService();

  /// Runs the build process with the given parameters.
  Future<void> run({
    String? version,
    bool shouldBump = true,
    String? androidBuildCmd,
    String? iosBuildCmd,
    String? preBuildCmd,
    String platform = 'both',
    String androidFormat = 'apk',
    String iosMethod = 'ad-hoc',
  }) async {
    Logger.info("Starting Flutter CI build...");
    Logger.info("----------------------------------");
    Logger.info("Selected Options:");
    Logger.info("  Platform: $platform");
    if (version != null) Logger.info("  Override Version: $version");
    Logger.info("  Bump Build Number: $shouldBump");
    if (preBuildCmd != null) {
      Logger.info("  Pre-build Command: $preBuildCmd");
    }
    if (androidBuildCmd != null) {
      Logger.info("  Android Build Command: $androidBuildCmd");
    } else if (platform == 'android' || platform == 'both') {
      Logger.info("  Android Format: $androidFormat");
    }
    if (iosBuildCmd != null) {
      Logger.info("  iOS Build Command: $iosBuildCmd");
    } else if (platform == 'ios' || platform == 'both') {
      Logger.info("  iOS Method: $iosMethod");
    }
    Logger.info("----------------------------------");

    // 1. Version Handling
    if (version != null) {
      versionService.updateVersion(version);
    } else if (shouldBump) {
      versionService.bumpBuildNumber();
    } else {
      Logger.info("Skipping version bump");
    }

    // 2. Pre-build Commands
    if (preBuildCmd != null && preBuildCmd.isNotEmpty) {
      Logger.info("Running custom pre-build commands");
      await buildService.execute(preBuildCmd);
    } else {
      Logger.info("Running default pre-build commands (clean, pub get)");
      await buildService.clean();
      await buildService.pubGet();
    }

    // 3. Build Generation
    switch (platform) {
      case 'ios':
        if (iosBuildCmd != null) {
          Logger.info("Running custom iOS build command: $iosBuildCmd");
          await buildService.execute(iosBuildCmd);
        } else {
          Logger.info("Building iOS IPA ($iosMethod)");
          await buildService.buildIOS(method: iosMethod);
        }
        break;
      case 'both':
        Logger.info("Building Android and iOS");
        try {
          if (androidBuildCmd != null) {
            Logger.info("Running custom Android build command: $androidBuildCmd");
            await buildService.execute(androidBuildCmd);
          } else {
            Logger.info("Building Android $androidFormat");
            await buildService.buildAndroid(format: androidFormat);
          }
        } catch (e) {
          Logger.error("Android build failed: $e");
        }
        try {
          if (iosBuildCmd != null) {
            Logger.info("Running custom iOS build command: $iosBuildCmd");
            await buildService.execute(iosBuildCmd);
          } else {
            Logger.info("Building iOS IPA ($iosMethod)");
            await buildService.buildIOS(method: iosMethod);
          }
        } catch (e) {
          Logger.error("iOS build failed: $e");
        }
        break;
      case 'android':
      default:
        if (androidBuildCmd != null) {
          Logger.info("Running custom Android build command: $androidBuildCmd");
          await buildService.execute(androidBuildCmd);
        } else {
          Logger.info("Building Android $androidFormat (default)");
          await buildService.buildAndroid(format: androidFormat);
        }
        break;
    }

    // 4. Storage
    try {
      final appName = versionService.getAppName();
      final currentVersion = versionService.getVersion();
      await storageService.storeArtifacts(appName: appName, version: currentVersion);
    } catch (e) {
      Logger.error("Failed to store artifacts: $e");
    }

    Logger.success("Build session completed");
  }
}
