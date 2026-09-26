import 'dart:io';
import 'package:flutter_ci/src/exceptions.dart';
import 'package:flutter_ci/src/services/build_service.dart';
import 'package:flutter_ci/src/services/version_service.dart';
import 'package:flutter_ci/src/services/storage_service.dart';
import 'package:flutter_ci/src/services/git_service.dart';
import 'package:flutter_ci/src/services/distribution_service.dart';
import 'package:flutter_ci/src/services/config_service.dart';
import 'package:flutter_ci/src/utils/logger.dart';
import 'package:flutter_ci/src/utils/process_runner.dart';

/// The command responsible for the complete CI build lifecycle.
class BuildCommand {
  /// Runs Flutter builds and shell steps.
  final buildService = BuildService();

  /// Reads and updates the version in `pubspec.yaml`.
  final versionService = VersionService();

  /// Collects build outputs into `builds/v<version>/`.
  final storageService = StorageService();

  /// Provides the commit hash recorded in `build_info.json`.
  final gitService = GitService();

  /// Not used by the build itself; kept for API compatibility.
  final distributionService = DistributionService();

  /// Loads `flutter_ci.yaml`.
  final configService = ConfigService();

  /// Supported values for `platform`.
  static const platforms = ['android', 'ios', 'both'];

  /// Supported values for `android.format`.
  static const androidFormats = ['apk', 'aab'];

  /// Supported values for `ios.method`.
  static const iosMethods = [
    'ad-hoc',
    'development',
    'app-store',
    'enterprise'
  ];

  /// Runs the build process with the given parameters, merging config file and CLI flags.
  ///
  /// Each setting is resolved as: the argument passed here (a CLI flag) if
  /// non-null, otherwise the value in `flutter_ci.yaml`, otherwise the
  /// default. Dart defines from the YAML `env` map and from [defines]
  /// (`KEY=VALUE` entries) are combined.
  ///
  /// Steps: set or bump the version, optionally run `flutter test
  /// --coverage`, run the pre-build steps, build each platform (in parallel
  /// when [parallel] is true), then store artifacts in `builds/v<version>/`.
  ///
  /// When the platform is `both` on a host other than macOS, the iOS build is
  /// skipped with a warning unless a custom iOS build command is configured.
  ///
  /// Throws a [FlutterCiException] if the configuration is invalid or any
  /// step fails. If one platform build fails, the others still run to
  /// completion before the exception is thrown.
  Future<void> run({
    String? version,
    bool? shouldBump,
    String? androidBuildCmd,
    String? iosBuildCmd,
    String? preBuildCmd,
    String? platform,
    String? androidFormat,
    String? iosMethod,
    String? flavor,
    bool parallel = true,
    bool? coverage,
    List<String>? defines,
  }) async {
    await configService.loadConfig();

    // Priority: CLI flag > flutter_ci.yaml > default.
    final resolvedPlatform = _choice(
        'platform', platform ?? configService.getString('platform'), platforms,
        fallback: 'both');
    final resolvedManualVersion =
        version ?? configService.getString('manual_version');
    final resolvedShouldBump =
        shouldBump ?? configService.getBool('version_bump') ?? true;
    final resolvedAndroidFormat = _choice(
        'android.format',
        androidFormat ?? configService.getString('android.format'),
        androidFormats,
        fallback: 'apk');
    final resolvedIosMethod = _choice('ios.method',
        iosMethod ?? configService.getString('ios.method'), iosMethods,
        fallback: 'ad-hoc');
    final resolvedFlavor = flavor ?? configService.getString('flavor');
    final resolvedPreBuildCmd =
        preBuildCmd ?? configService.getString('pre_build_command');
    final resolvedAndroidBuildCmd =
        androidBuildCmd ?? configService.getString('android.build_command');
    final resolvedIosBuildCmd =
        iosBuildCmd ?? configService.getString('ios.build_command');
    final resolvedCoverage =
        coverage ?? configService.getBool('test.coverage') ?? false;

    // Merge env map from YAML with defines from CLI (CLI wins on conflicts).
    final envMap = configService.getValue<Map>('env') ?? {};
    final mergedDefines = <String, String?>{
      for (final entry in envMap.entries) '${entry.key}': '${entry.value}',
      for (final define in defines ?? const <String>[])
        define.split('=').first: define.contains('=')
            ? define.substring(define.indexOf('=') + 1)
            : null,
    };
    final defineList = [
      for (final MapEntry(:key, :value) in mergedDefines.entries)
        value == null ? key : '$key=$value'
    ];

    var buildAndroid =
        resolvedPlatform == 'android' || resolvedPlatform == 'both';
    var buildIos = resolvedPlatform == 'ios' || resolvedPlatform == 'both';
    final hasCustomIosCmd =
        resolvedIosBuildCmd != null && resolvedIosBuildCmd.isNotEmpty;
    if (buildIos && !Platform.isMacOS && !hasCustomIosCmd) {
      if (resolvedPlatform == 'ios') {
        throw const FlutterCiException(
            'iOS builds require macOS. Use --platform android, or set '
            'ios.build_command to a command that works on this machine.');
      }
      Logger.warning("Skipping iOS build: iOS builds require macOS.");
      buildIos = false;
    }

    Logger.info("Starting Flutter CI build...");
    Logger.info("----------------------------------");
    Logger.info("Selected Options:");
    Logger.info("  Platform: $resolvedPlatform");
    if (resolvedFlavor != null) Logger.info("  Flavor: $resolvedFlavor");
    if (resolvedManualVersion != null) {
      Logger.info("  Override Version: $resolvedManualVersion");
    }
    Logger.info("  Bump Build Number: $resolvedShouldBump");
    if (resolvedCoverage) Logger.info("  Test Coverage: Enabled");
    // Only keys are printed: values are often secrets.
    if (mergedDefines.isNotEmpty) {
      Logger.info("  Dart Defines: ${mergedDefines.keys.join(', ')}");
    }
    Logger.info("----------------------------------");

    final startedAt = DateTime.now();

    // 1. Version Handling
    if (resolvedManualVersion != null) {
      if (resolvedManualVersion != versionService.getVersion()) {
        versionService.updateVersion(resolvedManualVersion);
      }
    } else if (resolvedShouldBump) {
      versionService.bumpBuildNumber();
    }

    // Capture version for explicit build flags. A version without `+build`
    // lets Flutter pick its default build number.
    final currentVersion = versionService.getVersion();
    final buildName = versionService.getVersionName();
    final buildNumber =
        currentVersion.contains('+') ? versionService.getBuildNumber() : null;

    // Prepare Build Log Output Directory
    final destDir = Directory("builds/v$currentVersion");
    if (!destDir.existsSync()) {
      destDir.createSync(recursive: true);
    }
    buildService.setLogFile(File('${destDir.path}/build.log'));

    // 1.5. Coverage
    if (resolvedCoverage) {
      Logger.info("Running tests with coverage...");
      await buildService.testWithCoverage();
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
    final builds = <String, Future<void> Function()>{
      if (buildAndroid)
        'Android': () => _runAndroidBuild(
            resolvedAndroidBuildCmd,
            resolvedAndroidFormat,
            buildName,
            buildNumber,
            defineList,
            resolvedFlavor),
      if (buildIos)
        'iOS': () => _runIosBuild(resolvedIosBuildCmd, resolvedIosMethod,
            buildName, buildNumber, defineList, resolvedFlavor),
    };

    final failures = <String>[];
    Future<void> guarded(String name, Future<void> Function() build) async {
      try {
        await build();
      } on FlutterCiException catch (e) {
        Logger.error("$name build failed: ${e.message}");
        failures.add(name);
      }
    }

    if (parallel && builds.length > 1) {
      Logger.info("Running builds in parallel...");
      await Future.wait([
        for (final entry in builds.entries) guarded(entry.key, entry.value)
      ]);
    } else {
      for (final entry in builds.entries) {
        await guarded(entry.key, entry.value);
      }
    }

    // 4. Storage & Build Info. Runs even after a failure so the artifacts of
    // the platforms that did build are kept.
    if (failures.length < builds.length) {
      try {
        final appName = versionService.getAppName();
        final commit = await gitService.getCurrentCommitHash();

        await storageService.storeArtifacts(
          appName: appName,
          version: currentVersion,
          gitCommit: commit,
          builtAfter: startedAt,
        );
      } on Exception catch (e) {
        Logger.error("Failed to store artifacts: $e");
      }
    }

    if (failures.isNotEmpty) {
      throw FlutterCiException('Build failed for ${failures.join(' and ')}. '
          'See ${destDir.path}/build.log for details.');
    }

    Logger.success("Build session completed");
  }

  String _choice(String key, String? value, List<String> allowed,
      {required String fallback}) {
    if (value == null) return fallback;
    if (!allowed.contains(value)) {
      throw FlutterCiException("Invalid $key '$value'. "
          "Allowed values: ${allowed.join(', ')}.");
    }
    return value;
  }

  /// Appends shell-quoted `--dart-define` arguments to a custom command and
  /// returns it together with a redacted version for display.
  (String, String) _withDefines(String command, List<String> defines) {
    final args = [for (final d in defines) '--dart-define=$d'];
    String join(Iterable<String> parts) => [command, ...parts].join(' ').trim();
    return (
      join(args.map(shellQuote)),
      join(args.map((a) => shellQuote(redactDefine(a)))),
    );
  }

  Future<void> _runAndroidBuild(
      String? customCmd,
      String format,
      String buildName,
      int? buildNumber,
      List<String> defines,
      String? flavor) {
    if (customCmd != null && customCmd.isNotEmpty) {
      final (command, display) = _withDefines(customCmd, defines);
      Logger.info("Running custom Android build command: $display");
      return buildService.execute(command, display: display);
    }
    Logger.info(
        "Building Android $format ($buildName${buildNumber == null ? '' : '+$buildNumber'})");
    return buildService.buildAndroid(
      format: format,
      buildName: buildName,
      buildNumber: buildNumber,
      flavor: flavor,
      dartDefines: defines,
    );
  }

  Future<void> _runIosBuild(String? customCmd, String method, String buildName,
      int? buildNumber, List<String> defines, String? flavor) {
    if (customCmd != null && customCmd.isNotEmpty) {
      final (command, display) = _withDefines(customCmd, defines);
      Logger.info("Running custom iOS build command: $display");
      return buildService.execute(command, display: display);
    }
    Logger.info(
        "Building iOS IPA ($method) ($buildName${buildNumber == null ? '' : '+$buildNumber'})");
    return buildService.buildIOS(
      method: method,
      buildName: buildName,
      buildNumber: buildNumber,
      flavor: flavor,
      dartDefines: defines,
    );
  }
}
