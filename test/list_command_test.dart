import 'dart:async';
import 'dart:io';

import 'package:flutter_ci/flutter_ci.dart';
import 'package:test/test.dart';

import 'helpers.dart';

Future<List<String>> capturePrints(Future<void> Function() body) async {
  final lines = <String>[];
  await runZoned(body,
      zoneSpecification:
          ZoneSpecification(print: (_, __, ___, line) => lines.add(line)));
  return lines;
}

void main() {
  useTempCwd();

  test('lists builds newest version first', () async {
    for (final name in [
      'v1.0.0+9',
      'v1.0.0+10',
      'v1.0.0+2',
      'v1.10.0+1',
      'v1.9.0+50',
      'notes',
    ]) {
      Directory('builds/$name').createSync(recursive: true);
    }
    File('builds/stray.txt').writeAsStringSync('');

    final lines = await capturePrints(() => ListCommand().run());
    expect(lines.map((l) => l.trim()).where((l) => l.isNotEmpty).toList(), [
      'v1.10.0+1',
      'v1.9.0+50',
      'v1.0.0+10',
      'v1.0.0+9',
      'v1.0.0+2',
      'notes',
    ]);
  });

  test('handles a missing builds directory', () async {
    final lines = await capturePrints(() => ListCommand().run());
    expect(lines, isEmpty);
  });
}
