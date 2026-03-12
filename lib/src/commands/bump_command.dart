import '../services/version_service.dart';

/// The command responsible for bumping the build number in `pubspec.yaml`.
class BumpCommand {
  final service = VersionService();

  /// Runs the bump operation.
  Future<void> run() async {
    service.bumpBuildNumber();
  }
}
