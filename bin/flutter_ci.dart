import 'package:args/args.dart';
import 'package:flutter_ci/src/commands/build_command.dart';
import 'package:flutter_ci/src/commands/bump_command.dart';
import 'package:flutter_ci/src/services/build_service.dart';
import 'package:flutter_ci/src/utils/logger.dart';

void main(List<String> arguments) async {
  final parser = ArgParser();

  // Build Command
  final buildParser = parser.addCommand('build');
  buildParser.addOption('version',
      abbr: 'v', help: 'Override the version in pubspec.yaml');
  buildParser.addFlag('bump',
      defaultsTo: true,
      negatable: true,
      help: 'Automatically bump build number');
  buildParser.addOption('platform',
      abbr: 'p',
      help: 'Target platform for the build',
      allowed: ['android', 'ios', 'both'],
      defaultsTo: 'both');
  buildParser.addOption('android-format',
      help: 'Android build format', allowed: ['apk', 'aab'], defaultsTo: 'apk');
  buildParser.addOption('ios-method',
      help: 'iOS export method',
      allowed: ['ad-hoc', 'development', 'app-store', 'enterprise'],
      defaultsTo: 'ad-hoc');
  buildParser.addOption('android-build-cmd',
      help: 'Custom Android build command');
  buildParser.addOption('ios-build-cmd', help: 'Custom iOS build command');
  buildParser.addOption('pre-build',
      help:
          'Custom pre-build commands (e.g., "flutter clean && flutter pub get")');

  // Bump Command
  parser.addCommand('bump');

  // Version Command
  parser.addCommand('version');

  // Clean Builds Command
  parser.addCommand('clean-builds');

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
          androidBuildCmd: cmdResult['android-build-cmd'],
          iosBuildCmd: cmdResult['ios-build-cmd'],
          preBuildCmd: cmdResult['pre-build'],
          platform: cmdResult['platform'],
          androidFormat: cmdResult['android-format'],
          iosMethod: cmdResult['ios-method'],
        );
        break;

      case 'bump':
        await BumpCommand().run();
        break;

      case 'version':
        print("flutter_ci version: 0.0.1");
        break;

      case 'clean-builds':
        await BuildService().cleanBuilds();
        break;

      default:
        Logger.error("Unknown command: ${result.command!.name}");
        _printUsage(parser);
    }
  } on ArgParserException catch (e) {
    Logger.error("Argument Error: ${e.message}");
    print(
        "\nTip: If your command contains flags (e.g., --delete-conflicting-outputs), ensure the entire command is enclosed in double quotes.");
    print(
        "Example: --pre-build \"flutter pub run build_runner build --delete-conflicting-outputs\"\n");
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
  print("  build            🚀 Start CI build process");
  print("    Options:");
  print("      --version, -v    Override version (e.g., 1.0.0+5)");
  print("      --no-bump        Skip version bump");
  print("      --platform, -p   Target platform (android, ios, both)");
  print("      --pre-build      Custom pre-build commands");
  print("      --android-format Android build format (apk, aab)");
  print("      --ios-method     iOS export method (ad-hoc, development, app-store, enterprise)");
  print("      --android-build-cmd  Custom Android build command");
  print("      --ios-build-cmd      Custom iOS build command\n");
  print("  clean-builds     🧹 Delete the build/ directory");
  print("  bump             📈 Bump version in pubspec.yaml");
  print("  version          🔢 Show current version");
  print("  help             ❓ Show this help message\n");
}
