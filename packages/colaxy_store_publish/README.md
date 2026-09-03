# colaxy_store_publish

Publish listings, screenshots and app bundles to Google Play and the App Store
from pure Dart.

Reads the `fastlane` directory layout — the one `colaxy_localization` and
`colaxy_screenshot` already write — so it drops in where `fastlane supply` and
`deliver` were, without a Ruby toolchain.

```dart
final publisher = await PlayPublisher.authenticate(
  account: PlayServiceAccount.fromFile('secrets/play-api.json'),
  packageName: 'com.example.app',
);

await publisher.edit(
  PlayMetadataPublisher(metadata: FastlaneMetadata.forProject('.')).publish,
);
```

Or from the command line:

```bash
export PLAY_KEY_JSON="$(cat secrets/play-api.json)"
export PLAY_PACKAGE=com.example.app

dart run colaxy_store_publish:publish --check     # local only, no network
dart run colaxy_store_publish:publish --doctor    # credentials and permissions
dart run colaxy_store_publish:publish --dry-run   # Google validates, nothing ships
dart run colaxy_store_publish:publish             # publishes
```

## Two stores, two shapes, no unified interface

Both stores are covered. Neither is wrapped in a shared type, and that is the
central design decision here.

| | Google Play | App Store Connect |
|---|---|---|
| **Transactional** | **yes** — `edits`, with commit and rollback | **no** — every write is live immediately |
| **Dry run** | **yes** — `edits.validate` | **none exists** |
| Metadata | one `Listing` per locale | **two resources**: app-wide and version-scoped |
| Screenshots | one `upload` call | **reserve → chunk → checksum → commit** |
| Device slots | 9, identical to the directory names on disk | **33**, matching nothing on disk |
| File transfer | the API receives the bytes | **every request body is JSON**; bytes go elsewhere |
| Binary | `bundles.upload` | `buildUploads` *(not implemented here yet)* |

Wrapping both in one type would claim things that are true of only one. The
most damaging would be rollback: an interrupted Play publish leaves *nothing*
behind, and code written against a shared interface would assume the same of
Apple, where a half-finished run leaves a half-updated store.

So there are two entry points, two publishers, two executables, and no base
class between them.

| | Google Play | App Store |
|---|---|---|
| Entry point | `PlayPublisher` | `AppStorePublisher` |
| Orchestration | `PlayMetadataPublisher` | `AppStoreMetadataPublisher` |
| Local tree | `FastlaneMetadata` | `FastlaneIosMetadata` |
| Executable | `colaxy-store-publish` | `colaxy-store-publish-ios` |

## What it replaces

`fastlane supply` — all of it. Metadata, images, app bundles and tracks.

`deliver` — the metadata and screenshot halves. Apple's binary upload
(`buildUploads`, added in App Store Connect API 4.1) is not implemented yet.

`pilot` is out of scope for now. So is `gym`: wrapping `xcodebuild` in Dart
calls the same binary and improves nothing.

## Install

```yaml
dependencies:
  colaxy_store_publish: ^0.1.0
```

## Credentials

A Google Cloud service account, invited in Play Console under **Users and
permissions**. Reading needs *View app information*; publishing also needs
*Edit and delete draft apps* and, per track, *Release apps to testing tracks*
or *Release to production*.

**The `androidpublisher` OAuth scope has no read-only variant.** Reading and
writing are the same scope. A service account already used with
`colaxy_store_console` to read reviews therefore *already had* the ability to
publish a release — installing this package grants it nothing new. The only
thing that limits such a token is the per-app permission grant in Play Console,
so that is where a credential meant only for reading has to be restricted.

## Directory layout

```text
fastlane/metadata/android/
├── featureGraphic.png            ← non-standard; see below
└── ja-JP/
    ├── title.txt                 → listing title
    ├── short_description.txt     → listing shortDescription
    ├── full_description.txt      → listing fullDescription
    ├── video.txt                 → listing video
    ├── changelogs/
    │   ├── default.txt           → release notes, fallback
    │   └── 412.txt               → release notes for version code 412
    └── images/
        ├── featureGraphic.png    → featureGraphic
        ├── icon.png              → icon
        ├── phoneScreenshots/     → phoneScreenshots
        ├── sevenInchScreenshots/ → sevenInchScreenshots
        └── tenInchScreenshots/   → tenInchScreenshots
```

The directory names under `images/` are already the `imageType` values the
Google Play API expects, so no translation table exists anywhere in this
package. The same is true of locale directory names, which are passed to Google
verbatim: Play's accepted locale list is not the App Store's, and a copy of it
compiled into this package would go stale and start rejecting locales that
work. An unaccepted locale comes back as an error from Google naming it.

Unknown files and directories are skipped, not rejected — a metadata tree also
holds iOS material.

> **`android/featureGraphic.png` is outside the fastlane convention.**
> `colaxy_screenshot` wrote the feature graphic there before its 0.10.0, as a
> single locale-independent file rather than at
> `<locale>/images/featureGraphic.png`. `fastlane supply` never picked it up
> either, so on those trees the graphic was generated on every run and never
> uploaded by anything.
>
> It is exposed as `FastlaneMetadata.strayFeatureGraphic` and published only
> when `PlayPublishOptions.uploadStrayFeatureGraphic` is on, because sending
> one image to every locale is a decision rather than a detail. Regenerating
> with a current `colaxy_screenshot` is the better fix; `--check` reports the
> leftover file either way.

## Edits are visible

Google Play publishes through a transaction: create an edit, stage changes,
commit. This package does not hide that behind a `publish()` that does
everything, because a caller who cannot see the commit cannot know when the
transaction ended, nor choose not to end it.

```dart
final session = await publisher.openEdit();
try {
  final report = await metadataPublisher.publish(session);
  if (report.isEmpty) {
    await session.discard();   // nothing to say to the store
  } else {
    await session.commit();
  }
} catch (_) {
  await session.discardQuietly();
  rethrow;
}
```

`publisher.edit(body)` does this for you, including discarding the edit when
`body` throws. An edit abandoned by a crashed CI job is what makes the *next*
job fail, with an error that names nothing about the run that caused it.

### Dry runs are real

`edit(body, dryRun: true)` calls `edits.validate` — the same check the commit
would run, performed by Google — and then discards. Nothing is imitated
locally.

### Committing has a side effect worth knowing

Google's default when an app already has changes under review is to **cancel
that review** and resubmit everything together. A routine metadata push can
therefore restart the review clock on a release in flight.

```dart
await session.commit(
  changesInReviewBehavior: ChangesInReviewBehavior.errorIfInReview,
);
```

Note also that committing an edit that staged nothing still cancels the review.
Check `PlayPublishReport.isEmpty` before committing an unattended run.

## Nothing is deleted unless asked

- **Screenshots append.** Google Play has no "replace this set" call;
  replacing means emptying the slot first, and emptying a slot destroys
  screenshots that may never have existed locally. Turn it on per run with
  `PlayPublishOptions(replaceScreenshots: true)`. Single-image slots — icon,
  feature graphic, TV banner — are replaced by Google on upload and are
  unaffected.
- **`listings.deleteAll` is never called for you.** A metadata directory
  holding five locales says nothing about a sixth that was translated in Play
  Console. The method exists; nothing in this package reaches it.
- **Listings are merged, not overwritten.** `listings.update` replaces the
  whole listing, so a locale directory holding only `title.txt` would blank
  the descriptions. The publisher reads the store's listings once and merges
  each local one over what is there.

## Checking the tree before you upload

```bash
dart run colaxy_store_publish:publish --check
```

Makes no network calls and needs no credentials, so it fits in a pre-commit
hook or ahead of a build. `MetadataCheck` is the same thing as a library.

It looks for two kinds of problem, and nothing else.

**Silent mistakes.** `FastlaneMetadata` skips what it does not recognise —
it has to, since a metadata tree also holds iOS material. So a directory named
`phonescreenshots` uploads zero screenshots, reports success, and is
indistinguishable from a run that worked. The check is the only place that
ever becomes visible:

```text
warning [ja-JP]: Not a Google Play image slot; every file under it is ignored.
                 → rename to phoneScreenshots
    fastlane/metadata/android/ja-JP/images/phonescreenshots
```

Also caught: App Store file names that landed in the Android tree
(`description.txt`), changelog files named after neither a version code nor
`default`, image suffixes that are not PNG or JPEG, empty slot directories,
and the stray feature graphic when it would go nowhere.

**Google's documented text limits**, as warnings — title 30, short description
80, full description 4000, counted in user-perceived characters rather than
UTF-16 code units so an emoji does not inflate the count. These are the store's
rules and the store enforces them; repeating them here saves a round trip and
never vetoes.

> This is the one thing `fastlane supply` could not do, and it only became
> possible because the generator and the publisher are now the same language.
> A worked example: `colaxy_localization` checks a description against 4000
> characters and *then* appends the minimum-version footer, so a description at
> the limit exceeds it on disk. Nothing could catch that before.

Errors block a publish by default; warnings do not. `--skip-check` overrides.

## Checking the account

```bash
dart run colaxy_store_publish:publish --doctor
```

The other half, and the part `MetadataCheck` cannot know. Setting up a service
account has several independent failure points, and every one of them shows up
as the same unhelpful `401` or `403` partway through a publish: the key is
valid but the account was never invited; it was invited but has no permission
on this app; it can read the app but not edit it; the package name names an app
it cannot see.

```text
PASS   Edit permission              opened edit 08154711…, expires 2026-09-04…
PASS   Store listings               3 locales: en-US, ja-JP, zh-TW
PASS   Release tracks               internal (1), production (2)
PASS   Local vs store locales       new here: de-DE
PASS   Cleanup                      discarded edit 08154711…; nothing written
```

**It opens an edit and discards it.** That is a deliberate write and the only
way to prove edit permission — reading a listing succeeds for an account that
could never publish. A discarded edit leaves nothing behind, but it does hold
the app's edit lock while it exists, so this is not something to run in a loop.
Nothing else is written and nothing is committed.

`EMPTY` is not `PASS`: an app with no listing yet proves the credentials and
the request shape, not that reading a listing works. `PlayDoctor` is the same
thing as a library.

## Image validation is Google's job

Dimensions, aspect ratios, file sizes, how many screenshots a listing needs —
none of it is checked locally. Google publishes some of those rules and
enforces all of them, and a second, staler rulebook here would reject
combinations the store would have accepted. Invalid images fail at upload with
Google's own message.

What *is* checked locally is only what makes the request impossible to build: a
file that is not there, and a suffix that is neither PNG nor JPEG.

## Releasing a bundle

```dart
await publisher.edit((session) async {
  final bundle = await session.bundles.upload(File('app-release.aab'));
  await session.tracks.release(
    track: PlayTrack.internal,
    versionCodes: [bundle.versionCode!],
    releaseNotes: {'ja-JP': '不具合の修正'},
  );
});
```

Uploading does not release anything: a bundle with no track update is visible
in Play Console and served to nobody. Bundles are sent as resumable uploads by
default, so a failure retries the chunk rather than the whole file.

`tracks.release` reads the track first and merges, because `tracks.update`
replaces a track's entire release list — sending only the new release would
drop a halted rollout or a still-serving older one.

## The App Store side

```bash
export ASC_KEY_ID=ABCD123456 ASC_ISSUER_ID=… ASC_APP_ID=6740000000
export ASC_P8="$(cat AuthKey_ABCD123456.p8)"

dart run colaxy_store_publish:publish-ios --doctor   # read-only
dart run colaxy_store_publish:publish-ios            # writes, immediately
```

The key must be a **team** key; an individual key is rejected by several
endpoints, which is the same limit `colaxy_store_console` hit on sales reports.

### Metadata splits across two resources

The fastlane directory is flat and says nothing about this. The API is not.

| file | resource | attribute |
|---|---|---|
| `name.txt` | `appInfoLocalizations` | `name` |
| `subtitle.txt` | `appInfoLocalizations` | `subtitle` |
| `privacy_url.txt` | `appInfoLocalizations` | `privacyPolicyUrl` |
| `description.txt` | `appStoreVersionLocalizations` | `description` |
| `keywords.txt` | `appStoreVersionLocalizations` | `keywords` |
| `release_notes.txt` | `appStoreVersionLocalizations` | `whatsNew` |
| `promotional_text.txt` | `appStoreVersionLocalizations` | `promotionalText` |
| `support_url.txt` | `appStoreVersionLocalizations` | `supportUrl` |
| `marketing_url.txt` | `appStoreVersionLocalizations` | `marketingUrl` |

Three go one way, six the other, through two different records with two
different editability windows. Google Play's equivalent is a single `Listing`.

> **An app has several `appInfo` records — one per state — and writing through
> the wrong one succeeds while changing nothing anybody can see.** There is no
> local symptom: `200`, success reported, old name still on the store. Worse,
> `/v1/apps/{id}/appInfos` accepts **no filter parameters at all**, so the
> state cannot be pushed to the server. `AppInfosApi.editable` fetches every
> record and picks the editable one, and the publisher stops rather than
> guessing when there is none.

### Screenshots are three steps and a wait

```text
POST  /v1/appScreenshots      reserve; answers upload operations
PUT   assets.apple.com/…      the bytes, chunked, to another host
PATCH /v1/appScreenshots/{id} commit with uploaded: true + MD5
GET   /v1/appScreenshots/{id} poll until processing settles
```

The bytes never touch the API — **every request body in the specification is
JSON** — so they go to a URL Apple hands back, without the bearer token.
`AppScreenshot` is one of the resources that requires `sourceFileChecksum`;
several newer asset types do not, so it cannot be inferred from the pattern.

If the upload fails after the reservation is made, the reservation is deleted.
An uncommitted one shows as a grey placeholder and blocks submission, which is
worse than the upload simply having failed.

Processing is **asynchronous**: an asset can upload cleanly and be rejected
minutes later. Waiting is on by default; `--no-wait` turns it off.

### Device slots need a translation table

Google Play's nine `imageType` values are exactly the directory names on disk,
so Android needs no mapping. Apple has 33 `ScreenshotDisplayType` values that
match nothing `colaxy_screenshot` writes, so `byCaptureName` bridges them —
`iphone65` → `APP_IPHONE_65`, `ipadPro13` → `APP_IPAD_PRO_3GEN_129`,
`mac` → `APP_DESKTOP`.

A capture whose device this package cannot place is **reported, not dropped**:
`AppStorePublishReport.unmappedScreenshots` lists them, and `--doctor` warns.

> ⚠️ `ipadPro13` → `APP_IPAD_PRO_3GEN_129` comes from a developer forum
> report, not the specification — Apple's website labels and the API's
> generation numbers are known to disagree. Confirm it before trusting a
> release to it.

### There is no dry run, and failures do not abort

`edits.validate` has no App Store equivalent, and imitating it locally would
check different things than the store does. Narrow a run with
`--no-app-info` / `--no-version-text` / `--no-screenshots` instead.

A locale that fails is recorded in `failedLocales` and the run continues. With
no rollback, stopping early leaves the store just as half-updated, minus the
locales that would have worked.

## API reference

### Entry points

| Class | Purpose |
|---|---|
| `PlayPublisher` | Holds the authenticated client; opens edits |
| `PlayEditSession` | One edit: `validate`, `commit`, `discard` |
| `PlayMetadataPublisher` | Stages a metadata directory into an edit |

### Inside an edit

| Class | Purpose |
|---|---|
| `PlayListingsApi` | `list`, `get`, `update`, `delete`, `deleteAll` |
| `PlayImagesApi` | `list`, `upload`, `delete`, `deleteAll` |
| `PlayTracksApi` | `list`, `get`, `update`, `release` |
| `PlayBundlesApi` | `list`, `upload` |

### Reading the local tree

| Class | Purpose |
|---|---|
| `FastlaneMetadata` | `locales`, `listing`, `imageSets`, `strayFeatureGraphic` |
| `FastlaneListing` | One locale's text and changelogs |
| `FastlaneImageSet` | One locale's files for one slot |
| `MetadataCheck` | Structural problems in the tree, before any request |
| `MetadataIssue` | One problem, with the fix for it |
| `PlayDoctor` | Credentials, permissions, and what the store already has |
| `DoctorCheck` | One check's result |

### App Store

| Class | Purpose |
|---|---|
| `AppStorePublisher` | Holds the authenticated client; exposes the APIs |
| `AppStoreMetadataPublisher` | Writes a fastlane tree. No transaction |
| `AppStoreVersionsApi` | `list`, `editable` |
| `AppInfosApi` | `list`, `editable` — filters locally, the endpoint cannot |
| `AppStoreVersionLocalizationsApi` | `list`, `get`, `update`, `delete` |
| `AppInfoLocalizationsApi` | `list`, `get`, `update` |
| `AppScreenshotsApi` | `sets`, `ensureSet`, `list`, `upload`, `delete`, `deleteAll`, `awaitProcessing` |
| `AssetUploader` | Chunked transfer to Apple's asset host, plus the MD5 |
| `FastlaneIosMetadata` | `locales`, `listing`, `screenshots`, `unmappedScreenshots` |
| `FastlaneIosListing` | One locale's text, split into its two halves |

### Command line

`dart run colaxy_store_publish:publish` — `--check`, `--doctor`, `--dry-run`,
`--metadata=DIR`, `--locales=a,b`, `--replace-screenshots`,
`--feature-graphic`, `--error-if-in-review`, `--skip-check`, `--allow-empty`.
Credentials come from `PLAY_KEY_JSON` and `PLAY_PACKAGE`.

`dart run colaxy_store_publish:publish-ios` — `--doctor`, `--root=DIR`,
`--locales=a,b`, `--no-app-info`, `--no-version-text`, `--no-screenshots`,
`--replace-screenshots`, `--no-wait`, `--platform=IOS`. Credentials come from
`ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_P8` and `ASC_APP_ID`.

Both exit `0` on success, `1` when the store rejected something or a check
found errors, `64` for bad arguments or missing credentials. See `--help`.

### Values

| Type | Notes |
|---|---|
| `PlayImageType` | The nine `imageType` slots, minus `appImageTypeUnspecified` |
| `PlayReleaseStatus` | `draft`, `inProgress`, `halted`, `completed` |
| `ChangesInReviewBehavior` | What committing does to a review in flight |
| `PlayAiGeneratedState` | The developer's AI attestation on an image |
| `PlayEditState` | `open`, `committed`, `discarded` |
| `ScreenshotDisplayType` | All 33 App Store device slots, plus `byCaptureName` |
| `AppStoreVersionState` | 20 values; only `PREPARE_FOR_SUBMISSION` is writable |
| `AppVersionState` | 15 values — a **different** enum on the same resource |

### Failures

Errors are raised as `colaxy_store_console`'s exception hierarchy, so a
pipeline that reads and writes has one set to handle. Added here:

| Exception | Meaning |
|---|---|
| `PlayEditConflictException` | Another edit was committed first; never retried |
| `PlayEditExpiredException` | The edit is gone, or the app is not visible |
| `FastlaneLayoutException` | The local layout cannot produce a request |

## Not verified against a live account

Every claim above comes from reading the specifications — the
`androidpublisher/v3` generated client for Google Play, Apple's own OpenAPI
document (4.4.1) for the App Store — and from tests against a mock. **No call
in this package has been made against a real store account yet.**

In this repository's experience that gap has produced real errors before, so
treat the first run against a live app as the verification step:

- **Google Play**: `--check`, then `--doctor`, then `--dry-run`. The dry run
  is Google's own validation, so it is a genuine rehearsal.
- **App Store**: `--doctor` reads only. There is no dry run to follow it with,
  so start with `--locales=` naming one locale and `--no-screenshots`, and
  widen from there.

Two mappings are secondary sources rather than specification, and are marked
in the code as well: `ipadPro13` → `APP_IPAD_PRO_3GEN_129`, and the claim that
writing through a non-editable `appInfo` silently no-ops.
