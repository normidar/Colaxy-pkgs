import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Fallback widget for the `AsyncError` branch of a provider.
///
/// In debug builds it shows the full error and stack trace so the problem is
/// visible while developing. In release builds it shows a short message only —
/// a stack trace is internal detail and should not be put in front of users.
///
/// widgetName: The name of the widget that caused the error.<br>
/// error: The error that was thrown.<br>
/// stackTrace: The stack trace of the error that was thrown.<br>
class RiverpodErrorView extends StatelessWidget {
  /// Creates an error view for [widgetName].
  const RiverpodErrorView({
    required this.widgetName,
    required this.error,
    required this.stackTrace,
    this.message,
    super.key,
  });

  /// The name of the widget that caused the error.
  final String widgetName;

  /// The error that was thrown.
  final Object error;

  /// The stack trace of the error that was thrown.
  final StackTrace stackTrace;

  /// Message shown to users in non-debug builds.
  ///
  /// Defaults to a generic English string; pass a localized one where it
  /// matters.
  final String? message;

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          message ?? 'Something went wrong.',
          style: TextStyle(color: Theme.of(context).colorScheme.error),
          textAlign: TextAlign.center,
        ),
      );
    }

    return SingleChildScrollView(
      child: Wrap(
        children: <Widget>[
          SelectableText('$widgetName Error: \n $error\nStack: \n $stackTrace'),
        ],
      ),
    );
  }
}

/// Reports a provider error through Flutter's error handler.
///
/// Call this from the `AsyncError` branch alongside [RiverpodErrorView] when
/// the error should also reach crash reporting. [RiverpodErrorView] used to do
/// this itself via a `print` inside `build`, which bypassed the error reporting
/// pipeline and re-ran on every rebuild.
void reportRiverpodError({
  required String widgetName,
  required Object error,
  required StackTrace stackTrace,
}) {
  FlutterError.reportError(
    FlutterErrorDetails(
      exception: error,
      stack: stackTrace,
      library: 'riverpod_helper',
      context: ErrorDescription('while building $widgetName'),
    ),
  );
}
