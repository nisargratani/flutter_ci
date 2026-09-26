import 'dart:io';

import 'package:test/test.dart';

/// Creates a fresh temporary directory for each test in the enclosing group
/// and makes it the current directory while the test runs.
///
/// Returns a getter for the directory of the running test.
Directory Function() useTempCwd() {
  late Directory dir;
  late Directory previous;
  setUp(() {
    previous = Directory.current;
    dir = Directory.systemTemp.createTempSync('flutter_ci_test_');
    Directory.current = dir;
  });
  tearDown(() {
    Directory.current = previous;
    dir.deleteSync(recursive: true);
  });
  return () => dir;
}

/// Writes a minimal Flutter-style pubspec.yaml into [dir] (default: the
/// current directory).
void writePubspec(
    {String name = 'demo', String? version = '1.0.0+1', Directory? dir}) {
  File('${dir?.path ?? '.'}/pubspec.yaml').writeAsStringSync('''
name: $name
description: A test app. # keep this comment
${version == null ? '' : 'version: $version'}

environment:
  sdk: ^3.5.0
''');
}

/// Runs git in [dir] and fails the test if it exits with a non-zero code.
String git(Directory dir, List<String> args) {
  final result = Process.runSync('git', args, workingDirectory: dir.path);
  if (result.exitCode != 0) {
    fail('git ${args.join(' ')} failed: ${result.stderr}');
  }
  return '${result.stdout}'.trim();
}

/// Initialises a git repository with a local identity and one commit.
void initGitRepo(Directory dir) {
  git(dir, ['init', '-q']);
  git(dir, ['config', 'user.email', 'ci@example.com']);
  git(dir, ['config', 'user.name', 'CI']);
  git(dir, ['config', 'commit.gpgsign', 'false']);
  git(dir, ['config', 'tag.gpgsign', 'false']);
  git(dir, ['add', '-A']);
  git(dir, ['commit', '-q', '--allow-empty', '-m', 'initial']);
}
