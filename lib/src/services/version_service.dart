import 'dart:io';
import 'package:flutter_ci/src/utils/logger.dart';
import 'package:yaml/yaml.dart';
import 'package:yaml_edit/yaml_edit.dart';

/// A service responsible for managing version numbers in `pubspec.yaml`.
class VersionService {
  /// Increments the build number (the part after `+`) in `pubspec.yaml`.
  void bumpBuildNumber() {
    final file = File('pubspec.yaml');

    if (!file.existsSync()) {
      throw Exception("pubspec.yaml not found");
    }

    final content = file.readAsStringSync();
    final yaml = loadYaml(content);

    final editor = YamlEditor(content);

    String version = yaml['version'];

    int build = 0;
    String versionBase = version;

    if (version.contains('+')) {
      final parts = version.split('+');
      versionBase = parts[0];
      build = int.parse(parts[1]);
    }

    build++;

    final newVersion = "$versionBase+$build";

    editor.update(['version'], newVersion);

    file.writeAsStringSync(editor.toString());

    Logger.success("Version updated → $newVersion");
  }

  /// Updates the version string in `pubspec.yaml` to the specified [newVersion].
  void updateVersion(String newVersion) {
    final file = File('pubspec.yaml');

    if (!file.existsSync()) {
      throw Exception("pubspec.yaml not found");
    }

    final content = file.readAsStringSync();
    final editor = YamlEditor(content);

    editor.update(['version'], newVersion);

    file.writeAsStringSync(editor.toString());

    Logger.success("Version set to → $newVersion");
  }

  /// Retrieves the current version string from `pubspec.yaml`.
  String getVersion() {
    final file = File('pubspec.yaml');
    if (!file.existsSync()) throw Exception("pubspec.yaml not found");
    final yaml = loadYaml(file.readAsStringSync());
    return yaml['version'];
  }

  /// Retrieves the version name (major.minor.patch) from `pubspec.yaml`.
  String getVersionName() {
    final version = getVersion();
    if (version.contains('+')) {
      return version.split('+')[0];
    }
    return version;
  }

  /// Retrieves the build number from `pubspec.yaml`.
  int getBuildNumber() {
    final version = getVersion();
    if (version.contains('+')) {
      return int.tryParse(version.split('+')[1]) ?? 0;
    }
    return 0;
  }

  /// Retrieves the application name from `pubspec.yaml`.
  String getAppName() {
    final file = File('pubspec.yaml');
    if (!file.existsSync()) throw Exception("pubspec.yaml not found");
    final yaml = loadYaml(file.readAsStringSync());
    return yaml['name'];
  }
}
