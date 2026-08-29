# colaxy_store_console

One Dart API over **Google Play Console** and **App Store Connect** — reviews
and statistics from both stores, without writing the JWT signing, the
JSON:API paging, the gzip and UTF-16 report decoding, or the two vendors'
different error shapes yourself.

Covered: reviews (read and reply), App Store sales and subscriptions, App
Store analytics, Android vitals, and Google Play's installs, ratings and
review history.

```dart
final console = await StoreConsole.connect(
  playAccount: PlayServiceAccount.fromFile('secrets/play-api.json'),
  packageName: 'com.example.app',
  appStoreKey: AppStoreApiKey.fromP8File(
    keyId: 'ABCD123456',
    issuerId: '69a6de70-0000-0000-0000-1f2c3d4e5f60',
    path: 'secrets/AuthKey_ABCD123456.p8',
  ),
  appId: '6740000000',
);

const needsAnswer = ReviewQuery(ratings: {1, 2}, hasReply: false);
await for (final review in console.reviews.list(needsAnswer)) {
  print('${review.store.displayName} ${review.rating}★ ${review.body}');
  await console.reviews.reply(review.id, 'Sorry — write to us at …');
}

console.close();
```

Either store can be left out, so the same code works for an Android-only or
iOS-only app.

## Features

- **Both stores, one model.** `StoreReview`, `ReviewReply`, `ReportTable`,
  `StoreMetric` and `StoreConsoleException` are the same shape whichever
  store answered, and every result carries the `Store` it came from.
- **Replies, including edits.** `reply()` creates or replaces a response.
  Google's documented 350-character limit is enforced locally, so an
  over-long reply fails before it costs one of the 2,000 daily writes.
- **Paging handled.** `list()` is a lazy `Stream` that fetches the next page
  only as you consume it; `listPage()` hands you a cursor to persist.
- **Reports decoded.** Apple's headerless gzip TSV and Google's UTF-16LE
  quoted CSV both come back as a `ReportTable` you read by column name.
- **The stores' worst errors, pre-empted.** Impossible report combinations,
  missing dimensions and out-of-range granularities are rejected locally,
  naming the parameter actually at fault — which the stores' own messages
  routinely do not.
- **Errors you can act on.** `StoreAuthException`, `StoreRateLimitException`,
  `ReviewNotFoundException`, with retry and backoff already applied.
- **Escape hatches.** `StoreReview.raw` keeps the original payload, and
  `AppStoreConnectClient`, `PlayReportingClient` and `PlayStorageClient` are
  plain authenticated clients you can point at any endpoint of their API.

## What is covered

| | Google Play | App Store |
| --- | --- | --- |
| Reviews, replies | `reviews` | `reviews` |
| Review history | `PlayReportType.reviews` (CSV) | `reviews` (full) |
| Ratings | `PlayReportType.ratings` (CSV) | — no report exists |
| Installs / downloads | `PlayReportType.installs` (CSV) | `SalesReportType.installs` |
| Sales, subscriptions | — not exposed | `salesReports` |
| Crashes, ANRs, memory | `PlayVitalsApi` | `analytics` (PERFORMANCE) |
| Store listing traffic | `PlayReportType.storePerformance` (CSV) | `analytics` (APP_STORE_ENGAGEMENT) |

"CSV" means Google publishes it only as a monthly file in a Cloud Storage
bucket, with no API behind it.

## Install

```yaml
dependencies:
  colaxy_store_console: ^0.1.0
```

A pure Dart package: it runs in scripts, CI jobs and servers. Deliberately
not in a Flutter app — see [Where to keep them](#where-to-keep-them).

## Credentials

Each surface needs its own set, and they are independent — you can set up one
store, or one API, and leave the rest. What each needs:

| Surface | Needs |
| --- | --- |
| App Store reviews | Team API key (Customer Support) + **app ID** |
| App Store analytics | Team API key (Admin to register) + **app ID** |
| App Store sales | Team API key (Sales / Finance) + **vendor number** |
| Play reviews | Service account + Play Console invitation |
| Play vitals | The same, plus the reporting scope |
| Play report CSVs | The same, plus the storage scope + **bucket ID** |

Two things to note before you start:

- **Two values cannot be fetched from any API.** The App Store **vendor
  number** and the Play **bucket ID** appear only on a console screen, so
  both have to be configured by hand.
- **No single App Store role covers everything.** Reviews and sales are
  separate concerns to Apple; covering both means an Admin key or two keys.

### App Store Connect

**1. Create a team API key.** In **Users and Access → Integrations → App
Store Connect API**, use the **Team Keys** tab and click **+**.

The tab matters: an *individual* key cannot reach the sales and finance
report endpoints at all, whatever role its owner has. If sales reports return
`403` on a key that reads reviews fine, this is usually why.

Pick a role covering what you need:

| Role | Reviews | Reply | Sales reports | Analytics |
| --- | --- | --- | --- | --- |
| Customer Support | ✅ | ✅ | — | — |
| Sales | — | — | ✅ | download only |
| Finance | — | — | ✅ | download only |
| Admin | ✅ | ✅ | ✅ | ✅ |

Two wrinkles in that table:

- **Registering an analytics report request needs Admin.** Once a report type
  has been requested for the app, a Sales or Finance key can download the
  generated reports. So `analytics.createRequest` may need an Admin key even
  though collecting afterwards does not — run
  `verify --allow-writes` once with Admin, then collect with a narrower key.
- **No single narrow role covers reviews *and* sales.** They are separate
  concerns to Apple. Use two keys, or accept Admin.

An API key's name and access level cannot be edited after creation; changing
either means revoking it and making a new one.

The **`.p8` file downloads exactly once**. Store it somewhere you can restore
from; Apple will not give it to you again, and the only remedy is a new key.

That page also shows the two IDs you need: the **key ID** (10 characters,
next to the key) and the **issuer ID** (a UUID, above the key list — one per
team, shared by every key).

**2. Find the app ID.** Open the app in App Store Connect and read it out of
the URL:

```text
https://appstoreconnect.apple.com/apps/6740000000/appstore
                                        ^^^^^^^^^^
```

This is the app's *resource* ID. It is **not** the bundle ID
(`com.example.app`) and not the App Store listing ID, both of which are
rejected.

**3. Find the vendor number** — sales reports only. **Payments and Financial
Reports**, shown near the top of the page, usually eight digits. No API
returns it.

It identifies the *account*, not the app: one sales report covers every app
you publish, keyed by SKU. There is no per-app filter, so filter by SKU after
the fact.

```dart
final console = AppStoreConnectConsole(  // reviews, analytics
  apiKey: AppStoreApiKey.fromP8File(
    keyId: 'ABCD123456',
    issuerId: '69a6de70-0000-0000-0000-1f2c3d4e5f60',
    path: 'secrets/AuthKey_ABCD123456.p8',
  ),
  appId: '6740000000',
);

final team = AppStoreTeam(               // sales reports
  apiKey: key,
  vendorNumber: '85000000',
);
```

In CI, pass the key as a string instead — see [Where to keep
them](#where-to-keep-them).

### Google Play

**1. Enable the APIs.** In Google Cloud, for the project you will use:

| API | Needed for |
| --- | --- |
| Google Play Android Developer API | Reviews |
| Google Play Developer Reporting API | Vitals |
| Cloud Storage API | Report CSVs |

**2. Create a service account** and download its JSON key from its **Keys**
tab. Take the *service account* key, not an OAuth client secret — this
package rejects the latter by name, because downloading the wrong one is an
easy slip.

**3. Invite it in Play Console.** Under **Users and permissions**, invite the
service account's email address (`…@….iam.gserviceaccount.com`) and grant it:

| Permission | Needed for |
| --- | --- |
| View app information | Reading anything |
| Reply to reviews | `reply()` |
| View financial data | Report CSVs |

**Step 3 is the one that gets missed.** Without it every call fails with
`401` despite a perfectly valid key, which is why this package's `401`
message names it.

**4. Find the bucket ID** — report CSVs only. **Download reports**, then the
**Copy Cloud Storage URI** button beside any section, or the *Direct Report
URIs* block at the foot of the page:

```text
gs://pubsite_prod_1234567898765432100/stats/installs/
     ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
```

Paste the whole thing — the scheme and path are trimmed for you. It is one
bucket per developer account, and no API returns it. Older accounts show
`pubsite_prod_rev_…`; either is fine.

**5. Grant bucket access at the account level.** This one deserves its own
step, because the obvious fixes do not work. The bucket belongs to Google,
not to your Cloud project, so **no GCP IAM role reaches it** — Storage Admin,
project Owner, none of them. Only Play Console grants it:

**Users and permissions → the service account → the *Account permissions*
tab → View app information and download bulk reports**

Granting that on the **Apps** tab instead is the most common cause of
`storage.objects.list denied`, and it looks correct while failing. Changes
can take **up to 24 hours** to reach the bucket, so a fresh grant that still
403s may just need waiting out.

**6. Request the scopes you need.** They are different per API, and a token
minted for one is rejected by the others in a way that looks like a bad key:

```dart
final account = PlayServiceAccount.fromFile('secrets/play-api.json');

// Reviews. The default, so `scopes:` can be omitted.
final console = await GooglePlayConsole.connect(
  account: account,
  packageName: 'com.example.app',
);

// Vitals and report CSVs. One client can cover both — then pass
// `ownsClient: false` so the first close() does not shut it for the other.
final client = await account.authenticate(
  scopes: [
    PlayServiceAccount.reportingScope,
    PlayServiceAccount.storageReadScope,
  ],
);
```

### Where to keep them

These are account-wide credentials. An App Store `.p8` can post replies as
you and read your revenue; a Play service-account key can do the same on that
side. Neither belongs in a repository, and the `.p8` in particular downloads
exactly once — committing one means revoking it and reissuing.

**Locally**, keep them outside the repo, or in an ignored directory:

```sh
secrets/                 # add to .gitignore, along with *.p8 and .env
├── AuthKey_ABCD123456.p8
└── play-api.json
```

```dart
AppStoreApiKey.fromP8File(… path: 'secrets/AuthKey_ABCD123456.p8');
PlayServiceAccount.fromFile('secrets/play-api.json');
```

Check the ignore actually covers them before the first commit — `secrets/` is
not ignored by default in most templates:

```sh
git check-ignore -v secrets/AuthKey_ABCD123456.p8   # must print a rule
```

**For local runs**, `dart run colaxy_store_console:verify --help` lists every
variable and where each comes from. There is also an
[`.env.example`][env-example] in the repository to copy:

```sh
cp .env.example .env      # .env is git-ignored
set -a && . ./.env && set +a
```

[env-example]: https://github.com/normidar/colaxy-pkgs/blob/main/packages/colaxy_store_console/.env.example

**In CI**, use the runner's secret store and pass the contents rather than a
path. Both key types have string constructors for exactly this:

```dart
AppStoreApiKey(
  keyId: Platform.environment['ASC_KEY_ID']!,
  issuerId: Platform.environment['ASC_ISSUER_ID']!,
  privateKey: Platform.environment['ASC_P8']!,
);
PlayServiceAccount.fromJsonString(Platform.environment['PLAY_KEY_JSON']!);
```

A multi-line PEM survives a round trip through most secret stores, but not
all of them: some return it with literal `\n` sequences, others with CRLF
line endings. Both are repaired on the way in, so
`ASC_P8="$(cat AuthKey_….p8)"` and a flattened single-line secret both work.

The app ID, vendor number and bucket ID are not secrets — they identify, they
do not authorise. Committing those is fine.

**Never ship any of this inside an app.** These credentials cover the whole
account, not one user, and an app binary is readable. Neither store's API is
callable from a shipped client anyway, which is why this package is pure Dart
rather than a Flutter plugin.

### Checking it works

Rather than debugging a `401` by hand, point the verifier at your account —
it reports each surface separately and names the likely cause of a failure:

```sh
dart run colaxy_store_console:verify --help
```

## Reviews

Read reviews from either store, or both at once, and answer them.

### Reading

```dart
// Lazy stream across every configured store, paging as you consume it.
await for (final review in console.reviews.list()) { … }

// Or one page at a time, when you persist a cursor between runs.
var page = await console.googlePlay!.reviews.listPage();
while (!page.isLast) {
  handle(page.reviews);
  page = await console.googlePlay!.reviews.listPage(
    ReviewQuery(cursor: page.nextCursor),
  );
}
```

`list()` drains one store fully before starting the next, and stops issuing
requests as soon as you stop consuming — so breaking out early does not spend
Play quota on pages you will not read. For a chronological merged view, sort
the collected results by `StoreReview.timestamp`.

### Replying

```dart
// Routed to whichever store owns the review — costs a lookup first.
await console.reviews.reply(review.id, 'Thanks for the report!');

// Cheaper when you already know: review.store tells you.
await console.appStore!.reviews.reply(review.id, 'Thanks!');

// App Store only.
await console.appStore!.reviews.deleteReply(review.id);
```

Replying again to a review that already has a reply replaces it on both
stores; neither keeps a history.

### Support, per store

The two APIs are not equivalent, and this package does not paper over the
gaps. `ReviewQuery` fields that a store cannot honour are marked below.

| | Google Play | App Store |
| --- | --- | --- |
| History reachable | **last 7 days only** | full |
| Ratings without text | **not returned** | returned |
| `ratings` filter | client-side, per page | server-side |
| `hasReply` filter | client-side, per page | server-side² |
| `sort` | **ignored** | server-side |
| `territories` filter | **ignored** (never reported) | server-side |
| `translationLanguage` | server-side | **ignored** |
| Reply length | 350, enforced locally | undocumented, not enforced¹ |
| Reply state | always published | may be `pendingPublish` |
| Delete a reply | not supported | `deleteReply()` |
| Quota | 200 reads/hour, 2,000 replies/day, per app | per key |

¹ Apple publishes no limit for `responseBody` — not in its help, its API
reference, or its OpenAPI spec, where the field is an unconstrained string.
The widely-quoted 5,970 is community-measured, so this package exposes it as
`AppStoreReviewsApi.advisoryReplyLength` to warn with, and does not block on
it. Google's 350 *is* documented, so that one is enforced.

² Apple's `exists[publishedResponse]` counts only *published* responses, so a
reply still pending publication reads as "no reply".

Two consequences worth designing around:

- **Google Play's seven-day window is not a bug you can work around.** For
  history, either poll on a schedule and store the results yourself, or read
  the monthly review CSVs via `PlayReportType.reviews` — those are not
  limited to a week, but they cannot be replied to.
- **Client-side filtering makes Play pages ragged.** A page can come back
  holding fewer reviews than you asked for — or none — while more still
  remain. Drive paging off `ReviewPage.isLast` or the returned cursor, never
  off the page length.

## Statistics

### App Store sales and subscriptions

Sales and Trends reports are **team-scoped**, not app-scoped: one report
covers every app under the account, keyed by SKU, and the API offers no way to
ask for a single app. So they hang off `AppStoreTeam`, keyed by your **vendor
number** (App Store Connect → Payments and Financial Reports — no API returns
it, so it has to be configured).

```dart
final team = AppStoreTeam(apiKey: key, vendorNumber: '85000000');

final table = await team.salesReports.fetch(
  SalesReportQuery.sales(date: DateTime.utc(2026, 8, 20)),
);
for (final row in table.entries) {
  print('${row['SKU']}: ${row.intAt('Units')} units');
}

team.close();
```

`SalesReportQuery` encodes Apple's allowed-values table, so an impossible
combination fails locally naming the parameter actually at fault. That matters
more than it sounds: Apple answers a bad *frequency* with `INVALID_COMBINATION`
and the detail "Invalid combination of date type and date", sending you off to
debug a date that was fine.

A few things the API does not make obvious:

- **A `404` means zero sales that period, not a failure.** `fetch` returns an
  empty table. A generated report always has a header row, so
  `table.columns.isEmpty` tells "no report" apart from "report with no rows".
- **Date format follows the frequency.** Daily and weekly take `YYYY-MM-DD`,
  monthly `YYYY-MM`, yearly `YYYY`. `SalesReportQuery` handles it.
- **Weekly reports are addressed by the Sunday that closes the week.** Use
  `SalesFrequency.endOfWeek(date)`. Any other day throws — Apple is reported
  to snap some of them to a week boundary instead of rejecting them, and
  quietly receiving a different week is worse than an error.
- **`version` is not validated.** Apple's published versions and the ones its
  API accepts have drifted apart, so an explicit `version:` is passed through
  untouched. Left unset, you get the newest Apple documents.
- **Reports lag.** Daily the next day, weekly on Mondays, monthly five days
  after month end, yearly six days after year end. Daily/weekly/monthly are
  kept one year, yearly ten, and are not regenerated after that.

### Google Play vitals

Crash rate, ANR rate and the rest of Android vitals, through the Play
Developer Reporting API. That API is in neither `googleapis` nor
`googleapis_beta`, so this is a hand-written client — and it needs a
**different scope** from reviews:

```dart
final client = PlayReportingClient(
  authenticatedClient: await account.authenticate(
    scopes: [PlayServiceAccount.reportingScope],
  ),
);
final api = PlayVitalsApi(client: client, packageName: 'com.example.app');

// Recent buckets are still moving, so stop where Google says data is settled.
final freshness = await api.freshness(VitalsMetricSet.crashRate);
final metrics = await api.query(
  VitalsQuery(
    metricSet: VitalsMetricSet.crashRate,
    metrics: const ['userPerceivedCrashRate', 'distinctUsers'],
    from: DateTime.utc(2026, 8, 2),
    to: freshness.clamp(DateTime.now().toUtc(), AggregationPeriod.daily),
  ),
);

print(metrics['userPerceivedCrashRate']?.average);
api.close();
```

Things that bite:

- **A daily bucket is an `America/Los_Angeles` day**, not a UTC one — Google
  calls this a historical constraint and offers no alternative. So a Play
  "day" and an App Store "day" cover different 24-hour windows. Dates come
  back as the civil date Google reported, labelled UTC, so they match Play
  Console rather than drifting off it.
- **A token minted for the Android Publisher scope is rejected here**, and the
  rejection looks like a bad key. The `401`/`403` message names the scope.
- **`errorCountMetricSet` requires the `reportType` dimension** on every
  query; `VitalsQuery` rejects it locally, since Google's error does not say
  which dimension is missing.
- **Rolling averages (`…7dUserWeighted`) are daily only.** Also rejected
  locally.
- **Metric names are not validated** — Google adds them without notice.
  `VitalsMetricSet.metrics` lists the documented ones for reference.
- **Installs, ratings and revenue are not here.** Google only publishes those
  as CSVs in a Cloud Storage bucket.

Google returns one row per bucket carrying every requested metric;
`PlayVitalsApi.query` pivots that into one `StoreMetric` per metric name. A
metric with no data is absent from the map rather than present and empty, so
"no data" stays distinguishable from "zero".

### Google Play installs, ratings and review history

Google publishes these **only as CSVs** in the developer's Cloud Storage
bucket — no API covers them. That makes this the only route to installs, to
store performance, to review history beyond seven days, and to a real rating
average (the reviews API omits ratings that carry no text, so an average
computed from it is wrong).

```dart
final api = PlayReportsApi(
  client: PlayStorageClient(
    authenticatedClient: await account.authenticate(
      scopes: [PlayServiceAccount.storageReadScope],
    ),
  ),
  // Paste the whole URI from Play Console's "Copy Cloud Storage URI" button;
  // the scheme and path are trimmed for you.
  bucket: 'gs://pubsite_prod_1234567898765432100/stats/installs/',
  packageName: 'com.example.app',
);

final table = await api.fetch(
  PlayReportType.installs,
  month: DateTime.utc(2026, 8),
  dimension: 'country',
);
```

The bucket ID is per developer account, lives only on the **Play Console →
Download reports** page, and appears in no API — so it has to be configured.
The service account needs `storageReadScope` *and* an invitation in Play
Console, the same two-step setup as reviews.

Breakdowns differ per report — `crashes` has no `carrier`, `store_performance`
has no `overview` — and asking for one that does not exist returns a `404`
indistinguishable from a month with no data, so `PlayReportType` rejects those
locally. A month Google has not published comes back as an empty table.

Rather than guessing month names, list what exists:

```dart
for (final name in await api.list(PlayReportType.ratings)) print(name);

await for (final table in api.fetchAll(
  PlayReportType.ratings,
  dimension: 'overview',
)) {
  // every published month, oldest first
}
```

### App Store analytics

Impressions, product page views, downloads by source, sessions, retention.
This is the one asynchronous surface in the package. Nothing is queryable —
you register a standing *request*, Apple generates *reports* under it, each
report has dated *instances*, and each instance is split into *segments* that
hold the gzipped TSV:

```text
request  →  report  →  instance  →  segment  →  gzip TSV
```

```dart
// Once, at setup. The first data lands 24–48 hours later.
await console.appStore!.analytics.createRequest(AnalyticsAccessType.ongoing);

// Later, on a schedule.
final api = console.appStore!.analytics;
final request = await api.ensureRequest(AnalyticsAccessType.ongoing);

for (final report in await api.reports(
  request.id,
  category: AnalyticsReportCategory.appStoreEngagement,
)) {
  for (final instance in await api.instances(
    report.id,
    granularity: AnalyticsGranularity.daily,
  )) {
    final table = await api.downloadInstance(instance.id);
  }
}
```

Design around these:

- **Registering and reading are separate calls.** A job that creates a request
  and reads it always reads nothing.
- **Unused requests are stopped and their data deleted.** Apple flags this as
  `stoppedDueToInactivity`, and every ID beneath a stopped request goes dead.
  `ensureRequest` skips stopped requests and registers a fresh one.
- **Instances expire.** Apple keeps them "for a limited period". Treat this as
  a pipeline that runs regularly and stores its own copy.
- **Segment URLs are pre-signed and expire.** List them immediately before
  downloading; an expired one throws `StoreApiException`.
- **Report names are prose, and Apple has renamed them.** Filter by
  `category`, not `name`.

`downloadInstance` joins an instance's segments for you. Each segment is an
independent file with its own header row, so only the concatenation is the
report — and `ReportTable.concat` throws if two segments disagree on columns
rather than shifting every value one column across.

### Reading reports

Every store report is read through these:

| Type | What it is |
| --- | --- |
| `ReportTable` / `ReportRow` | A report as a header plus rows, read by column name. `.fromTsv`, `.fromGzippedTsv`, `.fromCsvBytes`. |
| `TsvDecoder` | Apple's gzipped TSV, decompressed by magic number — Apple sends no `Content-Encoding`. |
| `CsvDecoder` | Google's report CSVs: UTF-16LE with a BOM, and genuinely quoted. |
| `StoreMetric` / `MetricPoint` | A date/value/dimensions series, with `total`, `average`, `byDate`, `whereDimension`. |

Reports are handed over as tables rather than typed models on purpose:
Apple's `SALES` and `SUBSCRIBER` reports share almost no columns, and both
stores rename headers between report versions. Cells stay as strings until you
convert them, so exact money is still reachable through `row['Developer
Proceeds']` when `decimalAt` would round it.

```dart
final table = ReportTable.fromGzippedTsv(bytes);
for (final row in table.entries) {
  print('${row.dateAt('Begin Date')}: ${row.intAt('Units')}');
}
```

`MetricUnit` records whether values may be summed. Summing a crash *rate* is
the usual way this kind of code produces confident nonsense, so `total` and
`average` are documented per unit rather than offered interchangeably.

## Operating notes

### Retries and logging

Every client backs off and retries throttling (`429`, and Google Play's `403
quotaExceeded` / `RESOURCE_EXHAUSTED`) and transient server errors, three
attempts by default. A
`Retry-After` header wins over the backoff curve, capped so a misreported
value cannot stall a job.

```dart
final console = await StoreConsole.connect(
  // …credentials…
  retryPolicy: const RetryPolicy(maxAttempts: 5),
  onLog: (message) => stderr.writeln('[store] $message'),
);
```

Nothing is logged unless you pass `onLog`. Pass `RetryPolicy.none()` to see
failures immediately — worth doing inside a job that is itself retried.

### Sharing a client

Each client closes the transport it owns. `AppStoreConnectClient` works that
out for itself: it closes a client it created and leaves one you passed in
alone. The Play clients cannot — an authenticated client always comes from
`PlayServiceAccount.authenticate` — so they take `ownsClient`, which defaults
to `true`.

One `authenticate` call can cover several APIs, and then the first `close()`
would shut the client the others still need:

```dart
final client = await account.authenticate(
  scopes: [
    PlayServiceAccount.reportingScope,
    PlayServiceAccount.storageReadScope,
  ],
);

final vitals = PlayVitalsApi(
  client: PlayReportingClient(authenticatedClient: client, ownsClient: false),
  packageName: 'com.example.app',
);
final reports = PlayReportsApi(
  client: PlayStorageClient(authenticatedClient: client, ownsClient: false),
  bucket: bucket,
  packageName: 'com.example.app',
);

// …then close the one you made.
client.close();
```

On the App Store side, `reviews` and `analytics` share their console's
transport, so close the console rather than either of them.

### Handling failures

```dart
try {
  await api.reply(id, body);
} on StoreRateLimitException catch (e) {
  await Future<void>.delayed(e.retryAfter ?? const Duration(minutes: 5));
} on StoreAuthException catch (e) {
  stderr.writeln(e.message);  // names the likely setup mistake
} on StoreApiException catch (e) {
  stderr.writeln('${e.statusCode} ${e.code}: ${e.detail}');
}
```

`reply()` throws `ArgumentError` for an empty body, and for one over Google's
documented 350 characters, before any request goes out.

### Reaching past this package

Nothing here is a wall. Every model keeps the payload it came from, and every
client is usable directly.

```dart
// The original payload: a googleapis `Review`, or the decoded JSON:API map.
final original = review.raw;

// Any App Store Connect endpoint, authenticated, retried and error-mapped.
final apps = await console.appStore!.client.getJson('/v1/apps');

// Any Play Developer Reporting endpoint.
await reportingClient.postJson('apps/com.example.app/anrRateMetricSet:query', {…});

// Any object in the Play report bucket, including report families this
// package does not model — subscriptions and buyer acquisition have their
// own file-name grammars.
await playReports.fetchObject('financial-stats/subscriptions/…csv');
```

## Examples

Runnable scripts in [`example/`](example), each driven by environment
variables:

| File | What it does |
| --- | --- |
| `colaxy_store_console_example.dart` | Answers unreplied 1- and 2-star reviews on both stores. |
| `sales_report_example.dart` | Sums a week of App Store units and proceeds, per SKU. |
| `play_vitals_example.dart` | Three weeks of Android crash rate, worst countries first. |
| `play_reports_example.dart` | Play installs by country, plus the real rating average. |
| `app_store_analytics_example.dart` | Registers an analytics request, then collects what exists. |

## API reference

### Entry points

| Type | What it is |
| --- | --- |
| `StoreConsole` | One app across both stores. `StoreConsole.connect(…)` builds it. |
| `GooglePlayConsole` | One app on Google Play: `reviews`. |
| `AppStoreConnectConsole` | One app on the App Store: `reviews`, `analytics`. |
| `AppStoreTeam` | One App Store *account*: `salesReports`, keyed by vendor number. |
| `PlayVitalsApi` / `PlayReportsApi` | Android vitals and the Play report CSVs, built directly. |

Everything here has a `close()` you must call, or the process will not exit.
An `AppStoreTeam` and an `AppStoreConnectConsole` for the same account can
share one `AppStoreConnectClient`, and then share its cached token too.

### Reviews

| Type | What it is |
| --- | --- |
| `StoreReviewsApi` | `list`, `listPage`, `get`, `reply`, `close`. Implemented by both stores. |
| `PlayReviewsApi` / `AppStoreReviewsApi` | The per-store implementations. |
| `MergedReviewsApi` | Fans out across stores. `listPage` is unsupported there — cursors are per-store. |
| `ReviewQuery` | `pageSize`, `cursor`, `sort`, `ratings`, `territories`, `hasReply`, `translationLanguage`. |
| `ReviewPage` | `reviews`, `nextCursor`, `total`, `isLast`. |
| `StoreReview` | See the table below. |
| `ReviewReply` | `body`, `id`, `lastModified`, `state`. |

`StoreReview` fields a store does not provide are `null` rather than faked:

| Field | Google Play | App Store |
| --- | --- | --- |
| `id`, `rating`, `authorName`, `reply` | ✅ | ✅ |
| `body` | ✅ (always present) | may be `null` |
| `title` | — | ✅ |
| `createdAt` | — (Play reports only last-modified) | ✅ |
| `updatedAt` | ✅ | — |
| `territory` | — | ✅ (alpha-3) |
| `languageCode`, `appVersion`, `device`, `osVersion` | ✅ | — |
| `thumbsUp`, `thumbsDown` | ✅ | — |

Use `timestamp` (`createdAt ?? updatedAt`) when sorting across stores.

### Credentials and transport

| Type | What it is |
| --- | --- |
| `PlayServiceAccount` | `.fromFile`, `.fromJsonString`, or a decoded map. `authenticate(scopes: …)` for APIs beyond reviews. |
| `AppStoreApiKey` | `.fromP8File`, or key ID + issuer ID + PEM string. |
| `AppStoreTokenProvider` | Signs and caches the ES256 bearer token. |
| `AppStoreConnectClient` | Authenticated JSON client for any ASC endpoint, with `getPage` / `pages` for collections. |
| `PlayReportingClient` / `PlayStorageClient` | The same, for Android vitals and the report bucket. |
| `RetryPolicy` | Backoff and retry rules, shared by every client. |
| `StoreConsoleLog` | The `onLog` callback signature. |

### Statistics

| Type | What it is |
| --- | --- |
| `SalesReportsApi`, `SalesReportQuery` | App Store sales, subscriptions and installs. |
| `AnalyticsReportsApi` | App Store analytics: requests, reports, instances, segments. |
| `PlayVitalsApi`, `VitalsQuery`, `VitalsMetricSet` | Android vitals. |
| `PlayReportsApi`, `PlayReportType` | Google Play's monthly report CSVs. |
| `ReportTable`, `ReportRow` | A report as a header plus rows, read by column name. |
| `StoreMetric`, `MetricPoint`, `MetricUnit` | A date/value/dimensions series. |
| `MetricFreshness` | How far forward a vitals metric set has settled. |

### Errors

`StoreConsoleException` is the base; `StoreAuthException`,
`StoreApiException` (with `statusCode`, `code`, `detail`),
`StoreRateLimitException` (with `retryAfter`) and `ReviewNotFoundException`
derive from it. `googleapis`' `DetailedApiRequestError` never escapes.

## Verifying against your own account

This package's tests run against mocked HTTP. That proves the code does what
it was written to do; it cannot prove the two vendors' APIs behave the way
their documentation says — and parts of both are documented thinly or not at
all. A review of this package found a transcription error in Apple's
allowed-values table that no mocked test could have caught, because the tests
were written from the same transcription.

So before trusting a surface, point it at your account:

```sh
export ASC_KEY_ID=ABCD123456
export ASC_ISSUER_ID=69a6de70-0000-0000-0000-1f2c3d4e5f60
export ASC_P8="$(cat AuthKey_ABCD123456.p8)"
export ASC_APP_ID=6740000000

dart run colaxy_store_console:verify
```

```text
PASS  App Store credentials    signed a token for key ABCD123456 (312 chars)
PASS  App Store reviews        read 1 review of 412
SKIP  App Store sales reports  needs ASC_VENDOR_NUMBER
…
```

Every surface is independent, so supply the credentials you have and the rest
are skipped — and skipped is reported, not passed. It is read-only unless you
pass `--allow-writes`, which lets it register an analytics report request
(the one thing Apple gives no way to preview). `--help` lists the variables
per surface.

## Caveats worth repeating

- **A rating average cannot come from the review endpoints.** Google Play's
  reviews exclude ratings without text, so an average over
  `StoreReview.rating` will not match Play Console. Use
  `PlayReportType.ratings` on Android; the App Store publishes no rating
  report at all, so there the reviews are the only source and the same
  caveat does not apply.
- **"The same day" is three different days.** An App Store sales day, a Play
  vitals day (`America/Los_Angeles`) and a UTC day are different 24-hour
  windows. Comparing the two stores' daily figures without saying so
  overstates the precision.
- **Neither store is queryable in real time.** Every statistics surface here
  lags by a day or more, and two of them expire data you did not collect.
  These are pipelines to run on a schedule and store from, not APIs to read
  on demand.

## License

MIT — see [LICENSE](LICENSE).
