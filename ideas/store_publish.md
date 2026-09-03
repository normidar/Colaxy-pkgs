# ストアへの投入層 (`colaxy_store_publish`)

**ステータス: Play 側は実装済み。実アカウント未検証。ASC 側は未着手。**

調査日: 2026-08-29。実装日: 2026-09-03。
`colaxy_store_console` の Firebase 拡張を検討した際に、リポジトリ全体を見渡して
見つかった穴。Firebase 案 ([firebase_reporting.md](firebase_reporting.md))
を保留にしたのに対し、**こちらは着手する価値がある**という判断だった。

パッケージ名は `colaxy_store_publish` に確定 (6節の候補から選択)。

---

## 前提と信頼度

| 区分 | 内容 |
|---|---|
| ✅ **検証済み** | Google Play 側は `googleapis` 17.0.0 の `androidpublisher/v3.dart` を**実際に読んだ**。リソース・メソッド・モデルのフィールド・`imageType` の許容値は実物 |
| ✅ **検証済み** | `colaxy_localization` / `colaxy_screenshot` / `colaxy_store_console` のソースを読み、出力パスと既存の API 利用範囲を確認 |
| ✅ **検証済み** | **実装した。** モック (`MockClient`) に対するテスト81件が通る |
| ⚠️ **未検証** | **実アカウントに対して1度も叩いていない。** ここが最大の残リスク (7節 U-8) |
| ⚠️ **未検証** | **App Store Connect 側は一切確認していない。** Apple は `googleapis` に含まれないので手元で読めるものが無い。本文中の ASC の記述は全て**要確認** |

---

## 0. 実装して分かったこと (調査時の記述との差分)

**調査の表が実物とズレていた箇所が4つ、調査で見落としていた API が3つあった。**
`colaxy_store_console` の「実データでしか分からないことがある」という教訓は、
今回は**実データを見る前のソース読解の段階で**同じ形で出た。

### 0-1. ファイル名が違った (3節の表の誤り)

調査時の表は `short_description` / `full_description` と書いていたが、
`colaxy_localization` が実際に書くのは **`.txt` 付き**:

| 実際の出力 | `Listing` |
|---|---|
| `title.txt` | `title` |
| `short_description.txt` | `shortDescription` |
| `full_description.txt` | `fullDescription` |
| `changelogs/default.txt` | トラックのリリースノート |

**まとめた時点でバグが入る (R-1)** がそのまま再現した形。

### 0-2. `changelogs/` は `default.txt` しか生成されない

fastlane supply の規約は `changelogs/<versionCode>.txt` で、`default.txt` は
フォールバック。`colaxy_localization` は `default.txt` だけを書く。
→ U-5 の答え: **リリース単位** (`TrackRelease.releaseNotes`) であり、
実装側は `<versionCode>.txt` → `default.txt` の順に探す形にした。

### 0-3. `featureGraphic.png` が規約外の場所にある

`colaxy_screenshot` は `fastlane/metadata/android/featureGraphic.png` に書く。
supply の規約は `<locale>/images/featureGraphic.png` なので、
**`fastlane supply` もこれを拾っていなかった**はず。

→ `FastlaneMetadata.strayFeatureGraphic` として明示的に露出し、
`PlayPublishOptions.uploadStrayFeatureGraphic` (既定 `false`) でのみ全ロケールに送る。
**本来の直し方は `colaxy_screenshot` 側を規約に合わせること**で、これは別件。

### 0-4. `commit` にレビュー破壊のパラメータがあった (調査で見落とし)

`edits.commit` は `changesInReviewBehavior` と `changesNotSentForReview` を取る。
**既定値は `CANCEL_IN_REVIEW_AND_SUBMIT`** — つまり
**メタデータを1行直しただけの投入が、審査中のリリースの審査を取り消して出し直す。**

調査時にこれを見落としていたのは、4-1 で `edits` を「トランザクションだから安全」と
まとめた結果、commit の引数を読まなかったため。**トランザクション性と、
commit が外の状態に与える影響は別の話**だった。

→ `ChangesInReviewBehavior` として露出。`errorIfInReview` を選べるようにした。

### 0-5. `images.upload` に `aiGeneratedState` が増えていた

AI 生成かどうかの開発者による申告。Google が検出するのではなく自己申告。
省略可なので既定では送らない。`PlayAiGeneratedState` として露出。

### 0-6. `AppEdit.expiryTimeSeconds` が存在した → U-6 が半分解決

エディットの有効期限は**レスポンスに入っている**。
`PlayEditSession.expiresAt` / `timeRemaining` として露出した。
残る未検証は「実際に何分か」だけ。

### 0-7. `listings.get` / `tracks.get` の 404 が二義的

ロケールのリスティングが無い場合と、**エディットが死んでいる場合**が
どちらも 404 で返る。後者を「まだ無い」と解釈すると、
**何も投入していないのに成功として報告する**実装になる。

→ `get` を `list` 経由で実装し、404 の経路を通らないようにした。
リスティングは多くても数十件なので、追加リクエスト1回のコストで曖昧さが消える。

### 0-8. `tracks.update` はリリース配列を丸ごと置換する

新しいリリース1件だけを送ると、**halted のロールアウトや旧リリースが消える**。
→ `PlayTracksApi.release` は必ず先に読んでマージする。

### 0-9. U-4 の判断: 画像のローカル検証はしない

`EditsImagesResource.upload` の制約 (サイズ・解像度・必要枚数) は調べていない。
**調べずに実装した**のが正しいという判断で、
Phase 2 の「ドキュメント化されていない値をローカルで強制しない」原則をそのまま適用。
ローカルで見るのは「リクエストが組み立てられないもの」だけ
(ファイルが無い / 拡張子が PNG でも JPEG でもない)。

---

## 1. なぜ穴があるか

現状のリポジトリはこうなっている:

| パッケージ | 役割 | 出力 |
|---|---|---|
| `colaxy_icons_launcher` | アイコン生成 | アプリ内のリソース |
| `colaxy_screenshot` | スクショ生成 | `fastlane/screenshots/…`、`…/images/phoneScreenshots` ほか |
| `colaxy_localization` | メタデータ生成 | `fastlane/metadata/android/…` (`title.txt` / `short_description` / `full_description` / `changelogs`) |
| `colaxy_store_console` | ストアから**読む** | — |

**つまり「fastlane 用の入力を Dart で生成し、投入だけ Ruby の fastlane に頼る」構造。**
ツールチェーンの最後の1歩だけが他言語に残っている。

さらに `colaxy_store_console` は既に `androidpublisher/v3.dart` に依存しているが、
**使っているのは `reviews` だけ**。投入に必要なリソース群が同じ生成クライアントの中で
丸ごと眠っている。

---

## 2. Google Play 側で使えるもの (実測)

`androidpublisher/v3` の `Edits*` リソースと全メソッド:

| リソース | メソッド |
|---|---|
| `EditsResource` | `insert` / `get` / `validate` / **`commit`** / `delete` |
| `EditsListingsResource` | `list` / `get` / `update` / `patch` / `delete` / `deleteall` |
| `EditsImagesResource` | `list` / `upload` / `delete` / `deleteall` |
| `EditsTracksResource` | `list` / `get` / `create` / `update` / `patch` |
| `EditsBundlesResource` | `list` / **`upload`** |
| `EditsApksResource` | `list` / `upload` / `addexternallyhosted` |
| `EditsDetailsResource` | `get` / `update` / `patch` |
| `EditsTestersResource` | `get` / `update` / `patch` |
| `EditsCountryavailabilityResource` | `get` |
| `EditsDeobfuscationfilesResource` | `upload` |
| `EditsExpansionfilesResource` | `get` / `update` / `patch` / `upload` |

### `Listing` モデルのフィールド (実測)

```dart
core.String? language;          // BCP-47 (例: "de-AT")
core.String? title;
core.String? shortDescription;
core.String? fullDescription;
core.String? video;             // YouTube URL
```

### `imageType` の許容値 (実測・discovery document 由来)

```
phoneScreenshots / sevenInchScreenshots / tenInchScreenshots
tvScreenshots / wearScreenshots
icon / featureGraphic / tvBanner
appImageTypeUnspecified   ← "Do not use" と明記されている
```

---

## 3. 対応関係が既に一致している (最大の発見)

**`colaxy_screenshot` が出力するディレクトリ名は、`androidpublisher` の `imageType` の
許容値とそのまま同一。**

| `colaxy_screenshot` の出力 | `EditsImagesResource.upload` の `imageType` |
|---|---|
| `android/<locale>/images/phoneScreenshots` | `phoneScreenshots` |
| `android/<locale>/images/sevenInchScreenshots` | `sevenInchScreenshots` |
| `android/<locale>/images/tenInchScreenshots` | `tenInchScreenshots` |
| `fastlane/metadata/android/featureGraphic.png` | `featureGraphic` ⚠️ **規約外の場所。0-3 参照** |

**`colaxy_localization` の出力も `Listing` のフィールドに1対1で対応する:**

| ファイル | `Listing` |
|---|---|
| `title.txt` | `title` |
| `short_description.txt` | `shortDescription` |
| `full_description.txt` | `fullDescription` |
| `changelogs/default.txt` | リリースのリリースノート (`TrackRelease` 側) |

> 上の表は 0-1 / 0-2 で実物に合わせて修正済み。当初は `.txt` を落として書いていた。

両方が fastlane の supply 規約に従っているため、**変換テーブルを新規に発明する必要がない**。
やることは実質「これらのファイルを読んで API を呼ぶ」だけ。

> **注意**: この一致は偶然ではなく、両パッケージが fastlane 規約に合わせた結果。
> つまり **fastlane 規約が事実上の中間形式**になっている。投入層もこの規約を入力に取れば、
> 既存2パッケージと疎結合のままつながる。逆に独自の中間形式を発明すると、
> 3パッケージが密結合になって全部を同時に直す羽目になる。

---

## 4. 隠してはいけない非対称

`colaxy_store_console` で「4つの API 面を単一インターフェースに統一しない」と決めたのと
同じ判断が、ここでも必要になる。

### 4-1. トランザクション性が違う

- **Play の `edits` はトランザクション。** `insert` でエディットを作り、変更を積み、
  `commit` して初めて反映される。`validate` で事前検証もできる。
  途中で失敗しても**中途半端な状態が残らない**。`delete` で破棄できる。
- **ASC は逐次反映と思われる**(要確認)。途中で失敗すると一部だけ更新された状態になる。

**統一インターフェースで包むと「両方ロールバックできる」という嘘になる。**
Play 側の `commit` を隠さず、ASC 側は「途中失敗時に何が残るか」を型かドキュメントで
明示すること。

### 4-2. バイナリのアップロードは線を引く

- **Play**: `EditsBundlesResource.upload` で aab を上げられる (実測)。
- **Apple**: ASC API ではバイナリを上げられず、**Transporter / altool が必要**と理解している
  (⚠️ 要確認)。

→ **「メタデータとスクショは両ストア、バイナリは Play のみ」と正直に線を引く。**
両対応に見せかけると、Apple 側で必ず破綻する。

### 4-3. `deleteall` の危険性

`EditsImagesResource.deleteall` と `EditsListingsResource.deleteall` がある。
「ローカルの状態をストアに同期する」実装では使いたくなるが、
**ローカルに無いロケールのリスティングを消す**ことになる。

`colaxy_store_console` の `verify` を既定で読み取り専用にした判断と同じ線で、
**破壊的操作は既定で無効、明示フラグでのみ有効**にすべき。
`--allow-writes` ではなく、もっと狭い `--prune` のような個別フラグが適切。

---

## 5. 再利用できる既存資産

新規に書く必要がないもの (すべて `colaxy_store_console` にある):

| 資産 | Phase | 備考 |
|---|---|---|
| `PlayServiceAccount.authenticate(scopes:)` | 0-1 | スコープ引数化済み。`androidpublisher` スコープが既定 |
| `AppStoreConnectClient` (ES256 JWT) | — | Apple 側の認証はそのまま使える |
| `RetryPolicy` (429/5xx、指数バックオフ、`Retry-After`) | 0-2 | アップロードは失敗しやすいので必須 |
| `getPaged()` | 0-3 | リスティング一覧などで使う |
| `onLog` | 0-4 | 多段の投入は進捗が見えないと使えない |
| `GoogleApiError` の変換 | Phase 4 | Play 側のエラー解釈が共通 |

**Phase 0 の基盤整備が、当時想定していなかった投入側にもそのまま効く。**

### `androidpublisher` スコープの注意

このスコープには **readonly が存在せず**、読み書きが不可分
([firebase_reporting.md](firebase_reporting.md) の調査で確認)。
つまり `colaxy_store_console` がレビューを読むために既に持っている権限で、
**アプリのリリース公開まで可能**。投入層を作ることで新たな権限は増えないが、
逆に言えば**読み取り専用のつもりのトークンが最初から危険だった**ことになる。
この事実はドキュメントに書くべき。

---

## 6. 設計方針 (実装済み)

方針は5つとも当初案のまま採用した。変更した点はない。

- **パッケージは分けた。** `colaxy_store_publish` として独立。
  ただし**依存の向きは `publish → console`** にした。
  `PlayServiceAccount` / `RetryPolicy` / 例外階層を再利用するためで、
  逆向き (console が publish に依存) ではないので
  「読むだけのつもりで入れた依存が書ける」問題は起きない。
  `RetryPolicy` と例外階層を2つ持つと、`GoogleApiError` のコメントが警告している
  「2つのクライアントが 403 の意味で食い違う」がそのまま起きる。
- **入力は fastlane 規約のディレクトリ。** 独自の中間形式は作っていない。
- **`commit` を隠さない。** `PlayEditSession` が `validate` / `commit` /
  `discard` / `discardQuietly` を持つ。dry-run は `edits.validate` そのもの。
- **破壊的操作は個別フラグ。** `replaceScreenshots` (既定 `false`)。
  `listings.deleteAll` はメソッドとしては存在するが、**どこからも呼ばれない**。
- **バイナリは Play のみ。** README の冒頭に非対称の表を置いた。

追加で必要になった方針が1つ:

- **リスティングは読んでからマージする。** `listings.update` は全体置換なので、
  `title.txt` しか無いロケールを素直に送ると**説明文が消える**。
  ストアの現状を1回だけ読んで重ねる。これは調査時の設計に無かった。

### 名前

`colaxy_store_publish` に確定。

---

## 7. 未検証事項

`colaxy_store_console` で実データ検証が5件の誤りを暴いた前例がある。

| # | 事項 | 状態 |
|---|---|---|
| U-1 | **ASC 側の API を一切確認していない。** メタデータ更新 (`appStoreVersionLocalizations` 系?)、スクショ (`appScreenshotSets` / reservation + chunk upload?) | **未着手。** この文書の Apple 側の記述は全て推測のまま |
| U-2 | ASC が本当に逐次反映か。トランザクション相当の仕組みが無いか | **未着手** |
| U-3 | Apple のバイナリアップロードが本当に ASC API 不可か | **未着手** |
| U-4 | `EditsImagesResource.upload` の実際の制約 (最大サイズ、必要枚数、解像度) | **調べないと決めた** (0-9)。ローカル検証はしない |
| U-5 | `changelogs/` → リリースノートへの対応。トラック単位かリリース単位か | **解決 (0-2)。** リリース単位 (`TrackRelease.releaseNotes`) |
| U-6 | エディットの有効期限。放置した `edits` がどうなるか | **半分解決 (0-6)。** `expiryTimeSeconds` で取得できる。実際の長さは未確認 |
| U-7 | 同時に複数の `edits` を開いた場合の挙動 | **推測で実装した。** 409 を `PlayEditConflictException` にして再試行しない。**409 が実際に返るかは未確認** |
| **U-8** | **実アカウントに対して1度も叩いていない** | **新規。最大の残リスク** |
| U-9 | `changesInReviewBehavior` の既定が本当にレビューを取り消すか (0-4) | discovery document の記述のみ。実挙動は未確認 |
| U-10 | `bundles.upload` のサイズ上限。resumable が既定で正しいか | 未確認。resumable にしたのは「大きいファイルだから」という判断のみ |

---

## 8. 次の一歩

Play 側の実装は済んだので、順序が変わった。

1. **実アカウントで1ロケールを通す (U-8)。** ここが完了条件。
   `dart run colaxy_store_publish:publish --dry-run` で
   `insert` → `listings.update` → `validate` → `delete` を先に通し、その後 commit まで。
   **U-7 / U-9 / U-10 もここで一緒に潰れる。**
2. ~~`colaxy_localization` の説明文が上限を超えうる欠陥を直す~~
   ✅ **完了 (v0.2.1)。** [dart_native_pipeline.md](dart_native_pipeline.md) 4-A
3. `colaxy_screenshot` の `featureGraphic.png` の場所を規約に合わせる (0-3)。
   これは `colaxy_store_publish` ではなく `colaxy_screenshot` の修正。
4. `colaxy_localization` が `changelogs/<versionCode>.txt` を書けるようにするか判断 (0-2)。
   今は `default.txt` だけなので、バージョンごとのリリースノートが書けない。
5. **認証・権限の検査を `--check` に足す** (Stage 9-1 の残り半分)。
   実アカウントが要るので U-8 と同時にやる。
6. **ASC 側の調査 (U-1〜U-3)。** 手元に読めるものが無いので、ここが最大の未知。
   Apple の OpenAPI 仕様を確認して、Play 側と同じ粒度の表を作る。
   **これが終わるまで ASC 側の設計を決めない。**
7. その時点で ASC 側をどこまで揃えるか決める。非対称が大きすぎるなら、
   「Play 完全対応 + ASC はメタデータのみ」で切る判断もある。

---

## 9. 一行まとめ

**Play 側の投入は埋まった。** `colaxy_store_publish` が `fastlane supply` の
メタデータ・画像・aab・トラックを全部置き換えている。
**ただし実アカウントで1度も叩いていないので、まだ「動く」とは言えない** (U-8)。
未知は ASC 側と、実データ検証。
