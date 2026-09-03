import 'package:meta/meta.dart';

/// A TestFlight tester group.
///
/// [isInternalGroup] is the field that decides everything else about how a
/// build reaches this group. **Internal groups get a build as soon as it is
/// assigned; external groups need Apple's beta review first**, which is a
/// separate request against `betaAppReviewSubmissions`. Assigning a build to
/// an external group and stopping there leaves it at "Ready to Submit" and no
/// tester ever sees it.
///
/// ## Parameters
///
/// ### Required
/// - **[id]**: Apple's identifier for the group.
///
/// ### Optional
/// - **[name]**: The group's name in App Store Connect.
/// - **[isInternalGroup]**: Whether it is an internal group.
/// - **[hasAccessToAllBuilds]**: Whether every build reaches it automatically.
/// - **[publicLinkEnabled]**: Whether it has a public join link.
/// - **[publicLink]**: The join link, when enabled.
/// - **[feedbackEnabled]**: Whether testers can send feedback.
@immutable
class BetaGroup {
  /// Creates a beta group.
  const BetaGroup({
    required this.id,
    this.name,
    this.isInternalGroup,
    this.hasAccessToAllBuilds,
    this.publicLinkEnabled,
    this.publicLink,
    this.feedbackEnabled,
  });

  /// Reads a group out of a JSON:API resource object.
  @internal
  factory BetaGroup.fromJson(Map<String, dynamic> json) {
    final attributes = json['attributes'] as Map<String, dynamic>? ?? const {};
    return BetaGroup(
      id: json['id'] as String? ?? '',
      name: attributes['name'] as String?,
      isInternalGroup: attributes['isInternalGroup'] as bool?,
      hasAccessToAllBuilds: attributes['hasAccessToAllBuilds'] as bool?,
      publicLinkEnabled: attributes['publicLinkEnabled'] as bool?,
      publicLink: attributes['publicLink'] as String?,
      feedbackEnabled: attributes['feedbackEnabled'] as bool?,
    );
  }

  /// Apple's identifier for the group.
  final String id;

  /// The group's name in App Store Connect.
  final String? name;

  /// Whether it is an internal group.
  ///
  /// `null` when Apple did not say, which is treated as external everywhere
  /// a decision depends on it — the safe direction, since it means beta
  /// review is not skipped.
  final bool? isInternalGroup;

  /// Whether every build reaches it automatically.
  final bool? hasAccessToAllBuilds;

  /// Whether it has a public join link.
  final bool? publicLinkEnabled;

  /// The join link, when enabled.
  final String? publicLink;

  /// Whether testers can send feedback.
  final bool? feedbackEnabled;

  /// Whether a build assigned here needs Apple's beta review first.
  ///
  /// Defaults to `true` for a group whose kind is unknown: assuming internal
  /// would skip the review step and leave the build reaching nobody, with
  /// nothing saying why.
  bool get needsBetaReview => !(isInternalGroup ?? false);

  @override
  String toString() =>
      'BetaGroup($id, ${name ?? '?'}, '
      '${(isInternalGroup ?? false) ? 'internal' : 'external'})';
}
