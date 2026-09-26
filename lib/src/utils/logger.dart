import 'dart:io';

/// A utility class for printing colored logs to the console.
///
/// Informational and success messages go to stdout; warnings and errors go
/// to stderr. Colors are disabled when the `NO_COLOR` environment variable
/// is set (see https://no-color.org).
class Logger {
  static final bool _color = !Platform.environment.containsKey('NO_COLOR');

  static String _paint(String code, String message) =>
      _color ? '\x1B[${code}m$message\x1B[0m' : message;

  /// Prints an informational message in cyan.
  static void info(String message) {
    stdout.writeln(_paint('36', 'ℹ️  $message'));
  }

  /// Prints a success message in green.
  static void success(String message) {
    stdout.writeln(_paint('32', '✅ $message'));
  }

  /// Prints a warning in yellow to stderr.
  static void warning(String message) {
    stderr.writeln(_paint('33', '⚠️  $message'));
  }

  /// Prints an error message in red to stderr.
  static void error(String message) {
    stderr.writeln(_paint('31', '❌ $message'));
  }
}
