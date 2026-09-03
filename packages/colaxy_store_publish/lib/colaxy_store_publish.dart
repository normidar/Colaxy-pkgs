/// Publish Android listings, screenshots and app bundles to Google Play from
/// pure Dart.
///
/// Reads the `fastlane supply` directory layout, which `colaxy_localization`
/// and `colaxy_screenshot` already write, so this drops in where
/// `fastlane supply` was without a Ruby toolchain.
///
/// Google Play only. App Store Connect has no equivalent for the binary half
/// of this, and the metadata half differs enough that pretending to one
/// interface would misdescribe both — see the README.
library;

export 'package:colaxy_store_publish/src/core/store_publish_exception.dart';
export 'package:colaxy_store_publish/src/fastlane/fastlane_image_set.dart';
export 'package:colaxy_store_publish/src/fastlane/fastlane_listing.dart';
export 'package:colaxy_store_publish/src/fastlane/fastlane_metadata.dart';
export 'package:colaxy_store_publish/src/fastlane/metadata_check.dart';
export 'package:colaxy_store_publish/src/fastlane/metadata_issue.dart';
export 'package:colaxy_store_publish/src/google_play/changes_in_review_behavior.dart';
export 'package:colaxy_store_publish/src/google_play/play_ai_generated_state.dart';
export 'package:colaxy_store_publish/src/google_play/play_api_guard.dart';
export 'package:colaxy_store_publish/src/google_play/play_bundle.dart';
export 'package:colaxy_store_publish/src/google_play/play_bundles_api.dart';
export 'package:colaxy_store_publish/src/google_play/play_edit_session.dart';
export 'package:colaxy_store_publish/src/google_play/play_edit_state.dart';
export 'package:colaxy_store_publish/src/google_play/play_image.dart';
export 'package:colaxy_store_publish/src/google_play/play_image_type.dart';
export 'package:colaxy_store_publish/src/google_play/play_images_api.dart';
export 'package:colaxy_store_publish/src/google_play/play_listing.dart';
export 'package:colaxy_store_publish/src/google_play/play_listings_api.dart';
export 'package:colaxy_store_publish/src/google_play/play_publisher.dart';
export 'package:colaxy_store_publish/src/google_play/play_release_status.dart';
export 'package:colaxy_store_publish/src/google_play/play_track.dart';
export 'package:colaxy_store_publish/src/google_play/play_track_release.dart';
export 'package:colaxy_store_publish/src/google_play/play_tracks_api.dart';
export 'package:colaxy_store_publish/src/publish/doctor_check.dart';
export 'package:colaxy_store_publish/src/publish/play_doctor.dart';
export 'package:colaxy_store_publish/src/publish/play_metadata_publisher.dart';
export 'package:colaxy_store_publish/src/publish/play_publish_options.dart';
export 'package:colaxy_store_publish/src/publish/play_publish_report.dart';
