# Firebase のレポート/管理情報を読むパッケージ

**ステータス: 保留。作らない。** 調査だけ済ませて置いておく。

調査日: 2026-08-29。発端は「`colaxy_store_console` に Firebase の event や analytics を
入れるべきか」という問い。結論としては**入れるべきではなく、別パッケージにする価値はあるが、
今は着手しない**。

---

## 調査の前提と信頼度

この文書の内容がどこまで裏付けられているかを最初に書く。後から読んだとき、
どれが事実でどれが推測かが分からないと使えないため。

| 区分 | 方法 |
|---|---|
| ✅ **検証済み** | `googleapis` 17.0.0 と `googleapis_beta` 9.0.0 の**生成クライアントを実際に読んだ**。スコープ定数・リソースクラス・メソッドシグネチャは実物 |
| ✅ **検証済み** | pub.dev の API (`/api/packages/*`, `/api/search`, `/api/packages/*/score`) を叩いて取得。数値は 2026-08-29 時点 |
| ⚠️ **未検証** | 実アカウントに対して**1度も叩いていない**。`colaxy_store_console` で「モックでは検出できない欠陥」が5件出たのと同じことが、ここでも起きうる |
| ⚠️ **未検証** | 後述の「未検証のまま残る事項」に列挙したもの(課金条件、OAuth 審査、トークン失効など)は当方の知識であって、この調査で確認していない |

---

## 1. 対象は2つの別世界に割れる

最初にこれを分けないと議論が噛み合わない。実際、調査中に何度も混線した。

| | データ面 (data plane) | 管理・レポート面 (control/reporting plane) |
|---|---|---|
| 何をする | Firestore / Auth / Storage の**中身**を読み書き | プロジェクトを**横断**して構造と数字を見る |
| 単位 | 1プロジェクトの中 | アカウントが持つ全プロジェクト |
| 代表 | Admin SDK | Management API / GA4 Data API |
| pub の状況 | **既に3つある** | **存在しない** |

「今の Google アカウントにプロジェクトが何個あるか」「各プロジェクトのイベント・リリース」
という当初の関心は**全部が右側**。Admin SDK は `FirebaseApp` を作る時点でプロジェクトを
指定する構造なので、「何個あるか」は概念として答えられない。

---

## 2. 読める API (全て公式生成クライアントが存在する)

| API | 収録先 | 読めるもの |
|---|---|---|
| `firebase/v1beta1` (Management) | googleapis_beta | プロジェクト一覧、Android/iOS/Web アプリ一覧、SHA 証明書、config |
| `analyticsdata/v1beta` | googleapis_beta | GA4 の数字。`runReport` / `runRealtimeReport` / `runPivotReport` / `batchRunReports` / `getMetadata` / `checkCompatibility` |
| `analyticsadmin/v1beta` | googleapis_beta | GA4 プロパティ、カスタムディメンション/指標、コンバージョンイベント、データストリーム、**FirebaseLinks** |
| `fcmdata/v1beta1` | googleapis_beta | FCM 配信データ |
| `firebaseappdistribution/v1` | googleapis | リリース、テスター、グループ、**フィードバックレポート** |
| `firebasehosting` | googleapis | サイト、カスタムドメイン、バージョン |
| `firebaserules` | googleapis | ルールセット、リリース |
| `firebaseappcheck` | googleapis | アプリごとの AppCheck 設定 |
| `firebasedatabase` / `firebasestorage` | googleapis_beta | **インスタンス/バケットのメタ情報のみ**(中身のデータではない) |
| `cloudresourcemanager/v3` | googleapis | **全 GCP プロジェクト**(Firebase 未有効のものも含む) |
| `bigquery/v2` | googleapis | Crashlytics export / GA4 生イベント (後述) |

### 存在しない API

- **Crashlytics** — `googleapis` にも `googleapis_beta` にも `firebasecrashlytics` が**無い**。
  BigQuery export 経由のみ。
- **Performance Monitoring** — 同様に生成クライアントが存在しない。
- **イベント単位の生データ** — `runReport` は集計クエリ。BigQuery export のみ。

### `fcmdata` は Android 専用

リソースが `ProjectsAndroidAppsDeliveryDataResource` しか無く、iOS 版が存在しない。
使うなら型でこの非対称を見せること。

---

## 3. スコープ表 (生成クライアントから実測)

| API | 要求スコープ |
|---|---|
| Firebase Management | `firebase.readonly` / `firebase` / `cloud-platform.read-only` / `cloud-platform` |
| `analyticsdata` | `analytics.readonly` / `analytics` |
| `analyticsadmin` | `analytics.readonly` / `analytics.edit` |
| `firebasedatabase` | `firebase.readonly` / `cloud-platform.read-only` ほか |
| `firebasestorage` | `firebase` / `cloud-platform` |
| **`firebaseappdistribution`** | **`cloud-platform` のみ** |
| **`fcmdata`** | **`cloud-platform` のみ** |
| **`firestore/v1`** | **`cloud-platform` / `datastore` のみ** |
| `bigquery/v2` | `bigquery` / `cloud-platform.read-only` / `cloud-platform` / `devstorage.*` |
| `cloudresourcemanager/v3` | `cloud-platform.read-only` / `cloud-platform` |
| `monitoring/v3` | `monitoring.read` / `monitoring` / `cloud-platform` |
| `logging/v2` | `logging.read` / `logging.admin` / `cloud-platform` |
| (参考) `androidpublisher/v3` | **`androidpublisher` 単一** |

### readonly が存在しない API が3つある

**`firebaseappdistribution` / `fcmdata` / `firestore`。** 読むだけでも書き込み可能な
スコープを要求される。

- App Distribution と fcmdata は `cloud-platform` のみ = **GCP プロジェクト全体への書き込み**。
  「配信データを読みたい」だけで、Cloud Storage 削除・BigQuery 削除・IAM 変更・
  プロジェクト削除が可能なトークンを持つことになる。
- `androidpublisher` も同じ構図で readonly が無い。この単一スコープには
  **アプリのリリースを公開する権限**が含まれる。「レビューを読むだけ」の用途に対して過大。

### Firestore の特例が最も重要

`firestore/v1` は `cloud-platform` と `datastore` の2つしか受け付けず、
**`cloud-platform.read-only` を含まない**。他の API には readonly の逃げ道があるのに
Firestore だけ無い。

ドキュメント1件を読むトークンで以下が全部できる:

```
documents:  createDocument / patch / delete / batchWrite / commit / rollback
databases:  create / patch / delete / importDocuments / exportDocuments
```

`databases.delete` を含む。**データベースごと消せる。**

→ **Firestore を読み取り専用にしたいなら、スコープではなく IAM で絞るしかない**
(`roles/datastore.viewer`)。これはサービスアカウントでしか成立しない。
OAuth はユーザー本人の IAM が適用されるので、本人が Owner なら絞れない。

---

## 4. OAuth とサービスアカウントの使い分け

OAuth にしても**使える API が増えるわけではない**。変わるのは主体。

| | サービスアカウント | ユーザー OAuth |
|---|---|---|
| `projects.list` が返すもの | SA 自身が IAM を持つものだけ | **本人が権限を持つ全部** |
| 権限の絞り込み | **IAM ロールで自由に絞れる** | 本人の IAM が上限。Owner なら絞れない |
| 対話 | 不要。定期実行に載る | ブラウザ同意が要る |

**「今の Google アカウントにプロジェクトが何個あるか」は OAuth でしか答えられない。**
これは `colaxy_store_console` が一貫して採ってきたサービスアカウント/ES256 JWT の
非対話モデルとは別物で、定期実行パイプラインには載らない。

逆に**「Firestore を安全に読む」はサービスアカウントでしか成立しない**(上記の理由)。
つまり用途によって認証方式を選び分ける必要があり、片方に統一できない。

`googleapis_auth` には `clientViaUserConsent` と `clientViaUserConsentManual`
(ヘッドレス用・コピペ方式) の両方がある。

### Apple 側は OAuth が存在しない

App Store Connect は API キー (ES256 JWT) のみ。ダッシュボードを作るなら
**Google 側=OAuth 対話 / Apple 側=キー非対話**という非対称を必ず抱える。

---

## 5. 逆引きできない: Firebase プロジェクト → GA4 プロパティ

`analyticsdata.runReport` は **GA4 プロパティ ID** を要求し、Firebase プロジェクト ID では
引けない。そして**逆引き API が存在しない**。

`FirebaseLink` は**プロパティ側にぶら下がっている**
(`properties/1234/firebaseLinks/5678`、中に `project` フィールド)。したがって:

```
accountSummaries.list              → 全 GA4 プロパティを列挙
  └ properties.firebaseLinks.list  → 各プロパティの project を見る
      └ 目的の Firebase プロジェクトと一致するものを拾う
```

**総当たりで対応表を作るしかない。** プロパティ数に比例してリクエストが増えるので、
対応表はキャッシュ前提の設計になる。

---

## 6. スコープの3段階

調査の途中で境界を2回引き直した。最終的にはこれが正確:

| | スコープ | 取れるもの |
|---|---|---|
| 最小 | `firebase.readonly` + `analytics.readonly` | プロジェクト、アプリ一覧、GA4 の集計とイベント |
| **推奨** | **`cloud-platform.read-only` + `analytics.readonly`** | ＋ **BigQuery (Crashlytics・生イベント)**、全 GCP プロジェクト、ログ、監視 |
| 書き込み込み | ＋ `cloud-platform` | ＋ App Distribution、FCM 配信データ、Firestore 操作 |

**中段が要点。** `cloud-platform.read-only` は「REST API が無いから取れない」と
判断していた Crashlytics と生イベントを、**書き込み権限なしで**解禁する。
BigQuery は `cloud-platform.read-only` を受け付けるため。

`analytics.readonly` は別枠のまま。GA4 は GCP リソースではないので
`cloud-platform.read-only` に含まれない。

### BigQuery 経由には利用者側の事前設定が要る

エクスポートは**デフォルト off** で、API からは有効化できない (Firebase コンソール操作)。
つまり `colaxy_store_console` の vendorNumber や Play のバケット ID と同じ性格の
「利用者に設定してもらう値」がここにも現れる。

→ **取得失敗時に「権限が無い」のか「エクスポート未設定」のかを区別してエラーに出すこと。**
曖昧にすると Play のバケット権限で踏んだのと同じ迷子が再現する。

---

## 7. pub.dev の既存パッケージ (2026-08-29 時点)

### データ面 — 既に3つ現役。作る理由がない

| パッケージ | 版 | 更新 | likes | pub点 | DL/月 | 実装されている面 |
|---|---|---|---|---|---|---|
| **`firebase_admin_sdk`** | 0.5.4 | 2026-08-05 | 24 | 140/160 | **10,336** | app / auth / **firestore** / **storage** / messaging / app_check / security_rules / **functions** |
| `dart_firebase_admin` | 0.4.1 | 2025-03-21 | 61 | 120/160 | 6,020 | app / auth / firestore / messaging / app_check / security_rules |
| `firebase_admin` | 0.3.1+5 | 2026-08-19 | 98 | **160/160** | 741 | app / auth / database / storage (**Firestore なし**) |
| `firebase_dart` | 1.6.2 | 2026-03-27 | **129** | 110/160 | 8,474 | database / auth / storage (クライアント寄り) |

カバー範囲は `firebase_admin_sdk` が最大。**`additionalScopes` をサポート**しており、
同じサービスアカウントから任意スコープの認証済みクライアントを取れる。

**3つとも管理・レポート面に一切触れていない**(実測)。
`firebase.googleapis.com` / `analyticsdata` / `analyticsadmin` / `firebaseappdistribution` /
`fcmdata` / `cloudresourcemanager` / `projects.list` の参照がゼロ。
`firebase_admin_sdk` の `bigquery` ヒットは `additionalScopes` のドキュメント例のみ。

### 管理・レポート面 — 空白

| 名前 | 実態 |
|---|---|
| `firebase_management` v0.0.5 | **likes 0 / DL 161・月**。「管理」用で読み取り集計ではない。実質未使用 |
| `firebase_app_distribution` v1.3.0 | Flutter プラグイン(テスターのアプリ内更新)。全くの別物 |
| `firebaseapis` v0.2.0 | 2023-08-28 で更新停止した自動生成物 |
| GA4 データ読み取りのラッパ | **無い**。`ambilytics` などは全てクライアント側の**送信** |

### ストア側 (`colaxy_store_console` の競合確認)

Apple 単体は複数存在: `app_store_connect_apis` / `appstore_connect` (0.3.2) /
`app_store_connect_api_v1` / `app_store_connect_app_versions`。
**Google Play Console 側および両ストア統合は見当たらない** → `colaxy_store_console` の
立ち位置は保たれている。

---

## 8. ⚠️ `googleapis_beta` が2年半止まっている

**`googleapis_beta` の最新は 9.0.0 / 2024-01-26。** `analyticsdata` `analyticsadmin`
`firebase` (Management) `fcmdata` は全てここにしか無いので、この停滞は直接効く。

これは着手を保留する理由の一つ。選択肢:

1. 古い生成物をそのまま使う (API 側の追加に追随できない)
2. Reporting / Storage でやったように **REST を直叩き**する
   (`colaxy_store_console` の Phase 3 / 4-2 で確立した手法。`playdeveloperreporting` も
   `google_cloud_storage` deprecated も同じ理由でこうした)
3. discovery document から自前生成

**着手するなら 2 が既存の流儀と一致する。** ただし「薄いラッパで済む」という当初の
コスト見積もりは崩れ、Phase 3・4 相当の作業量に戻る。

---

## 9. もし作るなら: パッケージ境界

```
Flutter アプリ ── colaxy_store_console   ストアの実績(権威データ)
              ├─ (新規)                  プロジェクト横断の構造とレポート
              └─ firebase_admin_sdk      Firebase のデータ操作 (既存を直接)
```

| 担当 | 誰が |
|---|---|
| ストア実績 | `colaxy_store_console` (既存) |
| Firebase のデータ操作 | `firebase_admin_sdk` (既存) |
| **プロジェクト横断の構造とレポート** | **新規・ここだけ** |
| 認証 | 既存の仕組みを流用 (下記) |

### 認証層は作らなくていい

必要なのは「サービスアカウント JSON → 指定スコープの認証済み HTTP クライアント」だけで、
`googleapis_auth` の `ServiceAccountCredentials` で足りる。
**しかもそのコードは既にある。** Phase 0-1 で `PlayServiceAccount.authenticate()` の
スコープを引数化したので、形がそのまま使える:

```dart
PlayServiceAccount.authenticate(scopes: [firebaseReadonly, analyticsReadonly])
```

Phase 0-1 の判断が、当時想定していなかった Firebase 側にもそのまま効いている。

### `colaxy_store_console` に入れない理由

1. **データの出所が根本的に違う。** ストア側は「ストアが観測した事実」で販売者アカウントが
   権威。Firebase は「アプリの SDK が送れた分」で、同意拒否・オフライン・SDK 未初期化で
   欠ける。**`first_open` と Play の `installs` は設計上一致しない。**
   同じ `StoreMetric` に並べられるようにすると、利用者は必ず並べて比較し、
   「数字が合わない」という(実際には正しい)報告が来る。
2. **Crashlytics は Play vitals と正面衝突する。** `crashRate`(ユーザー知覚クラッシュ率)と
   Crashlytics の crash-free users は別の測り方の別の数字。同じパッケージに両方あると
   「どっちが本当か」という答えられない問いを作る。
3. **認証単位がまた増える。** vendorNumber / バケット ID / package name に加えて
   GA4 プロパティ ID。`verify` のセットアップ失敗経路が8通り→12通りになる。
4. **名前とスコープが壊れる。** `colaxy_store_console` = 「2つのストアコンソール」という
   境界がある。Firebase を入れると次は AppsFlyer は? Adjust は? と際限がなくなる。

### 並べるのはアプリ層。出所ラベルを消さないこと

1つの数字にマージせず「ストア: 426 / Firebase: 391」と両方見せる。
合わないのが正常なので、合わせようとすると必ず嘘が入る。

### Firestore は新パッケージに入れない

理由は権限ではなく役割。`firebase_admin_sdk` が既にカバーしていて現役
(DL 10,336・月)。アプリ層で直接使えば済む。

新パッケージを `cloud-platform.read-only` + `analytics.readonly` の範囲——
**スコープレベルで書き込み不能が保証される面だけ**——に閉じれば、
「このパッケージはどう間違って使っても何も壊せない」を型ではなくスコープで言い切れる。
`colaxy_store_console` の `verify` を既定で読み取り専用にした判断と同じ線。
Firestore を入れるとその保証が消えて「Firebase 何でも屋」に戻る。

---

## 10. 未検証のまま残る事項

着手するなら**最初に潰すべき**もの。`colaxy_store_console` で実データ検証が
5件の誤りを暴いた前例があるので、机上のまま進めないこと。

| # | 事項 | なぜ重要か |
|---|---|---|
| U-1 | **実アカウントで1度も叩いていない。** この文書は全て生成クライアントと pub API の読解 | 前例では「バケット接頭辞」「バケット権限が Play Console アカウントレベル限定」など、モックでは原理的に検出できない誤りが出た |
| U-2 | サービスアカウントで `projects.list` を叩くと実際に何が見えるか | 「SA には何も見えない」という予測の確認。見えたらそれ自体が発見 |
| U-3 | Crashlytics の BigQuery エクスポートが Blaze プラン必須かどうか | 当方の知識であって未確認。前提条件の重さが変わる |
| U-4 | OAuth クライアントが Testing 状態だとリフレッシュトークンが7日で失効するか | 同上。事実なら「自分専用でも毎週ログイン」になり UX が変わる |
| U-5 | `analytics.readonly` / `cloud-platform` が OAuth 審査(sensitive/restricted)の対象か | 配布可否に直結 |
| U-6 | `accountSummaries` → `firebaseLinks` の総当たりが実際どれだけのリクエスト数になるか | キャッシュ設計の要否 |
| U-7 | BigQuery の GA4 export スキーマ (テーブル名の日付サフィックス、`event_params` のネスト) | SQL 層の規模見積もりに直結 |

---

## 11. 着手するときの最初の一歩

1. **使い捨てスクリプトで `clientViaUserConsent` を通し、`projects.list` を叩く。**
   実際に何個見えるか。U-1 / U-2 がここで片付く。
2. 同じトークンで `accountSummaries.list` → `firebaseLinks.list` を回し、
   Firebase プロジェクト ↔ GA4 プロパティの対応表が実際に作れるか確認 (U-6)。
3. `runReport` で `eventName` × `eventCount` を1本取る。ここまで通れば中核は成立する。
4. **その時点で BigQuery を第一級の取得経路にするか決める。** 採用するなら SQL 組み立て層が
   必要になり、`runReport` の薄いラッパとは別物の規模になる。ここが Crashlytics と
   生イベントを諦めるかどうかの分岐点。

パッケージ名は未定。`colaxy_app_analytics` が候補だが、扱うのが analytics だけでは
なくなる可能性があるので、範囲が確定してから決める。

---

## 12. 一行まとめ

**空白地帯は「1つの認証情報で、複数プロジェクトを横断して Firebase の構造とレポートを
読む層」。** pub に無く、生成クライアントしかない。ただし `googleapis_beta` の停滞により
コストは当初見積もりより大きい。急ぐ理由が無いので保留。
