import 'dart:convert';
import 'dart:io';

import 'package:flutter_ci/flutter_ci.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'helpers.dart';

void main() {
  useTempCwd();
  final storage = StorageService();

  File artifact(String relativePath, {DateTime? modified}) {
    final file = File(relativePath)
      ..createSync(recursive: true)
      ..writeAsStringSync(relativePath);
    if (modified != null) file.setLastModifiedSync(modified);
    return file;
  }

  Future<List<String>> store({DateTime? builtAfter}) async {
    final stored = await storage.storeArtifacts(
        appName: 'demo',
        version: '1.0.0+2',
        gitCommit: 'abc123',
        builtAfter: builtAfter);
    return [for (final f in stored) p.basename(f.path)];
  }

  test('copies an APK with the app-version name and writes build info',
      () async {
    artifact('build/app/outputs/flutter-apk/app-release.apk');
    artifact('build/app/outputs/flutter-apk/app-release.apk.sha1');

    expect(await store(), ['demo-1.0.0+2.apk']);
    expect(File('builds/v1.0.0+2/demo-1.0.0+2.apk').readAsStringSync(),
        'build/app/outputs/flutter-apk/app-release.apk');

    final info =
        jsonDecode(File('builds/v1.0.0+2/build_info.json').readAsStringSync())
            as Map<String, dynamic>;
    expect(info['version'], '1.0.0+2');
    expect(info['git_commit'], 'abc123');
    expect(info['app_name'], 'demo');
    expect(info['artifacts'], ['demo-1.0.0+2.apk']);
    expect(info, contains('build_time'));
    expect(info, contains('flutter_version'));
  });

  test('finds flavored AABs and IPAs', () async {
    artifact('build/app/outputs/bundle/prodRelease/app-prod-release.aab');
    artifact('build/ios/ipa/Runner.ipa');

    expect(await store(),
        unorderedEquals(['demo-1.0.0+2.aab', 'demo-1.0.0+2.ipa']));
  });

  test('keeps every artifact when several share an extension', () async {
    artifact('build/app/outputs/flutter-apk/app-arm64-v8a-release.apk');
    artifact('build/app/outputs/flutter-apk/app-x86_64-release.apk');

    expect(
        await store(),
        unorderedEquals([
          'demo-1.0.0+2-app-arm64-v8a-release.apk',
          'demo-1.0.0+2-app-x86_64-release.apk',
        ]));
  });

  test('ignores artifacts older than builtAfter', () async {
    final start = DateTime.now();
    artifact('build/app/outputs/flutter-apk/app-debug.apk',
        modified: start.subtract(const Duration(hours: 1)));
    artifact('build/app/outputs/flutter-apk/app-release.apk');

    expect(await store(builtAfter: start), ['demo-1.0.0+2.apk']);
    expect(File('builds/v1.0.0+2/demo-1.0.0+2.apk').readAsStringSync(),
        endsWith('app-release.apk'));
  });

  test('returns an empty list when nothing was built', () async {
    expect(await store(), isEmpty);
    expect(File('builds/v1.0.0+2/build_info.json').existsSync(), isTrue);
  });
}
