# flutter_ci

[![pub version](https://img.shields.io/pub/v/flutter_ci.svg)](https://pub.dev/packages/flutter_ci)
[![pub points](https://img.shields.io/pub/points/flutter_ci)](https://pub.dev/packages/flutter_ci/score)
[![likes](https://img.shields.io/pub/likes/flutter_ci)](https://pub.dev/packages/flutter_ci/score)

A command-line tool that automates the repetitive parts of building and releasing a Flutter app:

- 📈 **Versioning**: bumps the build number in `pubspec.yaml` (comments and formatting are preserved), or sets an explicit version.
- 🏗️ **Builds**: runs `flutter build apk`/`appbundle`/`ipa`, building Android and iOS in parallel.
- 📁 **Artifacts**: copies outputs into `builds/v<version>/` with a `build.log` and `build_info.json`.
- 🔗 **Releases**: commits the version bump, tags `v<version>`, and writes release notes to `CHANGELOG.md`.
- 📦 **Distribution**: uploads to Firebase App Distribution, Google Drive, App Store Connect and Google Play.
- 🔔 **Notifications**: posts to Slack or Discord webhooks.
- ⚙️ **Configuration**: reads a `flutter_ci.yaml` in your project, with `${ENV_VAR}` substitution for secrets.

It fails loudly: any failed step exits with a non-zero code, so your CI pipeline goes red instead of shipping a half-built release.

## Requirements

- Dart SDK 3.5 or later (bundled with Flutter 3.24 and later).
- Flutter on your `PATH`.
- iOS builds require macOS with Xcode. On Linux and Windows, `platform: both` builds Android only and prints a warning.

## Installation

Install it globally:

```bash
dart pub global activate flutter_ci
```

Make sure `~/.pub-cache/bin` is on your `PATH` (pub prints a warning if it isn't).

Alternatively, pin it per project as a dev dependency:

```bash
flutter pub add dev:flutter_ci
dart run flutter_ci build
```

## Quick start

Run these from the root of your Flutter project:

```bash
flutter_ci init                  # create flutter_ci.yaml
flutter_ci doctor                # check Flutter, Dart, Git, Xcode, ...
flutter_ci build -p android      # bump build number, build APK, store it in builds/
flutter_ci release --notes --tag # build, then tag and generate release notes
```

## Commands

| Command | What it does |
| --- | --- |
| `build` | Sets or bumps the version, runs pre-build steps, builds, stores artifacts. |
| `release` | Everything `build` does, plus changelog, commit, tag, uploads and notifications. |
| `bump` | Increments the build number in `pubspec.yaml` (`1.2.0+4` → `1.2.0+5`). |
| `init` | Writes a starter `flutter_ci.yaml`. Never overwrites an existing file. |
| `doctor` | Checks for Flutter, Dart and Git (required) and the Android SDK, Xcode and Firebase CLI (optional). |
| `list` | Lists the folders in `builds/`, newest version first. |
| `clean-builds` | Deletes the `builds/` directory. |
| `yaml-guide` | Prints a fully commented `flutter_ci.yaml`. |
| `version` | Prints the flutter_ci version (same as `--version`). |

Run `flutter_ci help <command>` or `flutter_ci <command> --help` for every option.

### `build` options

| Option | Description |
| --- | --- |
| `-v, --version <x.y.z[+n]>` | Set the version in `pubspec.yaml` instead of bumping. |
| `--[no-]bump` | Bump the build number (default: on). |
| `-p, --platform <android\|ios\|both>` | Platforms to build (default: `both`). |
| `--android-format <apk\|aab>` | Android output (default: `apk`). |
| `--ios-method <ad-hoc\|development\|app-store\|enterprise>` | IPA export method (default: `ad-hoc`). |
| `--flavor <name>` | Passed to `flutter build --flavor`. |
| `--[no-]parallel` | Build Android and iOS at the same time (default: on). |
| `--[no-]coverage` | Run `flutter test --coverage` first. A failing test stops the build. |
| `-d, --define KEY=VALUE` | Add a `--dart-define`. Repeat the flag for several values. Commas also separate values, so use `flutter_ci.yaml` `env` for values that contain commas. |
| `--pre-build <cmd>` | Shell command that replaces the default pre-build steps. |
| `--android-build-cmd <cmd>` | Shell command that replaces `flutter build apk/appbundle`. |
| `--ios-build-cmd <cmd>` | Shell command that replaces `flutter build ipa`. |

The build runs these steps in order:

1. Set the version (`--version`) or bump the build number.
2. Run `flutter test --coverage` if coverage is enabled.
3. Run the pre-build steps: `--pre-build`, else `pre_build` from the YAML, else `flutter clean` and `flutter pub get`.
4. Build each platform with `--build-name`, `--build-number`, `--flavor` and your dart-defines. Custom build commands get the dart-defines appended. They should read the version from `pubspec.yaml`, which Flutter does by default.
5. Copy the fresh artifacts to `builds/v<version>/`.

If one platform fails, the other still finishes and its artifacts are stored. The command then exits with code 1.

### `release` options

`release` accepts every `build` option, plus:

| Option | Description |
| --- | --- |
| `--notes` | Generate release notes from the commits since the last git tag (or the last 10 commits if there are no tags). |
| `--[no-]changelog` | Prepend the notes to `CHANGELOG.md`. Implies `--notes`. |
| `--[no-]commit` | Commit `pubspec.yaml` (and `CHANGELOG.md`). Other staged files are left alone. |
| `--[no-]tag` | Create a `v<version>` tag. |
| `--[no-]upload` | Upload to every target enabled under `distribution`. |
| `--app-store` | Upload the IPA to App Store Connect, even without `--upload`. |
| `--play-store` | Upload to Google Play, even without `--upload`. |

The release runs these steps in order:

1. Set or bump the version.
2. Generate notes and update `CHANGELOG.md`.
3. Build. **If the build fails, the release stops here**: nothing is committed, tagged or uploaded.
4. Commit and tag.
5. Upload.
6. Send notifications.

Uploads and notifications are all attempted. If any of them fails, the release exits with code 1 and lists what failed.

## Configuration (`flutter_ci.yaml`)

Settings come from three places, highest priority first:

1. **Command-line flags**
2. **`flutter_ci.yaml`** in the project root
3. **Built-in defaults**

So with `platform: both` in the YAML, `flutter_ci build -p android` builds Android only. `flutter_ci yaml-guide` prints the full reference. Here is a complete example:

```yaml
version_bump: true
# manual_version: "2.0.0+1"   # set an exact version instead of bumping
platform: both                # android, ios or both
# flavor: prod

android:
  format: aab                 # apk or aab
  # build_command: flutter build appbundle --release

ios:
  method: app-store           # ad-hoc, development, app-store or enterprise
  # build_command: flutter build ipa --export-options-plist=ios/ExportOptions.plist

test:
  coverage: false

env:                          # passed as --dart-define; values are never logged
  API_URL: https://api.example.com
  API_KEY: ${API_KEY}

pre_build:                    # replaces the default clean + pub get
  - flutter clean
  - flutter pub get
  - dart run build_runner build --delete-conflicting-outputs

git:
  commit: true
  tag: true
  changelog: true

distribution:
  enabled: true               # same as --upload
  firebase:
    enabled: true
    app_id: "1:1234567890:android:abcdef0123456789"
    testers: "qa-team, beta-testers"
  google_drive:
    enabled: false
    folder_id: "your-folder-id"
  app_store:
    enabled: false
    username: ${APP_STORE_USERNAME}
    password: ${APP_STORE_PASSWORD}   # app-specific password
  play_store:
    enabled: false
    package_name: com.example.app
    json_key_path: ${PLAY_STORE_KEY_PATH}
    track: internal                   # fastlane's default is production

notifications:
  slack: ${SLACK_WEBHOOK_URL}
  # discord: ${DISCORD_WEBHOOK_URL}
```

Invalid YAML, unknown `platform`/`format`/`method` values, and wrongly typed values (such as `version_bump: "yes"`) stop the build with an error pointing at the problem. They never silently fall back to defaults.

### Secrets

- Write `${NAME}` in any string value to read the environment variable `NAME` when the file is loaded. If the variable is unset, the text is left as-is and a warning names the variable.
- Dart-define values are shown as `***` in the console and in `build.log`. Only their keys are printed.
- The App Store password is passed to `altool` through an environment variable, never on the command line.
- Webhook URLs are never printed.

Keep secrets in your CI's secret store and reference them with `${...}` rather than committing them.

## Artifacts

```text
builds/
  v1.2.0+45/
    my_app-1.2.0+45.apk    # <pubspec name>-<version>.<ext>
    my_app-1.2.0+45.ipa
    build.log              # every command and its full output, including failures
    build_info.json        # app name, version, time, git commit, Flutter version, artifact list
```

flutter_ci collects APKs from `build/app/outputs/flutter-apk/`, AABs from `build/app/outputs/bundle/` (flavor folders included), and IPAs from `build/ios/ipa/`. Only files produced during the current run are collected, so stale outputs from earlier builds are ignored. If a run produces several files of one type, such as `--split-per-abi` APKs, each keeps its original name as a suffix: `my_app-1.2.0+45-app-arm64-v8a-release.apk`.

Add `builds/` to your `.gitignore`.

## Distribution requirements

Uploads use the official tools, which must be installed and authenticated on the build machine:

| Target | Tool | Artifact |
| --- | --- | --- |
| Firebase App Distribution | [`firebase` CLI](https://firebase.google.com/docs/cli) | IPA for iOS app IDs (`…:ios:…`), otherwise APK (or AAB) |
| Google Drive | [`gdrive` 3.x](https://github.com/glotlabs/gdrive) | every artifact |
| App Store Connect | Xcode (`xcrun altool`) | IPA |
| Google Play | [fastlane](https://fastlane.tools) `supply` | AAB (or APK) |

Slack and Discord webhooks need no extra tools.

## Exit codes

| Code | Meaning |
| --- | --- |
| `0` | Success |
| `1` | A step failed: build, test, git, upload, invalid config, missing `pubspec.yaml`, ... |
| `64` | Invalid command-line usage |

## GitHub Actions example

```yaml
name: Build

on:
  push:
    branches: [main]

jobs:
  build:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4

      - uses: subosito/flutter-action@v2
        with:
          channel: stable

      - name: Install flutter_ci
        run: |
          dart pub global activate flutter_ci
          echo "$HOME/.pub-cache/bin" >> "$GITHUB_PATH"

      - name: Build
        run: flutter_ci build --no-bump
        env:
          API_KEY: ${{ secrets.API_KEY }}

      - uses: actions/upload-artifact@v4
        with:
          name: builds
          path: builds/
```

## Using it from Dart code

The commands and services are also available as a library:

```dart
import 'package:flutter_ci/flutter_ci.dart';

Future<void> main() async {
  try {
    await BuildCommand().run(platform: 'android', shouldBump: false);
    print('Built ${VersionService().getVersion()}');
  } on FlutterCiException catch (e) {
    print('Build failed: ${e.message}');
  }
}
```

Every operation works on the project in the current directory and throws a `FlutterCiException` on failure. The exception is uploads and webhooks in `DistributionService`, which return `false`.

## Upgrading from 0.0.2 or earlier

Version 0.0.3 fixes several behaviors that hid failures. If you relied on them:

- **Exit codes**: failed builds, tests, pre-build steps, git operations, uploads and invalid arguments now exit non-zero. Previously flutter_ci always exited 0.
- **Precedence**: command-line flags now override `flutter_ci.yaml`. Previously the YAML won, so `--platform` and `--no-bump` were ignored whenever the file set them.
- **Invalid config**: invalid or wrongly typed `flutter_ci.yaml` content is now an error instead of being silently ignored.
- **Release order**: `release` now builds before committing and tagging, so a failed build no longer leaves a tag behind.
- **Library API**: `GitService.commitChanges`/`createTag` throw on failure, and the upload methods return `bool`.
- **Google Drive**: uploads now use the `gdrive` 3.x syntax (`gdrive files upload`).

See the [changelog](CHANGELOG.md) for the full list.

## Contributing

Issues and pull requests are welcome at [github.com/nisargratani/flutter_ci](https://github.com/nisargratani/flutter_ci). Please run `dart format .`, `dart analyze` and `dart test` before opening a PR.
