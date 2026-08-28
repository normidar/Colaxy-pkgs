# colaxy_store_console

One Dart API over **Google Play Console** and **App Store Connect**: read your
app's reviews from both stores and reply to them, without writing the JWT
signing, the JSON:API paging, or the two different error shapes yourself.

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

- **Both stores, one model.** `StoreReview`, `ReviewReply` and
  `StoreConsoleException` are the same shape whichever store answered, and
  every result carries the `Store` it came from.
- **Replies, including edits.** `reply()` creates or replaces a response.
  Length limits are checked locally, so an over-long reply fails before it
  costs quota.
- **Paging handled.** `list()` is a lazy `Stream` that fetches the next page
  only as you consume it; `listPage()` hands you a cursor to persist.
- **Errors you can act on.** `StoreAuthException`, `StoreRateLimitException`,
  `ReviewNotFoundException` — with messages that name the actual setup
  mistake rather than restating the HTTP status.
- **Escape hatches.** `StoreReview.raw` keeps the original payload, and
  `AppStoreConnectClient` is a plain authenticated JSON client you can point
  at any App Store Connect endpoint.

## Install

```yaml
dependencies:
  colaxy_store_console: ^0.1.0
```

This is a pure Dart package — it runs in scripts, CI jobs and servers, not in
a Flutter app (neither store's API is callable from a shipped client, and
neither should be: the credentials are account-wide).

## Credentials

### Google Play

1. In Google Cloud, enable the **Google Play Android Developer API**.
2. Create a service account and download its JSON key.
3. In **Play Console → Users and permissions**, invite the service account's
   email and grant it *View app information* to read and *Reply to reviews*
   to answer.

Step 3 is the one that gets missed. Without it every call fails with `401`
even though the key itself is valid — which is why this package's `401`
message names it.

### App Store Connect

In **App Store Connect → Users and Access → Integrations → App Store Connect
API**, create a key with a role that can read reviews and post responses
(**Customer Support** is the least-privilege role that covers replying;
**App Manager** also works). Keep the `.p8` — it downloads exactly once.

You need the **key ID**, the **issuer ID**, and the app's **resource ID** (the
number in the App Store Connect URL, `…/apps/6740000000/…` — not the bundle
ID).

In CI, pass the secrets as strings rather than files:

```dart
AppStoreApiKey(
  keyId: Platform.environment['ASC_KEY_ID']!,
  issuerId: Platform.environment['ASC_ISSUER_ID']!,
  privateKey: Platform.environment['ASC_P8']!,
);
```

A PEM that picked up literal `\n` or CRLF line endings on the way through a
secret store is repaired automatically.

## What each store actually supports

The two APIs are not equivalent, and this package does not paper over the
gaps. `ReviewQuery` fields that a store cannot honour are marked below.

| | Google Play | App Store |
| --- | --- | --- |
| History reachable | **last 7 days only** | full |
| Ratings without text | **not returned** | returned |
| `ratings` filter | client-side, per page | server-side |
| `hasReply` filter | client-side, per page | server-side¹ |
| `sort` | **ignored** | server-side |
| `territories` filter | **ignored** (never reported) | server-side |
| `translationLanguage` | server-side | **ignored** |
| Reply length | 350 characters | 5,970 characters |
| Reply state | always published | may be `pendingPublish` |
| Delete a reply | not supported | `deleteReply()` |
| Quota | 200 reads/hour, 2,000 replies/day, per app | per key |

¹ Apple's `exists[publishedResponse]` counts only *published* responses, so a
reply still pending publication reads as "no reply".

Two consequences worth designing around:

- **Google Play's seven-day window is not a bug you can work around.** If you
  need review history, poll on a schedule and store the results yourself.
- **Client-side filtering makes Play pages ragged.** A page can come back
  holding fewer reviews than you asked for — or none — while more still
  remain. Drive paging off `ReviewPage.isLast` or the returned cursor, never
  off the page length.

## Usage

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

### Retries and logging

Both clients back off and retry throttling (`429`, and Google Play's `403
quotaExceeded`) and transient server errors, three attempts by default. A
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

`reply()` throws `ArgumentError` for an empty or over-long body before any
request goes out.

### Reaching past this package

```dart
// The original payload: a googleapis `Review`, or the decoded JSON:API map.
final original = review.raw;

// Any App Store Connect endpoint, authenticated and error-mapped.
final apps = await console.appStore!.client.getJson('/v1/apps');
```

## API reference

### Entry points

| Type | What it is |
| --- | --- |
| `StoreConsole` | One app across both stores. `StoreConsole.connect(…)` builds it. |
| `GooglePlayConsole` | One app on Google Play. `GooglePlayConsole.connect(…)`. |
| `AppStoreConnectConsole` | One app on the App Store. Constructs synchronously. |

All three expose `reviews` and a `close()` you must call, or the process will
not exit.

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
| `RetryPolicy` | Backoff and retry rules, shared by both stores. |

### Errors

`StoreConsoleException` is the base; `StoreAuthException`,
`StoreApiException` (with `statusCode`, `code`, `detail`),
`StoreRateLimitException` (with `retryAfter`) and `ReviewNotFoundException`
derive from it. `googleapis`' `DetailedApiRequestError` never escapes.

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
- **Weekly reports must be requested by the Sunday that closes the week.**
  Use `SalesFrequency.endOfWeek(date)`; passing any other day throws rather
  than silently fetching a different week.
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

## Not yet implemented

Two of the four statistics surfaces. They share the transport, credential
and report layers above, but not much else — they differ in granularity,
freshness and even in which account they authenticate as:

- **Google Play installs, ratings and revenue** — only available as CSV
  reports in the developer's Cloud Storage bucket, not as an API.
- **App Store analytics** — the `analyticsReportRequests` family, an
  asynchronous request/report/instance/segment chain.

Note that neither store exposes a rating average through these review
endpoints, and Google Play's reviews exclude ratings without text — so an
average computed from `StoreReview.rating` will not match Play Console.

## License

MIT — see [LICENSE](LICENSE).
