import 'package:args/args.dart';
import 'package:flutter_ci/src/commands/build_command.dart';
import 'package:flutter_ci/src/commands/bump_command.dart';

void main(List<String> arguments) async {
  final parser = ArgParser();

  final buildParser = parser.addCommand('build');
  buildParser.addOption('version',
      abbr: 'v', help: 'Override the version in pubspec.yaml');
  buildParser.addFlag('bump',
      defaultsTo: true,
      negatable: true,
      help: 'Automatically bump build number');
  buildParser.addOption('build-cmd',
      help: 'Custom build command (default: flutter build apk)');
  buildParser.addOption('pre-build',
      help:
          'Custom pre-build commands (e.g., "flutter clean && flutter pub get")');

  parser.addCommand('bump');
  parser.addCommand('version');

  try {
    final result = parser.parse(arguments);

    if (result.command == null) {
      _printUsage(parser);
      return;
    }

    switch (result.command!.name) {
      case 'build':
        final cmdResult = result.command!;
        await BuildCommand().run(
          version: cmdResult['version'],
          shouldBump: cmdResult['bump'],
          buildCmd: cmdResult['build-cmd'],
          preBuildCmd: cmdResult['pre-build'],
        );
        break;

      case 'bump':
        await BumpCommand().run();
        break;

      case 'version':
        print("flutter_ci version: 0.0.1");
        break;

      default:
        print("Unknown command");
    }
  } on ArgParserException catch (e) {
    print("Argument Error: ${e.message}");
    print(
        "\nTip: If your command contains flags (e.g., --delete-conflicting-outputs), ensure the entire command is enclosed in double quotes.");
    print(
        "Example: --pre-build \"flutter pub run build_runner build --delete-conflicting-outputs\"\n");
    _printUsage(parser);
  } catch (e) {
    print("Error: $e");
    _printUsage(parser);
  }
}

void _printUsage(ArgParser parser) {
  print("Available commands:");
  print("  build     Start CI build process");
  print("    --version, -v    Override version (e.g., 1.0.0+5)");
  print("    --no-bump        Skip version bump");
  print("    --build-cmd      Custom build command");
  print("    --pre-build      Custom pre-build commands");
  print("  bump      Bump version in pubspec.yaml");
  print("  version   Show current version");
}
