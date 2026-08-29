# zaim_api

A Dart client for the [Zaim](https://zaim.net) REST API, version 2.1.0.

Zaim is a Japanese personal household-accounting service. This package wraps
its OAuth 1.0a API: the three-legged token dance, money record CRUD, the
user's categories, genres and accounts, and the public master data endpoints
that need no credentials at all.

Pure Dart, no Flutter dependency, and no code generation — every `fromJson` is
written by hand.

## Read this before you start

Two properties of the Zaim API surprise people:

- **Only manually entered records are exposed.** Rows that Zaim imported
  automatically from a linked bank or credit card through account aggregation
  are *not* returned by `GET /v2/home/money`. If a user's app shows a hundred
  transactions and the API returns twelve, this is why.
- **Permission expires after 24 hours** unless the app was registered with the
  *permanently accessible* access level. Without it, credentials that worked
  yesterday start raising `ZaimAuthException` today, and the user has to
  authorize again.

Individual developers can use the API for free. Corporate use requires
contacting Zaim first.

## Install

```yaml
dependencies:
  zaim_api: ^0.1.0
```

## Registering an app

1. Sign in at the Zaim Developers Center and create an application.
2. Choose the access levels you need: *read records*, *write records*, and
   *permanently accessible*. Pick the permanent flag unless a 24-hour session
   is genuinely what you want — see above.
3. For a **Browser App**, the Service URL you give restricts which domain may
   use the credentials; your OAuth callback has to live under it. A desktop or
   CLI tool can use out-of-band (PIN) authorization instead and skip the
   callback entirely.
4. Copy the **Consumer Key** and **Consumer Secret**. Keep them out of source
   control.

Everything is HTTPS-only and every response is JSON.

## Authenticating

Zaim uses OAuth 1.0a with **HMAC-SHA1** signatures — no other signature method
is accepted. The flow is the classic three-legged one:

| Step | URL | Method |
|---|---|---|
| 1. Request token | `https://api.zaim.net/v2/auth/request` | `POST` |
| 2. User authorization | `https://auth.zaim.net/users/auth?oauth_token=…` | browser |
| 3. Access token | `https://api.zaim.net/v2/auth/access` | `POST` + `oauth_verifier` |

```dart
import 'dart:io';
import 'package:zaim_api/zaim_api.dart';

Future<ZaimCredentials> authorize() async {
  final flow = ZaimAuthFlow(
    consumerKey: 'YOUR_CONSUMER_KEY',
    consumerSecret: 'YOUR_CONSUMER_SECRET',
  );
  try {
    // Step 1. Pass your own callback URL here for a Browser App; the default
    // 'oob' asks Zaim for out-of-band (PIN) authorization.
    final requestToken = await flow.requestToken();

    // Step 2. Send the user to this URL. Zaim comes back with an
    // oauth_verifier — on the callback query string, or as a PIN on screen.
    print(flow.authorizationUrl(requestToken));
    final verifier = stdin.readLineSync()!.trim();

    // Step 3. Exchange it for long-lived credentials, and persist those.
    return await flow.accessToken(requestToken, verifier);
  } finally {
    flow.close();
  }
}
```

`ZaimCredentials` serialises with `toJson()` / `fromJson()` so you can store it
in secure storage. Its `toString()` redacts both secrets. Every signed request
the client sends carries `oauth_consumer_key`, `oauth_signature_method`,
`oauth_version`, `oauth_token`, `oauth_timestamp`, `oauth_nonce`, and
`oauth_signature`.

In a web app the redirect happens between steps 1 and 3, so persist the
`ZaimRequestToken` (it also has `toJson()`) — its secret is needed to sign the
final exchange.

## Reading and writing

```dart
final client = ZaimClient(credentials: credentials);
try {
  // Scope: none. The cheapest way to check credentials are still valid.
  final me = await client.user.verify();

  // Scope: read.
  final categories = await client.category.list();
  final genres = await client.genre.list();
  final accounts = await client.account.list();

  final records = await client.money.list(
    mode: MoneyMode.payment,
    startDate: DateTime(2024, 1, 1),
    endDate: DateTime(2024, 12, 31),
    limit: 100, // 100 is the maximum Zaim allows.
  );

  // Or let the package walk the pages for you, 100 at a time.
  await for (final record in client.money.listAll(mode: MoneyMode.payment)) {
    print('${record.date}: ${record.amount} ${record.currencyCode}');
  }

  // Scope: write.
  final created = await client.money.createPayment(
    categoryId: categories.first.id,
    genreId: genres.first.id,
    amount: 1280,          // Integer. No decimal point, ever.
    date: DateTime.now(),  // Sent as Y-m-d.
    fromAccountId: accounts.first.id,
    name: 'Bento',
    place: 'Corner store',
    comment: 'Lunch',
  );

  await client.money.updatePayment(
    created.id,
    amount: 1300,          // Amount and date are required on every update,
    date: DateTime.now(),  // even when they have not changed.
  );

  await client.money.delete(MoneyMode.payment, created.id);
} on ZaimAuthException catch (e) {
  print('401: ${e.message}');
} on ZaimApiException catch (e) {
  print('${e.statusCode}: ${e.message}');
} finally {
  client.close();
}
```

### Public master data

`/v2/account`, `/v2/category`, `/v2/genre` and `/v2/currency` need no
credentials, so you can populate pickers before the user has authorized
anything:

```dart
final defaults = ZaimClient.defaults();
final currencies = await defaults.currencies();
defaults.close();
```

## Design notes

**`mapping=1`** is required on most endpoints. The package always sends it and
it is never part of a public method signature.

**Three update methods, one delete method.** Zaim puts the mode in the path
(`/v2/home/money/payment`, `…/income`, `…/transfer`) and takes a different
parameter set for each: payments need a genre, income does not; transfers need
both accounts, payments only the source. So creates and updates are
`createPayment` / `createIncome` / `createTransfer` and `updatePayment` /
`updateIncome` / `updateTransfer`, which lets the compiler reject a genre on
an income. Delete is the exception — its payload is nothing but the id — so
one `delete(MoneyMode mode, int id)` covers all three. `MoneyRecord.mode`
carries the mode you need to pass.

**`0` becomes `null`.** Zaim returns `0`, not `null`, for foreign keys that are
unset. `fromAccountId`, `toAccountId`, `genreId` and `receiptId` are therefore
`int?` on `MoneyRecord`, and `toJson()` restores the `0` sentinel. The same
mapping is applied to the equivalent fields on `ZaimPlace`, `ZaimAccount`, and
`ZaimCategory`.

**Timestamps.** `created`, `modified` and `profile_modified` arrive as
`"YYYY-MM-DD HH:MM:SS"` in JST. They are parsed into UTC `DateTime`s denoting
the same instant, so they compare correctly against timestamps from anywhere
else, and rendered back into Zaim's format by `toJson()`. Plain dates
(`Y-m-d`) stay calendar dates at local midnight.

**Amounts are integers.** Zaim sends no decimal point. `GET /v2/currency`
reports `point: 0` for JPY, which is the reason.

**Defensive parsing.** Zaim occasionally returns numbers as strings, and adds
fields without notice. Every model coerces rather than casts and ignores
fields it does not know, so a server-side addition will not break your app.

## Validation performed before the request

These raise `ArgumentError` locally, so you get a clear message instead of a
`400 Parameters are not enough.`:

| Rule | Applies to |
|---|---|
| `comment`, `name`, `place` at most 100 characters | all writes |
| `limit` in `1..100`, `page` at least 1 | `money.list` |
| `amount` greater than zero | all writes |
| `date` within ±5 years | payments, transfers, and all updates |
| `date` within the past three months and not in the future | `createIncome` |
| `fromAccountId` differs from `toAccountId` | transfers |

The three-month window is documented for *creating* income only; the update
parameter table gives the ±5 year window for all three modes, which is what
`updateIncome` enforces.

## Errors

| HTTP | Message | Thrown |
|---|---|---|
| 401 | This consumer key does not have a permission for the action. | `ZaimAuthException` |
| 401 | User authentication was failed. | `ZaimAuthException` |
| 404 | URL is not defined. | `ZaimApiException` |
| 400 | Parameters are not enough. | `ZaimApiException` |
| 400 | Insert action was failed. | `ZaimApiException` |
| 400 | Update action was failed. | `ZaimApiException` |

`ZaimAuthException` extends `ZaimApiException`, and both carry `statusCode`,
the server's own `message`, and the raw `body`.

## Testing

`ZaimClient`, `ZaimClient.defaults` and `ZaimAuthFlow` all accept an injected
`http.Client`, so tests can pass `MockClient` from `package:http/testing.dart`
and never touch the network. `close()` disposes only a client the package
created itself; an injected one is left to its owner.

```dart
final client = ZaimClient(
  credentials: credentials,
  httpClient: MockClient((request) async => http.Response(json, 200)),
);
```

## API reference

| Getter | Endpoint | Scope |
|---|---|---|
| `client.user.verify()` | `GET /v2/home/user/verify` | none |
| `client.money.list()` | `GET /v2/home/money` | read |
| `client.money.listAll()` | `GET /v2/home/money`, auto-paged | read |
| `client.money.createPayment()` | `POST /v2/home/money/payment` | write |
| `client.money.createIncome()` | `POST /v2/home/money/income` | write |
| `client.money.createTransfer()` | `POST /v2/home/money/transfer` | write |
| `client.money.updatePayment()` | `PUT /v2/home/money/payment/:id` | write |
| `client.money.updateIncome()` | `PUT /v2/home/money/income/:id` | write |
| `client.money.updateTransfer()` | `PUT /v2/home/money/transfer/:id` | write |
| `client.money.delete()` | `DELETE /v2/home/money/{mode}/:id` | write |
| `client.category.list()` | `GET /v2/home/category` | read |
| `client.genre.list()` | `GET /v2/home/genre` | read |
| `client.account.list()` | `GET /v2/home/account` | read |
| `ZaimClient.defaults().accounts()` | `GET /v2/account` | none |
| `ZaimClient.defaults().categories()` | `GET /v2/category` | none |
| `ZaimClient.defaults().genres()` | `GET /v2/genre` | none |
| `ZaimClient.defaults().currencies()` | `GET /v2/currency` | none |

Models: `ZaimUser`, `ZaimUserCounters`, `MoneyRecord`, `MoneyMode`,
`MoneyOrder`, `MoneyWriteResult`, `ZaimPlace`, `ZaimCategory`, `ZaimGenre`,
`ZaimAccount`, `ZaimCurrency`, `DefaultAccount`, `DefaultCategory`,
`DefaultGenre`. All are immutable and have `fromJson`, `toJson()`, `==`,
`hashCode` and a readable `toString()`.

See `example/example.dart` for a full run-through.

---

## 日本語

[Zaim](https://zaim.net) の REST API v2.1.0 を扱う Dart パッケージです。
OAuth 1.0a（HMAC-SHA1）の 3-legged 認証、入出金データの取得・作成・更新・削除、
カテゴリ・ジャンル・口座の取得、そして認証不要の公開マスタデータに対応します。
Flutter 非依存の純 Dart 製で、コード生成は使っていません。

使う前に知っておきたい点が 2 つあります。

- **手入力したデータしか取得できません。** 銀行やクレジットカードとの連携で
  自動取得された明細は API からは返りません。
- アプリ登録時に「**常時アクセス可能**」を選んでいない場合、
  ユーザーが許可してから **24 時間で権限が失効** します。失効後は
  `ZaimAuthException` が発生するので、再度認証してもらう必要があります。

個人開発者は無料で利用できます。法人利用の場合は Zaim への問い合わせが必要です。

### 認証

```dart
final flow = ZaimAuthFlow(
  consumerKey: 'YOUR_CONSUMER_KEY',
  consumerSecret: 'YOUR_CONSUMER_SECRET',
);
final requestToken = await flow.requestToken();   // 1. リクエストトークン
print(flow.authorizationUrl(requestToken));       // 2. ブラウザで許可
final credentials =
    await flow.accessToken(requestToken, verifier); // 3. アクセストークン
flow.close();
```

得られた `ZaimCredentials` を保存し、`ZaimClient(credentials: ...)` に渡します。

### 主な注意点

- `mapping=1` はパッケージが自動で付与します。引数には出てきません。
- `money.list` の `limit` は最大 **100** 件です。
- 収入の登録 (`createIncome`) は **過去 3 か月以内**の日付のみ、未来日は不可です。
  支払い・振替と更新系は前後 5 年以内です。
- 金額は小数点なしの整数です（JPY の小数桁数は 0）。
- 未設定の ID は Zaim から `0` で返ってくるため、モデル側では `null` に変換して
  います（`toJson()` で `0` に戻ります）。
- 日時 (`created` / `modified`) は JST 文字列なので、同じ瞬間を指す UTC の
  `DateTime` に変換して保持します。
