/// A utility class for printing colored logs to the console.
class Logger {
  static const String _reset = '\x1B[0m';
  static const String _cyan = '\x1B[36m';
  static const String _green = '\x1B[32m';
  static const String _red = '\x1B[31m';

  /// Prints an informational message in cyan.
  static void info(String message) {
    print("$_cyanℹ️  $message$_reset");
  }

  /// Prints a success message in green.
  static void success(String message) {
    print("$_green✅ $message$_reset");
  }

  /// Prints an error message in red.
  static void error(String message) {
    print("$_red❌ $message$_reset");
  }
}
