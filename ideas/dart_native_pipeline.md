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

### 壁 A: Apple のバイナリアップロード

ASC API にはバイナリを上げる口が無く、**Transporter (iTMSTransporter、Java 製) か
`altool` / `notarytool`** が必要 (⚠️ 要確認 = [store_publish.md](store_publish.md) の U-3)。

**fastlane も内部で同じものを呼んでいるだけ**なので、fastlane を外してもこの依存は消えない。
消えるのは Ruby であって、Apple のツールではない。

Google Play 側は `EditsBundlesResource.upload` で aab を上げられる (実測済み) ため、
**この壁は Apple 側にしか無い**。

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
| 外部プロセスを一切呼ばない | ❌ 不可能。`xcodebuild` と Transporter は Apple のもの |
| **Ruby ランタイムと gem 依存を消す** | ✅ **ほぼ可能。今のリポジトリの延長線上** |

そして**実際の痛みは後者**。bundler / gem のバージョン地獄、CI での Ruby セットアップ、
Fastfile の DSL が主なコストであって、Transporter を1回叩くこと自体は苦痛ではない。

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

### Stage A — Apple 側の空白を埋める (調査のみ、実装なし)

現時点で Apple に関する記述は**全て推測**。ここを埋めないと Stage 5 以降の設計ができない。

| # | 内容 |
|---|---|
| A-1 | **ASC の OpenAPI 仕様を取得し、投入系エンドポイントを Play 側と同じ粒度で表にする。** メタデータ (`appStoreVersionLocalizations` ?)、スクショ (`appScreenshotSets` / `appScreenshots` ?)、ビルド (`builds`)、TestFlight (`betaGroups` / `betaTesters`)、証明書 (`certificates` / `profiles` / `devices`) |
| A-2 | **バイナリアップロードの可否を確定する** (D-2 / [store_publish.md](store_publish.md) U-3)。不可なら Transporter / `altool` / `notarytool` のどれが必要かまで |
| A-3 | **ASC がトランザクションを持つか確認する** ([store_publish.md](store_publish.md) U-2)。Play の `edits` に相当する仕組みが無いなら、逐次反映を前提に失敗時の状態を設計する |
| A-4 | **fastlane の `deliver` / `supply` が内部で何を呼んでいるか読む** (D-4)。Apple の非公開挙動が判明している可能性が高く、最も効率の良い情報源 |
| A-5 | ASC のスクショが reservation + チャンク分割 + チェックサムの多段かどうか確認 |

**完了条件**: Apple 側の表が Play 側と同じ粒度で埋まり、「API でできること / できないこと」
の線が引かれている。**推測で埋めた箇所はゼロ**であること。

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

### Stage 5 — ASC のメタデータ投入

**Stage A の完了が前提。** ここから Apple 側。

| # | 内容 |
|---|---|
| 5-1 | Stage A-1 の表に基づいてメタデータ更新を実装 |
| 5-2 | **逐次反映なら、途中失敗時に何が残るかを型かドキュメントで明示する。** Play の `commit` と同じインターフェースで包まない (4-1) |
| 5-3 | `fastlane/metadata/` の iOS 側ディレクトリ構造への対応 |

**完了条件**: 実アカウントで1ロケール更新。**消えるもの**: `deliver` のメタデータ部分。

---

### Stage 6 — ASC のスクショ投入

| # | 内容 |
|---|---|
| 6-1 | Stage A-5 の結果に応じて、reservation → チャンク分割 → チェックサム → commit の多段を実装 |
| 6-2 | `colaxy_screenshot` の `fastlane/screenshots/<locale>` からの読み取り |
| 6-3 | デバイスサイズ種別のマッピング (Apple はディスプレイサイズ単位で、Play の `imageType` とは体系が違う) |

**完了条件**: 実アカウントで1ロケール分反映。**消えるもの**: `deliver` の残り。

---

### Stage 7 — TestFlight / 提出

| # | 内容 |
|---|---|
| 7-1 | `betaGroups` / `betaTesters` の操作 |
| 7-2 | ビルドの TestFlight 配布 |
| 7-3 | 審査提出。**既定で無効にする**。誤って提出すると取り消しが面倒で、`verify` を読み取り専用にしたのと同じ判断 |

**消えるもの**: `pilot`。

---

### Stage 8 — 署名とバイナリ (ここで初めて `Process.run` が入る)

**壁 A / 壁 B。** ここは「Dart 化」ではなく「Apple のツールを薄く呼ぶ」。

| # | 内容 |
|---|---|
| 8-1 | ASC API から証明書 / プロビジョニングプロファイルを取得 (D-1) |
| 8-2 | `security` コマンドでキーチェーンに導入する薄いラッパ |
| 8-3 | `xcodebuild` / `flutter build ipa` の呼び出し。**ラッパを厚くしない** (3節: CLI のラッパを書いても何も得しない) |
| 8-4 | Transporter / `altool` / `notarytool` でのアップロード (A-2 の結果次第)。認証に ASC API キーを流用できるか確認 (D-3) |
| 8-5 | **`match` 相当は作らない。** 個人開発では不要。必要になった時点で別途設計する (7節) |

**完了条件**: **Fastfile / Gemfile / Ruby なしで iOS のリリースが1回通る。**

**消えるもの**: **fastlane そのもの。** ただし Apple 純正ツールへの依存は残る (これは想定内)。

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
| Stage 5〜6 | `deliver` | まだ | 未着手 (Stage A 待ち) |
| Stage 7 | `pilot` | まだ | 未着手 |
| **Stage 8** | **fastlane 全体** | **完全に不要** | 未着手 |

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
| D-1 | ASC API で証明書 / プロビジョニングプロファイルを取得できるか。できる場合の粒度 | 未着手 |
| D-2 | Apple のバイナリアップロードが本当に ASC API 不可か (= [store_publish.md](store_publish.md) U-3) | 未着手 |
| D-3 | `notarytool` / `altool` を Dart から呼ぶ際の認証方式 (ASC API キーを流用できるか) | 未着手 |
| D-4 | fastlane の `deliver` が内部で何を呼んでいるか。ソースを読んで確認する価値がある | 未着手 |
| D-5 | Play の aab アップロードにサイズ上限やレジューム機構があるか | **半分解決。** レジュームは `ResumableUploadOptions` として存在し、既定で使う実装にした。**サイズ上限は未確認** |
| **D-6** | **Play 側の実装が実アカウントで動くか** (= [store_publish.md](store_publish.md) U-8) | **新規。Stage 1〜3 の完了条件** |

---

## 10. 一行まとめ

**Android は生成から投入まで純 Dart で閉じた** (`colaxy_store_publish`、Stage 1〜3)。
**ただし実アカウントで1度も叩いていないので、まだ「動く」とは言えない。**
残るのは Apple 側で、署名とバイナリの2点だけ Apple 純正ツールを薄く呼ぶ必要がある。
目標は fastlane の全廃ではなく、**Fastfile を書かなくて済む状態**。
