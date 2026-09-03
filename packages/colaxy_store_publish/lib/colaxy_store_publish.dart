/// Publish listings, screenshots and app binaries to Google Play and the App
/// Store from pure Dart.
///
/// Reads the `fastlane` directory layout, which `colaxy_localization` and
/// `colaxy_screenshot` already write, so this drops in where `supply`,
/// `deliver` and `pilot` were without a Ruby toolchain.
///
/// Covers both stores, with **separate shapes for each** — there is no
/// unified publishing interface here, and that is deliberate. Google Play
/// publishes through a transaction that can be validated and rolled back;
/// App Store Connect writes immediately and cannot. Code written against a
/// shared type would be wrong about the thing that matters most.
///
/// See the README for the per-store support matrix.
library;

export 'package:colaxy_store_publish/src/app_store/app_info.dart';
export 'package:colaxy_store_publish/src/app_store/app_info_localization.dart';
export 'package:colaxy_store_publish/src/app_store/app_info_localizations_api.dart';
export 'package:colaxy_store_publish/src/app_store/app_infos_api.dart';
export 'package:colaxy_store_publish/src/app_store/app_screenshot.dart';
export 'package:colaxy_store_publish/src/app_store/app_screenshot_set.dart';
export 'package:colaxy_store_publish/src/app_store/app_screenshots_api.dart';
export 'package:colaxy_store_publish/src/app_store/app_store_build.dart';
export 'package:colaxy_store_publish/src/app_store/app_store_builds_api.dart';
export 'package:colaxy_store_publish/src/app_store/app_store_publisher.dart';
export 'package:colaxy_store_publish/src/app_store/app_store_version.dart';
export 'package:colaxy_store_publish/src/app_store/app_store_version_localization.dart';
export 'package:colaxy_store_publish/src/app_store/app_store_version_localizations_api.dart';
export 'package:colaxy_store_publish/src/app_store/app_store_version_state.dart';
export 'package:colaxy_store_publish/src/app_store/app_store_versions_api.dart';
export 'package:colaxy_store_publish/src/app_store/asset_uploader.dart';
export 'package:colaxy_store_publish/src/app_store/beta_build_localization.dart';
export 'package:colaxy_store_publish/src/app_store/beta_group.dart';
export 'package:colaxy_store_publish/src/app_store/beta_groups_api.dart';
export 'package:colaxy_store_publish/src/app_store/beta_tester.dart';
export 'package:colaxy_store_publish/src/app_store/beta_testers_api.dart';
export 'package:colaxy_store_publish/src/app_store/build_beta_detail.dart';
export 'package:colaxy_store_publish/src/app_store/build_upload.dart';
export 'package:colaxy_store_publish/src/app_store/build_upload_file.dart';
export 'package:colaxy_store_publish/src/app_store/build_uploads_api.dart';
export 'package:colaxy_store_publish/src/app_store/checksum_algorithm.dart';
export 'package:colaxy_store_publish/src/app_store/review_submission.dart';
export 'package:colaxy_store_publish/src/app_store/review_submissions_api.dart';
export 'package:colaxy_store_publish/src/app_store/screenshot_display_type.dart';
export 'package:colaxy_store_publish/src/app_store/test_flight_api.dart';
export 'package:colaxy_store_publish/src/app_store/upload_operation.dart';
export 'package:colaxy_store_publish/src/core/store_publish_exception.dart';
export 'package:colaxy_store_publish/src/fastlane/fastlane_image_set.dart';
export 'package:colaxy_store_publish/src/fastlane/fastlane_ios_listing.dart';
export 'package:colaxy_store_publish/src/fastlane/fastlane_ios_metadata.dart';
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
export 'package:colaxy_store_publish/src/publish/app_store_metadata_publisher.dart';
export 'package:colaxy_store_publish/src/publish/app_store_publish_options.dart';
export 'package:colaxy_store_publish/src/publish/app_store_publish_report.dart';
export 'package:colaxy_store_publish/src/publish/doctor_check.dart';
export 'package:colaxy_store_publish/src/publish/play_doctor.dart';
export 'package:colaxy_store_publish/src/publish/play_metadata_publisher.dart';
export 'package:colaxy_store_publish/src/publish/play_publish_options.dart';
export 'package:colaxy_store_publish/src/publish/play_publish_report.dart';
