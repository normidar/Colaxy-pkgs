import 'package:meta/meta.dart';

/// How much an issue in the local metadata tree matters.
///
/// The split is about **who decides**, not about how annoying the problem is.
///
/// ## Example
///
/// ```dart
/// final blocking = issues.where((issue) => issue.severity.blocks);
/// ```
enum MetadataSeverity {
  /// The publish cannot do what the tree says, or will visibly do the wrong
  /// thing.
  ///
  /// A missing directory, an image the uploader cannot send. These are facts
  /// about the local files, decidable without asking Google.
  error,

  /// The publish will run, but something looks like a mistake.
  ///
  /// Mostly *silent* mistakes: a misspelled slot directory uploads zero
  /// screenshots and reports success, because an unrecognised directory is
  /// skipped by design. A warning is the only place that ever becomes
  /// visible.
  ///
  /// Also covers Google's documented text limits. Those are the store's rules
  /// and the store enforces them; repeating them here is a courtesy that
  /// saves a round trip, never a veto.
  warning;

  /// Whether this severity should stop a publish by default.
  bool get blocks => this == MetadataSeverity.error;
}

/// One problem found in the local metadata tree.
///
/// ## Parameters
///
/// ### Required
/// - **[severity]**: Whether this blocks a publish.
/// - **[message]**: What is wrong, in one line.
///
/// ### Optional
/// - **[locale]**: The locale it was found under (default: `null`, for
///   issues about the tree as a whole).
/// - **[path]**: The file or directory concerned (default: `null`).
/// - **[fix]**: What to do about it (default: `null`).
///
/// ## Example
///
/// ```dart
/// for (final issue in check.run()) {
///   stderr.writeln(issue);
/// }
/// ```
@immutable
class MetadataIssue {
  /// Creates an issue.
  const MetadataIssue({
    required this.severity,
    required this.message,
    this.locale,
    this.path,
    this.fix,
  });

  /// Creates a blocking issue.
  const MetadataIssue.error(
    this.message, {
    this.locale,
    this.path,
    this.fix,
  }) : severity = MetadataSeverity.error;

  /// Creates a non-blocking issue.
  const MetadataIssue.warning(
    this.message, {
    this.locale,
    this.path,
    this.fix,
  }) : severity = MetadataSeverity.warning;

  /// Whether this blocks a publish.
  final MetadataSeverity severity;

  /// What is wrong, in one line.
  final String message;

  /// The locale it was found under, when it belongs to one.
  final String? locale;

  /// The file or directory concerned.
  final String? path;

  /// What to do about it.
  ///
  /// Worth carrying separately from [message]: the checks that matter most
  /// here are the silent ones, and "your screenshots were not uploaded" is
  /// only useful next to "rename the directory to phoneScreenshots".
  final String? fix;

  @override
  String toString() {
    final buffer = StringBuffer()
      ..write(severity == MetadataSeverity.error ? 'error' : 'warning')
      ..write(locale == null ? '' : ' [$locale]')
      ..write(': $message');
    if (fix != null) buffer.write(' → $fix');
    if (path != null) buffer.write('\n    $path');
    return buffer.toString();
  }
}
