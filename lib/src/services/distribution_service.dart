import 'package:process_run/shell.dart';
import 'package:flutter_ci/src/utils/logger.dart';

class DistributionService {
  final shell = Shell(verbose: true);

  Future<void> uploadToFirebase({
    required String artifactPath,
    required String appId,
    String? testers,
    String? releaseNotes,
  }) async {
    Logger.info("Uploading to Firebase App Distribution: $artifactPath");
    
    final notesArg = releaseNotes != null ? " --release-notes \"$releaseNotes\"" : "";
    final testersArg = testers != null ? " --testers \"$testers\"" : "";
    
    try {
      await shell.run(
        "firebase appdistribution:distribute \"$artifactPath\" --app \"$appId\"$notesArg$testersArg"
      );
      Logger.success("Firebase distribution successful!");
    } catch (e) {
      Logger.error("Firebase distribution failed: $e");
    }
  }

  Future<void> uploadToGoogleDrive({
    required String artifactPath,
    required String folderId,
  }) async {
    Logger.info("Uploading to Google Drive: $artifactPath");
    
    try {
      // Using 'gdrive' CLI tool
      await shell.run(
        "gdrive upload --parent \"$folderId\" \"$artifactPath\""
      );
      Logger.success("Google Drive upload successful!");
    } catch (e) {
      Logger.error("Google Drive upload failed: $e");
      Logger.info("Ensure 'gdrive' CLI is installed and authenticated.");
    }
  }
  Future<void> sendWebhook({
    required String url,
    required String message,
  }) async {
    Logger.info("Sending webhook notification...");
    try {
      // Escape inner quotes
      final safeMessage = message.replaceAll('"', '\\"');
      await shell.run('''
        curl -X POST -H 'Content-type: application/json' --data '{"text": "$safeMessage"}' "$url"
      ''');
      Logger.success("Webhook sent successfully!");
    } catch (e) {
      Logger.error("Failed to send webhook: $e");
    }
  }

  Future<void> uploadToAppStore({
    required String artifactPath,
    required String username,
    required String password,
  }) async {
    Logger.info("Uploading to Apple App Store Connect: $artifactPath");
    try {
      await shell.run(
        "xcrun altool --upload-app -f \"$artifactPath\" -t ios -u \"$username\" -p \"$password\""
      );
      Logger.success("App Store upload successful!");
    } catch (e) {
      Logger.error("App Store upload failed: $e");
      Logger.info("Ensure you have properly configured app-specific passwords for altool.");
    }
  }

  Future<void> uploadToPlayStore({
    required String artifactPath,
    required String jsonKeyPath,
    required String packageName,
  }) async {
    Logger.info("Uploading to Google Play Console: $artifactPath");
    try {
      // Example using fastlane supply directly
      await shell.run(
        "fastlane supply --apk \"$artifactPath\" --package_name \"$packageName\" --json_key \"$jsonKeyPath\""
      );
      Logger.success("Play Store upload successful!");
    } catch (e) {
      Logger.error("Play Store upload failed: $e");
      Logger.info("Ensure fastlane is installed and the Google Play JSON key path is correct.");
    }
  }
}

