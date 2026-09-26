import 'dart:io';

import 'package:flutter_ci/flutter_ci.dart';
import 'package:test/test.dart';

import 'helpers.dart';

void main() {
  useTempCwd();
  late ConfigService config;
  setUp(() => config = ConfigService());

  void writeConfig(String yaml) =>
      File('flutter_ci.yaml').writeAsStringSync(yaml);

  test('missing file gives an empty config', () async {
    await config.loadConfig();
    expect(config.config, isEmpty);
    expect(config.getValue('platform', defaultValue: 'both'), 'both');
  });

  test('empty file gives an empty config', () async {
    writeConfig('');
    await config.loadConfig();
    expect(config.config, isEmpty);
  });

  test('reads nested values with dot notation', () async {
    writeConfig('android:\n  format: aab\npre_build:\n  - a\n  - b\n');
    await config.loadConfig();
    expect(config.getValue<String>('android.format'), 'aab');
    expect(config.getValue<List>('pre_build'), ['a', 'b']);
    expect(config.getValue('android.missing'), isNull);
    expect(config.getValue('android.format.deeper'), isNull);
  });

  test('comment-only sections are null, not errors', () async {
    writeConfig('env:\n  # API_KEY: x\nnotifications:\n  # slack: y\n');
    await config.loadConfig();
    expect(config.getValue<Map>('env'), isNull);
    expect(config.getString('notifications.slack'), isNull);
  });

  test('interpolates set environment variables', () async {
    final home = Platform.environment['HOME'] ?? Platform.environment['PATH']!;
    final name = Platform.environment.containsKey('HOME') ? 'HOME' : 'PATH';
    writeConfig('a: "x-\${$name}-y"\nlist:\n  - "\${$name}"\n');
    await config.loadConfig();
    expect(config.getString('a'), 'x-$home-y');
    expect(config.getValue<List>('list'), [home]);
  });

  test('leaves unset environment variables untouched', () async {
    writeConfig(r'a: "${FLUTTER_CI_SURELY_UNSET_VAR}"');
    await config.loadConfig();
    expect(config.getString('a'), r'${FLUTTER_CI_SURELY_UNSET_VAR}');
  });

  test('invalid YAML throws instead of silently using defaults', () async {
    writeConfig('app_store:\n  username: "\\\${X}"\n');
    expect(
        config.loadConfig(),
        throwsA(isA<FlutterCiException>()
            .having((e) => e.message, 'message', contains('line 2'))));
  });

  test('a non-map top level throws', () async {
    writeConfig('- a\n- b\n');
    expect(config.loadConfig(), throwsA(isA<FlutterCiException>()));
  });

  test('reloading resets values from a deleted file', () async {
    writeConfig('platform: ios\n');
    await config.loadConfig();
    expect(config.getString('platform'), 'ios');
    File('flutter_ci.yaml').deleteSync();
    await config.loadConfig();
    expect(config.getString('platform'), isNull);
  });

  group('typed getters', () {
    test('getString converts scalars', () async {
      writeConfig('flavor: 1\nversion: 2.5\nflag: true\n');
      await config.loadConfig();
      expect(config.getString('flavor'), '1');
      expect(config.getString('version'), '2.5');
      expect(config.getString('flag'), 'true');
    });

    test('getString rejects maps', () async {
      writeConfig('android:\n  format: apk\n');
      await config.loadConfig();
      expect(() => config.getString('android'),
          throwsA(isA<FlutterCiException>()));
    });

    test('getBool rejects non-booleans with a clear message', () async {
      writeConfig('version_bump: "yes"\n');
      await config.loadConfig();
      expect(
          () => config.getBool('version_bump'),
          throwsA(isA<FlutterCiException>().having(
              (e) => e.message, 'message', contains("'version_bump'"))));
    });

    test('getBool returns null for absent keys', () async {
      await config.loadConfig();
      expect(config.getBool('git.commit'), isNull);
    });
  });
}
