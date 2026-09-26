@TestOn('!windows')
library;

import 'dart:io';

import 'package:flutter_ci/flutter_ci.dart';
import 'package:flutter_ci/src/utils/process_runner.dart';
import 'package:test/test.dart';

void main() {
  group('splitArguments', () {
    test('splits on whitespace and honours quotes', () {
      expect(splitArguments('  --a  "b c" \'d "e"\' f'),
          ['--a', 'b c', 'd "e"', 'f']);
      expect(splitArguments(''), isEmpty);
      expect(splitArguments('--x=""'), ['--x=']);
    });
  });

  group('shellQuote', () {
    for (final value in [
      'plain',
      'hello world',
      "it's",
      r'$HOME `id` "q"',
      'emoji 🚀',
      '',
    ]) {
      test('round-trips ${value.isEmpty ? 'an empty string' : value}', () {
        final result = Process.runSync(
            '/bin/sh', ['-c', 'printf %s ${shellQuote(value)}']);
        expect(result.stdout, value);
      });
    }
  });

  test('redactDefine hides only dart-define values', () {
    expect(redactDefine('--dart-define=API_KEY=secret=x'),
        '--dart-define=API_KEY=***');
    expect(redactDefine('--flavor=prod'), '--flavor=prod');
    expect(formatCommand('flutter', ['build', '--dart-define=A=b c']),
        "flutter build '--dart-define=A=***'");
  });

  group('ProcessRunner', () {
    late Directory dir;
    setUp(() => dir = Directory.systemTemp.createTempSync('runner_test_'));
    tearDown(() => dir.deleteSync(recursive: true));

    test('logs output of failing commands and throws', () async {
      final log = File('${dir.path}/build.log');
      final runner = ProcessRunner()..logFile = log;

      await expectLater(
          runner.runShell('echo out; echo err >&2; exit 3'),
          throwsA(isA<FlutterCiException>()
              .having((e) => e.message, 'message', contains('exit code 3'))));
      expect(
          log.readAsStringSync(),
          allOf(contains('> echo out; echo err >&2; exit 3'), contains('out'),
              contains('err')));
    });

    test('passes arguments verbatim', () async {
      final log = File('${dir.path}/args.log');
      await (ProcessRunner()..logFile = log)
          .run('printf', ['[%s]', 'a b', "c'd", r'$HOME']);
      expect(log.readAsStringSync(), contains(r"[a b][c'd][$HOME]"));
    });

    test('reports a missing executable clearly', () {
      expect(
          ProcessRunner().run('flutter-ci-no-such-tool', []),
          throwsA(isA<FlutterCiException>()
              .having((e) => e.message, 'message', contains('PATH'))));
    });
  });
}
