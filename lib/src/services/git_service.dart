import 'package:process_run/shell.dart';
import 'package:flutter_ci/src/utils/logger.dart';

class GitService {
  final shell = Shell(verbose: false);

  Future<String?> getCurrentCommitHash() async {
    try {
      final results = await shell.run('git rev-parse --short HEAD');
      return results.first.outText.trim();
    } catch (e) {
      Logger.error("Failed to get git commit hash: $e");
      return null;
    }
  }

  Future<void> commitChanges(String message, List<String> files) async {
    try {
      await shell.run('git add ${files.join(' ')}');
      await shell.run('git commit -m "$message"');
      Logger.success("Committed changes: $message");
    } catch (e) {
      Logger.error("Failed to commit changes: $e");
    }
  }

  Future<void> createTag(String tagName) async {
    try {
      await shell.run('git tag $tagName');
      Logger.success("Created git tag: $tagName");
    } catch (e) {
      Logger.error("Failed to create git tag: $e");
    }
  }

  Future<String> getRecentCommits({int count = 10}) async {
    try {
      final results = await shell.run('git log -n $count --pretty=format:"- %s"');
      return results.map((r) => r.outText).join('\n');
    } catch (e) {
      Logger.error("Failed to get recent commits: $e");
      return "No release notes available.";
    }
  }
}
