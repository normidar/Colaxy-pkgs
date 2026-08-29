# ストアへの投入層 (`colaxy_store_publish` 仮)

**ステータス: 未着手。ただし優先度は高い。**

調査日: 2026-08-29。`colaxy_store_console` の Firebase 拡張を検討した際に、
リポジトリ全体を見渡して見つかった穴。Firebase 案 ([firebase_reporting.md](firebase_reporting.md))
を保留にしたのに対し、**こちらは着手する価値がある**という判断。

---

## 前提と信頼度

| 区分 | 内容 |
|---|---|
| ✅ **検証済み** | Google Play 側は `googleapis` 17.0.0 の `androidpublisher/v3.dart` を**実際に読んだ**。リソース・メソッド・モデルのフィールド・`imageType` の許容値は実物 |
| ✅ **検証済み** | `colaxy_localization` / `colaxy_screenshot` / `colaxy_store_console` のソースを読み、出力パスと既存の API 利用範囲を確認 |
| ⚠️ **未検証** | **App Store Connect 側は一切確認していない。** Apple は `googleapis` に含まれないので手元で読めるものが無い。本文中の ASC の記述は全て**要確認** |
| ⚠️ **未検証** | 実アカウントに対して1度も叩いていない |

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
| `fastlane/metadata/android/featureGraphic.png` | `featureGraphic` |

**`colaxy_localization` の出力も `Listing` のフィールドに1対1で対応する:**

| ファイル | `Listing` |
|---|---|
| `title.txt` | `title` |
| `short_description` | `shortDescription` |
| `full_description` | `fullDescription` |
| `changelogs/` | トラックのリリースノート (`Track` 側) |

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

## 6. 設計方針の案

- **パッケージは分ける。** `colaxy_store_console` は「読む」で完結していて、
  publish 済み (v0.1.0)。投入という真逆の性格を混ぜると、
  「読むだけのつもりで入れた依存が書ける」状態になる。
- **入力は fastlane 規約のディレクトリ。** 独自の中間形式を作らない (3節の理由)。
- **`commit` を隠さない。** Play のトランザクションは利点なので、
  「変更を積む」→「commit する」を利用者に見せる。dry-run は `validate` で自然に実装できる。
- **破壊的操作は個別フラグ。** `deleteall` 系は既定で無効。
- **バイナリは Play のみ**と最初から明示。

### 名前

`colaxy_store_publish` が候補。ただし `colaxy_store_console` と紛らわしいかもしれない。
`colaxy_store_upload` / `colaxy_store_supply` (fastlane の supply に寄せる) も候補。
範囲が確定してから決める。

---

## 7. 未検証事項

着手時に最初に潰すもの。`colaxy_store_console` で実データ検証が5件の誤りを暴いた前例がある。

| # | 事項 | なぜ重要か |
|---|---|---|
| U-1 | **ASC 側の API を一切確認していない。** メタデータ更新 (`appStoreVersionLocalizations` 系?)、スクショ (`appScreenshotSets` / reservation + chunk upload?) | この文書の Apple 側の記述は全て推測。設計の半分が未確定 |
| U-2 | ASC が本当に逐次反映か。トランザクション相当の仕組みが無いか | 4-1 の非対称が前提になっているので、外れると設計が変わる |
| U-3 | Apple のバイナリアップロードが本当に ASC API 不可か | 可能なら「Play のみ」の線引きが不要になる |
| U-4 | `EditsImagesResource.upload` の実際の制約 (最大サイズ、必要枚数、解像度) | ローカル検証すべきか、Google に弾かせるべきかの判断。`colaxy_store_console` の「ドキュメント化されていない値をローカルで強制しない」原則が効く |
| U-5 | `changelogs/` → `Track` のリリースノートへの対応。トラック単位かリリース単位か | `colaxy_localization` との接続点 |
| U-6 | エディットの有効期限。放置した `edits` がどうなるか | 失敗時のクリーンアップ設計に直結 |
| U-7 | 同時に複数の `edits` を開いた場合の挙動 | CI で並列実行されうる |

---

## 8. 最初の一歩

1. **ASC 側の調査 (U-1〜U-3)。** 手元に読めるものが無いので、ここが最大の未知。
   Apple の OpenAPI 仕様を確認して、Play 側と同じ粒度の表を作る。
   **これが終わるまで設計を決めない。**
2. Play 側だけで `insert` → `listings.update` → `validate` → `commit` を通す。
   既存の `PlayServiceAccount` がそのまま使えるはずなので、認証の作業はゼロのはず。
3. `colaxy_localization` の出力ディレクトリを読んで `Listing` に詰める変換を書く。
   3節のとおり1対1なので、ここは短い。
4. `EditsImagesResource.upload` でスクショを1枚上げる。`imageType` は
   `colaxy_screenshot` の出力ディレクトリ名がそのまま使える。
5. **その時点で ASC 側をどこまで揃えるか決める。** 非対称が大きすぎるなら、
   「Play 完全対応 + ASC はメタデータのみ」で最初のリリースを切る判断もある。

---

## 9. 一行まとめ

**このリポジトリは投入用の入力を Dart で全部生成しているのに、投入だけ Ruby の fastlane に
依存している。** 埋めるべきは1箇所で、Play 側は API・認証・変換テーブルが全て揃っており、
未知は ASC 側だけ。
