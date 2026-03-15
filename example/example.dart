import 'package:flutter_ci/flutter_ci.dart';

void main() async {
  final buildCommand = BuildCommand();

  // Example of running a build programmatically
  await buildCommand.run(
    shouldBump: true,
    preBuildCmd: 'flutter clean && flutter pub get',
  );

  final versionService = VersionService();
  // Example of bumping version manually
  versionService.bumpBuildNumber();

  Logger.success('Example completed successfully!');
}
