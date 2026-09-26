import 'dart:io';

import 'package:flutter_ci/flutter_ci.dart';
import 'package:test/test.dart';

import 'helpers.dart';

void main() {
  final cwd = useTempCwd();
  final gitService = GitService();

  void commit(String message) =>
      git(cwd(), ['commit', '-q', '--allow-empty', '-m', message]);

  test('getCurrentCommitHash returns the short HEAD hash', () async {
    initGitRepo(cwd());
    expect(await gitService.getCurrentCommitHash(),
        git(cwd(), ['rev-parse', '--short', 'HEAD']));
  });

  test('getCurrentCommitHash returns null outside a repository', () async {
    expect(await gitService.getCurrentCommitHash(), isNull);
  });

  test('commitChanges commits only the given files', () async {
    initGitRepo(cwd());
    File('pubspec.yaml').writeAsStringSync('a');
    File('other.txt').writeAsStringSync('b');
    git(cwd(), ['add', 'other.txt']);

    await gitService.commitChanges('Release v1.0.0+2', ['pubspec.yaml']);

    expect(git(cwd(), ['log', '-1', '--pretty=%s']), 'Release v1.0.0+2');
    expect(git(cwd(), ['show', '--name-only', '--pretty=', 'HEAD']),
        'pubspec.yaml');
    // The unrelated staged file is still staged, not committed.
    expect(git(cwd(), ['diff', '--cached', '--name-only']), 'other.txt');
  });

  test('commitChanges throws when there is nothing to commit', () async {
    initGitRepo(cwd());
    File('pubspec.yaml').writeAsStringSync('a');
    git(cwd(), ['add', '-A']);
    git(cwd(), ['commit', '-q', '-m', 'add']);
    expect(gitService.commitChanges('noop', ['pubspec.yaml']),
        throwsA(isA<FlutterCiException>()));
  });

  test('createTag creates a tag and rejects duplicates', () async {
    initGitRepo(cwd());
    await gitService.createTag('v1.0.0+2');
    expect(git(cwd(), ['tag']), 'v1.0.0+2');
    expect(
        gitService.createTag('v1.0.0+2'), throwsA(isA<FlutterCiException>()));
  });

  test('getRecentCommits keeps special characters intact', () async {
    initGitRepo(cwd());
    commit('fix: user\'s "quoted" bug 🐛');
    expect(await gitService.getRecentCommits(count: 1),
        '- fix: user\'s "quoted" bug 🐛');
  });

  test('getCommitsSinceLastTag lists only commits after the last tag',
      () async {
    initGitRepo(cwd());
    commit('before tag');
    git(cwd(), ['tag', 'v1.0.0']);
    commit('feat: one');
    commit('fix: two');
    expect(
        await gitService.getCommitsSinceLastTag(), '- fix: two\n- feat: one');
  });

  test('getCommitsSinceLastTag is empty right after a tag', () async {
    initGitRepo(cwd());
    git(cwd(), ['tag', 'v1.0.0']);
    expect(await gitService.getCommitsSinceLastTag(), isEmpty);
  });

  test('getCommitsSinceLastTag falls back to recent commits without tags',
      () async {
    initGitRepo(cwd());
    commit('second');
    expect(await gitService.getCommitsSinceLastTag(fallbackCount: 5),
        '- second\n- initial');
  });
}
