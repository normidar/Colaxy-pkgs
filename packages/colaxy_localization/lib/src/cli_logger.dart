import 'dart:io';

/// Minimal console output for the `colaxy_localization` CLI.
///
/// The package used to call `print` directly, which always writes to stdout and
/// is flagged by `avoid_print`. Routing through here keeps diagnostics on
/// stderr, so a caller can pipe stdout without picking up log noise.
abstract final class CliLogger {
  /// Writes an informational line to stdout.
  static void info(String message) => stdout.writeln(message);

  /// Writes a warning to stderr.
  static void warn(String message) => stderr.writeln('⚠️  $message');

  /// Writes an error to stderr.
  static void error(String message) => stderr.writeln('❌ $message');
}
