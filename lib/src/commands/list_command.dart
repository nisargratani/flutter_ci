import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:flutter_ci/src/utils/logger.dart';

/// The command responsible for listing previous CI build artifacts.
class ListCommand {
  /// Runs the list operation by scanning the `builds/` directory.
  ///
  /// Builds are listed newest version first (`v1.0.0+10` before `v1.0.0+9`).
  Future<void> run() async {
    final buildsDir = Directory('builds');
    if (!buildsDir.existsSync()) {
      Logger.info("No builds found. Directory 'builds/' does not exist.");
      return;
    }

    final names = buildsDir
        .listSync()
        .whereType<Directory>()
        .map((dir) => path.basename(dir.path))
        .toList();

    if (names.isEmpty) {
      Logger.info("No builds found in 'builds/' directory.");
      return;
    }

    names.sort(_compareBuildNames);

    Logger.info("📦 Previous Builds:\n");
    for (final name in names) {
      print("  $name");
    }

    print("");
  }
}

final _buildName = RegExp(r'^v?(\d+)\.(\d+)\.(\d+)(?:-[^+]*)?(?:\+(\d+))?$');

/// Orders build folder names newest first by semantic version and build
/// number. Names that are not versions sort last, alphabetically.
int _compareBuildNames(String a, String b) {
  final ma = _buildName.firstMatch(a);
  final mb = _buildName.firstMatch(b);
  if (ma == null || mb == null) {
    if (ma != null) return -1;
    if (mb != null) return 1;
    return a.compareTo(b);
  }
  for (var i = 1; i <= 4; i++) {
    final diff = int.parse(mb.group(i) ?? '0') - int.parse(ma.group(i) ?? '0');
    if (diff != 0) return diff;
  }
  return b.compareTo(a);
}
