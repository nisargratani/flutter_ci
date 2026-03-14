import 'dart:io';
import 'package:yaml/yaml.dart';
import 'package:flutter_ci/src/utils/logger.dart';

class ConfigService {
  static const String _configFileName = 'flutter_ci.yaml';

  Map<String, dynamic> _config = {};

  Future<void> loadConfig() async {
    final configFile = File(_configFileName);
    if (await configFile.exists()) {
      try {
        final content = await configFile.readAsString();
        final yaml = loadYaml(content);
        if (yaml is Map) {
          _config = _recursiveConvertMap(yaml);
          Logger.info("Loaded configuration from $_configFileName");
        }
      } catch (e) {
        Logger.error("Error reading $_configFileName: $e");
      }
    }
  }

  Map<String, dynamic> _recursiveConvertMap(Map map) {
    return map.map((key, value) {
      if (value is Map) {
        return MapEntry(key.toString(), _recursiveConvertMap(value));
      } else if (value is YamlList) {
        return MapEntry(key.toString(), value.toList());
      }
      return MapEntry(key.toString(), value);
    });
  }

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

  Map<String, dynamic> get config => _config;
}
