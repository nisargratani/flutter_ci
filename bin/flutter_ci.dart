import 'dart:io';

import 'package:flutter_ci/src/cli/cli.dart';

Future<void> main(List<String> arguments) async {
  exitCode = await runCli(arguments);
}
