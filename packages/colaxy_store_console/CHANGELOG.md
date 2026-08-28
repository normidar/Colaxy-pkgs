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
