import 'dart:io';
import 'package:flutter_ci/src/utils/logger.dart';

class ListCommand {
  Future<void> run() async {
    final buildsDir = Directory('builds');
    if (!buildsDir.existsSync()) {
      Logger.info("No builds found. Directory 'builds/' does not exist.");
      return;
    }

    final List<FileSystemEntity> entities = buildsDir.listSync();
    final directories = entities.whereType<Directory>().toList();

    if (directories.isEmpty) {
      Logger.info("No builds found in 'builds/' directory.");
      return;
    }

    // Sort by name descending to show latest first
    directories.sort((a, b) => b.path.compareTo(a.path));

    Logger.info("📦 Previous Builds:\n");
    for (var dir in directories) {
      final name = dir.path.split(Platform.pathSeparator).last;
      print("  $name");
    }

    print("");
  }
}
