import 'dart:io';
import 'package:flutter_ci/src/exceptions.dart';
import 'package:flutter_ci/src/utils/logger.dart';
import 'package:yaml/yaml.dart';
import 'package:yaml_edit/yaml_edit.dart';

/// Matches a Flutter app version: `major.minor.patch`, an optional
/// pre-release suffix and an optional integer build number,
/// e.g. `1.2.3`, `1.2.3+45` or `2.0.0-beta.1+7`.
final _versionPattern = RegExp(r'^\d+\.\d+\.\d+(-[0-9A-Za-z.-]+)?(\+\d+)?$');

/// A service responsible for managing version numbers in `pubspec.yaml`.
///
/// All methods operate on `pubspec.yaml` in the current directory and throw
/// a [FlutterCiException] if it is missing or has no usable `version`.
class VersionService {
  /// Increments the build number (the part after `+`) in `pubspec.yaml`.
  ///
  /// A version without a build number, such as `1.2.0`, becomes `1.2.0+1`.
  /// Comments and formatting in `pubspec.yaml` are preserved.
  void bumpBuildNumber() {
    final file = _pubspec();
    final content = file.readAsStringSync();
    final version = _readVersion(content);

    int build = 0;
    String versionBase = version;

    if (version.contains('+')) {
      final parts = version.split('+');
      versionBase = parts[0];
      final parsed = int.tryParse(parts[1]);
      if (parsed == null) {
        throw FlutterCiException(
            "Cannot bump build number: '${parts[1]}' in version '$version' "
            'is not an integer.');
      }
      build = parsed;
    }

    build++;

    final newVersion = "$versionBase+$build";
    _write(file, content, newVersion);

    Logger.success("Version updated → $newVersion");
  }

  /// Updates the version string in `pubspec.yaml` to the specified [newVersion].
  ///
  /// Throws a [FlutterCiException] if [newVersion] is not of the form
  /// `major.minor.patch[-prerelease][+build]` with an integer build number.
  void updateVersion(String newVersion) {
    if (!_versionPattern.hasMatch(newVersion)) {
      throw FlutterCiException(
          "Invalid version '$newVersion'. Expected major.minor.patch with an "
          'optional integer build number, e.g. 1.2.0 or 1.2.0+5.');
    }

    final file = _pubspec();
    final content = file.readAsStringSync();
    _write(file, content, newVersion);

    Logger.success("Version set to → $newVersion");
  }

  /// Retrieves the current version string from `pubspec.yaml`.
  String getVersion() => _readVersion(_pubspec().readAsStringSync());

  /// Retrieves the version name (major.minor.patch) from `pubspec.yaml`.
  String getVersionName() {
    final version = getVersion();
    if (version.contains('+')) {
      return version.split('+')[0];
    }
    return version;
  }

  /// Retrieves the build number from `pubspec.yaml`.
  ///
  /// Returns `0` if the version has no integer build number.
  int getBuildNumber() {
    final version = getVersion();
    if (version.contains('+')) {
      return int.tryParse(version.split('+')[1]) ?? 0;
    }
    return 0;
  }

  /// Retrieves the application name from `pubspec.yaml`.
  String getAppName() {
    final name = _load(_pubspec().readAsStringSync())['name'];
    if (name is! String || name.isEmpty) {
      throw const FlutterCiException("pubspec.yaml has no 'name' field.");
    }
    return name;
  }

  File _pubspec() {
    final file = File('pubspec.yaml');
    if (!file.existsSync()) {
      throw FlutterCiException(
          'pubspec.yaml not found in ${Directory.current.path}. '
          'Run flutter_ci from the root of your Flutter project.');
    }
    return file;
  }

  Map _load(String content) {
    final Object? yaml;
    try {
      yaml = loadYaml(content);
    } on YamlException catch (e) {
      throw FlutterCiException('Invalid pubspec.yaml: $e');
    }
    if (yaml is! Map) {
      throw const FlutterCiException('Invalid pubspec.yaml: expected a map.');
    }
    return yaml;
  }

  String _readVersion(String content) {
    final version = _load(content)['version'];
    if (version == null) {
      throw const FlutterCiException(
          "pubspec.yaml has no 'version' field. Add one, e.g. version: 1.0.0+1");
    }
    return version.toString();
  }

  void _write(File file, String content, String newVersion) {
    final editor = YamlEditor(content)..update(['version'], newVersion);
    file.writeAsStringSync(editor.toString());
  }
}
