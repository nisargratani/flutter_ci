import 'dart:io';
import 'package:yaml/yaml.dart';
import 'package:flutter_ci/src/exceptions.dart';
import 'package:flutter_ci/src/utils/logger.dart';

/// A service responsible for loading and parsing the `flutter_ci.yaml` configuration.
///
/// String values may reference environment variables as `${NAME}`; they are
/// substituted when the file is loaded. References to unset variables are
/// left as-is and reported with a warning.
class ConfigService {
  static const String _configFileName = 'flutter_ci.yaml';

  Map<String, dynamic> _config = {};

  /// Loads the configuration from `flutter_ci.yaml` in the current directory.
  ///
  /// A missing or empty file results in an empty configuration. Calling this
  /// again reloads the file from scratch.
  ///
  /// Throws a [FlutterCiException] if the file is not valid YAML or its top
  /// level is not a map, rather than silently building with defaults.
  Future<void> loadConfig() async {
    _config = {};
    final configFile = File(_configFileName);
    if (!await configFile.exists()) return;

    final Object? yaml;
    try {
      yaml = loadYaml(await configFile.readAsString());
    } on YamlException catch (e) {
      throw FlutterCiException('Invalid $_configFileName: $e');
    }

    if (yaml == null) return;
    if (yaml is! Map) {
      throw const FlutterCiException(
          'Invalid $_configFileName: the top level must be a map of settings.');
    }
    _config = _recursiveConvertMap(yaml);
    Logger.info("Loaded configuration from $_configFileName");
  }

  Map<String, dynamic> _recursiveConvertMap(Map map) {
    return map.map((key, value) {
      if (value is Map) {
        return MapEntry(key.toString(), _recursiveConvertMap(value));
      } else if (value is Iterable) {
        return MapEntry(
            key.toString(),
            value
                .map((e) => e is String ? _interpolateEnvString(e) : e)
                .toList());
      } else if (value is String) {
        return MapEntry(key.toString(), _interpolateEnvString(value));
      }
      return MapEntry(key.toString(), value);
    });
  }

  String _interpolateEnvString(String value) {
    return value.replaceAllMapped(RegExp(r'\$\{(\w+)\}'), (match) {
      final envVar = match.group(1)!;
      final resolved = Platform.environment[envVar];
      if (resolved != null) return resolved;
      Logger.warning(
          "Environment variable '$envVar' referenced in $_configFileName is not set.");
      return match.group(0)!;
    });
  }

  /// Retrieves a value from the configuration using a dot-notated [key].
  /// Returns [defaultValue] if the key is not found.
  T? getValue<T>(String key, {T? defaultValue}) {
    final parts = key.split('.');
    dynamic current = _config;

    for (var part in parts) {
      if (current is Map && current.containsKey(part)) {
        current = current[part];
      } else {
        return defaultValue;
      }
    }

    if (current is T) {
      return current;
    }
    return defaultValue;
  }

  /// Returns the value at [key] as a string, or `null` if it is absent or
  /// explicitly `null`.
  ///
  /// Numbers and booleans are converted to strings, so `flavor: 1` works.
  /// Throws a [FlutterCiException] if the value is a map or list.
  String? getString(String key) {
    final value = getValue<Object>(key);
    if (value == null) return null;
    if (value is String || value is num || value is bool) {
      return value.toString();
    }
    throw _typeError(key, 'a string', value);
  }

  /// Returns the value at [key] as a boolean, or `null` if it is absent or
  /// explicitly `null`.
  ///
  /// Throws a [FlutterCiException] if the value is not `true` or `false`.
  bool? getBool(String key) {
    final value = getValue<Object>(key);
    if (value == null || value is bool) return value as bool?;
    throw _typeError(key, 'true or false', value);
  }

  FlutterCiException _typeError(String key, String expected, Object value) =>
      FlutterCiException(
          "Invalid value for '$key' in $_configFileName: expected $expected, "
          'got ${value is String ? '"$value"' : value}.');

  /// Returns the raw configuration map.
  Map<String, dynamic> get config => _config;
}
