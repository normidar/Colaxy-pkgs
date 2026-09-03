# colaxy_store_publish

Publish Android listings, screenshots and app bundles to Google Play from pure
Dart.

Reads the `fastlane supply` directory layout — the one `colaxy_localization`
and `colaxy_screenshot` already write — so it drops in where `fastlane supply`
was, without a Ruby toolchain.

```dart
final publisher = await PlayPublisher.authenticate(
  account: PlayServiceAccount.fromFile('secrets/play-api.json'),
  packageName: 'com.example.app',
);

await publisher.edit(
  PlayMetadataPublisher(metadata: FastlaneMetadata.forProject('.')).publish,
);
```

## Google Play only

This package does not touch App Store Connect, and will not grow a unified
interface over both.

| | Google Play | App Store Connect |
|---|---|---|
| Metadata over an API | yes | yes, differently |
| Screenshots over an API | yes, one call | reservation + chunked upload |
| **Binary over an API** | **yes** (`bundles.upload`) | **no** — Transporter or `notarytool` |
| **Transactional** | **yes** (`edits`, with commit and rollback) | **no** — changes apply as they are made |

Wrapping both in one type would claim things that are only true of one of them.
The most damaging would be rollback: an interrupted Play publish leaves
*nothing* behind, and code written against a shared interface would assume the
same of Apple, where it is false.

## What it replaces

`fastlane supply` — all of it. Metadata, images, app bundles, and tracks.

`deliver` and `pilot` are Apple's, and are out of scope. So is `gym`: wrapping
`xcodebuild` in Dart calls the same binary and improves nothing.

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
> `colaxy_screenshot` writes the feature graphic there, as a single
> locale-independent file, rather than at
> `<locale>/images/featureGraphic.png`. `fastlane supply` never picked it up
> either. It is exposed as `FastlaneMetadata.strayFeatureGraphic` and published
> only when `PlayPublishOptions.uploadStrayFeatureGraphic` is on, because
> sending one image to every locale is a decision rather than a detail.

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

### Values

| Type | Notes |
|---|---|
| `PlayImageType` | The nine `imageType` slots, minus `appImageTypeUnspecified` |
| `PlayReleaseStatus` | `draft`, `inProgress`, `halted`, `completed` |
| `ChangesInReviewBehavior` | What committing does to a review in flight |
| `PlayAiGeneratedState` | The developer's AI attestation on an image |
| `PlayEditState` | `open`, `committed`, `discarded` |

### Failures

Errors are raised as `colaxy_store_console`'s exception hierarchy, so a
pipeline that reads and writes has one set to handle. Added here:

| Exception | Meaning |
|---|---|
| `PlayEditConflictException` | Another edit was committed first; never retried |
| `PlayEditExpiredException` | The edit is gone, or the app is not visible |
| `FastlaneLayoutException` | The local layout cannot produce a request |

## Not verified against a live account

Every claim above comes from reading the `androidpublisher/v3` client and from
tests against a mock. **No call in this package has been made against a real
Play Console account yet.** In this repository's experience that gap has
produced real errors before, so treat the first run against a live app as the
verification step: use `dryRun: true`, and start with one locale.
