# colaxy_store_console 開発計画

レビュー機能(0.1.0)は完了。ここから**ストア統計**を段階的に追加する。

> **ステータス**: ✅ = 完了、🚧 = 作業中、無印 = 未着手

## 前提として判明している事実

計画の形を決めている、調査済みの制約:

1. **Play Developer Reporting API は `googleapis` に無い。** 282 ライブラリを確認したが
   `playdeveloperreporting` は未生成で、`googleapis_beta` にも無い。ASC と同様、
   手書きの HTTP クライアントが必要。認証だけは `googleapis_auth` を流用できる。
2. **統計は4つの互いに異なる API 面に分かれている。** 単一の抽象には収まらない:

   | 面 | 取得方法 | 同期/非同期 | 形式 |
   |---|---|---|---|
   | Play vitals | Reporting API (手書き) | 同期クエリ | JSON |
   | Play インストール/売上 | Cloud Storage バケットの CSV | ダウンロード | CSV (UTF-16LE) |
   | ASC 売上/サブスク | `GET /v1/salesReports` | 同期 | gzip TSV |
   | ASC アナリティクス | `analyticsReportRequests` 系 | **非同期4段** | gzip TSV |

3. **スコープがレビューと異なる。** Play vitals は
   `https://www.googleapis.com/auth/playdeveloperreporting`。現在の
   `PlayServiceAccount.authenticate()` は `androidpublisher` スコープ決め打ちなので要修正。
4. **粒度がアプリ単位ではないものがある。** ASC の `salesReports` は **vendorNumber**
   (チーム単位) が必須で、appId では引けない。Play の CSV バケットも開発者アカウント単位。
   現在の `AppStoreConnectConsole` / `GooglePlayConsole` はアプリ単位なので、
   チーム単位の入れ物が別途要る。
5. **レビュー API から平均評価は出せない。** Play はテキスト無し評価を返さないため。
   評価の統計が要るなら Play は CSV (Phase 4)、ASC は別途必要。

---

## Phase 0 — 統計を載せる前の基盤の穴埋め

レビュー実装時に「統計で必要になる」と分かっていて後回しにした部分。

| # | 内容 | 理由 |
|---|------|------|
| ✅ 0-1 | **`PlayServiceAccount.authenticate()` のスコープを引数化する。** 現在 `androidpublisher` 決め打ち。`scopes` パラメータを取り、既定値は現状維持。 | これが無いと Play vitals の認証が通らない。破壊的変更にならないうちにやる。 |
| ✅ 0-2 | **429 / 5xx のリトライとバックオフ。** 現在は 401 の1回リトライのみ。指数バックオフ + `Retry-After` 尊重を `AppStoreConnectClient` と Play 側の `_guard` に入れる。上限回数は設定可能に。 | 統計はレポート生成待ちのポーリングが前提で、`500 UNEXPECTED_ERROR` の報告例もある。レビューより明確に必要。 |
| ✅ 0-3 | **`AppStoreConnectClient` に自動ページングヘルパー `getPaged()` を追加。** 現在は `AppStoreReviewsApi` が `links.next` を自前で追っている。 | アナリティクスの instances / segments でも同じ処理が要る。3回目を書く前に共通化。 |
| ✅ 0-4 | **ロギングの口を用意する。** `void Function(String)? onLog` を各クライアントに。既定は無出力。 | 非同期レポートの待ち時間が数十分になるので、進捗が見えないと使えない。 |

**完了条件**: 既存 75 テストが通ったまま、0-1〜0-4 のテストが追加されている。

> ✅ **Phase 0 完了 (テスト 75 → 113)**。実装時に判明したこと:
> - **Play のクォータ超過 (`403 quotaExceeded`) はリトライ対象、素の `403` は対象外。**
>   ステータスだけでは判別できないので、Play 側は変換後の例外型
>   (`StoreRateLimitException` かどうか) でリトライ可否を決めている。
> - **`401` はリトライ方針とは別扱い。** 待っても直らず、必要なのは再署名。
>   1回だけ許可し、2回目は即失敗させる(不正なキーでループさせないため)。
> - **既存テストをリトライ非依存にする必要があった。** レスポンスを1つだけ
>   積んだテストがリトライで 2 回目のリクエストを打ち、モックの既定値
>   (`{} 200`) を拾って誤って成功していた。テストの既定を
>   `RetryPolicy.none()` にし、リトライのテストだけ明示的に有効化 + 偽スリープ。

---

## Phase 1 — 統計の共通モデルとレポート取り込み基盤

4つの API 面すべてが「表形式のデータを落として読む」に帰着するので、そこだけ先に共通化する。
**ここで過度に抽象化しない**こと。面ごとの差が大きいので、共通なのは「行の取り込み」だけ。

| # | 内容 |
|---|------|
| ✅ 1-1 | **`ReportTable`** — ヘッダ + 行の素朴な表モデル。列名でのアクセス、型変換ヘルパー(`intAt` / `dateAt` / `decimalAt`)。 |
| ✅ 1-2 | **gzip TSV デコーダ。** ASC の2面が共通で使う。`dart:io` の `gzip` + タブ分割。空値・引用符・改行コードの扱いをテストで固定。 |
| ✅ 1-3 | **CSV デコーダ (UTF-16LE)。** Play の GCS レポートは UTF-16LE BOM 付き CSV。Phase 4 用だが、1-1 の設計を歪めないようここで形だけ決めておく。 |
| ✅ 1-4 | **`StoreMetric` / `MetricPoint`** — 「日付 × 指標 × 値」の統一系列モデル。ストア横断で並べたいのはここだけなので、範囲を絞る。 |

**完了条件**: 実 API 無しで、記録済みのレポート payload からテーブルと系列が組み立てられる。

> **判断メモ**: 統計を `StoreReviewsApi` のような単一インターフェースで統一するのは**やらない**。
> 4面で粒度も鮮度も認証単位も違い、共通化すると全部の最小公倍数になって使い物にならない。
> 共通化するのは 1-1 / 1-4 のデータ形だけにする。

> ✅ **Phase 1 完了 (テスト 119 → 180)**。設計上の判断:
> - **型付きの売上モデルは作らない。** Apple の `SALES` と `SUBSCRIBER` は列がほぼ共通しておらず、
>   両社ともヘッダ名を予告なく変える。`ReportTable` + 列名アクセスにして、列の意味は
>   ドキュメントで説明する方針にした。
> - **数値は文字列のまま保持し、要求時に変換する。** 売上を最初から `double` に通すと、
>   呼び出し側が正確な金額を見る前に精度が失われる。`operator []` で生文字列を取れる。
> - **変換失敗は `null`。** 日次1年分のうち1セルが壊れているだけで取り込み全体が
>   落ちるべきではない。
> - **日付は必ず UTC 深夜。** レポートの日付は瞬間ではなく暦日なので、
>   ローカル時刻で解釈するとジョブの実行地域によって日がズレる。
> - **Apple は `MM/DD/YYYY`、Google は `YYYY-MM-DD`。** `DD/MM` として読むと
>   毎月1〜12日だけ「成功」して残りが壊れるという最悪の失敗をするため、
>   両形式を明示的に判別している。
> - **列名照合は大小文字・空白を無視。** 両社がレポート版間でヘッダの表記を変えた実績がある。

---

## Phase 2 — ASC 売上レポート (最初の実装対象) ✅

4面で最も単純。同期 GET 1本で gzip TSV が返る。Phase 1 の基盤の検証を兼ねる。

- エンドポイント: `GET /v1/salesReports`
- 必須パラメータ: `filter[frequency]` (`DAILY`/`WEEKLY`/`MONTHLY`/`YEARLY`)、
  `filter[reportType]` (`SALES`/`SUBSCRIPTION`/`SUBSCRIBER`/`INSTALLS` ほか)、
  `filter[reportSubType]` (`SUMMARY`/`DETAILED`/`SUMMARY_INSTALL_TYPE` ほか)、
  `filter[vendorNumber]`
- 任意: `filter[reportDate]`、`filter[version]`

| # | 内容 |
|---|------|
| ✅ 2-1 | **`AppStoreTeam`** — vendorNumber を持つチーム単位の入れ物。アプリ単位の `AppStoreConnectConsole` とは別階層にする(前提4)。 |
| ✅ 2-2 | **`SalesReportsApi`** — 上記パラメータを型で表現(`SalesFrequency` / `SalesReportType` / `SalesReportSubType` enum)。組み合わせ不正は Apple が 400 を返す前にローカルで弾く。 |
| ✅ 2-3 | **売上行のマッピング。** ただし `SALES` と `SUBSCRIBER` では列が全く違うので、**型付きモデルは作らず** `ReportTable` を返す。列の意味は README の表で説明する。 |
| ✅ 2-4 | **データが無い日は 404 が返る**ことの扱い。エラーではなく空として返す(Apple の仕様であって失敗ではない)。 |

**完了条件**: MockClient で gzip TSV を返し、`ReportTable` として読めるテスト。

> ✅ **Phase 2 完了 (テスト 180 → 206)**。判明したこと・計画からの逸脱:
> - **`version` はローカル検証しないことにした。** 計画では「組み合わせ不正はローカルで弾く」と
>   書いたが、Apple の公開表と実 API の受理値が過去に食い違っている
>   (`SALES`/`DAILY` に対しドキュメントは `1_0`、実際は `1_1` を要求されたアカウントの報告あり)。
>   厳格に弾くと**実際には動く組み合わせを塞いでしまう**。
>   type × subType × frequency のみ検証し、`version` は既定値を入れつつ明示指定は素通しする。
> - **`frequency` の検証には明確な価値があった。** Apple は不正な frequency に対し
>   `INVALID_COMBINATION` + 「Invalid combination of date type and date」を返す。
>   日付は正しいのに日付のせいだと言われるので、デバッグが完全に迷子になる。
> - **日付形式は frequency ごとに違う。** DAILY/WEEKLY は `YYYY-MM-DD`、
>   MONTHLY は `YYYY-MM`、YEARLY は `YYYY`。`SalesFrequency.formatDate` に閉じ込めた。
> - **WEEKLY は日曜日(週の最終日)必須。** 自動補正は「頼んだ期間と違うデータが黙って返る」ので
>   採用せず、`ArgumentError` + `SalesFrequency.endOfWeek()` を案内する形にした。
> - **404 = 売上ゼロの日。** 「There were no sales for the date specified」が返る。
>   エラー扱いだと閑散日のたびにジョブが落ちる。空テーブルを返す。
>   生成済みレポートは必ずヘッダ行を持つので、`columns.isEmpty` で
>   「レポート無し」と「0行のレポート」を曖昧さなく区別できる。
> - **売上レポートはアプリ単位で引けない。** vendorNumber (チーム単位) 必須で、
>   1レポートにアカウント配下の全アプリが SKU 別に入る。API に絞り込みは無い。
>   そのため `AppStoreTeam` という別階層を作った。
> - **vendorNumber を返す API は存在しない。** App Store Connect の
>   「お支払いとお取引レポート」画面にしか出ないので、利用者に設定してもらう。

---

## Phase 3 — Play vitals (Reporting API) ✅

手書きクライアント。同期クエリで JSON が返るので、非同期4段の Phase 5 より先にやる。

- ベース: `https://playdeveloperreporting.googleapis.com/v1beta1/`
- スコープ: `https://www.googleapis.com/auth/playdeveloperreporting` (0-1 が前提)
- リソース: `vitals.crashrate` / `vitals.anrrate` / `vitals.errors` /
  `vitals.excessivewakeuprate` / `vitals.slowstartrate` ほか、各 `query` と `get`

| # | 内容 |
|---|------|
| ✅ 3-1 | **`PlayReportingClient`** — 認証済み HTTP + エラー変換。`AppStoreConnectClient` と対になる位置づけ。 |
| ✅ 3-2 | **`PlayVitalsApi`** — メトリクスセットごとの `query`。時間粒度 (`DAILY`/`HOURLY`)、期間、ディメンション指定。 |
| ✅ 3-3 | **レスポンス → `MetricPoint` 系列へのマッピング。** Google の `timelineSpec` / `rows` 形式は素直ではないので、マッパーを分離してテストする。 |
| ✅ 3-4 | **`freshnessInfo` の扱い。** どこまでのデータが確定済みかを返す仕組みがあるので、無視せずモデルに載せる(未確定データを確定として扱うと日次集計が狂う)。 |

**完了条件**: 記録済み JSON からクラッシュ率の日次系列が組み立てられるテスト。

> ✅ **Phase 3 完了 (テスト 206 → 240)**。discovery document から確定した事実:
> - **DAILY バケットは `America/Los_Angeles` の暦日。** Google は「歴史的経緯」として
>   これ以外のタイムゾーンを提供していない。つまり Play の「8/20」と App Store の「8/20」は
>   **異なる24時間**を指し、どちらも UTC の1日ではない。
>   `MetricPoint.date` は Google が報告した暦日をそのまま UTC ラベルで保持する方針にした
>   (実 UTC に変換すると深夜からズレ、境界では日付自体が変わって Play Console と食い違う)。
>   `AggregationPeriod.timeZoneId` で型として可視化。
> - **`errorCountMetricSet` は `reportType` ディメンション必須。** 全メトリックセット中これだけ。
>   欠落時の Google のエラーはどのディメンションか言わない。ローカルで弾く。
> - **ローリング平均 (`…7dUserWeighted` / `…28dUserWeighted`) は HOURLY 非対応。**
>   これもローカルで弾く。
> - **メトリック名自体は検証しない。** Phase 2 の `version` と同じ理由
>   (Google は予告なくメトリックを追加する)。ドキュメントとして
>   `VitalsMetricSet.metrics` に列挙はする。
> - **`google.type.Decimal` は必ず文字列 `{"value": "0.0231"}`。** 数値として読むと
>   null になって点が黙って落ちる。
> - **1行に複数メトリックが乗る。** `StoreMetric` は1メトリックの時系列なので、
>   レスポンスを転置するマッパーが必要だった。
> - **クォータ超過は `RESOURCE_EXHAUSTED`** で、429 でも 403 でも来る。
>   Phase 0 と同じく変換後の例外型でリトライ可否を決める。
> - **スコープ間違いは「鍵が不正」に見える。** Android Publisher スコープのトークンは
>   ここでは拒否されるので、401/403 のメッセージで `reportingScope` を名指しする。

---

## Phase 4 — Play のインストール/評価/売上 (GCS CSV) ✅

**API が存在しない**面。`gs://pubsite_prod_rev_<developer-id>/stats/...` の CSV を落とす。

| # | 内容 |
|---|------|
| ✅ 4-1 | **バケット取得方法の確定。** Play Console の「レポートをダウンロード」画面にしか出ない ID なので、ユーザーに設定してもらう前提でよいか要判断。 |
| ✅ 4-2 | **Cloud Storage からのダウンロード。** `googleapis` の `storage/v1` は利用可能(確認済み)。スコープは `devstorage.read_only`。 |
| ✅ 4-3 | **UTF-16LE CSV のデコード (1-3)** と、installs / ratings / crashes / reviews の各レポート形式のマッピング。 |
| ✅ 4-4 | **月次ファイルの列挙とマージ。** 1ファイル=1ヶ月なので、期間指定は複数ファイルにまたがる。 |

> ✅ **Phase 4 完了 (テスト 240 → 258)**。判明したこと・計画からの変更:
> - **4-1 の結論: バケット ID は利用者に設定してもらう。** Play Console の
>   「レポートのダウンロード」画面にしか出ず、どの API にも出てこない。ただし
>   コピーボタンが渡すのは `gs://pubsite_prod_rev_…/stats/installs/` という
>   **URI 全体**なので、そのまま貼っても動くよう `normaliseBucket` で
>   scheme とパスを落とす(生で渡すと「無効なバケット名」で落ちる)。
> - **4-2 は `googleapis` の storage を使わなかった。** `package:googleapis/storage/v1.dart` は
>   **deprecated**(`google_cloud_storage` へ移行を推奨)。必要なのは list と download の
>   GET 2本だけなので、Reporting と同様に Cloud Storage JSON API を直接叩く。
>   deprecated API も新規依存も避けられる。
> - **Google 系エラー変換を `GoogleApiError` に共通化した。** Reporting と Storage は
>   同じ `{"error": {code, message, status}}` 形式。2箇所が別々に育つと
>   「403 の意味」が食い違うので1箇所にまとめ、認証ヒントだけ差し替える。
> - **オブジェクト名は丸ごと percent-encode が必要。** JSON API はオブジェクト名を
>   1つのパスセグメントとして扱うので、`/` を生で残すと別の(存在しない)
>   エンドポイントに解決される。
> - **レポート種別ごとに breakdown が違う。** `crashes` に `carrier` は無く、
>   `store_performance` には `overview` が無い。存在しない breakdown を頼むと
>   404 が返り、「その月はデータ無し」と見分けがつかないのでローカルで弾く。
> - **月の列挙は推測ではなく prefix list で行う。** Google 自身が
>   「特定時刻に更新される前提で作るな」と言っているため。
> - **`ratings` レポートが本当の平均評価の唯一の入手経路。** レビュー API は
>   テキスト無し評価を返さないので平均が出せない。

---

## Phase 5 — ASC アナリティクスレポート ✅

非同期4段 (`request` → `report` → `instance` → `segment`) で最も複雑。最後に回す。

| # | 内容 |
|---|------|
| ✅ 5-1 | **`AnalyticsReportsApi`** — `POST /v1/analyticsReportRequests` (`ONGOING` / `ONE_TIME_SNAPSHOT`)、既存リクエストの列挙 (`filter[accessType]`)。 |
| ✅ 5-2 | **ダウンロードチェーンの実装。** `/analyticsReports/{id}/instances` → `/analyticsReportInstances/{id}/segments` → segment の URL から gzip TSV。0-3 のページングを使う。 |
| ✅ 5-3 | **待機とポーリング。** `ONGOING` の初回は 24〜48時間後。同期的に待つのは非現実なので、「リクエスト作成」と「取得」を別 API として分ける。 |
| ✅ 5-4 | **`stoppedDueToInactivity` の扱い。** 使われないリクエストは Apple 側で削除され ID が無効になる。再作成が必要なことを型で表現する。 |

> ✅ **Phase 5 完了 (テスト 258 → 278)**。設計と発見:
> - **「リクエスト作成」と「取得」を別 API に分けた (5-3)。** `ONGOING` の初回データは
>   24〜48時間後なので、作成と読み取りを同じジョブでやると必ず空になる。
>   `createRequest` はセットアップ時に1回、以降は `requests`/`reports`/`instances` で回収。
> - **`ensureRequest` は停止済みリクエストを飛ばして新規作成する (5-4)。**
>   `stoppedDueToInactivity` が立つと以下の ID がすべて解決しなくなるため、
>   「生きているものを再利用、全部死んでいたら作り直す」が正しい挙動。
> - **セグメント URL は事前署名済みで、API とは別ホスト・別期限。** Bearer トークンは
>   無関係なので、認証ヘッダを付けない専用の取得経路 (`getSignedBytes`) を用意した。
>   期限切れは `StoreApiException` になるので、segments を取り直す。
> - **1 instance は複数セグメントに分割され、各セグメントが独自のヘッダ行を持つ。**
>   連結して初めて1つのレポートになる。`ReportTable.concat` を追加し、
>   **列が食い違ったら例外**にした(黙って連結すると全値が1列ずれた
>   「もっともらしい嘘」になるため)。
> - **レポート名は識別子ではなく散文**で、Apple が改名した実績がある。
>   `filter[name]` より `filter[category]` を推奨する旨をドキュメントに書いた。
> - **未確認事項は推測で埋めなかった。** 同一 accessType のリクエストを2つ作った場合の
>   Apple の挙動は非公開なので、`ensureRequest` は「生きているものがあれば再利用」に留め、
>   その旨をドキュメントに明記している。

---

## Phase 6 — 仕上げ ✅

| # | 内容 |
|---|------|
| ✅ 6-1 | **統計の README セクション。** レビューと同じ粒度で、面ごとの対応表と制約を書く。 |
| ✅ 6-2 | **`example/` に統計のサンプル追加。** |
| ✅ 6-3 | **CLI (`bin/`) を作るか判断。** `colaxy_localization` / `colaxy_icons_launcher` は CLI を持つので、リポジトリの流儀としては自然。ただしライブラリとして使う想定が主なら不要。Phase 3 完了時点で判断。 |
| ✅ 6-4 | **リリース準備。** CHANGELOG、パッケージ名の最終確認(publish 前ならリネームは機械的)。 |

> ✅ **Phase 6 完了 (テスト 278)**。判断:
> - **6-3: CLI は作らない。** リポジトリ内の `colaxy_localization` /
>   `colaxy_icons_launcher` は「1回叩いてファイルを生成する」ツールで、CLI そのものが成果物。
>   一方このパッケージは**定期実行して自前で貯めるパイプラインに組み込む**用途が主で、
>   出力形式・保存先・スケジュールはすべて利用者側の決定事項になる。
>   CLI を用意するとそれらを勝手に決めることになるので、ライブラリのままにした。
>   → ただし**認証チェック用の `doctor` サブコマンド**には別の価値がある。
>     セットアップの失敗経路が8通りほどあり(スコープ違い、Play Console への招待漏れ、
>     vendorNumber、バケット ID、.p8 の改行、appId 取り違えなど)、
>     どれも分かりにくいエラーになる。必要になったら追加する。
> - **6-4: バージョンは `0.2.0` ではなく `0.1.0` のまま。** pub.dev に一度も publish
>   していない(`colaxy_store_console` は 404 = 未取得)ので、存在しない 0.1.0 の
>   リリースノートが残るのは不正直。CHANGELOG を単一の 0.1.0 に統合した。
>   開発経緯は git 履歴に残っている。
> - **パッケージ名は `colaxy_store_console` で確定。** pub.dev で未使用を確認済み。

---

## 進め方

- 1項目 = 1コミット。`dart analyze` / `dart test` / `dart pub publish --dry-run` が
  全部通ってから次へ。
- 各 Phase の完了時に、実際の API 仕様と食い違いが無いか再確認する
  (Apple も Google もドキュメント外の挙動が多いため)。
- **Phase 2 と Phase 3 が終わった時点で一度立ち止まる。** そこまでで
  「何が取れて何が取れないか」が確定するので、Phase 4 / 5 に進む価値があるかを
  そこで判断する。
