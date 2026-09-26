/// Thrown when a flutter_ci operation cannot complete.
///
/// Examples are an invalid `flutter_ci.yaml`, a malformed version string, a
/// missing `pubspec.yaml`, or an external command (such as `flutter build`)
/// exiting with a non-zero code. The CLI reports [message] and exits with
/// code 1.
class FlutterCiException implements Exception {
  /// Creates an exception with a human-readable [message].
  const FlutterCiException(this.message);

  /// A description of what went wrong, suitable for showing to the user.
  final String message;

  @override
  String toString() => 'FlutterCiException: $message';
}
