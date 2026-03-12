import '../services/build_service.dart';
import '../services/version_service.dart';
import '../services/storage_service.dart';
import '../utils/logger.dart';

/// The command responsible for the complete CI build lifecycle.
class BuildCommand {
  final buildService = BuildService();
  final versionService = VersionService();
  final storageService = StorageService();

  /// Runs the build process with the given parameters.
  Future<void> run({
    String? version,
    bool shouldBump = true,
    String? buildCmd,
    String? preBuildCmd,
  }) async {
    Logger.info("Starting Flutter CI build...");

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
    if (buildCmd != null) {
      Logger.info("Running custom build command: $buildCmd");
      await buildService.execute(buildCmd);
    } else {
      Logger.info("Building Android APK (default)");
      await buildService.buildAndroid();
    }

    // 4. Storage
    await storageService.storeArtifacts();

    Logger.success("Build completed successfully");
  }
}
