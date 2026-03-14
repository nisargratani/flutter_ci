import 'package:args/args.dart';
import 'package:flutter_ci/src/commands/build_command.dart';
import 'package:flutter_ci/src/commands/bump_command.dart';
import 'package:flutter_ci/src/commands/release_command.dart';
import 'package:flutter_ci/src/commands/doctor_command.dart';
import 'package:flutter_ci/src/commands/init_command.dart';
import 'package:flutter_ci/src/commands/list_command.dart';
import 'package:flutter_ci/src/services/build_service.dart';
import 'package:flutter_ci/src/utils/logger.dart';

void main(List<String> arguments) async {
  final parser = ArgParser();

  // Build Command
  final buildParser = parser.addCommand('build');
  buildParser.addOption('version',
      abbr: 'v', help: 'Override the version in pubspec.yaml');
  buildParser.addFlag('bump',
      defaultsTo: null, // Allow null to detect if user provided it
      negatable: true,
      help: 'Automatically bump build number');
  buildParser.addOption('platform',
      abbr: 'p',
      help: 'Target platform for the build',
      allowed: ['android', 'ios', 'both']);
  buildParser.addOption('android-format',
      help: 'Android build format', allowed: ['apk', 'aab']);
  buildParser.addOption('ios-method',
      help: 'iOS export method',
      allowed: ['ad-hoc', 'development', 'app-store', 'enterprise']);
  buildParser.addOption('flavor',
      help: 'Build flavor (e.g. dev, staging, prod)');
  buildParser.addFlag('parallel',
      defaultsTo: true, help: 'Run builds in parallel');
  buildParser.addFlag('coverage',
      help: 'Run flutter test --coverage before building', defaultsTo: false);
  buildParser.addMultiOption('define',
      abbr: 'd', help: 'Pass --dart-define environment variables');

  // Release Command
  final releaseParser = parser.addCommand('release');
  releaseParser.addFlag('notes',
      help: 'Generate release notes from git commits');
  releaseParser.addFlag('upload', help: 'Trigger distribution uploads');
  releaseParser.addFlag('commit',
      help: 'Commit the updated pubspec.yaml', defaultsTo: false);
  releaseParser.addFlag('tag',
      help: 'Create a git tag for the new version', defaultsTo: false);
  releaseParser.addFlag('changelog',
      help: 'Append release notes to CHANGELOG.md', defaultsTo: false);
  releaseParser.addFlag('app-store',
      help: 'Upload to Apple App Store Connect', defaultsTo: false);
  releaseParser.addFlag('play-store',
      help: 'Upload to Google Play Console', defaultsTo: false);

  // Bump Command
  parser.addCommand('bump');

  // Doctor Command
  parser.addCommand('doctor');

  // Init Command
  parser.addCommand('init');

  // List Command
  parser.addCommand('list');

  // Version Command
  parser.addCommand('version');

  // Clean Builds Command
  parser.addCommand('clean-builds');

  // YAML Guide Command
  parser.addCommand('yaml-guide');

  // Help Command
  parser.addCommand('help');

  try {
    final result = parser.parse(arguments);

    if (result.command == null || result.command!.name == 'help') {
      _printUsage(parser);
      return;
    }

    switch (result.command!.name) {
      case 'build':
        final cmdResult = result.command!;
        await BuildCommand().run(
          version: cmdResult['version'],
          shouldBump: cmdResult['bump'],
          platform: cmdResult['platform'],
          androidFormat: cmdResult['android-format'],
          iosMethod: cmdResult['ios-method'],
          flavor: cmdResult['flavor'],
          parallel: cmdResult['parallel'],
          coverage: cmdResult['coverage'],
          defines: cmdResult['define'] as List<String>?,
        );
        break;

      case 'release':
        final cmdResult = result.command!;
        await ReleaseCommand().run(
          generateNotes: cmdResult['notes'],
          upload: cmdResult['upload'],
          commit: cmdResult['commit'],
          createTag: cmdResult['tag'],
          changelog: cmdResult['changelog'],
          appStore: cmdResult['app-store'],
          playStore: cmdResult['play-store'],
        );
        break;

      case 'bump':
        await BumpCommand().run();
        break;

      case 'doctor':
        await DoctorCommand().run();
        break;

      case 'init':
        await InitCommand().run();
        break;

      case 'list':
        await ListCommand().run();
        break;

      case 'version':
        print("flutter_ci version: 0.0.2");
        break;

      case 'clean-builds':
        await BuildService().cleanBuilds();
        break;

      case 'yaml-guide':
        _printYamlGuide();
        break;

      default:
        Logger.error("Unknown command: ${result.command!.name}");
        _printUsage(parser);
    }
  } on ArgParserException catch (e) {
    Logger.error("Argument Error: ${e.message}");
    _printUsage(parser);
  } catch (e) {
    Logger.error("An unexpected error occurred: $e");
    _printUsage(parser);
  }
}

void _printUsage(ArgParser parser) {
  print("\n🚀 FLUTTER CI - Command Line Interface\n");
  print("Usage: flutter_ci <command> [arguments]\n");
  print("Available commands:");
  print(
      "  build            🚀 Start CI build process (supports flutter_ci.yaml)");
  print("    Options:");
  print("      --coverage   Run tests with coverage");
  print("      -d, --define Pass --dart-define vars");
  print(
      "  release          📦 Full release cycle (bump, tag, build, distribute)");
  print("    Options:");
  print("      --notes      Generate release notes from git");
  print("      --changelog  Append release notes to CHANGELOG.md");
  print("      --upload     Upload to configured platforms");
  print("      --app-store  Upload to App Store Connect");
  print("      --play-store Upload to Google Play Console");
  print("      --commit     Commit the bumped pubspec.yaml");
  print("      --tag        Create a git version tag\n");
  print("  clean-builds     🧹 Delete the build/ directory");
  print("  bump             📈 Bump version in pubspec.yaml");
  print("  doctor           🩺 Show environment diagnostics");
  print("  init             📝 Generate default flutter_ci.yaml config");
  print("  list             📄 List previous builds");
  print("  yaml-guide       📜 Show complete flutter_ci.yaml config guide");
  print("  version          🔢 Show current version");
  print("  help             ❓ Show this help message\n");
}

void _printYamlGuide() {
  print("\n📜 FLUTTER CI - YAML Configuration Guide");
  print("Create a 'flutter_ci.yaml' file in your project root:\n");
  print('''
# ==========================================
# 🚀 FLUTTER CI GLOBAL CONFIGURATION
# ==========================================

# --- VERSIONING ---
version_bump: true # Auto-increment build number (e.g., 1.0.0+1 -> +2)
# manual_version: "2.0.0+1" # Explicitly force a specific version

# --- TARGETS ---
platform: both # Options: 'android', 'ios', or 'both'

# --- ANDROID CONFIGURATION ---
android:
  format: apk # Options: 'apk' or 'aab'
  build_command: flutter build apk --release

# --- IOS CONFIGURATION ---
ios:
  method: ad-hoc # 'ad-hoc', 'development', 'app-store', 'enterprise'
  build_command: flutter build ipa --no-codesign

# --- TESTING & ENV ---
test:
  coverage: false # Run flutter test --coverage before building

env:
  # API_KEY: "secret123" # Passed as --dart-define=API_KEY=secret123

# --- PRE-BUILD STEPS ---
pre_build:
  - flutter clean
  - flutter pub get

# --- GIT INTEGRATION (Release only) ---
git:
  commit: false # Auto-commit pubspec.yaml on release
  tag: false    # Auto-tag on release
  changelog: false # Auto-append release notes to CHANGELOG.md

# --- DISTRIBUTION / UPLOADS ---
distribution:
  enabled: false
  google_drive:
    enabled: false
    folder_id: "your-google-drive-folder-id-here"
  firebase:
    enabled: false
    app_id: "1:1234567890:android:abcdef0123456789"
    testers: "qa-team, beta-testers"
  app_store:
    enabled: false
    username: "your-apple-id"
    password: "app-specific-password"
  play_store:
    enabled: false
    package_name: "com.example.app"
    json_key_path: "path/to/play-store-key.json"

notifications:
  # slack: "https://hooks.slack.com/services/..."
  # discord: "https://discord.com/api/webhooks/..."
''');
}
