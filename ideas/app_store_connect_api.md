# App Store Connect API: 投入系の実測

**ステータス: 調査完了 (Stage A)。Stage 5〜6 は実装済み・実アカウント未検証。**

調査日: 2026-09-03。[dart_native_pipeline.md](dart_native_pipeline.md) の Stage A
「Apple 側の空白を埋める」の結果。それまで Apple に関する記述は
**この ideas フォルダ全体で推測しか無かった**ので、その置き換え。

---

## 前提と信頼度

| 区分 | 内容 |
|---|---|
| ✅ **検証済み** | **Apple 公式の OpenAPI 仕様 (`openapi.oas.json`) をダウンロードして実際に読んだ。** `info.version` は **4.4.1**、966 paths / 1393 schemas。パス・メソッド・スキーマ属性・enum の値は**実物** |
| ✅ **検証済み** | Play 側と同じ基準。あちらは `googleapis` の生成クライアントを読んだ ([store_publish.md](store_publish.md))。**ようやく両者の信頼度が揃った** |
| ⚠️ **未検証** | **実アカウントに対して1度も叩いていない。** Play 側と同じ状態 |
| ⚠️ **二次情報** | 運用上の注意 (レート制限、既知の不具合、altool の制約) はフォーラムとブログ由来。**仕様ではないので別扱い**。本文では「二次」と明記する |

> **表を要約しない** ([dart_native_pipeline.md](dart_native_pipeline.md) の R-1)。
> 以下の enum とメソッドは仕様から機械的に抜き出したもので、間引いていない。

---

## 0. 最大の発見: 壁 A が消えた

**このリポジトリの Apple 側の設計は、前提が1つ間違っていた。**

[dart_native_pipeline.md](dart_native_pipeline.md) の 4節「壁 A: Apple のバイナリ
アップロード」は、**ASC API にバイナリを上げる口が無い**ことを前提にしていた。
これは当時としては正しく、Apple 自身がフォーラムでそう回答していた (二次)。

**もう違う。** 仕様に以下がある:

```
POST   /v1/buildUploads
GET    /v1/buildUploads/{id}
DELETE /v1/buildUploads/{id}
GET    /v1/buildUploads/{id}/buildUploadFiles
POST   /v1/buildUploadFiles
GET    /v1/buildUploadFiles/{id}
PATCH  /v1/buildUploadFiles/{id}
GET    /v1/apps/{id}/buildUploads
```

`deprecated: false`。WWDC25 で発表され、**API 4.1 で出荷**された (二次)。

### 何が変わるか

| これまでの記述 | 実際 |
|---|---|
| 壁 A: バイナリは Transporter / altool が必須 | **不要。** API で完結する |
| Stage 8-4: Transporter / altool / notarytool でアップロード | **API で置き換わる** |
| 「外部プロセスを一切呼ばない = 不可能」(5節) | **署名だけになった。** バイナリ転送は Dart から HTTP で足りる |
| [store_publish.md](store_publish.md) 4-2「バイナリは Play のみ」 | **線を引き直せる。両ストア対応が可能** |
| D-2 / U-3「バイナリが本当に不可か」 | **解決。可能** |

> **`notarytool` は最初から無関係だった。** これは App Store 外で配布する
> Developer ID 署名の macOS アプリを公証するためのもので、`.ipa` の提出には使わない (二次)。
> Stage 8-4 が3つを並べていたのは誤り。

### 手順 (仕様から)

```
1. POST /v1/buildUploads
   required: cfBundleVersion, cfBundleShortVersionString, platform
   → BuildUpload (state: AWAITING_UPLOAD)

2. POST /v1/buildUploadFiles
   required: fileName, fileSize, uti, assetType
   relationship: buildUpload
   → uploadOperations[] を受け取る

3. uploadOperations の各要素で転送
   {method, url, length, offset, requestHeaders}

4. PATCH /v1/buildUploadFiles/{id}
   { uploaded: true, sourceFileChecksums: Checksums }

5. GET /v1/buildUploads/{id} を state が COMPLETE になるまでポーリング
```

`BuildUploadState`: `AWAITING_UPLOAD`, `PROCESSING`, `FAILED`, `COMPLETE`

`Platform`: `IOS`, `MAC_OS`, `TV_OS`, `VISION_OS`

`BuildUpload` のリレーション: `build`, `assetFile`, `assetDescriptionFile`,
`assetSpiFile`, `buildUploadFiles`
→ **ファイルは1つではない。** `assetFile` のほかに description と spi があり、
`.ipa` を1つ投げれば済む形ではない可能性が高い。**ここは実データ検証が要る (U-A3)。**

`Checksums` は `{file: {hash, algorithm}, composite: {hash, algorithm}}` で、
`ChecksumAlgorithm` は `MD5` と `SHA_256`。
**スクリーンショットの `sourceFileChecksum` (ただの文字列) とは別の形。** 混同しないこと。

---

## 1. `builds` は読み取り専用 (実測)

```
GET   /v1/builds        ← POST は無い
GET,PATCH /v1/builds/{id}
```

**`POST /v1/builds` は存在しない。** ビルドは自分で作るものではなく、
`buildUploads` の処理結果として現れる。`PATCH` できるのは
`usesNonExemptEncryption` などの属性のみ。

`Build` の属性 (実測): `version`, `uploadedDate`, `expirationDate`, `expired`,
`minOsVersion`, `lsMinimumSystemVersion`, `computedMinMacOsVersion`,
`computedMinVisionOsVersion`, `iconAssetToken`, `processingState`,
`buildAudienceType`, `usesNonExemptEncryption`

### 仕様全体でバイナリを直接 POST する口は無い

念のため966パスの `requestBody` を全部走査した:

> **JSON 以外の `content-type` を受け取るパスは1つも無い。**

つまり ASC API は**すべて JSON**で、ファイルの実体は必ず
`uploadOperations` が指す**別のエンドポイント**へ送る。
Play の `androidpublisher` が multipart/resumable でファイルを直接受けるのと
**根本的に方式が違う**。ここは共通化できない。

---

## 2. メタデータは2つのリソースに割れている (最重要の非対称)

**fastlane の `<locale>/` ディレクトリは平坦だが、ASC 側は2つのリソースに分かれる。**

### `AppInfoLocalization` (バージョン非依存・アプリ共通)

```
locale, name, subtitle, privacyPolicyUrl, privacyChoicesUrl, privacyPolicyText
```
`POST,GET,PATCH,DELETE /v1/appInfoLocalizations`
親は `appInfos` (`GET,PATCH` のみ。**POST は無い**)

### `AppStoreVersionLocalization` (バージョン固有)

```
locale, description, keywords, whatsNew, promotionalText, marketingUrl, supportUrl
```
`POST,GET,PATCH,DELETE /v1/appStoreVersionLocalizations`
親は `appStoreVersions` (`POST,GET,PATCH,DELETE`)

### `colaxy_localization` の出力との対応 (実測)

| ファイル | ASC のリソース | 属性 |
|---|---|---|
| `<iosLocale>/name.txt` | **AppInfoLocalization** | `name` |
| `<iosLocale>/subtitle.txt` | **AppInfoLocalization** | `subtitle` |
| `<iosLocale>/privacy_url.txt` | **AppInfoLocalization** | `privacyPolicyUrl` |
| `<iosLocale>/description.txt` | AppStoreVersionLocalization | `description` |
| `<iosLocale>/keywords.txt` | AppStoreVersionLocalization | `keywords` |
| `<iosLocale>/release_notes.txt` | AppStoreVersionLocalization | `whatsNew` |
| `<iosLocale>/promotional_text.txt` | AppStoreVersionLocalization | `promotionalText` |
| `<iosLocale>/support_url.txt` | AppStoreVersionLocalization | `supportUrl` |

**3 : 5 に割れる。** Play 側が `Listing` 1つに1対1で収まったのとまったく違う。

> **Play 側の「変換表を発明しなくていい」は Apple 側には効かない。**
> [store_publish.md](store_publish.md) 3節の発見はディレクトリ名が
> `imageType` と同一だったから成り立った話で、ここには対応物が無い。

### 静かに失敗する経路 (二次・要検証)

**アプリは `appInfo` を複数持つ** (状態ごとに1つ、例えば公開中と
`PREPARE_FOR_SUBMISSION` 用)。**間違った方に書くと何も起きないまま成功する**と
報告されている。書く前に状態で絞る必要がある。

この「成功として報告されるが何も起きない」形は、
`colaxy_store_publish` の `MetadataCheck` が Android 側で潰したのと同じ種類。
**Apple 側では検証層ではなくクライアント側で潰すしかない** (ローカルには情報が無い)。

---

## 3. トランザクションは無い (A-3 の答え)

**Play の `edits` に相当する仕組みは存在しない。** リソースごとに独立した
POST / PATCH で、サーバは現在の状態に合わないものを 409 で弾く。

つまり:

- **途中で失敗すると中途半端な状態が残る。** 補償操作は自分で書く
- 一番近いロールバックは **`DELETE /v1/appStoreVersions/{id}`**
  (未提出のバージョンを丸ごと消す)。仕様に `DELETE` がある

`AppStoreVersionState` (20値・実測):
```
ACCEPTED, DEVELOPER_REMOVED_FROM_SALE, DEVELOPER_REJECTED, IN_REVIEW,
INVALID_BINARY, METADATA_REJECTED, PENDING_APPLE_RELEASE, PENDING_CONTRACT,
PENDING_DEVELOPER_RELEASE, PREPARE_FOR_SUBMISSION, PREORDER_READY_FOR_SALE,
PROCESSING_FOR_APP_STORE, READY_FOR_REVIEW, READY_FOR_SALE, REJECTED,
REMOVED_FROM_SALE, WAITING_FOR_EXPORT_COMPLIANCE, WAITING_FOR_REVIEW,
REPLACED_WITH_NEW_VERSION, NOT_APPLICABLE
```

`AppVersionState` という**別の15値の enum も存在する** (実測)。
`PROCESSING_FOR_DISTRIBUTION` / `READY_FOR_DISTRIBUTION` を持ち、
`AppStoreVersionState` には無い。**どちらをいつ使うのかは未検証 (U-A4)。**

> **[store_publish.md](store_publish.md) 4-1 の判断は正しかった。**
> 「統一インターフェースで包むと『両方ロールバックできる』という嘘になる」。
> Play は `commit` を持ち、Apple は持たない。この非対称は隠せない。

---

## 4. スクリーンショットは予約 → 分割 → 確定 (A-5 の答え)

```
POST  /v1/appScreenshotSets    { screenshotDisplayType }
POST  /v1/appScreenshots       { fileName, fileSize } + rel: appScreenshotSet
      → uploadOperations[] {method, url, length, offset, requestHeaders}
PUT   各 uploadOperation の url へ、offset/length で切った実体を送る
PATCH /v1/appScreenshots/{id}  { uploaded: true, sourceFileChecksum }
```

`AppScreenshot` の属性 (実測): `fileSize`, `fileName`, `sourceFileChecksum`,
`imageAsset`, `assetToken`, `assetType`, `uploadOperations`, `assetDeliveryState`

`AppMediaAssetState.state`: `AWAITING_UPLOAD`, `UPLOAD_COMPLETE`, `COMPLETE`, …

`appScreenshotSets` に **`PATCH` は無い** (`POST,GET,DELETE` のみ)。
差し替えはセットごと消して作り直す形になる。

### 予約方式を使うリソースは25個ある (実測)

`uploadOperations` を持つスキーマを全部数えた。`AppScreenshot`, `AppPreview`,
`BuildUploadFile`, `AppEventScreenshot`, `AppStoreReviewAttachment`,
`RoutingAppCoverage`, GameCenter 系9個、InAppPurchase / Subscription 系6個 …

**うち `sourceFileChecksum` を要求するものと、しないものがある** (実測):

| チェックサム要 | チェックサム不要 |
|---|---|
| `AppScreenshot`, `AppPreview`, `AppStoreReviewAttachment`, `RoutingAppCoverage`, `InAppPurchaseImage`, `SubscriptionImage` … | `AppEventScreenshot`, `AppEventVideoClip`, `GameCenter*Image`, `InAppPurchaseImageV2`, `SubscriptionImageV2` … |

新しいリソースほど不要になる傾向。**`AppScreenshot` は要る側**なので、
Stage 6 では MD5 の計算が必要。

### `ScreenshotDisplayType` (33値・実測、間引かず全部)

```
APP_IPHONE_67, APP_IPHONE_61, APP_IPHONE_65, APP_IPHONE_58, APP_IPHONE_55,
APP_IPHONE_47, APP_IPHONE_40, APP_IPHONE_35,
APP_IPAD_PRO_3GEN_129, APP_IPAD_PRO_3GEN_11, APP_IPAD_PRO_129, APP_IPAD_105,
APP_IPAD_97,
APP_DESKTOP,
APP_WATCH_ULTRA, APP_WATCH_SERIES_10, APP_WATCH_SERIES_7, APP_WATCH_SERIES_4,
APP_WATCH_SERIES_3,
APP_APPLE_TV, APP_APPLE_VISION_PRO,
IMESSAGE_APP_IPHONE_67, IMESSAGE_APP_IPHONE_61, IMESSAGE_APP_IPHONE_65,
IMESSAGE_APP_IPHONE_58, IMESSAGE_APP_IPHONE_55, IMESSAGE_APP_IPHONE_47,
IMESSAGE_APP_IPHONE_40,
IMESSAGE_APP_IPAD_PRO_3GEN_129, IMESSAGE_APP_IPAD_PRO_3GEN_11,
IMESSAGE_APP_IPAD_PRO_129, IMESSAGE_APP_IPAD_105, IMESSAGE_APP_IPAD_97
```

**Play の `imageType` が9値だったのに対し33値。**
しかも `colaxy_screenshot` が出す `fastlane/screenshots/<locale>/` の
ファイル名 (`1_iphone65_1.welcome.png`) は**この enum と一致しない**。
`iphone65` → `APP_IPHONE_65`、`ipadPro13` → ? という変換表が要る。

> **ここが Android と決定的に違う。** Play では
> 「`colaxy_screenshot` の出力ディレクトリ名 = `imageType`」で変換表が不要だった。
> **Apple 側は変換表を書かざるを得ない。**

### 世代番号がウェブ UI と食い違う (二次・要検証)

13インチ iPad はウェブでは「iPad Pro (6th Gen) 12.9"」と出るのに、
API では `APP_IPAD_PRO_3GEN_129` として返る、という報告がある。
**`3GEN` を素直に「第3世代」と読むと外す。**

---

## 5. 提出とトラック相当

| リソース | メソッド (実測) |
|---|---|
| `reviewSubmissions` | `GET,PATCH,POST` |
| `reviewSubmissionItems` | `POST,PATCH,DELETE` |
| `appStoreVersionSubmissions` | **`DELETE` のみ** ← 旧方式。提出は `reviewSubmissions` を使う |
| `appStoreVersionPhasedReleases` | `POST,PATCH,DELETE` |
| `betaGroups` | `POST,GET,PATCH,DELETE` |
| `betaTesters` | `POST,GET,DELETE` |
| `betaAppReviewSubmissions` | `POST,GET` |

**`appStoreVersionSubmissions` に `POST` が無い**のが重要。
古い記事はこれで提出しろと書いているが、現在の口は `reviewSubmissions` +
`reviewSubmissionItems`。

`appStoreVersionPhasedReleases` が Play の `userFraction` に相当するが、
**Play は数値、Apple は状態遷移**で、粒度が違う。

---

## 6. 署名系 (Stage 8 用)

| リソース | メソッド (実測) |
|---|---|
| `certificates` | `POST,GET,PATCH,DELETE` |
| `profiles` | `POST,GET,DELETE` (**`PATCH` 無し**) |
| `devices` | `POST,GET,PATCH` (**`DELETE` 無し**。無効化は `PATCH`) |
| `bundleIds` | `POST,GET,PATCH,DELETE` |

→ **D-1 の答え: 取得できる。** ただしキーチェーンへの導入 (`security`) と
`xcodebuild` は依然として macOS のコマンドで、そこは Dart から `Process.run` する。
**壁 B は残る。**

---

## 7. Play との対比 (両方とも実測に基づく)

| | Google Play | App Store Connect |
|---|---|---|
| 仕様の入手 | `googleapis` 17.0.0 の生成クライアント | 公式 OpenAPI 4.4.1 |
| トランザクション | **あり** (`edits` + `commit` / `delete`) | **無し**。409 で弾かれる |
| ドライラン | **あり** (`edits.validate`) | **無し**。相当物が見当たらない |
| メタデータ | `Listing` 1つ | **2リソースに分割** (AppInfo / AppStoreVersion) |
| 画像 | 1回の `upload` | **予約 → 分割 → チェックサム → 確定** |
| 画像の種別 | `imageType` 9値、ディレクトリ名と同一 | `ScreenshotDisplayType` **33値、変換表が要る** |
| バイナリ | `bundles.upload` (multipart/resumable) | **`buildUploads` (予約方式)** ← 新 |
| ファイル転送 | API が直接受ける | **必ず別エンドポイントへ**。API 本体は全部 JSON |
| 署名 | 不要 | `certificates` / `profiles` / `devices` は取れるが、導入は OS のコマンド |

**「投入」という一語で括れるのはここまで。** 共通化できるのは認証・リトライ・
ロギングといった土台だけで、投入そのものの形はほとんど重ならない。

---

## 8. これで確定した判断

- **`commit` を隠さない判断は正しかった。** Apple に `commit` は無いので、
  共通インターフェースで包めば必ず嘘になる
- **バイナリの線引きは引き直せる。** 「Play のみ」ではなくなった
- **変換表を発明しない方針は Apple 側では成立しない。** `ScreenshotDisplayType`
  への変換は書くしかない。Play 側で不要だったのは幸運であって設計ではなかった

### ~~ASC は別パッケージにすべき~~ → **撤回。同じパッケージに入れた**

この節は当初「ASC 側は `colaxy_store_publish` に足すのではなく別パッケージに
すべき」と書いていた。**理由付けが間違っていた。**

挙げた理由は「投入の形は共有しない」だったが、それが要求するのは
**名前空間の分離であってパッケージの分離ではない**。
そして `colaxy_store_console` が**まさにそれを1パッケージでやっている** —
`src/app_store/` と `src/google_play/` に分け、
「4つの API 面を単一インターフェースに統一しない」と明記したうえで同居させている。

`colaxy_store_publish` を `colaxy_store_console` から分けた理由は
**読み取りと書き込みの分離** ([store_publish.md](store_publish.md) 6節) であって、
これは Play 投入と Apple 投入の間には**当てはまらない**。両方とも書き込みで、
リスクの性質が同じ。

→ `lib/src/app_store/` として同じパッケージに入れた。
共通の型は作らず、`PlayPublisher` / `AppStorePublisher`、
`PlayMetadataPublisher` / `AppStoreMetadataPublisher`、
`colaxy-store-publish` / `colaxy-store-publish-ios` と**二本立てにしてある**。
基底クラスは無い。

---

## 9. 未検証事項

| # | 事項 | なぜ重要か |
|---|---|---|
| U-A1 | **実アカウントで1度も叩いていない。** この文書は仕様の読解 | Play 側と同じ段階。前例では実データで5件の誤りが出た |
| U-A2 | `appInfos` が状態ごとに複数ある件 (二次)。間違った方に書くと無反応か | 「成功として報告されるが何も起きない」形。最も高くつく |
| U-A3 | `BuildUpload` の `assetFile` / `assetDescriptionFile` / `assetSpiFile` の3つに何を入れるのか | `.ipa` を1つ投げれば済むのか、xcodebuild が出す他のファイルが要るのか |
| U-A4 | `AppStoreVersionState` (20値) と `AppVersionState` (15値) の使い分け | 状態で分岐する実装の前提 |
| U-A5 | `uploadOperations` の並列度とリトライ。Apple がレート制限をかけるという報告 (二次) | 分割アップロードの設計に直結 |
| U-A6 | `colaxy_screenshot` のファイル名 → `ScreenshotDisplayType` の対応表 | `iphone65` / `ipadPro13` / `mac` の3つだけなので小さいが、実物で確認が要る |
| U-A7 | `.pkg` (macOS) も `buildUploads` で上げられるか。三者ツールは `.ipa` のみと言う (二次) | `Platform` に `MAC_OS` はあるので、仕様上は通るはず |
| U-A8 | ドライラン相当が本当に無いか。966パスを目視で確認したわけではない | Play との差が一番大きいところ |

---

## 10. 次の一歩

Stage 5〜6 は実装済み。`colaxy_store_console` の `AppStoreConnectClient` を
そのまま土台にしたので、認証・リトライ・ページングの作業はゼロだった
(5節の「再利用できる既存資産」が Apple 側でもそのまま効いた)。

1. **実アカウントで `--doctor` を通す (U-A1)。**
   ```bash
   export ASC_KEY_ID=… ASC_ISSUER_ID=… ASC_APP_ID=… ASC_P8="$(cat AuthKey.p8)"
   dart run colaxy_store_publish:publish-ios --doctor
   ```
   読み取りのみ。**U-A2 (複数 `appInfo`) と U-A4 (2つの state enum) が
   ここで片付く** — どの record がどの状態で返るかが見えるので
2. 1ロケールだけ `--locales=ja --no-screenshots` で書く (Stage 5)
3. スクショを1枚通す (Stage 6)。**U-A5 (分割の並列度) / U-A6 (`ipadPro13` の
   対応先)** がここで片付く。特に U-A6 は二次情報のままなので要確認
4. `buildUploads` を実装する (Stage 8 の前倒し)。U-A3 / U-A7
5. TestFlight と提出 (Stage 7)。`reviewSubmissions` 側を使うこと

> **Apple 側には dry-run が無い**ので、Play のような「安全な予行演習」ができない。
> `--doctor` は読み取り専用にとどめ、書き込みの検証は
> **1ロケール・スクショ無しから広げる**しかない。

---

## 11. 一行まとめ

**Apple 側は「API で何もできない」から「Play とは別の形で全部できる」に変わった。**
バイナリまで API で上げられるようになり (`buildUploads`、WWDC25)、壁 A は消えた。
残る非対称は**トランザクションの不在**と**メタデータが2リソースに割れること**、
そして**画像の種別が33値で変換表が要ること**。
共通化できるのは認証とリトライだけで、投入の形は重ならない。
