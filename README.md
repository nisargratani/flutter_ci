# flutter_ci

A powerful Flutter CLI tool designed for CI/CD automation. It simplifies the build process by handling version bumps, generating builds (APK/IPA), and organizing artifacts into structured, timestamped directories.

## Features

- 🚀 **Automatic Version Bump**: Increment your build number in `pubspec.yaml` with zero effort.
- 📦 **Multi-platform Build**: Supports generating release-ready Android APKs and iOS IPAs.
- 📁 **Structured Artifact Storage**: Automatically collects build outputs into organized, timestamped folders.
- 🛠️ **Fully Configurable**: Easily override versions, skip bumps, or define custom build and pre-build shell commands.
- 💻 **Programmatic API**: Use the provided services and commands directly in your own Dart scripts.

## Installation

Activate the tool globally from your terminal:

```bash
# To install from pub.dev (once published)
dart pub global activate flutter_ci

# To install from local source
dart pub global activate --source path .
```

## Usage

### Build Command

The `build` command handles the complete lifecycle: cleaning, fetching dependencies, bumping the version, running the build, and storing artifacts.

```bash
flutter_ci build
```

**Customizing the Build:**

| Option | Description | Example |
|---|---|---|
| `--version`, `-v` | Manually set the version | `flutter_ci build -v 1.2.0+10` |
| `--no-bump` | Skip the automatic build number increment | `flutter_ci build --no-bump` |
| `--build-cmd` | Use a custom shell command for the build | `flutter_ci build --build-cmd "flutter build ipa --no-codesign"` |
| `--pre-build` | Define custom commands to run before building | `flutter_ci build --pre-build "flutter test && dart run build_runner build"` |

### Bump Command

Increment only the build number in your `pubspec.yaml`.

```bash
flutter_ci bump
```

## Programmatic Usage

You can also use the package programmatically in your Dart scripts:

```dart
import 'package:flutter_ci/flutter_ci.dart';

void main() async {
  final buildCommand = BuildCommand();
  await buildCommand.run(shouldBump: true);
}
```

## Artifacts Location

All generated artifacts are stored in:
`builds/YYYY-MM-DD_HHMM/`

## Contributing

Issues and PRs are welcome! Feel free to contribute to making Flutter CI/CD even smoother.
