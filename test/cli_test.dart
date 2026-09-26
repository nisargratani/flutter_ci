// End-to-end tests: runs the compiled `flutter_ci` executable against a
// temporary project, with a fake `flutter` on PATH that records its
// arguments and produces build outputs.
@TestOn('!windows')
@Timeout(Duration(minutes: 2))
library;

import 'dart:io';

import 'package:flutter_ci/flutter_ci.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'helpers.dart';

const _fakeFlutter = r'''#!/bin/sh
if [ "$1" = "--version" ]; then echo "Flutter 0.0.0-fake"; exit 0; fi
# Records each invocation as one line with every argument in brackets.
line=""
for arg in "$@"; do line="$line[$arg]"; done
echo "$line" >> "$FAKE_FLUTTER_LOG"
case "$1 $2" in
  "build apk")
    mkdir -p build/app/outputs/flutter-apk
    echo apk > build/app/outputs/flutter-apk/app-release.apk ;;
  "build appbundle")
    mkdir -p build/app/outputs/bundle/release
    echo aab > build/app/outputs/bundle/release/app-release.aab ;;
  "build ipa")
    if [ -n "$FAKE_IPA_FAIL" ]; then echo "ipa signing failed" >&2; exit 1; fi
    mkdir -p build/ios/ipa
    echo ipa > build/ios/ipa/Runner.ipa ;;
esac
''';

void main() {
  late Directory tools;
  late String cli;

  setUpAll(() async {
    tools = Directory.systemTemp.createTempSync('flutter_ci_cli_');
    cli = p.join(tools.path, 'flutter_ci.dill');
    final compile = await Process.run(Platform.resolvedExecutable,
        ['compile', 'kernel', 'bin/flutter_ci.dart', '-o', cli]);
    expect(compile.exitCode, 0, reason: '${compile.stdout}${compile.stderr}');

    final bin = Directory(p.join(tools.path, 'bin'))..createSync();
    final flutter = File(p.join(bin.path, 'flutter'))
      ..writeAsStringSync(_fakeFlutter);
    Process.runSync('chmod', ['+x', flutter.path]);
  });
  tearDownAll(() => tools.deleteSync(recursive: true));

  late Directory project;
  setUp(() {
    project = Directory.systemTemp.createTempSync('flutter_ci_project_');
    writePubspec(dir: project);
  });
  tearDown(() => project.deleteSync(recursive: true));

  File projectFile(String path) => File(p.join(project.path, path));
  String version() => RegExp(r'^version: (.+)$', multiLine: true)
      .firstMatch(projectFile('pubspec.yaml').readAsStringSync())!
      .group(1)!;
  List<String> flutterCalls() {
    final log = projectFile('.flutter_calls');
    return log.existsSync() ? log.readAsLinesSync() : [];
  }

  Future<ProcessResult> run(List<String> args,
          {Map<String, String> env = const {}}) =>
      Process.run(Platform.resolvedExecutable, [cli, ...args],
          workingDirectory: project.path,
          environment: {
            'PATH':
                '${p.join(tools.path, 'bin')}:${Platform.environment['PATH']}',
            'FAKE_FLUTTER_LOG': projectFile('.flutter_calls').path,
            'NO_COLOR': '1',
            ...env,
          });

  test('build: bumps, runs default steps and stores the APK', () async {
    final result = await run(['build', '-p', 'android']);

    expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
    expect(version(), '1.0.0+2');
    expect(flutterCalls(), [
      '[clean]',
      '[pub][get]',
      '[build][apk][--build-name=1.0.0][--build-number=2]',
    ]);
    expect(
        projectFile('builds/v1.0.0+2/demo-1.0.0+2.apk').existsSync(), isTrue);
    expect(projectFile('builds/v1.0.0+2/build.log').readAsStringSync(),
        contains('> flutter build apk'));
  });

  test('build: aab with flavor', () async {
    final result = await run([
      'build',
      '-p',
      'android',
      '--android-format',
      'aab',
      '--flavor',
      'prod',
      '--no-bump',
    ]);

    expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
    expect(version(), '1.0.0+1');
    expect(flutterCalls().last,
        '[build][appbundle][--flavor=prod][--build-name=1.0.0][--build-number=1]');
    expect(
        projectFile('builds/v1.0.0+1/demo-1.0.0+1.aab').existsSync(), isTrue);
  });

  test('build: CLI flags override flutter_ci.yaml', () async {
    expect((await run(['init'])).exitCode, 0);
    expect(projectFile('flutter_ci.yaml').readAsStringSync(),
        contains('platform: both'));

    final result = await run(['build', '-p', 'android', '--no-bump']);

    expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
    expect(version(), '1.0.0+1', reason: '--no-bump must win over the YAML');
    expect(flutterCalls().where((c) => c.startsWith('[build]')),
        ['[build][apk][--build-name=1.0.0][--build-number=1]'],
        reason: '--platform android must win over the YAML');
  });

  test('build: YAML values apply when no flag is given', () async {
    projectFile('flutter_ci.yaml').writeAsStringSync('''
platform: android
version_bump: false
android:
  format: aab
pre_build:
  - echo custom-step
env:
  FROM_YAML: yaml
''');
    final result = await run(['build', '-d', 'FROM_CLI=cli']);

    expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
    expect(result.stdout, contains('custom-step'));
    expect(flutterCalls(), [
      '[build][appbundle][--dart-define=FROM_YAML=yaml]'
          '[--dart-define=FROM_CLI=cli][--build-name=1.0.0][--build-number=1]',
    ]);
  });

  test('build: dart-define values keep spaces and are never printed', () async {
    final result = await run([
      'build',
      '-p',
      'android',
      '-d',
      'GREETING=hello world',
      '-d',
      'API_KEY=s3cr3t-value',
      '-d',
      'BARE',
    ]);

    expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
    expect(
        flutterCalls().last,
        contains('[--dart-define=GREETING=hello world]'
            '[--dart-define=API_KEY=s3cr3t-value][--dart-define=BARE]'));
    expect('${result.stdout}${result.stderr}', isNot(contains('s3cr3t-value')));
    expect(projectFile('builds/v1.0.0+2/build.log').readAsStringSync(),
        isNot(contains('s3cr3t-value')));
    expect(result.stdout, contains('--dart-define=API_KEY=***'));
  });

  test('build: a failing platform exits 1 but keeps the other artifacts',
      () async {
    final result = await run([
      'build',
      '--android-build-cmd',
      'echo android-failed; exit 3',
      '--ios-build-cmd',
      'mkdir -p build/ios/ipa && echo ipa > build/ios/ipa/Runner.ipa',
    ]);

    expect(result.exitCode, 1);
    expect(result.stderr, contains('Build failed for Android'));
    expect(
        projectFile('builds/v1.0.0+2/demo-1.0.0+2.ipa').existsSync(), isTrue);
    expect(projectFile('builds/v1.0.0+2/build.log').readAsStringSync(),
        contains('android-failed'));
  }, testOn: 'mac-os');

  test('build: parallel custom commands each run their own script', () async {
    final result = await run([
      'build',
      '--pre-build',
      'true',
      '--android-build-cmd',
      'sleep 1; echo ANDROID-RAN',
      '--ios-build-cmd',
      'echo IOS-RAN',
    ]);

    expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
    expect(result.stdout, allOf(contains('ANDROID-RAN'), contains('IOS-RAN')));
  }, testOn: 'mac-os');

  test('build: invalid flutter_ci.yaml fails instead of using defaults',
      () async {
    projectFile('flutter_ci.yaml').writeAsStringSync('platform: [oops\n');
    final result = await run(['build']);

    expect(result.exitCode, 1);
    expect(result.stderr, contains('Invalid flutter_ci.yaml'));
    expect(flutterCalls(), isEmpty);
    expect(version(), '1.0.0+1');
  });

  test('build: invalid platform in YAML is rejected', () async {
    projectFile('flutter_ci.yaml').writeAsStringSync('platform: Android\n');
    final result = await run(['build']);

    expect(result.exitCode, 1);
    expect(result.stderr, contains("Invalid platform 'Android'"));
  });

  test('build: failing pre-build step stops the build', () async {
    final result = await run(['build', '--pre-build', 'exit 7']);

    expect(result.exitCode, 1);
    expect(result.stderr, contains('exit code 7'));
    expect(flutterCalls(), isEmpty);
  });

  test('usage errors exit with 64', () async {
    expect((await run(['build', '--platform', 'windows'])).exitCode, 64);
    expect((await run(['build', 'unexpected'])).exitCode, 64);
    expect((await run(['no-such-command'])).exitCode, 64);
  });

  test('help and version', () async {
    final help = await run(['--help']);
    expect(help.exitCode, 0);
    expect(help.stdout, allOf(contains('build'), contains('release')));

    final buildHelp = await run(['build', '--help']);
    expect(buildHelp.exitCode, 0);
    expect(buildHelp.stdout, contains('--android-format'));

    for (final args in [
      ['--version'],
      ['version'],
    ]) {
      final result = await run(args);
      expect(result.stdout.toString().trim(),
          'flutter_ci version: $packageVersion');
    }
  });

  test('bump', () async {
    expect((await run(['bump'])).exitCode, 0);
    expect(version(), '1.0.0+2');
  });

  test('bump without pubspec.yaml exits 1 with a clear message', () async {
    projectFile('pubspec.yaml').deleteSync();
    final result = await run(['bump']);
    expect(result.exitCode, 1);
    expect(result.stderr, contains('pubspec.yaml not found'));
  });

  test('init does not overwrite an existing config', () async {
    projectFile('flutter_ci.yaml').writeAsStringSync('platform: ios\n');
    expect((await run(['init'])).exitCode, 0);
    expect(
        projectFile('flutter_ci.yaml').readAsStringSync(), 'platform: ios\n');
  });

  test('clean-builds and list', () async {
    Directory(p.join(project.path, 'builds', 'v1.0.0+1'))
        .createSync(recursive: true);
    expect((await run(['list'])).stdout, contains('v1.0.0+1'));
    expect((await run(['clean-builds'])).exitCode, 0);
    expect(Directory(p.join(project.path, 'builds')).existsSync(), isFalse);
  });

  test('yaml-guide prints valid YAML', () async {
    final result = await run(['yaml-guide']);
    expect(result.exitCode, 0);
    final yaml = result.stdout.toString();
    projectFile('flutter_ci.yaml')
        .writeAsStringSync(yaml.substring(yaml.indexOf('# ====')));
    final config = ConfigService();
    final previous = Directory.current;
    Directory.current = project;
    try {
      await config.loadConfig();
    } finally {
      Directory.current = previous;
    }
    expect(config.getString('platform'), 'both');
  });

  group('release', () {
    setUp(() => initGitRepo(project));

    test('commits, tags and writes the changelog after a successful build',
        () async {
      git(project, ['tag', 'v1.0.0+1']);
      git(project, ['commit', '-q', '--allow-empty', '-m', 'feat: new thing']);

      final result = await run(
          ['release', '-p', 'android', '--commit', '--tag', '--changelog']);

      expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
      expect(git(project, ['tag', '--points-at', 'HEAD']), 'v1.0.0+2');
      expect(git(project, ['log', '-1', '--pretty=%s']), 'Release v1.0.0+2');
      expect(
          git(project, ['show', '--name-only', '--pretty=', 'HEAD'])
              .split('\n'),
          unorderedEquals(['CHANGELOG.md', 'pubspec.yaml']));
      expect(projectFile('CHANGELOG.md').readAsStringSync(),
          startsWith('## v1.0.0+2\n\n- feat: new thing\n'));
    });

    test('does not commit or tag when the build fails', () async {
      final result = await run([
        'release',
        '-p',
        'android',
        '--commit',
        '--tag',
        '--android-build-cmd',
        'exit 1',
      ]);

      expect(result.exitCode, 1);
      expect(git(project, ['tag']), isEmpty);
      expect(git(project, ['log', '-1', '--pretty=%s']), 'initial');
    });

    test('fails when an enabled upload has no artifact', () async {
      projectFile('flutter_ci.yaml').writeAsStringSync('''
distribution:
  play_store:
    enabled: true
    package_name: com.example.demo
    json_key_path: key.json
''');
      final result = await run([
        'release',
        '-p',
        'android',
        '--upload',
        '--android-build-cmd',
        'true',
      ]);

      expect(result.exitCode, 1);
      expect(result.stderr, contains('Play Store'));
    });
  });
}
