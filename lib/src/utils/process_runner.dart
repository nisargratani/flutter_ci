import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_ci/src/exceptions.dart';

/// Runs external commands, streaming their output to the console and
/// optionally appending it to a log file.
///
/// Arguments are passed to the process as a list, so values containing
/// spaces, quotes or newlines reach the command unchanged. A non-zero exit
/// code raises a [FlutterCiException].
class ProcessRunner {
  /// When set, the echoed command line and all process output are appended
  /// to this file.
  File? logFile;

  /// Runs [executable] with [arguments] and waits for it to finish.
  ///
  /// [display] replaces the echoed command line, which is useful for hiding
  /// secrets. By default the command is echoed with `--dart-define` values
  /// redacted.
  Future<void> run(
    String executable,
    List<String> arguments, {
    String? display,
    Map<String, String>? environment,
    bool? runInShell,
  }) async {
    final shown = display ?? formatCommand(executable, arguments);
    stdout.writeln('\$ $shown');
    _log(utf8.encode('\n> $shown\n'));

    final Process process;
    try {
      process = await Process.start(
        executable,
        arguments,
        environment: environment,
        // By default, lets Windows resolve `flutter.bat`, `firebase.cmd`, ...
        runInShell: runInShell ?? Platform.isWindows,
      );
    } on ProcessException catch (e) {
      throw FlutterCiException(
        "Could not run '$executable'. Is it installed and on your PATH? "
        '(${e.message})',
      );
    }

    final output = [
      process.stdout.listen((data) {
        stdout.add(data);
        _log(data);
      }).asFuture<void>(),
      process.stderr.listen((data) {
        stderr.add(data);
        _log(data);
      }).asFuture<void>(),
    ];
    final code = await process.exitCode;
    await Future.wait(output);

    if (code != 0) {
      throw FlutterCiException('Command failed with exit code $code: $shown');
    }
  }

  /// Runs [command] through the platform shell (`/bin/sh -c` on macOS and
  /// Linux, `cmd /c` on Windows), so pipes, `&&` chains and `cd` work.
  Future<void> runShell(String command, {String? display}) {
    if (Platform.isWindows) {
      return run('cmd', ['/c', command],
          display: display ?? command, runInShell: false);
    }
    return run('/bin/sh', ['-c', command], display: display ?? command);
  }

  void _log(List<int> data) {
    final file = logFile;
    if (file == null) return;
    try {
      file.writeAsBytesSync(data, mode: FileMode.append);
    } on FileSystemException {
      // Losing the log must never fail the build itself.
      logFile = null;
    }
  }
}

final _safeShellWord = RegExp(r'^[A-Za-z0-9_\-+=./:,@%]+$');

/// Quotes [value] so the platform shell passes it as a single argument.
String shellQuote(String value) {
  if (value.isNotEmpty && _safeShellWord.hasMatch(value)) return value;
  if (Platform.isWindows) return '"${value.replaceAll('"', r'\"')}"';
  return "'${value.replaceAll("'", r"'\''")}'";
}

/// Splits a command-line fragment such as `--foo "a b" --bar` into
/// arguments, honouring single and double quotes.
List<String> splitArguments(String input) {
  final args = <String>[];
  final current = StringBuffer();
  String? quote;
  var inWord = false;

  for (final char in input.split('')) {
    if (quote != null) {
      if (char == quote) {
        quote = null;
      } else {
        current.write(char);
      }
    } else if (char == '"' || char == "'") {
      quote = char;
      inWord = true;
    } else if (char.trim().isEmpty) {
      if (inWord) {
        args.add(current.toString());
        current.clear();
        inWord = false;
      }
    } else {
      current.write(char);
      inWord = true;
    }
  }
  if (inWord) args.add(current.toString());
  return args;
}

/// Replaces the value of a `--dart-define=KEY=VALUE` argument with `***`.
///
/// Other arguments are returned unchanged.
String redactDefine(String argument) {
  const prefix = '--dart-define=';
  if (!argument.startsWith(prefix)) return argument;
  final key = argument.substring(prefix.length).split('=').first;
  return '$prefix$key=***';
}

/// Formats a command for display, redacting `--dart-define` values.
String formatCommand(String executable, List<String> arguments) => [
      executable,
      ...arguments.map((a) => shellQuote(redactDefine(a)))
    ].join(' ');
