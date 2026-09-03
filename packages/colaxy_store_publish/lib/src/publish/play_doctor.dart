// Results are appended one check at a time, each a multi-line await, and the
// order matters — the listings check fills in what the locale comparison
// reads. A cascade over those reads worse than repeating the receiver, which
// is the same call colaxy_store_console's verify tool made.
// ignore_for_file: cascade_invocations

import 'package:colaxy_store_console/colaxy_store_console.dart';
import 'package:colaxy_store_publish/src/fastlane/fastlane_metadata.dart';
import 'package:colaxy_store_publish/src/google_play/play_edit_session.dart';
import 'package:colaxy_store_publish/src/google_play/play_publisher.dart';
import 'package:colaxy_store_publish/src/publish/doctor_check.dart';

/// Checks that a real Play Console account is set up to be published to.
///
/// The local tree can be checked without a network; this is the other half —
/// the part `MetadataCheck` cannot know. Setting up a service account has
/// several independent failure points, and every one of them surfaces as the
/// same unhelpful `401` or `403` in the middle of a publish:
///
/// - the key is valid but the account was never invited in Play Console
/// - it was invited but granted no permission on this app
/// - it can read the app but not edit it
/// - the package name names an app this account cannot see
///
/// **It opens an edit and discards it.** That is a deliberate write, and the
/// only way to prove edit permission: reading a listing succeeds for an
/// account that could never publish. A discarded edit leaves nothing behind,
/// but it does hold the app's edit lock for the moment it exists, so this is
/// not something to run in a loop.
///
/// Nothing else is written. No listing, image, bundle or track is touched,
/// and the edit is never committed.
///
/// ## Parameters
///
/// ### Required
/// - **[publisher]**: An authenticated publisher for the app to check.
///
/// ### Optional
/// - **[metadata]**: The local tree, so the store's locales can be compared
///   against it (default: `null`, skipping that check).
///
/// ## Example
///
/// ```dart
/// for (final check in await PlayDoctor(publisher: publisher).run()) {
///   stdout.writeln(check);
/// }
/// ```
class PlayDoctor {
  /// Creates a doctor for one app.
  const PlayDoctor({required this.publisher, this.metadata});

  /// An authenticated publisher for the app to check.
  final PlayPublisher publisher;

  /// The local tree, when there is one to compare against.
  final FastlaneMetadata? metadata;

  /// Runs every check, and answers what each concluded.
  ///
  /// Never throws. A tool that dies on the first failure tells you less than
  /// one that reports every surface — and here the first failure is usually
  /// the *only* thing anyone sees, so the rest go unexamined.
  Future<List<DoctorCheck>> run() async {
    final results = <DoctorCheck>[];

    final PlayEditSession session;
    try {
      session = await publisher.openEdit();
    } on StoreConsoleException catch (error) {
      return [
        DoctorCheck(
          'Edit permission',
          DoctorOutcome.fail,
          '$error',
        ),
        const DoctorCheck.skipped('Store listings', 'a usable edit'),
        const DoctorCheck.skipped('Release tracks', 'a usable edit'),
        const DoctorCheck.skipped('Local vs store locales', 'a usable edit'),
      ];
    }

    results.add(
      DoctorCheck(
        'Edit permission',
        DoctorOutcome.pass,
        'opened edit ${session.editId}'
        '${session.expiresAt == null ? '' : ', expires ${session.expiresAt}'}',
      ),
    );

    final locales = <String>[];
    results.add(
      await _check('Store listings', () async {
        final listings = await session.listings.list();
        if (listings.isEmpty) {
          return const (
            DoctorOutcome.empty,
            'the app has no store listing yet',
          );
        }
        locales
          ..addAll(listings.map((listing) => listing.language))
          ..sort();
        return (
          DoctorOutcome.pass,
          '${listings.length} locales: ${locales.join(', ')}',
        );
      }),
    );

    results.add(
      await _check('Release tracks', () async {
        final tracks = await session.tracks.list();
        if (tracks.isEmpty) {
          return const (DoctorOutcome.empty, 'the app has no tracks yet');
        }
        final described = tracks.map(
          (track) => '${track.name} (${track.releases.length})',
        );
        return (DoctorOutcome.pass, described.join(', '));
      }),
    );

    results.add(_compareLocales(locales));

    // The edit has served its purpose. Discarding quietly: a cleanup failure
    // is not what this run is reporting on, and letting it replace the
    // results would hide them.
    final discarded = await session.discardQuietly();
    results.add(
      DoctorCheck(
        'Cleanup',
        discarded ? DoctorOutcome.pass : DoctorOutcome.fail,
        discarded
            ? 'discarded edit ${session.editId}; nothing was written'
            : 'could not discard edit ${session.editId}; it will expire on '
                  'its own',
      ),
    );

    return results;
  }

  /// Compares the locales on the store against the local directories.
  ///
  /// Neither direction is an error. A local locale with no listing is a new
  /// translation about to be published; a store locale with no directory was
  /// translated in Play Console and this run will leave it alone. Both are
  /// worth seeing before a publish, and neither is worth blocking one.
  DoctorCheck _compareLocales(List<String> storeLocales) {
    final tree = metadata;
    if (tree == null) {
      return const DoctorCheck.skipped(
        'Local vs store locales',
        'a metadata directory',
      );
    }

    final List<String> local;
    try {
      local = tree.locales();
    } on StoreConsoleException catch (error) {
      return DoctorCheck(
        'Local vs store locales',
        DoctorOutcome.fail,
        error.message,
      );
    }

    if (storeLocales.isEmpty) {
      return DoctorCheck(
        'Local vs store locales',
        DoctorOutcome.empty,
        '${local.length} local locales; the store has none to compare with',
      );
    }

    final onStore = storeLocales.toSet();
    final onDisk = local.toSet();
    final newLocales = (onDisk.difference(onStore).toList())..sort();
    final untouched = (onStore.difference(onDisk).toList())..sort();

    if (newLocales.isEmpty && untouched.isEmpty) {
      return DoctorCheck(
        'Local vs store locales',
        DoctorOutcome.pass,
        '${local.length} locales, matching the store exactly',
      );
    }
    final parts = [
      if (newLocales.isNotEmpty) 'new here: ${newLocales.join(', ')}',
      if (untouched.isNotEmpty) 'store only: ${untouched.join(', ')}',
    ];
    return DoctorCheck(
      'Local vs store locales',
      DoctorOutcome.pass,
      parts.join('; '),
    );
  }

  /// Runs one check, turning any failure into a readable result.
  Future<DoctorCheck> _check(
    String name,
    Future<(DoctorOutcome, String)> Function() body,
  ) async {
    try {
      final (outcome, detail) = await body();
      return DoctorCheck(name, outcome, detail);
    } on StoreConsoleException catch (error) {
      // These already carry a message naming the likely setup mistake.
      return DoctorCheck(name, DoctorOutcome.fail, '$error');
    } on Object catch (error) {
      return DoctorCheck(name, DoctorOutcome.fail, '$error');
    }
  }
}
