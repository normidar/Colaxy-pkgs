import 'package:meta/meta.dart';

/// Where a tester is in the invitation cycle.
enum BetaTesterState {
  /// Added, but no invitation sent.
  notInvited('NOT_INVITED'),

  /// Invited and not yet accepted.
  invited('INVITED'),

  /// Accepted the invitation.
  accepted('ACCEPTED'),

  /// Installed the app.
  installed('INSTALLED'),

  /// Access withdrawn.
  revoked('REVOKED');

  /// Creates a state with the wire name App Store Connect uses for it.
  const BetaTesterState(this.wireName);

  /// The value App Store Connect sends.
  final String wireName;

  /// The state [wireName] names, or `null` for one this package does not know.
  static BetaTesterState? byWireName(String wireName) {
    for (final state in values) {
      if (state.wireName == wireName) return state;
    }
    return null;
  }
}

/// How a tester was brought in.
enum BetaInviteType {
  /// Invited by email.
  email('EMAIL'),

  /// Joined through a public link.
  publicLink('PUBLIC_LINK');

  /// Creates an invite type with the wire name App Store Connect uses.
  const BetaInviteType(this.wireName);

  /// The value App Store Connect sends.
  final String wireName;

  /// The type [wireName] names, or `null` for one this package does not know.
  static BetaInviteType? byWireName(String wireName) {
    for (final type in values) {
      if (type.wireName == wireName) return type;
    }
    return null;
  }
}

/// One TestFlight tester.
///
/// Only [email] is required to create one; Apple keys testers by it. Adding a
/// tester who already exists on the account attaches the existing record to
/// the group rather than making a second one.
///
/// ## Parameters
///
/// ### Required
/// - **[email]**: The tester's address, and their identity to Apple.
///
/// ### Optional
/// - **[id]**: Apple's identifier, when this came from the store.
/// - **[firstName]**, **[lastName]**: Shown in App Store Connect.
/// - **[state]**: Where they are in the invitation cycle.
/// - **[inviteType]**: How they were brought in.
@immutable
class BetaTester {
  /// Creates a tester.
  const BetaTester({
    required this.email,
    this.id,
    this.firstName,
    this.lastName,
    this.state,
    this.inviteType,
  });

  /// Reads a tester out of a JSON:API resource object.
  @internal
  factory BetaTester.fromJson(Map<String, dynamic> json) {
    final attributes = json['attributes'] as Map<String, dynamic>? ?? const {};
    return BetaTester(
      id: json['id'] as String?,
      email: attributes['email'] as String? ?? '',
      firstName: attributes['firstName'] as String?,
      lastName: attributes['lastName'] as String?,
      state: BetaTesterState.byWireName(
        attributes['state'] as String? ?? '',
      ),
      inviteType: BetaInviteType.byWireName(
        attributes['inviteType'] as String? ?? '',
      ),
    );
  }

  /// The tester's address, and their identity to Apple.
  final String email;

  /// Apple's identifier, when this came from the store.
  final String? id;

  /// Shown in App Store Connect.
  final String? firstName;

  /// Shown in App Store Connect.
  final String? lastName;

  /// Where they are in the invitation cycle.
  final BetaTesterState? state;

  /// How they were brought in.
  final BetaInviteType? inviteType;

  /// The attributes to send when creating, dropping the ones left unset.
  @internal
  Map<String, dynamic> toAttributes() => <String, dynamic>{
    'email': email,
    'firstName': ?firstName,
    'lastName': ?lastName,
  };

  @override
  String toString() => 'BetaTester($email, ${state?.wireName ?? '?'})';
}
