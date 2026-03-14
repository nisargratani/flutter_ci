# flutter_ci

A powerful Flutter CLI tool designed for CI/CD automation. It simplifies the build process by handling version bumps, generating parallel builds (APK/IPA), and organizing artifacts into versioned directories with full git integration.

## Features

- 🚀 **Automatic Version Bump**: Increment your build number in `pubspec.yaml` with zero effort.
- ⚙️ **Config File Support**: Use `flutter_ci.yaml` to define project-wide settings and build pipelines.
- 🏗️ **Parallel Build Generation**: Build Android and iOS concurrently for faster CI cycles.
- 📁 **Versioned Artifact Storage**: Automatically collects build outputs into `builds/v[version]/` folders.
- 📄 **Build Metadata**: Generates `build_info.json` with version, time, git commit, and environment details.
- 🔗 **Git Integration**: Automated commits and tagging for release builds.
- 📦 **Distribution Framework**: Infrastructure for uploading to Firebase App Distribution and Google Drive.
- 📝 **Release Notes**: Automatically generate release notes from your recent git commits.

## Installation

Activate the tool globally from your terminal:

```bash
dart pub global activate flutter_ci
```

## Quick Start

```bash
# 1. Create a config file (optional but recommended)
# flutter_ci.yaml

# 2. Run a build (uses config or defaults)
flutter_ci build

# 3. Perform a full release
flutter_ci release --notes --upload
```

## Configuration (`flutter_ci.yaml`)

You can define your build process in a `flutter_ci.yaml` file at the root of your project:

```yaml
version_bump: true
manual_version: null # e.g. "2.0.0+1" Override version directly
platform: both # android, ios, or both

android:
  format: apk
  build_command: flutter build apk --release

ios:
  method: ad-hoc
  build_command: flutter build ipa --no-codesign

git:
  commit: false # Auto-commit pubspec.yaml on release
  tag: false    # Auto-tag on release
  changelog: false # Auto-append release notes to CHANGELOG.md

test:
  coverage: false # Run `flutter test --coverage` before building

# Pass custom --dart-define environment variables
env:
  # API_KEY: "secret123"
  # ENVIRONMENT: "prod"

pre_build:
  - flutter clean
  - flutter pub get

distribution:
  enabled: true
  firebase:
    enabled: true
    app_id: "your-app-id"
    testers: "beta-testers"
  google_drive:
    enabled: false
    folder_id: "your-folder-id"
  app_store:
    enabled: false
    username: "your-apple-id"
    password: "app-specific-password"
  play_store:
    enabled: false
    package_name: "com.example.app"
    json_key_path: "path/to/play-store-key.json"

notifications:
  # Webhook URLs for post-release alerts
  # slack: "https://hooks.slack.com/services/..."
  # discord: "https://discord.com/api/webhooks/..."
```

## Usage

### CLI Commands

#### `build`
Handles the build lifecycle: versioning, pre-build steps, and parallel artifact generation.

```bash
flutter_ci build [options]
```
- `--version, -v`: Override version.
- `--no-bump`: Skip version increment.
- `--platform, -p`: Target platform (android, ios, both).
- `--parallel`: Run Android/iOS builds concurrently (default: true).
- `--coverage`: Run tests with coverage generation before building.
- `--define, -d`: Pass custom dart-defines (e.g. `-d API_KEY=123`).

#### `release`
The ultimate command for production readiness.
- Bumps version.
- Commits `pubspec.yaml` change.
- Tags the git repository.
- Generates release notes from git logs.
- Appends to `CHANGELOG.md`.
- Builds artifacts with testing/coverage rules.
- Uploads to distributed platforms (Firebase, Drive, Play Store, App Store).
- Fires webhooks to Slack/Discord.

```bash
flutter_ci release [options]
```
- `--notes`: Generate notes from git commits.
- `--changelog`: Append generation to CHANGELOG.md.
- `--upload`: Trigger distribution uploads (Drive, Firebase).
- `--app-store`: Trigger upload to Apple App Store Connect.
- `--play-store`: Trigger upload to Google Play Console.
- `--commit`: Auto-commit pubspec bump.
- `--tag`: Auto-tag git repository.

#### `bump`
Increment only the build number in your `pubspec.yaml`.

#### `clean-builds`
Delete the `build/` directory to start fresh.

## Artifacts Structure

Outputs are organized logically:
```text
builds/
  v1.0.0+5/
    app-release.apk
    app-release.ipa
    build_info.json  <-- Metadata (commit, time, etc.)
```

## Contributing

Issues and PRs are welcome! Feel free to contribute to making Flutter CI/CD even smoother.
