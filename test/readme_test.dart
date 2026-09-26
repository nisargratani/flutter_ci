import 'dart:io';

import 'package:flutter_ci/flutter_ci.dart';
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

import 'helpers.dart';

/// Keeps README examples in sync with the actual behavior.
void main() {
  final readme = File('README.md').readAsStringSync();
  final yamlBlocks = RegExp(r'```yaml\n(.*?)```', dotAll: true)
      .allMatches(readme)
      .map((m) => m.group(1)!)
      .toList();

  test('README contains YAML examples', () {
    expect(yamlBlocks, hasLength(greaterThanOrEqualTo(2)));
  });

  test('every README YAML block parses', () {
    for (final block in yamlBlocks) {
      expect(() => loadYaml(block), returnsNormally, reason: block);
    }
  });

  group('the README flutter_ci.yaml example', () {
    useTempCwd();

    test('loads with the documented values', () async {
      final example = yamlBlocks.firstWhere((b) => b.contains('version_bump'));
      File('flutter_ci.yaml').writeAsStringSync(example);
      final config = ConfigService();
      await config.loadConfig();

      expect(config.getBool('version_bump'), isTrue);
      expect(BuildCommand.platforms, contains(config.getString('platform')));
      expect(BuildCommand.androidFormats,
          contains(config.getString('android.format')));
      expect(BuildCommand.iosMethods, contains(config.getString('ios.method')));
      expect(config.getValue<List>('pre_build'), hasLength(3));
      expect(config.getBool('git.tag'), isTrue);
      expect(config.getString('distribution.play_store.track'), 'internal');
    });
  });

  test('README mentions every CLI command', () {
    for (final command in [
      'build',
      'release',
      'bump',
      'init',
      'doctor',
      'list',
      'clean-builds',
      'yaml-guide',
      'version',
    ]) {
      expect(readme, contains('| `$command` |'));
    }
  });
}
