## 0.1.0

First release. Publishing to Google Play and the App Store over the fastlane
directory layout: listings, screenshots, app bundles and tracks.

This closes the one step of the release pipeline in this repository that still
needed Ruby. Icons, screenshots and metadata were already generated in Dart,
and `colaxy_store_console` already read from both stores; only pushing to the
store went through `fastlane supply`.

### Edits
- `PlayPublisher` over an authenticated `PlayServiceAccount`, with `openEdit`
  for callers who manage the transaction and `edit` for those who do not.
- `PlayEditSession` with `validate`, `commit`, `discard` and `discardQuietly`.
  The commit is deliberately not hidden — Play's edits are transactional, and
  a caller who cannot see the commit cannot choose not to make it.
- `expiresAt` from the edit's own `expiryTimeSeconds`, so a long upload can be
  checked against its deadline.
- `edit(body, dryRun: true)` runs `edits.validate` and discards. The dry run is
  Google's, not a local imitation.
- `ChangesInReviewBehavior`, because Google's default is to cancel a review in
  flight and resubmit — a routine metadata push can restart a release's review
  clock without saying so.

### Resources
- `PlayListingsApi`, `PlayImagesApi`, `PlayTracksApi`, `PlayBundlesApi`, each
  bound to one edit.
- `get` on listings and tracks goes through `list`. The API's own `get`
  answers `404` both for "no such locale" and for a dead edit, and treating the
  second as the first would report success having published nothing.
- Bundles upload resumably by default; a failure retries the chunk rather than
  the file.
- `PlayTracksApi.release` reads the track and merges. `tracks.update` replaces
  a track's whole release list, so sending only the new release would drop a
  halted rollout.

### Local layout
- `FastlaneMetadata` reads `fastlane/metadata/android/`, the layout
  `colaxy_localization` and `colaxy_screenshot` already write. No intermediate
  format was invented, so the three packages stay independent.
- Directory names under `images/` are already the API's `imageType` values, and
  locale directory names are sent verbatim. Neither has a translation table.
- `strayFeatureGraphic` surfaces `android/featureGraphic.png`, which
  `colaxy_screenshot` wrote outside the fastlane convention before its 0.10.0
  and which `fastlane supply` never picked up either. Publishing it to every
  locale is opt-in; regenerating with a current `colaxy_screenshot` is the
  better fix.

### Checking the tree
- `MetadataCheck` reports structural problems before anything is sent, and the
  `colaxy-store-publish` executable exposes it as `--check` — no network, no
  credentials.
- The point is *silent* mistakes. `FastlaneMetadata` skips what it does not
  recognise, so a directory named `phonescreenshots` uploads nothing and
  reports success. Misspelled slots, App Store file names in the Android tree,
  unselectable changelog names, unsupported image suffixes, empty slots and the
  stray feature graphic are all otherwise invisible.
- Google's documented text limits are reported as warnings, counted in
  grapheme clusters so an emoji does not inflate the count. Warnings, because
  the store is the authority.
- This is what `fastlane supply` could not do: the generator and the publisher
  had to be the same language first. It already earns its place —
  `colaxy_localization` validates a description against 4000 characters and
  *then* appends the minimum-version footer, so a description at the limit is
  over it on disk.

### Checking the account
- `PlayDoctor`, and `--doctor` on the executable: credentials, permissions,
  and what the store already has. The half `MetadataCheck` cannot know.
- It opens an edit and discards it. That is the only way to prove edit
  permission — reading a listing succeeds for an account that could never
  publish. Nothing else is written and nothing is committed.
- Setting up a service account has several independent failure points, and
  every one of them surfaces as the same `401` or `403` partway through a
  publish. Each is now a separate line with its own verdict.
- `EMPTY` is distinct from `PASS`, as in `colaxy_store_console`'s verify tool:
  an app with no listing yet proves the credentials, not the decoding.
- It also reports which locales exist locally but not on the store, and which
  the store has that a publish will leave alone. Neither is an error.

### Command line
- `dart run colaxy_store_publish:publish`, with `--check`, `--doctor`,
  `--dry-run`,
  `--locales`, `--replace-screenshots`, `--feature-graphic`,
  `--error-if-in-review`, `--skip-check` and `--allow-empty`.
- Credentials come from `PLAY_KEY_JSON` and `PLAY_PACKAGE`, matching
  `colaxy_store_console`'s verify tool, including the key-or-path
  accommodation.
- Blocking check problems refuse the publish by default.
- An edit that staged nothing is discarded rather than committed, because
  committing an empty edit still cancels a review in progress.

### Safety
- Nothing is deleted unless asked. Screenshot uploads append;
  `replaceScreenshots` empties the slot first, and `listings.deleteAll` is
  never called for you.
- Listings are merged against the store, so a locale directory holding only
  `title.txt` does not blank the descriptions.
- Image dimensions, sizes and counts are not validated locally. Google enforces
  those, and a second rulebook here would reject what the store accepts.
- `PlayEditConflictException` is never retried: replaying a commit against the
  same stale snapshot fails identically.

### App Store
- `AppStorePublisher` and `AppStoreMetadataPublisher`, deliberately **not**
  sharing a type with the Google Play side. Play publishes through a
  transaction that can be validated and rolled back; the App Store writes
  immediately. A shared interface would claim rollback where there is none.
- No `dryRun`. `edits.validate` has no App Store equivalent and imitating it
  locally would check different things than the store does.
- A failing locale does not abort the run — with no rollback, stopping early
  leaves the store just as half-updated, minus the locales that would have
  worked. Failures land in `AppStorePublishReport.failedLocales`.
- Metadata splits across **two resources**: `name`, `subtitle` and
  `privacyPolicyUrl` go to `appInfoLocalizations`; `description`, `keywords`,
  `whatsNew`, `promotionalText`, `supportUrl` and `marketingUrl` go to
  `appStoreVersionLocalizations`. The flat fastlane directory says nothing
  about this; `FastlaneIosListing` is where it is enforced.
- `AppInfosApi.editable` filters locally, because
  `/v1/apps/{id}/appInfos` accepts **no filter parameters at all**. An app has
  one record per state and writing through the wrong one is reported to
  succeed while changing nothing visible, so the publisher stops rather than
  taking the first record.
- Screenshots are reserve → chunked transfer → MD5 commit → poll. The bytes go
  to Apple's asset host without the API's bearer token, because every request
  body in the specification is JSON. A failed upload deletes its reservation:
  an uncommitted one blocks submission.
- `ScreenshotDisplayType` carries all 33 slots and `byCaptureName` maps
  `colaxy_screenshot`'s file names onto them. Unlike Android, where the
  directory names *are* the API values, Apple needs a table — so captures it
  cannot place are reported in `unmappedScreenshots` rather than dropped.
- `colaxy-store-publish-ios` executable, with `--doctor` (read-only).

### Not yet verified
No call has been made against a real account on either store. The API surface
comes from reading the `androidpublisher/v3` generated client and Apple's own
OpenAPI document (4.4.1); the tests run against a mock.

Two App Store mappings are secondary sources rather than specification, and
are marked as such in the code: `ipadPro13` → `APP_IPAD_PRO_3GEN_129`, and
the claim that writing through a non-editable `appInfo` silently no-ops.
