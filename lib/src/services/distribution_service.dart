import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:process_run/shell.dart';
import 'package:flutter_ci/src/exceptions.dart';
import 'package:flutter_ci/src/utils/logger.dart';
import 'package:flutter_ci/src/utils/process_runner.dart';

/// A service responsible for distributing build artifacts to various platforms.
///
/// Each method logs its outcome and returns `true` on success or `false` on
/// failure instead of throwing, so one failed upload does not prevent the
/// others from running.
class DistributionService {
  /// The shell instance used for executing commands.
  @Deprecated('No longer used by flutter_ci. Will be removed in 1.0.0.')
  final shell = Shell(verbose: true);

  final ProcessRunner _runner = ProcessRunner();

  /// Name of the environment variable used to hand the App Store password
  /// to `altool` without exposing it on the command line or in logs.
  static const appStorePasswordEnvVar = 'FLUTTER_CI_APP_STORE_PASSWORD';

  /// Uploads the artifact at [artifactPath] to Firebase App Distribution.
  ///
  /// Requires the `firebase` CLI to be installed and authenticated.
  /// [testers] is a comma-separated list of tester emails or group aliases.
  Future<bool> uploadToFirebase({
    required String artifactPath,
    required String appId,
    String? testers,
    String? releaseNotes,
  }) {
    Logger.info("Uploading to Firebase App Distribution: $artifactPath");
    return _attempt('Firebase distribution', artifactPath, () {
      return _runner.run('firebase', [
        'appdistribution:distribute',
        artifactPath,
        '--app',
        appId,
        if (releaseNotes != null && releaseNotes.isNotEmpty) ...[
          '--release-notes',
          releaseNotes,
        ],
        if (testers != null && testers.isNotEmpty) ...['--testers', testers],
      ]);
    });
  }

  /// Uploads the artifact at [artifactPath] to Google Drive.
  ///
  /// Requires the [gdrive](https://github.com/glotlabs/gdrive) 3.x CLI to be
  /// installed and authenticated.
  Future<bool> uploadToGoogleDrive({
    required String artifactPath,
    required String folderId,
  }) {
    Logger.info("Uploading to Google Drive: $artifactPath");
    return _attempt('Google Drive upload', artifactPath, () {
      return _runner.run(
          'gdrive', ['files', 'upload', '--parent', folderId, artifactPath]);
    }, hint: "Ensure the 'gdrive' 3.x CLI is installed and authenticated.");
  }

  /// Sends a webhook notification to the specified [url] with [message].
  ///
  /// Discord webhook URLs receive a `{"content": ...}` payload (truncated to
  /// Discord's 2000-character limit); all other URLs, including Slack,
  /// receive `{"text": ...}`. The URL is never logged because webhook URLs
  /// act as credentials.
  Future<bool> sendWebhook({
    required String url,
    required String message,
  }) async {
    Logger.info("Sending webhook notification...");
    final uri = Uri.tryParse(url);
    if (uri == null || !(uri.isScheme('http') || uri.isScheme('https'))) {
      Logger.error("Failed to send webhook: not a valid http(s) URL.");
      return false;
    }

    final isDiscord =
        uri.host.contains('discord') && !uri.path.endsWith('/slack');
    final payload =
        isDiscord ? {'content': _truncate(message, 2000)} : {'text': message};

    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 30);
    try {
      final request = await client.postUrl(uri);
      final body = utf8.encode(jsonEncode(payload));
      request.headers.contentType = ContentType.json;
      // An explicit length avoids chunked encoding, which some receivers
      // do not accept.
      request.contentLength = body.length;
      request.add(body);
      final response =
          await request.close().timeout(const Duration(seconds: 30));
      await response.drain<void>();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        Logger.error("Failed to send webhook to ${uri.host}: "
            "HTTP ${response.statusCode}");
        return false;
      }
      Logger.success("Webhook sent successfully!");
      return true;
    } on Exception catch (e) {
      Logger.error("Failed to send webhook to ${uri.host}: ${_describe(e)}");
      return false;
    } finally {
      client.close(force: true);
    }
  }

  /// Uploads the artifact at [artifactPath] to Apple App Store Connect.
  ///
  /// Uses `xcrun altool` (macOS only) with an
  /// [app-specific password](https://support.apple.com/en-us/102654). The
  /// password is passed through the [appStorePasswordEnvVar] environment
  /// variable, never on the command line.
  Future<bool> uploadToAppStore({
    required String artifactPath,
    required String username,
    required String password,
  }) {
    Logger.info("Uploading to Apple App Store Connect: $artifactPath");
    if (username.isEmpty || password.isEmpty) {
      Logger.error("App Store upload failed: distribution.app_store.username "
          "and password must be set in flutter_ci.yaml.");
      return Future.value(false);
    }
    return _attempt('App Store upload', artifactPath, () {
      return _runner.run(
        'xcrun',
        [
          'altool',
          '--upload-app',
          '-f',
          artifactPath,
          '-t',
          'ios',
          '-u',
          username,
          '-p',
          '@env:$appStorePasswordEnvVar',
        ],
        environment: {appStorePasswordEnvVar: password},
      );
    },
        hint:
            "Ensure you have properly configured app-specific passwords for altool.");
  }

  /// Uploads the artifact at [artifactPath] to Google Play Console.
  ///
  /// Requires [fastlane](https://fastlane.tools) to be installed. `.aab`
  /// files are uploaded with `--aab`, anything else with `--apk`. When
  /// [track] is null, fastlane's default track (`production`) is used.
  Future<bool> uploadToPlayStore({
    required String artifactPath,
    required String jsonKeyPath,
    required String packageName,
    String? track,
  }) {
    Logger.info("Uploading to Google Play Console: $artifactPath");
    if (packageName.isEmpty || jsonKeyPath.isEmpty) {
      Logger.error("Play Store upload failed: distribution.play_store."
          "package_name and json_key_path must be set in flutter_ci.yaml.");
      return Future.value(false);
    }
    final isBundle = path.extension(artifactPath) == '.aab';
    return _attempt('Play Store upload', artifactPath, () {
      return _runner.run('fastlane', [
        'supply',
        isBundle ? '--aab' : '--apk',
        artifactPath,
        '--package_name',
        packageName,
        '--json_key',
        jsonKeyPath,
        if (track != null && track.isNotEmpty) ...['--track', track],
      ]);
    },
        hint:
            "Ensure fastlane is installed and the Google Play JSON key path is correct.");
  }

  Future<bool> _attempt(
    String label,
    String artifactPath,
    Future<void> Function() upload, {
    String? hint,
  }) async {
    if (!File(artifactPath).existsSync()) {
      Logger.error("$label failed: artifact not found at $artifactPath");
      return false;
    }
    try {
      await upload();
      Logger.success("$label successful!");
      return true;
    } on FlutterCiException catch (e) {
      Logger.error("$label failed: ${e.message}");
      if (hint != null) Logger.info(hint);
      return false;
    }
  }

  static String _truncate(String text, int max) =>
      text.length <= max ? text : '${text.substring(0, max - 1)}…';

  static String _describe(Exception e) {
    if (e is SocketException) return e.message;
    if (e is TimeoutException) return 'timed out';
    // HttpException.toString() includes the full URL, which is a secret.
    if (e is HttpException) return e.message;
    return e.runtimeType.toString();
  }
}
