import 'dart:io';

import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:flutter_ci/src/commands/build_command.dart';
import 'package:flutter_ci/src/commands/bump_command.dart';
import 'package:flutter_ci/src/commands/doctor_command.dart';
import 'package:flutter_ci/src/commands/init_command.dart';
import 'package:flutter_ci/src/commands/list_command.dart';
import 'package:flutter_ci/src/commands/release_command.dart';
import 'package:flutter_ci/src/exceptions.dart';
import 'package:flutter_ci/src/services/build_service.dart';
import 'package:flutter_ci/src/utils/logger.dart';
import 'package:flutter_ci/src/version.dart';

/// Exit code for invalid command-line usage (EX_USAGE).
const _usageExitCode = 64;

/// Runs the `flutter_ci` command line with [arguments] and returns the
/// process exit code: 0 on success, 1 on failure, 64 on invalid usage.
Future<int> runCli(List<String> arguments) async {
  try {
    return await _FlutterCiRunner().run(arguments) ?? 0;
  } on UsageException catch (e) {
    stderr
      ..writeln(e.message)
      ..writeln()
      ..writeln(e.usage);
    return _usageExitCode;
  } on FlutterCiException catch (e) {
    Logger.error(e.message);
    return 1;
  } catch (e, stackTrace) {
    Logger.error("An unexpected error occurred: $e");
    stderr.writeln(stackTrace);
    return 1;
  }
}

class _FlutterCiRunner extends CommandRunner<int> {
  _FlutterCiRunner()
      : super('flutter_ci',
            '🚀 FLUTTER CI - version, build and release automation for Flutter apps.') {
    argParser.addFlag('version',
        negatable: false, help: 'Print the flutter_ci version.');
    addCommand(_BuildCli());
    addCommand(_ReleaseCli());
    addCommand(_SimpleCli('bump', '📈 Bump the build number in pubspec.yaml.',
        () => BumpCommand().run()));
    addCommand(_DoctorCli());
    addCommand(_SimpleCli('init', '📝 Generate a default flutter_ci.yaml.',
        () => InitCommand().run()));
    addCommand(_SimpleCli('list', '📄 List previous builds in builds/.',
        () => ListCommand().run()));
    addCommand(_SimpleCli('clean-builds', '🧹 Delete the builds/ directory.',
        () => BuildService().cleanBuilds()));
    addCommand(_SimpleCli(
        'yaml-guide',
        '📜 Show the complete flutter_ci.yaml configuration guide.',
        () async => print(yamlGuide)));
    addCommand(_SimpleCli('version', '🔢 Show the flutter_ci version.',
        () async => print('flutter_ci version: $packageVersion')));
  }

  @override
  Future<int?> runCommand(ArgResults topLevelResults) async {
    if (topLevelResults['version'] == true) {
      print('flutter_ci version: $packageVersion');
      return 0;
    }
    return super.runCommand(topLevelResults);
  }
}

abstract class _BaseCli extends Command<int> {
  ArgResults get args => argResults!;

  void _rejectExtraArguments() {
    if (args.rest.isNotEmpty) {
      usageException('Unexpected arguments: ${args.rest.join(' ')}');
    }
  }

  /// The flag's value if it was passed explicitly, otherwise `null` so the
  /// value from flutter_ci.yaml (or the default) applies.
  bool? _explicitFlag(String name) =>
      args.wasParsed(name) ? args[name] as bool : null;
}

class _SimpleCli extends _BaseCli {
  _SimpleCli(this.name, this.description, this._action);

  @override
  final String name;

  @override
  final String description;

  final Future<void> Function() _action;

  @override
  Future<int> run() async {
    _rejectExtraArguments();
    await _action();
    return 0;
  }
}

class _DoctorCli extends _BaseCli {
  @override
  String get name => 'doctor';

  @override
  String get description => '🩺 Show environment diagnostics.';

  @override
  Future<int> run() async {
    _rejectExtraArguments();
    return await DoctorCommand().run() ? 0 : 1;
  }
}

void _addBuildOptions(ArgParser parser) {
  parser
    ..addOption('version',
        abbr: 'v', help: 'Set the version in pubspec.yaml, e.g. 1.2.0+5.')
    ..addFlag('bump',
        defaultsTo: null,
        help: 'Bump the build number (default). Use --no-bump to keep it.')
    ..addOption('platform',
        abbr: 'p',
        help: 'Target platform for the build (default: both).',
        allowed: BuildCommand.platforms)
    ..addOption('android-format',
        help: 'Android build format (default: apk).',
        allowed: BuildCommand.androidFormats)
    ..addOption('ios-method',
        help: 'iOS export method (default: ad-hoc).',
        allowed: BuildCommand.iosMethods)
    ..addOption('flavor', help: 'Build flavor (e.g. dev, staging, prod).')
    ..addFlag('parallel',
        defaultsTo: true, help: 'Build Android and iOS in parallel.')
    ..addFlag('coverage',
        defaultsTo: null, help: 'Run flutter test --coverage before building.')
    ..addMultiOption('define',
        abbr: 'd',
        help: 'Pass a --dart-define KEY=VALUE (repeatable; commas separate '
            'multiple values).')
    ..addOption('pre-build',
        help: 'Shell command to run instead of the default pre-build steps.')
    ..addOption('android-build-cmd',
        help: 'Shell command to run instead of flutter build apk/appbundle.')
    ..addOption('ios-build-cmd',
        help: 'Shell command to run instead of flutter build ipa.');
}

const _precedenceNote =
    'Command-line flags override flutter_ci.yaml, which overrides defaults.';

class _BuildCli extends _BaseCli {
  _BuildCli() {
    _addBuildOptions(argParser);
  }

  @override
  String get name => 'build';

  @override
  String get description =>
      '🚀 Bump the version, build Android/iOS and store artifacts in '
      'builds/.\n$_precedenceNote';

  @override
  Future<int> run() async {
    _rejectExtraArguments();
    await BuildCommand().run(
      version: args['version'] as String?,
      shouldBump: args['bump'] as bool?,
      platform: args['platform'] as String?,
      androidFormat: args['android-format'] as String?,
      iosMethod: args['ios-method'] as String?,
      preBuildCmd: args['pre-build'] as String?,
      androidBuildCmd: args['android-build-cmd'] as String?,
      iosBuildCmd: args['ios-build-cmd'] as String?,
      flavor: args['flavor'] as String?,
      parallel: args['parallel'] as bool,
      coverage: _explicitFlag('coverage'),
      defines: args['define'] as List<String>,
    );
    return 0;
  }
}

class _ReleaseCli extends _BaseCli {
  _ReleaseCli() {
    _addBuildOptions(argParser);
    argParser
      ..addFlag('notes', help: 'Generate release notes from git commits.')
      ..addFlag('changelog',
          help: 'Prepend release notes to CHANGELOG.md (implies --notes).')
      ..addFlag('commit', help: 'Commit pubspec.yaml (and CHANGELOG.md).')
      ..addFlag('tag', help: 'Create a v<version> git tag.')
      ..addFlag('upload',
          help: 'Upload to the targets enabled under distribution.')
      ..addFlag('app-store', help: 'Upload the IPA to App Store Connect.')
      ..addFlag('play-store', help: 'Upload to Google Play Console.');
  }

  @override
  String get name => 'release';

  @override
  String get description =>
      '📦 Full release: bump, build, commit, tag, upload and notify.\n'
      '$_precedenceNote';

  @override
  Future<int> run() async {
    _rejectExtraArguments();
    await ReleaseCommand().run(
      generateNotes: args['notes'] as bool,
      upload: _explicitFlag('upload'),
      commit: _explicitFlag('commit'),
      createTag: _explicitFlag('tag'),
      changelog: _explicitFlag('changelog'),
      appStore: args['app-store'] as bool,
      playStore: args['play-store'] as bool,
      version: args['version'] as String?,
      shouldBump: args['bump'] as bool?,
      platform: args['platform'] as String?,
      androidFormat: args['android-format'] as String?,
      iosMethod: args['ios-method'] as String?,
      preBuildCmd: args['pre-build'] as String?,
      androidBuildCmd: args['android-build-cmd'] as String?,
      iosBuildCmd: args['ios-build-cmd'] as String?,
      flavor: args['flavor'] as String?,
      parallel: args['parallel'] as bool,
      coverage: _explicitFlag('coverage'),
      defines: args['define'] as List<String>,
    );
    return 0;
  }
}

/// The text printed by `flutter_ci yaml-guide`.
const yamlGuide = r'''

📜 FLUTTER CI - YAML Configuration Guide
Create a 'flutter_ci.yaml' file in your project root.
Command-line flags override values in this file.
String values may use ${ENV_VAR} to read environment variables.

# ==========================================
# 🚀 FLUTTER CI GLOBAL CONFIGURATION
# ==========================================

# --- VERSIONING ---
version_bump: true # Auto-increment build number (e.g., 1.0.0+1 -> +2)
# manual_version: "2.0.0+1" # Explicitly force a specific version

# --- TARGETS ---
platform: both # Options: 'android', 'ios', or 'both' (iOS is skipped off macOS)
# flavor: prod

# --- ANDROID CONFIGURATION ---
android:
  format: apk # Options: 'apk' or 'aab'
  # build_command: flutter build apk --release # Replaces the default build

# --- IOS CONFIGURATION ---
ios:
  method: ad-hoc # 'ad-hoc', 'development', 'app-store', 'enterprise'
  # build_command: flutter build ipa --no-codesign # Replaces the default build

# --- TESTING & ENV ---
test:
  coverage: false # Run flutter test --coverage before building

env:
  # API_KEY: ${API_KEY} # Passed as --dart-define=API_KEY=<value>; values are never logged

# --- PRE-BUILD STEPS ---
pre_build: # Replaces the default 'flutter clean' + 'flutter pub get'
  - flutter clean
  - flutter pub get

# --- GIT INTEGRATION (Release only) ---
git:
  commit: false # Commit pubspec.yaml (and CHANGELOG.md) after a successful build
  tag: false    # Create a v<version> tag after a successful build
  changelog: false # Prepend release notes to CHANGELOG.md

# --- DISTRIBUTION / UPLOADS (Release only) ---
distribution:
  enabled: false # Same as --upload
  google_drive: # Requires the gdrive 3.x CLI
    enabled: false
    folder_id: "your-google-drive-folder-id-here"
  firebase: # Requires the firebase CLI; uploads the IPA for iOS app IDs
    enabled: false
    app_id: "1:1234567890:android:abcdef0123456789"
    testers: "qa-team, beta-testers"
  app_store: # Requires Xcode (xcrun altool)
    enabled: false
    username: ${APP_STORE_USERNAME}
    password: ${APP_STORE_PASSWORD} # App-specific password
  play_store: # Requires fastlane; prefers the AAB
    enabled: false
    package_name: "com.example.app"
    json_key_path: "path/to/play-store-key.json"
    # track: internal # fastlane defaults to 'production'

notifications:
  # slack: ${SLACK_WEBHOOK_URL}
  # discord: ${DISCORD_WEBHOOK_URL}
''';
