import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:flutter_ci/src/exceptions.dart';
import 'package:flutter_ci/src/services/git_service.dart';
import 'package:flutter_ci/src/services/version_service.dart';
import 'package:flutter_ci/src/services/distribution_service.dart';
import 'package:flutter_ci/src/services/config_service.dart';
import 'package:flutter_ci/src/commands/build_command.dart';
import 'package:flutter_ci/src/utils/logger.dart';

/// The command responsible for the complete release lifecycle.
class ReleaseCommand {
  /// The command for building artifacts.
  final buildCommand = BuildCommand();

  /// The service for git operations.
  final gitService = GitService();

  /// The service for version management.
  final versionService = VersionService();

  /// The service for configuration loading.
  final configService = ConfigService();

  /// The service for artifact distribution.
  final distributionService = DistributionService();

  /// Runs the complete release process including bumping, tagging, and building.
  ///
  /// Steps, in order:
  /// 1. Set or bump the version in `pubspec.yaml`.
  /// 2. Generate release notes from the commits since the last tag when
  ///    [generateNotes] or [changelog] is enabled, and prepend them to
  ///    `CHANGELOG.md` when [changelog] is enabled.
  /// 3. Build, exactly as [BuildCommand.run] does with the build arguments.
  /// 4. Commit `pubspec.yaml` (and `CHANGELOG.md` if updated) when [commit] is
  ///    enabled, and create a `v<version>` tag when [createTag] is enabled.
  /// 5. Upload artifacts to the targets enabled in `flutter_ci.yaml` when
  ///    [upload] is enabled. [appStore] and [playStore] upload to that store
  ///    even without [upload].
  /// 6. Send Slack/Discord notifications configured in `flutter_ci.yaml`.
  ///
  /// Nullable flags fall back to `flutter_ci.yaml` (`git.commit`, `git.tag`,
  /// `git.changelog`, `distribution.enabled`) and then to `false`.
  ///
  /// Throws a [FlutterCiException] if the build fails (nothing is committed,
  /// tagged or uploaded in that case), if committing or tagging fails, or,
  /// after all targets have been attempted, if any upload or notification
  /// failed.
  Future<void> run({
    bool generateNotes = false,
    bool? upload,
    bool? commit,
    bool? createTag,
    bool? changelog,
    bool appStore = false,
    bool playStore = false,
    String? version,
    bool? shouldBump,
    String? platform,
    String? androidFormat,
    String? iosMethod,
    String? preBuildCmd,
    String? androidBuildCmd,
    String? iosBuildCmd,
    String? flavor,
    bool parallel = true,
    bool? coverage,
    List<String>? defines,
  }) async {
    await configService.loadConfig();

    Logger.info("🚀 Starting Release Process...");

    // Priority: CLI flag > flutter_ci.yaml > default.
    final resolvedCommit =
        commit ?? configService.getBool('git.commit') ?? false;
    final resolvedTag = createTag ?? configService.getBool('git.tag') ?? false;
    final resolvedChangelog =
        changelog ?? configService.getBool('git.changelog') ?? false;
    final resolvedUpload =
        upload ?? configService.getBool('distribution.enabled') ?? false;

    // 1. Version Bump
    final resolvedManualVersion =
        version ?? configService.getString('manual_version');
    final resolvedShouldBump =
        shouldBump ?? configService.getBool('version_bump') ?? true;

    if (resolvedManualVersion != null) {
      versionService.updateVersion(resolvedManualVersion);
    } else if (resolvedShouldBump) {
      versionService.bumpBuildNumber();
    }
    final newVersion = versionService.getVersion();
    final appName = versionService.getAppName();

    // 2. Release notes and changelog
    String? notes;
    var changelogUpdated = false;
    if (generateNotes || resolvedChangelog) {
      Logger.info("Generating release notes from git...");
      notes = await gitService.getCommitsSinceLastTag();
      Logger.info("\nRelease Notes Preview:\n$notes\n");

      if (resolvedChangelog && notes.isNotEmpty) {
        Logger.info("Appending notes to CHANGELOG.md...");
        final file = File('CHANGELOG.md');
        final currentContent = file.existsSync() ? file.readAsStringSync() : "";
        final newEntry = "## v$newVersion\n\n$notes\n\n";
        file.writeAsStringSync(newEntry + currentContent);
        changelogUpdated = true;
        Logger.success("CHANGELOG.md updated!");
      }
    }

    // 3. Run Build. A failure throws, so nothing below runs.
    await buildCommand.run(
      version: newVersion,
      shouldBump: false, // Already bumped
      platform: platform,
      androidFormat: androidFormat,
      iosMethod: iosMethod,
      preBuildCmd: preBuildCmd,
      androidBuildCmd: androidBuildCmd,
      iosBuildCmd: iosBuildCmd,
      flavor: flavor,
      parallel: parallel,
      coverage: coverage,
      defines: defines,
    );

    // 4. Git Commit & Tag
    if (resolvedCommit) {
      await gitService.commitChanges("Release v$newVersion",
          ["pubspec.yaml", if (changelogUpdated) "CHANGELOG.md"]);
    }
    if (resolvedTag) {
      await gitService.createTag("v$newVersion");
    }

    // 5. Distribution
    final failures = <String>[];
    final artifacts = _artifacts("builds/v$newVersion");
    String? pick(List<String> extensions) {
      for (final ext in extensions) {
        for (final file in artifacts) {
          if (path.extension(file) == ext) return file;
        }
      }
      return null;
    }

    Future<void> distribute(String target, String? artifact,
        Future<bool> Function(String artifact) upload) async {
      if (artifact == null) {
        Logger.error(
            "$target: no suitable artifact found in builds/v$newVersion");
        failures.add(target);
      } else if (!await upload(artifact)) {
        failures.add(target);
      }
    }

    Map? section(String name) =>
        configService.getValue<Map>('distribution.$name');
    bool enabled(Map? config) => resolvedUpload && config?['enabled'] == true;

    const targets = ['google_drive', 'firebase', 'app_store', 'play_store'];
    if (resolvedUpload &&
        !appStore &&
        !playStore &&
        !targets.any((t) => enabled(section(t)))) {
      Logger.warning("Upload requested, but no target under 'distribution' "
          "in flutter_ci.yaml has 'enabled: true'.");
    }

    final googleDrive = section('google_drive');
    if (enabled(googleDrive)) {
      final files = artifacts
          .where(
              (f) => const ['.apk', '.aab', '.ipa'].contains(path.extension(f)))
          .toList();
      // Uploads every artifact; an empty list is reported as a failure.
      for (final file in files.isEmpty ? <String?>[null] : files) {
        await distribute(
            'Google Drive',
            file,
            (artifact) => distributionService.uploadToGoogleDrive(
                  artifactPath: artifact,
                  folderId: '${googleDrive!['folder_id'] ?? ''}',
                ));
      }
    }

    final firebase = section('firebase');
    if (enabled(firebase)) {
      final appId = '${firebase!['app_id'] ?? ''}';
      // Firebase app IDs look like 1:123:android:abc or 1:123:ios:abc.
      final artifact =
          appId.contains(':ios:') ? pick(['.ipa']) : pick(['.apk', '.aab']);
      await distribute(
          'Firebase',
          artifact,
          (artifact) => distributionService.uploadToFirebase(
                artifactPath: artifact,
                appId: appId,
                testers: firebase['testers']?.toString(),
                releaseNotes: notes,
              ));
    }

    final appStoreConfig = section('app_store');
    if (appStore || enabled(appStoreConfig)) {
      await distribute(
          'App Store',
          pick(['.ipa']),
          (artifact) => distributionService.uploadToAppStore(
                artifactPath: artifact,
                username: '${appStoreConfig?['username'] ?? ''}',
                password: '${appStoreConfig?['password'] ?? ''}',
              ));
    }

    final playStoreConfig = section('play_store');
    if (playStore || enabled(playStoreConfig)) {
      await distribute(
          'Play Store',
          pick(['.aab', '.apk']),
          (artifact) => distributionService.uploadToPlayStore(
                artifactPath: artifact,
                jsonKeyPath: '${playStoreConfig?['json_key_path'] ?? ''}',
                packageName: '${playStoreConfig?['package_name'] ?? ''}',
                track: playStoreConfig?['track']?.toString(),
              ));
    }

    // 6. Notifications
    final notesSection = notes != null && notes.isNotEmpty;
    final slackUrl = configService.getString('notifications.slack');
    if (slackUrl != null && slackUrl.isNotEmpty) {
      final sent = await distributionService.sendWebhook(
        url: slackUrl,
        message: "🚀 Version $newVersion of $appName is ready!"
            "${notesSection ? "\n\nRelease Notes:\n$notes" : ""}",
      );
      if (!sent) failures.add('Slack notification');
    }

    final discordUrl = configService.getString('notifications.discord');
    if (discordUrl != null && discordUrl.isNotEmpty) {
      final sent = await distributionService.sendWebhook(
        url: discordUrl,
        message: "🚀 **Version $newVersion of $appName is ready!**"
            "${notesSection ? "\n\n**Release Notes:**\n$notes" : ""}",
      );
      if (!sent) failures.add('Discord notification');
    }

    if (failures.isNotEmpty) {
      throw FlutterCiException("Release v$newVersion was built, but these "
          "steps failed: ${failures.toSet().join(', ')}.");
    }

    Logger.success("Release v$newVersion completed successfully! 🌟");
  }

  List<String> _artifacts(String dirPath) {
    final dir = Directory(dirPath);
    if (!dir.existsSync()) return const [];
    return dir.listSync().whereType<File>().map((f) => f.path).toList()..sort();
  }
}
