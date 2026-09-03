import 'package:meta/meta.dart';

/// The "what to test" note shown to TestFlight testers, for one locale.
///
/// **Not the same field as an App Store version's `whatsNew`.** That one is
/// the release note on the public listing; this one is the tester-facing note
/// on a build, and they live on different resources with different lifetimes.
/// `colaxy_localization` writes one `release_notes.txt` per locale, which can
/// feed both — but they are two writes, not one.
///
/// ## Parameters
///
/// ### Required
/// - **[locale]**: The App Store locale, e.g. `ja`, `en-US`.
///
/// ### Optional
/// - **[id]**: Apple's identifier, when this came from the store.
/// - **[whatsNew]**: The note itself.
@immutable
class BetaBuildLocalization {
  /// Creates a tester-facing build note.
  const BetaBuildLocalization({
    required this.locale,
    this.id,
    this.whatsNew,
  });

  /// Reads one out of a JSON:API resource object.
  @internal
  factory BetaBuildLocalization.fromJson(Map<String, dynamic> json) {
    final attributes = json['attributes'] as Map<String, dynamic>? ?? const {};
    return BetaBuildLocalization(
      id: json['id'] as String?,
      locale: attributes['locale'] as String? ?? '',
      whatsNew: attributes['whatsNew'] as String?,
    );
  }

  /// The App Store locale.
  final String locale;

  /// Apple's identifier, when this came from the store.
  final String? id;

  /// The note itself.
  final String? whatsNew;

  @override
  String toString() => 'BetaBuildLocalization($locale)';
}
