import 'package:flutter_ci/src/services/build_service.dart';
import 'package:flutter_ci/src/services/version_service.dart';
import 'package:flutter_ci/src/services/storage_service.dart';
import 'package:flutter_ci/src/services/git_service.dart';
import 'package:flutter_ci/src/services/distribution_service.dart';
import 'package:flutter_ci/src/services/config_service.dart';
import 'package:flutter_ci/src/utils/logger.dart';

/// The command responsible for the complete CI build lifecycle.
class BuildCommand {
  final buildService = BuildService();
  final versionService = VersionService();
  final storageService = StorageService();
  final gitService = GitService();
  final distributionService = DistributionService();
  final configService = ConfigService();

  /// Runs the build process with the given parameters, merging config file and CLI flags.
  Future<void> run({
    String? version,
    bool? shouldBump,
    String? androidBuildCmd,
    String? iosBuildCmd,
    String? preBuildCmd,
    String? platform,
    String? androidFormat,
    String? iosMethod,
    bool parallel = true,
    bool? coverage,
    List<String>? defines,
  }) async {
    await configService.loadConfig();

    // Merge configuration (Config File > CLI flag > Default)
    // Priority: YAML > CLI > Default
    final resolvedPlatform = configService.getValue('platform') ?? platform ?? 'both';
    final resolvedManualVersion = configService.getValue('manual_version') ?? version;
    final resolvedShouldBump = configService.getValue('version_bump') ?? shouldBump ?? true;
    final resolvedAndroidFormat = configService.getValue('android.format') ?? androidFormat ?? 'apk';
    final resolvedIosMethod = configService.getValue('ios.method') ?? iosMethod ?? 'ad-hoc';
    final resolvedPreBuildCmd = configService.getValue('pre_build_command') ?? preBuildCmd;
    final resolvedAndroidBuildCmd = configService.getValue('android.build_command') ?? androidBuildCmd;
    final resolvedIosBuildCmd = configService.getValue('ios.build_command') ?? iosBuildCmd;
    
    // Coverage & Defines
    final resolvedCoverage = configService.getValue('test.coverage') ?? coverage ?? false;
    
    // Merge env map from YAML with defines from CLI
    final envMap = configService.getValue<Map>('env') ?? {};
    final mergedDefines = <String>[];
    envMap.forEach((key, value) {
      mergedDefines.add('--dart-define=$key=$value');
    });
    if (defines != null) {
      for (var d in defines) {
        mergedDefines.add('--dart-define=$d');
      }
    }
    final defineString = mergedDefines.join(' ');

    Logger.info("Starting Flutter CI build...");
    Logger.info("----------------------------------");
    Logger.info("Selected Options:");
    Logger.info("  Platform: $resolvedPlatform");
    if (resolvedManualVersion != null) Logger.info("  Override Version: $resolvedManualVersion");
    Logger.info("  Bump Build Number: $resolvedShouldBump");
    if (resolvedCoverage) Logger.info("  Test Coverage: Enabled");
    if (mergedDefines.isNotEmpty) Logger.info("  Dart Defines: $mergedDefines");
    Logger.info("----------------------------------");

    // 1. Version Handling
    if (resolvedManualVersion != null) {
      versionService.updateVersion(resolvedManualVersion);
    } else if (resolvedShouldBump) {
      versionService.bumpBuildNumber();
    }

    // Capture version for explicit build flags
    final buildName = versionService.getVersionName();
    final buildNumber = versionService.getBuildNumber();

    // 1.5. Coverage
    if (resolvedCoverage) {
      Logger.info("Running tests with coverage...");
      await buildService.execute("flutter test --coverage");
    }

    // 2. Pre-build Commands
    if (resolvedPreBuildCmd != null && resolvedPreBuildCmd.isNotEmpty) {
      Logger.info("Running custom pre-build commands");
      await buildService.execute(resolvedPreBuildCmd);
    } else {
      final preBuildSteps = configService.getValue<List>('pre_build');
      if (preBuildSteps != null && preBuildSteps.isNotEmpty) {
        for (var step in preBuildSteps) {
           await buildService.execute(step.toString());
        }
      } else {
        Logger.info("Running default pre-build commands (clean, pub get)");
        await buildService.clean();
        await buildService.pubGet();
      }
    }

    // 3. Build Generation (Parallel Support)
    final builds = <Future>[];

    if (resolvedPlatform == 'android' || resolvedPlatform == 'both') {
      final actCmd = resolvedAndroidBuildCmd != null ? "$resolvedAndroidBuildCmd $defineString".trim() : null;
      builds.add(_runAndroidBuild(
        actCmd, 
        resolvedAndroidFormat,
        buildName,
        buildNumber,
        defineString,
      ));
    }

    if (resolvedPlatform == 'ios' || resolvedPlatform == 'both') {
      final actCmd = resolvedIosBuildCmd != null ? "$resolvedIosBuildCmd $defineString".trim() : null;
      builds.add(_runIosBuild(
        actCmd, 
        resolvedIosMethod,
        buildName,
        buildNumber,
        defineString,
      ));
    }

    if (parallel && builds.length > 1) {
      Logger.info("Running builds in parallel...");
      await Future.wait(builds);
    } else {
      for (var b in builds) {
        await b;
      }
    }

    // 4. Storage & Build Info
    try {
      final appName = versionService.getAppName();
      final currentVersion = versionService.getVersion();
      final commit = await gitService.getCurrentCommitHash();
      
      await storageService.storeArtifacts(
        appName: appName, 
        version: currentVersion,
        gitCommit: commit,
      );
    } catch (e) {
      Logger.error("Failed to store artifacts: $e");
    }

    Logger.success("Build session completed");
  }

  Future<void> _runAndroidBuild(String? customCmd, String format, String buildName, int buildNumber, String defineString) async {
    try {
      if (customCmd != null && customCmd.isNotEmpty) {
        Logger.info("Running custom Android build command: $customCmd");
        await buildService.execute(customCmd);
      } else {
        Logger.info("Building Android $format ($buildName+$buildNumber)");
        await buildService.buildAndroid(
          format: format,
          buildName: buildName,
          buildNumber: buildNumber,
          extraFlags: defineString,
        );
      }
    } catch (e) {
      Logger.error("Android build failed: $e");
    }
  }

  Future<void> _runIosBuild(String? customCmd, String method, String buildName, int buildNumber, String defineString) async {
    try {
      if (customCmd != null && customCmd.isNotEmpty) {
        Logger.info("Running custom iOS build command: $customCmd");
        await buildService.execute(customCmd);
      } else {
        Logger.info("Building iOS IPA ($method) ($buildName+$buildNumber)");
        await buildService.buildIOS(
          method: method,
          buildName: buildName,
          buildNumber: buildNumber,
          extraFlags: defineString,
        );
      }
    } catch (e) {
      Logger.error("iOS build failed: $e");
    }
  }
}

