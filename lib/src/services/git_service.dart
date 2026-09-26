import 'dart:io';
import 'package:process_run/shell.dart';
import 'package:flutter_ci/src/exceptions.dart';
import 'package:flutter_ci/src/utils/logger.dart';

/// A service responsible for Git operations in the current directory.
class GitService {
  /// The shell instance used for executing commands.
  @Deprecated('No longer used by flutter_ci. Will be removed in 1.0.0.')
  final shell = Shell(verbose: false);

  Future<ProcessResult> _git(List<String> args) async {
    try {
      return await Process.run('git', args);
    } on ProcessException catch (e) {
      throw FlutterCiException(
          'Could not run git. Is it installed and on your PATH? (${e.message})');
    }
  }

  Future<String> _gitOrThrow(List<String> args) async {
    final result = await _git(args);
    if (result.exitCode != 0) {
      final output = '${result.stderr}'.trim();
      throw FlutterCiException(
          'git ${args.first} failed${output.isEmpty ? '' : ': $output'}');
    }
    return '${result.stdout}'.trim();
  }

  /// Returns the current git commit hash (short version), or `null` if the
  /// current directory is not a git repository.
  Future<String?> getCurrentCommitHash() async {
    try {
      return await _gitOrThrow(['rev-parse', '--short', 'HEAD']);
    } on FlutterCiException catch (e) {
      Logger.warning("Failed to get git commit hash: ${e.message}");
      return null;
    }
  }

  /// Commits the specified [files] with the given [message].
  ///
  /// Throws a [FlutterCiException] if staging or committing fails, for
  /// example when there is nothing to commit or no git identity is set.
  Future<void> commitChanges(String message, List<String> files) async {
    await _gitOrThrow(['add', '--', ...files]);
    await _gitOrThrow(['commit', '-m', message, '--', ...files]);
    Logger.success("Committed changes: $message");
  }

  /// Creates a git tag with the specified [tagName].
  ///
  /// Throws a [FlutterCiException] if the tag cannot be created, for example
  /// because it already exists.
  Future<void> createTag(String tagName) async {
    await _gitOrThrow(['tag', tagName]);
    Logger.success("Created git tag: $tagName");
  }

  /// Retrieves the most recent [count] commits as release notes.
  ///
  /// Each commit subject is formatted as a `- ` bullet on its own line.
  Future<String> getRecentCommits({int count = 10}) async {
    try {
      return await _gitOrThrow(['log', '-n', '$count', '--pretty=format:- %s']);
    } on FlutterCiException catch (e) {
      Logger.error("Failed to get recent commits: ${e.message}");
      return "No release notes available.";
    }
  }

  /// Retrieves the commits since the most recent tag as release notes.
  ///
  /// Falls back to the last [fallbackCount] commits when the repository has
  /// no tags. Returns an empty string when there are no new commits.
  Future<String> getCommitsSinceLastTag({int fallbackCount = 10}) async {
    final lastTag = await _git(['describe', '--tags', '--abbrev=0']);
    if (lastTag.exitCode != 0) {
      return getRecentCommits(count: fallbackCount);
    }
    final tag = '${lastTag.stdout}'.trim();
    try {
      return await _gitOrThrow(['log', '$tag..HEAD', '--pretty=format:- %s']);
    } on FlutterCiException catch (e) {
      Logger.error("Failed to get commits since $tag: ${e.message}");
      return "No release notes available.";
    }
  }
}
