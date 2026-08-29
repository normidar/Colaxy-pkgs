## 0.1.0

First release. A Dart client for the Zaim REST API v2.1.0.

### Authentication
- `ZaimAuthFlow` for the three-legged OAuth 1.0a dance (request token,
  authorization URL, access token), signing with HMAC-SHA1 through the
  `oauth1` package.
- `ZaimCredentials` and `ZaimRequestToken`, both serialisable so they survive
  a redirect or a restart. Neither prints its secrets in `toString()`.
- `ZaimOAuthEndpoints` for the three documented URLs.

### Endpoints
- `UserApi.verify` — `GET /v2/home/user/verify`.
- `MoneyApi.list` and `MoneyApi.listAll`, the latter walking pages of 100 as a
  lazy `Stream`.
- `MoneyApi.createPayment` / `createIncome` / `createTransfer`,
  `updatePayment` / `updateIncome` / `updateTransfer`, and a single
  `delete(MoneyMode, int)`.
- `CategoryApi.list`, `GenreApi.list`, `AccountApi.list`.
- `DefaultApi` via `ZaimClient.defaults()` for the unauthenticated
  `/v2/account`, `/v2/category`, `/v2/genre` and `/v2/currency` masters.

### Models
- `ZaimUser`, `ZaimUserCounters`, `MoneyRecord`, `MoneyMode`, `MoneyOrder`,
  `MoneyWriteResult`, `ZaimPlace`, `ZaimCategory`, `ZaimGenre`, `ZaimAccount`,
  `ZaimCurrency`, `DefaultAccount`, `DefaultCategory`, `DefaultGenre` — all
  immutable, hand-written `fromJson`/`toJson`, with `==`, `hashCode` and
  `toString`.
- Defensive parsing throughout: numeric strings are coerced, unknown fields
  are ignored, and Zaim's `0`-means-unset foreign keys become `null`.
- JST timestamps are parsed into UTC `DateTime`s denoting the same instant.

### Behaviour
- `mapping=1` is sent automatically wherever Zaim requires it and is never
  part of a public signature.
- Local validation raises `ArgumentError` before any request: text fields at
  most 100 characters, `limit` in `1..100`, `page` at least 1, positive
  amounts, the ±5 year date window, the three-month income window, and
  transfers between two different accounts.
- `ZaimApiException` carries `statusCode`, the server's `message` and the raw
  body; `ZaimAuthException` subclasses it for 401.
- `http.Client` is injectable everywhere for tests; `close()` disposes only a
  client the package created itself.
