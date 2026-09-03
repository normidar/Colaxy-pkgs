import 'package:colaxy_store_publish/src/app_store/app_store_version_state.dart';
import 'package:meta/meta.dart';

/// The app-wide half of an App Store listing.
///
/// Holds what does not change between versions: the app's name, subtitle and
/// privacy policy URL, through its `appInfoLocalizations`.
///
/// **An app has more than one of these — one per state.** A live app
/// typically has a `READY_FOR_SALE` record and a `PREPARE_FOR_SUBMISSION`
/// one, and writing to the wrong one is reported to succeed while changing
/// nothing anybody can see. That is the worst failure shape there is, and it
/// is why [isEditable] exists and why `AppInfosApi.editable` filters rather
/// than taking the first record.
///
/// Making it worse: **`/v1/apps/{id}/appInfos` accepts no filter parameters
/// at all** (verified against the specification), so the state cannot be
/// pushed to the server. Every record has to be fetched and sorted through
/// here.
///
/// ## Parameters
///
/// ### Required
/// - **[id]**: Apple's identifier for the record.
///
/// ### Optional
/// - **[appStoreState]**: Which state this record belongs to.
/// - **[state]**: Apple's newer free-form state string, kept verbatim.
@immutable
class AppInfo {
  /// Creates an app info record.
  const AppInfo({required this.id, this.appStoreState, this.state});

  /// Reads a record out of a JSON:API resource object.
  @internal
  factory AppInfo.fromJson(Map<String, dynamic> json) {
    final attributes = json['attributes'] as Map<String, dynamic>? ?? const {};
    return AppInfo(
      id: json['id'] as String? ?? '',
      appStoreState: AppStoreVersionState.byWireName(
        attributes['appStoreState'] as String? ?? '',
      ),
      state: attributes['state'] as String?,
    );
  }

  /// Apple's identifier for the record.
  final String id;

  /// Which state this record belongs to.
  final AppStoreVersionState? appStoreState;

  /// Apple's newer free-form state string.
  ///
  /// Typed as a plain string in the specification rather than an enum, so it
  /// is carried through untouched instead of being guessed at.
  final String? state;

  /// Whether app-wide metadata can be written to this record.
  bool get isEditable => appStoreState?.isEditable ?? false;

  @override
  String toString() => 'AppInfo($id, ${appStoreState?.wireName ?? '?'})';
}
