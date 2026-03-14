import 'dart:io';
import 'package:flutter_ci/src/services/git_service.dart';
import 'package:flutter_ci/src/services/version_service.dart';
import 'package:flutter_ci/src/services/distribution_service.dart';
import 'package:flutter_ci/src/services/config_service.dart';
import 'package:flutter_ci/src/commands/build_command.dart';
import 'package:flutter_ci/src/utils/logger.dart';

class ReleaseCommand {
  final buildCommand = BuildCommand();
  final gitService = GitService();
  final versionService = VersionService();
  final configService = ConfigService();
  final distributionService = DistributionService();

  Future<void> run({
    bool generateNotes = false,
    bool upload = false,
    bool commit = false,
    bool createTag = false,
    bool changelog = false,
    bool appStore = false,
    bool playStore = false,
  }) async {
    await configService.loadConfig();
    
    Logger.info("🚀 Starting Release Process...");
    
    // 1. Version Bump
    final manualVersion = configService.getValue('manual_version');
    if (manualVersion != null) {
      versionService.updateVersion(manualVersion);
    } else {
      versionService.bumpBuildNumber();
    }
    final newVersion = versionService.getVersion();
    final appName = versionService.getAppName();
    
    // 2. Git Commit & Tag
    final resolvedCommit = configService.getValue('git.commit') ?? commit;
    final resolvedTag = configService.getValue('git.tag') ?? createTag;

    if (resolvedCommit == true) {
      await gitService.commitChanges("Release v$newVersion", ["pubspec.yaml"]);
    }
    if (resolvedTag == true) {
      await gitService.createTag("v$newVersion");
    }
    
    // 3. Generate Release Notes if requested
    String? notes;
    if (generateNotes) {
      Logger.info("Generating release notes from git...");
      notes = await gitService.getRecentCommits();
      Logger.info("\nRelease Notes Preview:\n$notes\n");
      
      final writeChangelog = configService.getValue('git.changelog') ?? changelog;
      if (writeChangelog == true && notes.isNotEmpty) {
        Logger.info("Appending notes to CHANGELOG.md...");
        final file = File('CHANGELOG.md');
        final currentContent = file.existsSync() ? file.readAsStringSync() : "";
        final newEntry = "## v$newVersion\n\n$notes\n\n";
        file.writeAsStringSync(newEntry + currentContent);
        Logger.success("CHANGELOG.md updated!");
      }
    }
    
    // 4. Run Build
    await buildCommand.run(shouldBump: false); // Already bumped
    
    // 5. Distribution if requested
    // Priority: YAML > CLI
    final resolvedUpload = configService.getValue('distribution.enabled') ?? upload;
    
    if (resolvedUpload == true) {
      final googleDriveConfig = configService.getValue('distribution.google_drive');
      final firebaseConfig = configService.getValue('distribution.firebase');
      final appStoreConfig = configService.getValue('distribution.app_store');
      final playStoreConfig = configService.getValue('distribution.play_store');
      
      final artifactsDir = "builds/v$newVersion";
      final apkPath = "$artifactsDir/$appName-$newVersion.apk";
      final aabPath = "$artifactsDir/$appName-$newVersion.aab"; // Fallback for Play Store
      final ipaPath = "$artifactsDir/$appName-$newVersion.ipa";

      if (googleDriveConfig != null && googleDriveConfig['enabled'] == true) {
        await distributionService.uploadToGoogleDrive(
          artifactPath: apkPath,
          folderId: googleDriveConfig['folder_id'],
        );
      }
      
      if (firebaseConfig != null && firebaseConfig['enabled'] == true) {
        // Firebase CLI expects the path, usually we'd pass the built artifact directly
        await distributionService.uploadToFirebase(
          artifactPath: apkPath,
          appId: firebaseConfig['app_id'],
          testers: firebaseConfig['testers'],
          releaseNotes: notes,
        );
      }
      
      if (appStoreConfig != null && (appStoreConfig['enabled'] == true || appStore)) {
        await distributionService.uploadToAppStore(
          artifactPath: ipaPath,
          username: appStoreConfig['username'] ?? '',
          password: appStoreConfig['password'] ?? '',
        );
      }

      if (playStoreConfig != null && (playStoreConfig['enabled'] == true || playStore)) {
        await distributionService.uploadToPlayStore(
          artifactPath: aabPath, // Usually you upload AAB to Play Store
          jsonKeyPath: playStoreConfig['json_key_path'] ?? '',
          packageName: playStoreConfig['package_name'] ?? '',
        );
      }
    }

    // 6. Notifications
    final slackUrl = configService.getValue('notifications.slack');
    if (slackUrl != null && slackUrl.isNotEmpty) {
      await distributionService.sendWebhook(
        url: slackUrl,
        message: "🚀 Version $newVersion of $appName is ready!\n\nRelease Notes:\n$notes",
      );
    }

    final discordUrl = configService.getValue('notifications.discord');
    if (discordUrl != null && discordUrl.isNotEmpty) {
      await distributionService.sendWebhook(
        url: discordUrl,
        message: "🚀 **Version $newVersion of $appName is ready!**\n\n**Release Notes:**\n$notes",
      );
    }
    
    Logger.success("Release v$newVersion completed successfully! 🌟");
  }
}
