import 'dart:io';

import 'package:flutter_ci/flutter_ci.dart';
import 'package:test/test.dart';

import 'helpers.dart';

void main() {
  useTempCwd();
  final service = VersionService();

  group('bumpBuildNumber', () {
    test('increments the build number and keeps comments', () {
      writePubspec(version: '1.2.3+9');
      service.bumpBuildNumber();
      final content = File('pubspec.yaml').readAsStringSync();
      expect(content, contains('version: 1.2.3+10'));
      expect(content, contains('# keep this comment'));
    });

    test('adds +1 when there is no build number', () {
      writePubspec(version: '1.2.3');
      service.bumpBuildNumber();
      expect(service.getVersion(), '1.2.3+1');
    });

    test('is repeatable', () {
      writePubspec(version: '1.0.0+1');
      for (var i = 0; i < 3; i++) {
        service.bumpBuildNumber();
      }
      expect(service.getVersion(), '1.0.0+4');
    });

    test('keeps a pre-release suffix', () {
      writePubspec(version: '2.0.0-beta.1+3');
      service.bumpBuildNumber();
      expect(service.getVersion(), '2.0.0-beta.1+4');
    });

    test('rejects a non-integer build number', () {
      writePubspec(version: '1.0.0+abc');
      expect(service.bumpBuildNumber, throwsA(isA<FlutterCiException>()));
    });

    test('reports a missing version field', () {
      writePubspec(version: null);
      expect(
          service.bumpBuildNumber,
          throwsA(isA<FlutterCiException>().having(
              (e) => e.message, 'message', contains("no 'version' field"))));
    });

    test('reports a missing pubspec.yaml', () {
      expect(
          service.bumpBuildNumber,
          throwsA(isA<FlutterCiException>().having((e) => e.message, 'message',
              contains('pubspec.yaml not found'))));
    });
  });

  group('updateVersion', () {
    test('writes a valid version', () {
      writePubspec();
      service.updateVersion('3.4.5+6');
      expect(service.getVersion(), '3.4.5+6');
      expect(service.getVersionName(), '3.4.5');
      expect(service.getBuildNumber(), 6);
    });

    for (final invalid in ['foo', '1.0', '1.0.0+', '1.0.0+abc', 'v1.0.0', '']) {
      test('rejects "$invalid" without touching pubspec.yaml', () {
        writePubspec();
        expect(() => service.updateVersion(invalid),
            throwsA(isA<FlutterCiException>()));
        expect(service.getVersion(), '1.0.0+1');
      });
    }
  });

  test('getBuildNumber is 0 without a build number', () {
    writePubspec(version: '1.0.0');
    expect(service.getBuildNumber(), 0);
    expect(service.getVersionName(), '1.0.0');
  });

  test('getAppName reads the package name', () {
    writePubspec(name: 'my_app');
    expect(service.getAppName(), 'my_app');
  });
}
