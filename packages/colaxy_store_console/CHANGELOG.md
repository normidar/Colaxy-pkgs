## 0.1.0

First release. Reviews and statistics across Google Play Console and App
Store Connect.

The `0.1.0` and `0.2.0` split that this file previously showed was never
published; both are folded together here so the versions listed match the
versions you can actually depend on.

### Entry points
- `StoreConsole` over `GooglePlayConsole` and `AppStoreConnectConsole`,
  either of which may be omitted for a single-platform app.
- `AppStoreTeam`, separate from the app-scoped console because Apple's sales
  reports are keyed by vendor number and cover the whole account at once.

### Reviews
- `StoreReviewsApi` with `list` (a lazy, auto-paging `Stream`), `listPage`
  (cursor-based), `get` and `reply`, implemented for both stores and fanned
  out by `MergedReviewsApi`.
- `ReviewQuery` filters. App Store Connect handles `ratings`, `territories`,
  `hasReply` and `sort` server-side; Google Play, which has no equivalent,
  applies `ratings` and `hasReply` per page and ignores the rest.
- Unified `StoreReview` and `ReviewReply`, with `raw` keeping the original
  store payload.
- Reply length is validated locally — 350 characters on Google Play, 5,970 on
  the App Store — so an over-long reply fails before it costs quota.
- `AppStoreReviewsApi.deleteReply`, which Google Play has no equivalent for.

### App Store statistics
- `SalesReportsApi` for Sales and Trends: units, proceeds, subscriptions and
  installs.
- `SalesReportQuery` with `SalesReportType`, `SalesReportSubType`,
  `SalesFrequency` and `SalesReportCombination` — Apple's allowed-values
  table as types. An impossible combination throws locally naming the
  parameter actually at fault; Apple's own error blames the date. `version`
  is passed through unvalidated, since Apple's published versions and the
  ones its API accepts have drifted apart.
- `SalesFrequency.formatDate` and `.endOfWeek`: the per-frequency
  `reportDate` formats, and the Sunday a weekly report must be requested by.
- `AnalyticsReportsApi` on `AppStoreConnectConsole.analytics`: the
  request → report → instance → segment chain. Registering and collecting are
  separate calls, because the first data lands 24–48 hours after
  registration. `ensureRequest` reuses a live request and registers a new one
  only when the existing ones have been stopped for inactivity, which kills
  every ID beneath them.

### Google Play statistics
- `PlayVitalsApi` over the Play Developer Reporting API — crash rate, ANR
  rate, memory and more. Hand-written, because that API is in neither
  `googleapis` nor `googleapis_beta`.
- `VitalsQuery` rejects the two restrictions whose Google-side errors do not
  name the cause: `errorCountMetricSet` requires the `reportType` dimension,
  and rolling averages are not available hourly. Metric names are not
  validated, for the same reason sales report versions are not.
- `MetricFreshness.clamp`, for trimming a query to the buckets Google has
  settled. Recent vitals are still moving, and storing them as final is how a
  pipeline ends up disagreeing with Play Console.
- `PlayReportsApi` for the monthly CSVs in the developer's Cloud Storage
  bucket — installs, ratings, crashes, store performance and review history.
  None of these have an API, and the ratings report is the only route to a
  real rating average. `list` and `fetchAll` discover which months exist
  rather than guessing, since Google says not to depend on its schedule.

### Reports and metrics
- `ReportTable` and `ReportRow`: a report as a header plus rows, read by
  column name. Lookups ignore case and whitespace; cells stay as strings
  until converted; a conversion that cannot be made returns `null` rather
  than failing the import. Dates come back as UTC midnight, parsed from
  Apple's `MM/DD/YYYY` as well as `YYYY-MM-DD` and full ISO timestamps.
- `ReportTable.concat` joins an analytics instance's segments, throwing if
  two disagree on columns rather than shifting every value one column across.
- `TsvDecoder` for Apple's gzipped TSV, decompressed by magic number since
  Apple sends no `Content-Encoding`.
- `CsvDecoder` for Google's report CSVs, which are UTF-16LE with a
  byte-order mark and genuinely quoted.
- `StoreMetric`, `MetricPoint` and `MetricUnit`: a date/value/dimensions
  series with `total`, `average`, `latest`, `period`, `byDate` and
  `whereDimension`. `MetricUnit` records whether summing is meaningful.

### Credentials and transport
- `AppStoreApiKey` and `AppStoreTokenProvider`: ES256 JWT signing from a
  `.p8` key, cached and re-signed near expiry, with escaped-`\n` and CRLF
  PEMs repaired on the way in.
- `PlayServiceAccount` with a `scopes` argument — the Android Publisher,
  Play Developer Reporting and Cloud Storage scopes are all different, and a
  token minted for the wrong one fails in a way that looks like a bad key.
- `AppStoreConnectClient`, `PlayReportingClient` and `PlayStorageClient`:
  plain authenticated clients you can point at any endpoint of their API,
  with `JsonApiPage` unwrapping Apple's collection envelope.
- `RetryPolicy`: exponential backoff with a `Retry-After` override for
  throttling and transient server errors. Google Play's quota failures arrive
  as `403 quotaExceeded` rather than `429`, so retryability follows the
  translated exception type, not the raw status. Off with
  `RetryPolicy.none()`.
- `StoreConsoleLog`: an optional `onLog` on every client, reporting retries
  and token re-signs. Nothing is logged unless a callback is supplied.
- `StoreConsoleException` and subclasses, with messages that name the likely
  setup mistake rather than restating the HTTP status.
