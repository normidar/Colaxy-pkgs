# Fastlane を使わない Flutter リリースパイプライン

**ステータス: 構想。Stage 1〜3 は実装済み (実アカウント未検証)。**
このリポジトリが結果的に向かっている方向を明文化したもの。
Play 側の実装内容と、実装して分かったことは [store_publish.md](store_publish.md) にある。

調査日: 2026-08-29。Stage 1〜3 実装日: 2026-09-03。

---

## 前提と信頼度

| 区分 | 内容 |
|---|---|
| ✅ **検証済み** | 全パッケージのソースを検索し、`Process.run` / `Process.start` の呼び出しが**1つも無い**ことを確認 |
| ✅ **検証済み** | `colaxy_screenshot` が `RepaintBoundary` + `toImage` で描画していること |
| ✅ **検証済み** | `androidpublisher/v3` の投入系 API ([store_publish.md](store_publish.md) 参照) |
| ⚠️ **未検証** | **Apple 側は全般的に未確認。** コード署名、バイナリアップロード、ASC のメタデータ API |
| ⚠️ **未検証** | fastlane の内部実装についての記述は当方の理解であり、ソースを読んで確認していない |

---

## 1. 夢の形

```
                    ┌─────────────── すべて Dart ───────────────┐

  アイコン生成   →   スクショ生成   →   メタデータ生成   →   投入   →   監視
  icons_launcher    screenshot         localization    store_publish  store_console
       ✅                ✅                  ✅          ✅ Play のみ      ✅
                                                        ❌ ASC 未着手
                    └──────────────────────────────────────────┘
                                       ↑
                              Ruby / fastlane / Gemfile なし
```

**Android はこの流れが全部 Dart で閉じた** (Stage 3 完了)。
iOS 側は投入が空いたままで、そこは Stage 5 以降。

---

## 2. 現在地 (実測)

| パッケージ | 役割 | 外部プロセス依存 |
|---|---|---|
| `colaxy_icons_launcher` | アイコン生成 | **なし** |
| `colaxy_screenshot` | スクショ生成 | **なし** (`RepaintBoundary` + `toImage`) |
| `colaxy_localization` | メタデータ生成 | **なし** |
| `colaxy_store_console` | ストアから読む | **なし** (HTTP のみ) |
| `colaxy_store_publish` | **Play へ投入** | **なし** (HTTP のみ) |
| **ASC への投入** | — | **fastlane (Ruby)** のまま |

### `colaxy_screenshot` の方式が効いている

fastlane の `snapshot` / `screengrab` は**シミュレータ/エミュレータを起動して UI テストを回す**。
一方 `colaxy_screenshot` は Flutter のウィジェットを直接描画して `toImage` で書き出す。

- シミュレータ不要 → CI で macOS ランナーを使わずに Android 用スクショが撮れる
- 実行時間が桁で違う
- **外部プロセスが要らない**

つまり「fastlane を置き換える」という話以前に、**この部分は既に fastlane より軽い方式で
置き換え済み**になっている。

---

## 3. fastlane を3層に分解する

「fastlane を置き換える」と一括りにすると判断を誤る。中身は性格の違う3層でできている。

| 層 | fastlane の action | 実態 | Dart 化の価値 |
|---|---|---|---|
| **API のラッパ** | `supply` / `deliver` / `pilot` | ストア API を叩いているだけ | **高い。** 自分で叩けば済む |
| **CLI のラッパ** | `gym` / `build_app` / `scan` | `xcodebuild` / `flutter` を呼ぶだけ | **ゼロ。** Dart から呼んでも `Process.run` するだけで何も得しない |
| **運用の発明** | **`match`** | API ではなく仕組み。証明書を暗号化して git/S3 で共有する規約 | **最も重い。** 置換ではなく再発明になる |

**置き換える価値があるのは1層目だけ。** ここを見誤ると、
「xcodebuild を Dart から呼ぶラッパ」を書いて何も改善しない、という結末になる。

---

## 4. 残る2つの壁

### 壁 A: Apple のバイナリアップロード → ❌ **消滅した**

> **この節の前提は間違いだった。** 調査時 (2026-08-29) は正しく、Apple 自身も
> フォーラムでそう回答していたが、**WWDC25 で Build Upload API が追加され、
> ASC API 4.1 で出荷済み**。詳細は
> [app_store_connect_api.md](app_store_connect_api.md) 0節。

~~ASC API にはバイナリを上げる口が無く、Transporter か altool / notarytool が必要~~

**`POST /v1/buildUploads` → `POST /v1/buildUploadFiles` → `uploadOperations` で転送
→ `PATCH { uploaded: true }`** で完結する。公式 OpenAPI 4.4.1 に
`deprecated: false` で存在することを実測。

→ **Transporter も altool も要らない。** D-2 / U-3 の答えは「可能」。
`notarytool` はそもそも App Store 提出とは無関係 (App Store 外で配布する
Developer ID 署名の macOS アプリ用) で、ここに並べていたのが誤り。

Google Play 側は `EditsBundlesResource.upload` で aab を上げられる (実測済み)。
**両ストアともバイナリを API で上げられる**が、**方式は違う**:
Play は multipart / resumable で API が直接ファイルを受け、
Apple は必ず予約して別エンドポイントへ送る (ASC API のリクエストボディは
966パス全部が JSON。実測)。

### 壁 B: コード署名

証明書とプロビジョニングプロファイルは ASC API で取得できるはず (⚠️ 要確認) だが、

- キーチェーンへの導入 → `security` コマンド
- `xcodebuild` への引き渡し → `xcodebuild`

は macOS のコマンド。ここは Dart から `Process.run` するしかない。

さらに `match` 相当 (複数人・複数マシンで証明書を共有する仕組み) は **API ではなく運用の発明**
なので、必要なら自分で設計することになる。ただし **個人開発で証明書を1台で管理しているなら
そもそも不要**。ここは「全員に必要な機能」ではない。

---

## 5. 目標を定義し直す

「Dart で完結」には2つの解釈があり、達成可能性が違う。

| 解釈 | 可否 |
|---|---|
| 外部プロセスを一切呼ばない | ⚠️ **署名だけ残る。** Transporter は不要になった (壁 A) が、`xcodebuild` と `security` は Apple のもの |
| **Ruby ランタイムと gem 依存を消す** | ✅ **ほぼ可能。今のリポジトリの延長線上** |

そして**実際の痛みは後者**。bundler / gem のバージョン地獄、CI での Ruby セットアップ、
Fastfile の DSL が主なコストであって、`xcodebuild` を1回叩くこと自体は苦痛ではない。

> **調査後の更新**: 上の1行目は当初「不可能」と書いていた。
> Transporter が要らなくなったので、**残るのは署名とビルドだけ**になった。
> 「iOS のバイナリを配るのに Dart 以外のプロセスが要る」という制約は消えている。

> **目標: 「fastlane 全廃」ではなく「Fastfile を書かなくて済む状態」。**
> Ruby も Gemfile.lock も Fastfile も無く、Apple のツールだけを薄く呼ぶ状態。

---

## 6. 全ステップ

各段階で**何が実際に消えるか**を基準にする。段階ごとに独立した価値があり、
途中で止めても損をしない構成にすること。
`colaxy_store_console` の PLAN.md と同じ粒度で書く。

### 依存関係と進め方

```
Stage A (Apple 調査) ──────────────┐
                                   ├→ Stage 5 → 6 → 7 → 8 → 9
Stage 1 → 2 → 3  [Android 独立] ───┘
```

**重要: Stage 1〜3 は Stage A に依存しない。** Play 側の API は実測で確定しているので、
Apple の調査を待たずに始められる。逆に Stage 5 以降は Stage A が終わるまで
**設計を決めてはいけない** (未確定のまま転記して R-1 を再現するのが最悪の失敗)。

Stage A と Stage 1 は並行して進められる。

---

### Stage A — Apple 側の空白を埋める ✅ **完了**

結果は **[app_store_connect_api.md](app_store_connect_api.md)** に全部ある。
公式 OpenAPI 仕様 (**4.4.1**、966 paths / 1393 schemas) をダウンロードして実際に読んだ。
Play 側が生成クライアントの実物を読んだのと**同じ基準**になった。

| # | 内容 | 結果 |
|---|---|---|
| A-1 | ASC の OpenAPI 仕様を取得し、投入系エンドポイントを Play 側と同じ粒度で表にする | ✅ 表は [app_store_connect_api.md](app_store_connect_api.md) の 1〜6節 |
| A-2 | **バイナリアップロードの可否を確定する** | ✅ **可能。壁 A は消滅** (`buildUploads`、WWDC25 / API 4.1)。`notarytool` は最初から無関係だった |
| A-3 | ASC がトランザクションを持つか | ✅ **持たない。** 409 で弾かれる。一番近いロールバックは `DELETE /v1/appStoreVersions/{id}` |
| A-4 | fastlane の `deliver` が内部で何を呼んでいるか | ✅ `Spaceship::ConnectAPI` (旧 Tunes から移行済み)。Transporter はバイナリ専用で、メタデータ/画像には使っていない |
| A-5 | スクショが reservation + チャンク + チェックサムの多段か | ✅ **そのとおり。** `AppScreenshot` は `sourceFileChecksum` を要求する側 (要求しないリソースもある) |

**完了条件**: Apple 側の表が Play 側と同じ粒度で埋まり、「API でできること /
できないこと」の線が引かれている。**推測で埋めた箇所はゼロ**であること。
→ **達成。** 仕様由来と二次情報 (フォーラム・ブログ) は文書内で明示的に分けてある。

> **調査して分かった最大のこと: 前提が1つ古くなっていた。**
> 「Apple はバイナリを API で上げられない」は調査時点では正しく、
> Apple 自身がそう回答していた。**それが変わっていた。**
> ideas フォルダの「推測で表を埋めない」という約束は、
> 推測を防ぐだけでなく**前提が変わったことに気づく**ためにも効いた。

> **原則**: `colaxy_store_console` の教訓「**転記した表は、転記元の粒度のまま持つ**。
> まとめた時点でバグが入る」(R-1) をここで適用する。Apple の表を要約しない。

---

### Stage 1 — Play のメタデータ投入 ✅ **実装済み**

`colaxy_store_publish` として実装。

| # | 内容 | 実装 |
|---|---|---|
| 1-1 | **`PlayEditSession`** — `insert` → 変更 → `validate` → `commit` / `delete` を型で表す。**`commit` を隠さない**。未 commit で破棄されるのが既定 | ✅ `PlayEditSession` + `PlayEditState`。`discardQuietly` も追加 |
| 1-2 | **fastlane 規約のディレクトリ読み取り。** 独自の中間形式は作らない | ✅ `FastlaneMetadata`。ファイル名は `.txt` 付きだった ([store_publish.md](store_publish.md) 0-1) |
| 1-3 | **`Listing` へのマッピングと `listings.update`** | ✅ `PlayListing`。**ロケール名の変換表は持たない** — Play の許容リストは変わるので、そのまま送って Google に弾かせる |
| 1-4 | **dry-run は `validate` で実装する** | ✅ `edit(body, dryRun: true)` |
| 1-5 | **`deleteall` は既定で無効** | ✅ `listings.deleteAll` はどこからも呼ばれない |
| **1-6** | **(追加) リスティングは読んでからマージする** | `listings.update` は全体置換なので、`title.txt` だけのロケールを送ると説明文が消える。当初の設計に無かった |

**完了条件**: MockClient のテストが通り、かつ**実アカウントで1ロケールのリスティングが
実際に更新される**こと。→ **テストは通った (81件)。実アカウントは未検証なので未完了。**

**消えるもの**: `supply` のメタデータ部分。

---

### Stage 2 — Play の画像投入 ✅ **実装済み**

| # | 内容 | 実装 |
|---|---|---|
| 2-1 | **`images.upload`。** `imageType` は `colaxy_screenshot` の出力ディレクトリ名がそのまま使える | ✅ `PlayImageType.byDirectoryName`。変換表なし |
| 2-2 | **`appImageTypeUnspecified` は送らない** | ✅ enum に含めていないので表現不可能 |
| 2-3 | **画像のサイズ・解像度をローカルで検証しない** | ✅ 見るのは「存在するか」と「PNG/JPEG か」だけ |
| 2-4 | **`images.deleteall` も既定で無効** | ✅ `replaceScreenshots` (既定 `false`)。単一枠は Google が置換するので削除しない |
| 2-5 | **アップロード失敗時のリトライ** | ✅ `PlayApiGuard`。ストリームはクロージャ内で開く (再試行時に空にならないように) |
| **2-6** | **(追加) `aiGeneratedState`** | 調査時に見落としていた新フィールド ([store_publish.md](store_publish.md) 0-5) |

**完了条件**: 実アカウントで1ロケール分のスクショが実際に反映されること。→ **未検証。**

**消えるもの**: `supply` の画像部分。

---

### Stage 3 — Play のバイナリとトラック ✅ **実装済み**

| # | 内容 | 実装 |
|---|---|---|
| 3-1 | **`bundles.upload` で aab を上げる。** サイズ上限とレジューム機構の有無を確認 (D-5) | ✅ 既定で resumable。**サイズ上限は未確認** |
| 3-2 | **`tracks.update`** | ✅ `PlayTracksApi`。**`tracks.update` はリリース配列の全体置換**だったので、`release` は先に読んでマージする ([store_publish.md](store_publish.md) 0-8) |
| 3-3 | **`changelogs/` → リリースノートへの対応** | ✅ **リリース単位** (`TrackRelease.releaseNotes`)。U-5 解決 |
| 3-4 | **段階的公開 (`userFraction`)** | ✅ `inProgress` のときのみ必須。整合性はローカルで検査する (Google のルールが明文化されているため) |
| 3-5 | **`edits` の有効期限とクリーンアップ** | ✅ `expiresAt` で取得。`edit()` は失敗時に必ず破棄する |
| 3-6 | **並列実行時の挙動確認** (U-7) | ⚠️ **推測で実装。** 409 を `PlayEditConflictException` にして再試行しない。実挙動未確認 |
| **3-7** | **(追加) `changesInReviewBehavior`** | **既定が「審査中のものを取り消して出し直す」。** 調査時に完全に見落としていた ([store_publish.md](store_publish.md) 0-4) |

**完了条件**: **`fastlane supply` を一度も呼ばずに Android のリリースが1回通る。**
→ **コードは揃った。実アカウントで通してはいない。**

**消えるもの**: **`supply` が丸ごと。Android 側は fastlane から完全に独立する。**

> **ここが最初の大きな区切り。** Play は `bundles.upload` でバイナリまで上げられるので
> 壁 A が存在せず、Android だけで完結できる。Apple 側で詰まってもこの成果は残る。

---

### Stage 4 — 中間形式の型検証 ✅ **実装済み**

`MetadataCheck` / `MetadataIssue` と、CLI の `--check`。
ネットワークも認証情報も要らないので、pre-commit フックやビルド前に置ける。

| # | 内容 | 実装 |
|---|---|---|
| 4-1 | **`colaxy_localization` / `colaxy_screenshot` の出力を、投入前に検証する** | ✅ `MetadataCheck` |
| 4-2 | ロケール名の不一致、必須ファイルの欠落、文字数超過を投入前に検出する | ✅ ただし**ロケール名は照合しない** (許容リストを持たない方針のため)。代わりに**「静かに無視されるもの」**を検出対象の中心にした |
| 4-3 | ただし**ストアが判定すべきものはストアに任せる** | ✅ 画像の寸法・サイズ・枚数は見ない。文字数は **warning** 止まりで、ブロックしない |

**検出の中心を「必須ファイルの欠落」から「静かに無視されるもの」に変えた。**
`FastlaneMetadata` は認識できないものをスキップする設計 (メタデータツリーには
iOS の資材も入るため)。つまり `phonescreenshots` と小文字で書いたディレクトリは
**1枚も上がらないのに成功として報告される**。これが最も高くつく誤りで、
検証層以外に露見する場所が無い。

検出するもの: スロット名の綴り違い / App Store 用のファイル名が android ツリーに
混ざっている (`description.txt`) / `changelogs/` の選択されないファイル名 /
PNG・JPEG 以外の拡張子 / 空のスロットディレクトリ / 行き場のない `featureGraphic.png` /
Google が明記している文字数上限 (書記素クラスタで数える)。

**完了条件**: 生成 → 検証 → 投入がローカルで完結し、ストアに送る前に構造的な誤りが出る。
→ **達成。**

> これは fastlane では原理的にできない。生成側と投入側が同じ言語だから可能になる利点で、
> **「Ruby を消す」以外の実質的な価値**がここで初めて出た。
>
> **既に1件回収している** (下記)。

#### 4-A. `colaxy_localization` の説明文が上限を超えうる ✅ **修正済み (v0.2.1)**

`LocaleUnit._getDescription()` は 4000 文字を検査していたが、
`_fitDescriptionToFastlane()` は**その後で**
`\n\n[Minimum supported app version: X]` を追記していた。
→ **上限ぎりぎりの説明文はディスク上で 4000 文字を超えていた。**
生成側では捕まらず、Play に送って初めて弾かれる。iOS 側も同様 (`[:mav: X]`)。

**修正**: 検査を「書き出すファイルの中身」に対して行うようにした。
エラーメッセージは追記分のコストと、説明文が収まるべき長さを名指しする
(`4040 characters` / `footer adds 40` / `under 3960`)。

> **これが Stage 4 の存在理由そのもの。** 検証層を作ったから見つかったのではなく、
> **「生成側の検査と、投入側が読むファイルがズレる」という発想が出たから**見つかった。
> 生成と投入が別言語なら、この2つを並べて考える機会が無い。

---

### Stage 5 — ASC のメタデータ投入 ✅ **実装済み**

**Stage A は完了済み。** ここから Apple 側。設計は
[app_store_connect_api.md](app_store_connect_api.md) の実測に基づける。

| # | 内容 |
|---|---|
| 5-1 | **メタデータは2リソースに割れる。** `AppInfoLocalization` (name / subtitle / privacyPolicyUrl) と `AppStoreVersionLocalization` (description / keywords / whatsNew / promotionalText / supportUrl)。`colaxy_localization` の8ファイルが **3 : 5 に分かれる** |
| 5-2 | **逐次反映なので、途中失敗時に何が残るかを型かドキュメントで明示する。** Play の `commit` と同じインターフェースで包まない (4-1)。トランザクションが無いことは実測で確定 |
| 5-3 | `fastlane/metadata/<iosLocale>/` の読み取り。Android 側と違い**平坦なディレクトリが2リソースに割れる**ので、`FastlaneMetadata` の素直な移植にはならない |
| 5-4 | **`appInfos` を状態で絞ってから書く。** アプリは状態ごとに複数の `appInfo` を持ち、間違った方に書くと**成功として報告されたまま何も起きない** (U-A2)。Android 側で `MetadataCheck` が潰したのと同じ種類の失敗 |

**完了条件**: 実アカウントで1ロケール更新。**消えるもの**: `deliver` のメタデータ部分。

---

### Stage 6 — ASC のスクショ投入 ✅ **実装済み**

| # | 内容 |
|---|---|
| 6-1 | **`POST appScreenshotSets` → `POST appScreenshots` → `uploadOperations` で分割転送 → `PATCH {uploaded, sourceFileChecksum}`。** A-5 で確定した多段。`AppScreenshot` は**チェックサムを要求する側** (MD5) |
| 6-2 | `colaxy_screenshot` の `fastlane/screenshots/<locale>` からの読み取り |
| 6-3 | **`ScreenshotDisplayType` への変換表を書く。33値ある。** `colaxy_screenshot` のファイル名 (`iphone65` / `ipadPro13` / `mac`) は enum と一致しないので、**Play 側と違って変換表が避けられない** |
| 6-4 | **`appScreenshotSets` に `PATCH` は無い** (実測)。差し替えはセットごと削除して作り直す。Android 側の `replaceScreenshots` と同じく既定で無効にする |
| 6-5 | アップロードは非同期で処理される。提出前に状態をポーリングする必要がある (fastlane も同じことをしている) |

**完了条件**: 実アカウントで1ロケール分反映。**消えるもの**: `deliver` の残り。

---

### Stage 7 — TestFlight / 提出 ✅ **実装済み**

| # | 内容 | 実装 |
|---|---|---|
| 7-1 | `betaGroups` / `betaTesters` の操作 | ✅ `BetaGroupsApi` / `BetaTestersApi`。**グループからのビルド削除だけ実装していない** — `DELETE` にボディが要るのに共有クライアントが送れず、POST のパスを発明するのは推測になるため |
| 7-2 | ビルドの TestFlight 配布。外部テスターには `betaAppReviewSubmissions` の POST も要る | ✅ `TestFlightApi.distribute` が一連でやる |
| 7-3 | 審査提出は **`reviewSubmissions` + `reviewSubmissionItems`** | ✅ `ReviewSubmissionsApi`。**`prepare` は submission と item の両方を作るが提出はしない**。item を忘れると「提出できるが何も提出されない」submission になる |
| 7-4 | 提出は**既定で無効にする** | ✅ **どこからも自動で呼ばれない。** CLI にフラグすら無く、`prepare` → `submit` の2行を手で書かせる |

#### 7-A. 実装して分かった「静かに失敗する」経路が2つ

**Stage 7 で最も重要なのはここ。** どちらもリクエストは全部成功を返す。

1. **外部グループにビルドを割り当てただけでは誰にも届かない。**
   `READY_FOR_BETA_SUBMISSION` のまま止まる。
   `betaAppReviewSubmissions` を POST して初めて動く
2. **輸出コンプライアンスの回答が無いビルドは誰にも届かない。**
   `MISSING_EXPORT_COMPLIANCE` のまま止まる

→ `TestFlightApi.distribute` が両方を検出して警告する。
また**種別が不明なグループは外部として扱う** — 内部と仮定すると
審査を飛ばしてビルドが宙に浮き、理由がどこにも出ない。

`InternalBetaState` (7値) と `ExternalBetaState` (13値) は**別の enum**で、
審査サイクルを持つのは外部だけ (実測)。

#### 7-B. テスター向けのノートは listing の `whatsNew` ではない

`betaBuildLocalizations.whatsNew` と
`appStoreVersionLocalizations.whatsNew` は**別リソースの別フィールド**。
`colaxy_localization` の `release_notes.txt` 1つから**2回書く**ことになる。

**消えるもの**: `pilot`。

---

### Stage 8 — 署名とバイナリ

**壁 B のみ。壁 A は消えた** ([app_store_connect_api.md](app_store_connect_api.md) 0節)。
`Process.run` が入るのは**署名とビルドだけ**で、アップロードは HTTP で足りる。

| # | 内容 |
|---|---|
| 8-1 | ASC API から証明書 / プロビジョニングプロファイルを取得。**D-1 の答えは「取れる」** — `certificates` (`POST,GET,PATCH,DELETE`) / `profiles` (`POST,GET,DELETE`、**PATCH 無し**) / `devices` (`POST,GET,PATCH`、**DELETE 無し**、無効化は PATCH) |
| 8-2 | `security` コマンドでキーチェーンに導入する薄いラッパ ← **ここは残る (壁 B)** |
| 8-3 | `xcodebuild` / `flutter build ipa` の呼び出し。**ラッパを厚くしない** (3節: CLI のラッパを書いても何も得しない) ← **ここも残る (壁 B)** |
| 8-4 | ~~Transporter / altool / notarytool~~ → **`buildUploads` で API から上げる。** 予約 → `uploadOperations` で分割転送 → `PATCH {uploaded, sourceFileChecksums}` → `state` が `COMPLETE` になるまでポーリング。**D-3 (altool の認証) は問い自体が消えた** |
| 8-5 | **`match` 相当は作らない。** 個人開発では不要。必要になった時点で別途設計する (7節) |
| 8-6 | `BuildUpload` は `assetFile` / `assetDescriptionFile` / `assetSpiFile` の3つのリレーションを持つ。**`.ipa` を1つ投げれば済むのかは未検証** (U-A3) |

**完了条件**: **Fastfile / Gemfile / Ruby なしで iOS のリリースが1回通る。**

**消えるもの**: **fastlane そのもの。**
Apple 純正ツールへの依存も**署名とビルドだけに縮んだ** — 転送は Dart で完結する。

---

### Stage 9 — 仕上げ

| # | 内容 | 状態 |
|---|---|---|
| 9-1 | **`doctor` サブコマンド。** 認証、権限、必要ファイルの有無を検査する | ✅ **完了。** ファイルは `--check` (Stage 4)、認証と権限は `--doctor` (`PlayDoctor`)。**エディットを1つ開いて破棄する** — 読めるだけの権限と公開できる権限は別なので、書きにいかないと区別できない |
| 9-2 | README と例。段階ごとに「fastlane の何を置き換えるか」を対応表で書く | ✅ Play 側は完了。ASC 側は未着手なので表が埋まっていない |
| 9-3 | **fastlane と併用できることを明記する。** 全部を一度に置き換える必要はなく、`supply` だけ差し替える使い方ができるべき | ✅ README 冒頭に「`supply` を置き換える。`deliver` / `pilot` は範囲外」と明記した |

---

### 各段階で消えるもの (一覧)

| 段階 | fastlane から消えるもの | Ruby が要らなくなるか | 状態 |
|---|---|---|---|
| Stage 0 | `snapshot` / `screengrab` | — | ✅ 完了 |
| Stage 1〜2 | `supply` のメタデータと画像 | まだ | ✅ 実装済み・未検証 |
| **Stage 3** | **`supply` 全体** | **Android のみ不要** | ✅ 実装済み・未検証 |
| Stage 4 | (中間形式の型検証) | — | ✅ **完了。** ネットワーク不要なので実アカウント検証を待たない |
| Stage 5〜6 | `deliver` のメタデータと画像 | まだ | ✅ 実装済み・未検証 |
| Stage 7 | `pilot` | まだ | ✅ 実装済み・未検証 |
| **Stage 8** | **fastlane 全体** | **完全に不要** | 未着手 (`buildUploads` で壁 A は消滅済み) |

> **「実装済み・未検証」を「完了」と書かないこと。** `colaxy_store_console` では
> モックで通ったあと実データで5件の誤りが出た。今回も同じ段階にいる。

---

## 7. やらないこと

構想が肥大化しないよう、最初から除外するものを決めておく。

| 除外 | 理由 |
|---|---|
| **`gym` / `scan` の置換** | `xcodebuild` / `flutter test` のラッパを書いても何も改善しない (3節) |
| **`match` の完全再発明** | 個人開発では不要。必要になってから設計する |
| **CI そのもの** | GitHub Actions などは残る。これは fastlane の代替物ではない |
| **バージョン管理・タグ打ち** | `fastlane` の `increment_version_number` 相当。git と pubspec の操作で、リリース層の責務ではない |

---

## 8. リスクと、それでもやる理由

構想として気持ちよく書けてしまうので、逆の材料も書いておく。

### リスク

- **API 追随コストを自分で背負う。** 今は fastlane のコミュニティが Apple / Google の
  仕様変更に追随してくれている。自作するとそれが自分の負担になる。
  `colaxy_store_console` で「Apple も Google もドキュメント外の挙動が多い」と何度も
  踏んだとおり、これは軽くない。
- **fastlane は現に動いている。** 置き換えの価値は Ruby 依存の除去に限定され、
  機能面では**同じかやや劣る**状態からスタートする。
- **Apple 側の未知が大きい。** この文書の Apple に関する記述は全て未検証。
  調べた結果、想定より重いと分かる可能性がある。

### それでもやる理由

- **既に7割できている。** 生成側3つと監視が完成済みで、外部プロセス依存もゼロ。
  ゼロから始める話ではなく、**1箇所を埋める話**。
- **認証基盤が済んでいる。** `colaxy_store_console` の Phase 0 (スコープ引数化、
  リトライ、ページング、ロギング) がそのまま投入側でも効く。
- **生成物と投入が同じ言語なら、中間形式を型で検証できる。** 今は
  `colaxy_localization` が書いた `fastlane/metadata/` を fastlane が読むまで
  誤りが分からない。同一言語なら生成時点で弾ける。
- **Stage 1 で Android が独立する。** 部分的な達成に意味がある構成。

---

## 9. 未検証事項

| # | 事項 | 状態 |
|---|---|---|
| D-1 | ASC API で証明書 / プロビジョニングプロファイルを取得できるか。できる場合の粒度 | ✅ **解決。取れる。** メソッドの粒度は Stage 8-1 |
| D-2 | Apple のバイナリアップロードが本当に ASC API 不可か (= [store_publish.md](store_publish.md) U-3) | ✅ **解決。可能になっていた** (`buildUploads`)。**前提が古かった** |
| D-3 | `notarytool` / `altool` を Dart から呼ぶ際の認証方式 (ASC API キーを流用できるか) | ✅ **問いが消えた。** D-2 の結果、どちらも呼ばない |
| D-4 | fastlane の `deliver` が内部で何を呼んでいるか。ソースを読んで確認する価値がある | ✅ **解決。** `Spaceship::ConnectAPI` (旧 Tunes から移行済み)。Transporter はバイナリ専用 |
| D-5 | Play の aab アップロードにサイズ上限やレジューム機構があるか | **半分解決。** レジュームは `ResumableUploadOptions` として存在し、既定で使う実装にした。**サイズ上限は未確認** |
| **D-6** | **Play 側の実装が実アカウントで動くか** (= [store_publish.md](store_publish.md) U-8) | **新規。Stage 1〜3 の完了条件** |

---

## 10. 一行まとめ

**Android は生成から投入まで純 Dart で閉じた** (`colaxy_store_publish`、Stage 1〜4)。
**ただし実アカウントで1度も叩いていないので、まだ「動く」とは言えない。**

**Apple 側は調査が終わり (Stage A)、壁 A が消え、Stage 5〜6 も実装した。**
`deliver` のメタデータと画像は置き換わっている。
バイナリまで API で上げられるので、Apple 純正ツールが要るのは**署名とビルドだけ**。
残る非対称はトランザクションの不在・メタデータが2リソースに割れること・
画像種別が33値で変換表が要ること
([app_store_connect_api.md](app_store_connect_api.md))。

残るのは **Stage 8 (署名とバイナリ)** と、**両ストアの実アカウント検証**だけ。
`supply` / `deliver` / `pilot` は置き換わっている。

目標は fastlane の全廃ではなく **Fastfile を書かなくて済む状態**だったが、
**全廃の方が当初の想定より近い**。
