## Unreleased

### Added
- `RetryPolicy`: exponential backoff with a `Retry-After` override for
  throttling and transient server errors, on both stores' clients. Off with
  `RetryPolicy.none()`. Google Play's quota failures arrive as `403
  quotaExceeded` rather than `429`, so retryability there follows the
  translated exception type, not the raw status.
- `StoreConsoleLog`: an optional `onLog` on every client, reporting retries
  and token re-signs. Nothing is logged unless a callback is supplied.
- `JsonApiPage` and `AppStoreConnectClient.getPage` / `getPageAt` / `pages` /
  `resources`: the App Store Connect collection envelope, pulled apart once
  instead of in each API.
- `PlayServiceAccount.reportingScope` and `.storageReadScope`, for the Play
  Developer Reporting API and the Cloud Storage report bucket.
- `ReportTable` and `ReportRow`: store reports as a header plus rows, read by
  column name. Lookups ignore case and whitespace, cells stay as strings until
  converted, and a conversion that cannot be made returns `null` rather than
  failing the import. Dates come back as UTC midnight, parsed from Apple's
  `MM/DD/YYYY` as well as `YYYY-MM-DD` and full ISO timestamps.
- `TsvDecoder`: the gzipped TSV App Store Connect serves for sales and
  analytics reports, decompressed by magic number since Apple sends no
  `Content-Encoding`.
- `CsvDecoder`: Google Play's Cloud Storage report CSVs, which are UTF-16LE
  with a byte-order mark and genuinely quoted.
- `StoreMetric`, `MetricPoint` and `MetricUnit`: a date/value/dimensions
  series shared by every statistics surface, with `total`, `average`,
  `latest`, `period`, `byDate` and `whereDimension`.

- `AppStoreTeam` and `SalesReportsApi`: App Store Connect Sales and Trends
  reports. These are team-scoped, keyed by vendor number rather than app ID,
  and cover every app in the account at once — which is why they hang off a
  new `AppStoreTeam` rather than `AppStoreConnectConsole`.
- `SalesReportQuery`, `SalesReportType`, `SalesReportSubType`,
  `SalesFrequency` and `SalesReportCombination`: Apple's allowed-values table
  as types. An impossible report type/sub-type/frequency combination throws
  locally, naming the parameter actually at fault — Apple's own error blames
  the date. `version` is passed through unvalidated, since Apple's published
  versions and the ones its API accepts have drifted apart.
- `SalesFrequency.formatDate` and `.endOfWeek`: the per-frequency
  `reportDate` formats, and the Sunday a weekly report must be requested by.
- `AppStoreConnectClient.getBytes`, for endpoints that answer with something
  other than JSON.

- `PlayVitalsApi`, `PlayReportingClient`, `VitalsQuery`, `VitalsMetricSet`,
  `AggregationPeriod`, `UserCohort` and `MetricFreshness`: Android vitals from
  the Play Developer Reporting API. Hand-written, because that API is in
  neither `googleapis` nor `googleapis_beta`.
- Queries validate the two restrictions whose Google-side errors do not name
  the cause: `errorCountMetricSet` requires the `reportType` dimension, and
  rolling averages are not available hourly. Metric names are not validated,
  for the same reason sales report versions are not.
- `MetricFreshness.clamp`, for trimming a query to the buckets Google has
  settled — recent vitals are still moving and storing them as final is how a
  pipeline ends up disagreeing with Play Console.
- `MetricUnit.bytes`, for the memory-usage metric sets.

- `PlayReportsApi`, `PlayStorageClient` and `PlayReportType`: Google Play's
  monthly report CSVs from the developer's Cloud Storage bucket — installs,
  ratings, crashes, store performance and review history. None of these have
  an API; the CSVs are the only route, and the ratings report is the only
  route to a real rating average.
- The bucket ID accepts the whole `gs://…/stats/installs/` URI Play Console's
  copy button produces, not just the bare name.
- `PlayReportsApi.list` and `.fetchAll` discover which months exist by listing
  the bucket, since Google says not to depend on its publishing schedule.
- `GoogleApiError`, shared by the reporting and storage clients so the two
  cannot drift on what a given status means.

### Changed
- `PlayServiceAccount.authenticate` takes a `scopes` list, defaulting to the
  Android Publisher scope it previously hardcoded. `GooglePlayConsole.connect`
  passes one through. Not a breaking change — existing calls behave the same.

## 0.1.0

First release. Reviews across both stores; statistics are not implemented yet.

### Added
- `StoreConsole` over `GooglePlayConsole` and `AppStoreConnectConsole`, either
  of which may be omitted for a single-platform app.
- `StoreReviewsApi` with `list` (a lazy, auto-paging `Stream`), `listPage`
  (cursor-based), `get` and `reply`, implemented for both stores and fanned
  out by `MergedReviewsApi`.
- `ReviewQuery` filters. App Store Connect handles `ratings`, `territories`,
  `hasReply` and `sort` server-side; Google Play, which has no equivalent,
  applies `ratings` and `hasReply` per page and ignores the rest. See the
  support matrix in the README.
- Unified `StoreReview` and `ReviewReply` models, with `raw` keeping the
  original store payload.
- `AppStoreApiKey` and `AppStoreTokenProvider`: ES256 JWT signing from a
  `.p8` key, cached and re-signed near expiry, with escaped-`\n` and CRLF
  PEMs repaired on the way in.
- `PlayServiceAccount` for service-account authentication.
- `AppStoreConnectClient`, a plain authenticated JSON client for any App
  Store Connect endpoint.
- `StoreConsoleException` and subclasses, including
  `StoreRateLimitException` for Google Play's quota (signalled as `403`
  `quotaExceeded`, not `429`) and `StoreAuthException` messages that name the
  likely setup mistake.
- Reply length is validated locally — 350 characters on Google Play, 5,970 on
  the App Store — so an over-long reply fails before it costs quota.
- `AppStoreReviewsApi.deleteReply`, which Google Play has no equivalent for.
