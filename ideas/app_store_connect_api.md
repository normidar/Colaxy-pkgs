# App Store Connect API: 投入系の実測

**ステータス: 調査完了 (Stage A)。Stage 5〜8 は実装済み。
読み取りは検証済み (12節)。**バイナリ投入は転送・確定まで実アカウントで動作**
(13節)。メタデータとスクショの書き込みは未検証。**

調査日: 2026-09-03。[dart_native_pipeline.md](dart_native_pipeline.md) の Stage A
「Apple 側の空白を埋める」の結果。それまで Apple に関する記述は
**この ideas フォルダ全体で推測しか無かった**ので、その置き換え。

---

## 前提と信頼度

| 区分 | 内容 |
|---|---|
| ✅ **検証済み** | **Apple 公式の OpenAPI 仕様 (`openapi.oas.json`) をダウンロードして実際に読んだ。** `info.version` は **4.4.1**、966 paths / 1393 schemas。パス・メソッド・スキーマ属性・enum の値は**実物** |
| ✅ **検証済み** | Play 側と同じ基準。あちらは `googleapis` の生成クライアントを読んだ ([store_publish.md](store_publish.md))。**ようやく両者の信頼度が揃った** |
| ✅ **実アカウント検証済み (2026-09-04)** | **読み取り経路を実際に叩いた。** `appInfos` / `appStoreVersions` / `betaGroups`。12節に結果 |
| ✅ **実アカウント検証済み (2026-09-04)** | **`buildUploads` の転送と確定が動いた** — 29MB / 6チャンク。Apple の処理段階でバージョン理由の拒否 (13節) |
| ⚠️ **未検証** | **メタデータ PATCH / スクショ / TestFlight は未検証。** ビルドが COMPLETE まで通るのも未確認 |
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

> **U-A3 は仕様だけで解けた (2026-09-03 追記)。**
> 初回の抽出で `uti` と `assetType` を「素の文字列」と書いたのは**誤り**で、
> スキーマの `type` だけ見て `enum` を見落としていた。実際は両方 enum:
>
> ```
> assetType: ASSET | ASSET_DESCRIPTION | ASSET_SPI   ← 3つのリレーションに対応
> uti:       com.apple.ipa | com.apple.pkg | com.apple.binary-property-list
>            | com.apple.xml-property-list | com.pkware.zip-archive
> ```
>
> つまり3つのファイルは**役割が型で決まっている**。本体は `ASSET` +
> `com.apple.ipa` (macOS なら `com.apple.pkg`)。残り2つは plist で、
> Transporter が同梱していたメタデータに相当する。
> **API 経由で必須かどうかだけが未検証**で、実装は本体1つだけ送っている。
>
> `uti` が enum である以上、**列挙に無い種類は原理的に上げられない** —
> `.aab` を投げる余地は無い。

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

### 静かに失敗する経路 ✅ **実アカウントで確認済み (12-1)**

**アプリは `appInfo` を複数持つ。** 実測で2つあり、状態が違った
(`READY_FOR_SALE` と `REJECTED`)。**間違った方に書くと何も起きないまま成功する**
という部分だけは二次情報のままだが、**複数あること自体は確定**。
書く前に状態で絞る必要がある。

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
`AppStoreVersionState` には無い。
✅ **U-A4 解決 (12-2)**: **両方とも常に埋まり、語彙が違う**
(`READY_FOR_SALE` ⇄ `READY_FOR_DISTRIBUTION`)。別名ではなく別の状態機械。

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
| U-A2 | `appInfos` が状態ごとに複数ある件 | ✅ **複数あることは確認 (12-1)。** 「無反応になるか」だけ二次情報のまま |
| U-A3 | ~~3つのファイル関係に何を入れるのか~~ | ✅ **仕様で解決。** `assetType` / `uti` が enum だった (0節)。**残るのは「description と spi が必須か」だけ** — 実装は本体1つだけ送る |
| U-A4 | ~~2つの state enum の使い分け~~ | ✅ **解決 (12-2)。** 両方埋まり語彙が違う。`filter` が受ける `appStoreState` に分岐を揃えた |
| U-A5 | `uploadOperations` の並列度とリトライ。Apple がレート制限をかけるという報告 (二次) | 分割アップロードの設計に直結 |
| U-A6 | `colaxy_screenshot` のファイル名 → `ScreenshotDisplayType` の対応表 | `iphone65` / `ipadPro13` / `mac` の3つだけなので小さいが、実物で確認が要る |
| U-A7 | `.pkg` (macOS) も `buildUploads` で上げられるか。三者ツールは `.ipa` のみと言う (二次) | `Platform` に `MAC_OS` はあるので、仕様上は通るはず |
| U-A8 | ドライラン相当が本当に無いか。966パスを目視で確認したわけではない | Play との差が一番大きいところ |
| **U-A9** | **`betaGroups` の `isInternalGroup` が実際に返るか。** 返らない場合、実装は全グループを外部扱いにしてベータ審査を投げる | 内部グループに対して不要な審査を投げることになる。逆よりは安全だが、余計な待ちが入る |
| U-A10 | `reviewSubmissions` の `state` に実際どんな値が入るか。仕様では enum ではなく素の文字列 | 状態で分岐する実装ができない |
| U-A11 | `betaGroups/{id}/relationships/builds` の `DELETE` にどんなボディが要るか | 未実装のまま残している唯一の操作 |

---

## 10. 次の一歩

Stage 5〜7 と Stage 8 のバイナリ投入は実装済み。`colaxy_store_console` の `AppStoreConnectClient` を
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
4. **TestFlight を内部グループで1回通す。**
   `--testflight=<内部グループ名>`。**外部グループで先に試さないこと** —
   ベータ審査が走るので取り消しが効かない。U-A9 がここで片付く
5. ~~`buildUploads` を実装する~~ ✅ **完了。** U-A3 は仕様で解決した (0節)。
   **残るのは署名 (壁 B) だけ** — `security` / `xcodebuild` を呼ぶ層で、
   ここは Dart 化ではなく薄いラッパになる
6. ~~TestFlight と提出 (Stage 7)~~ ✅ **実装完了。** 分かったことは
   [dart_native_pipeline.md](dart_native_pipeline.md) 7-A / 7-B

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

---

## 12. 実アカウントでの検証 (2026-09-04)

`colaxy_store_console` の `.env` にある実資格情報で**読み取り経路だけ**叩いた。
書き込みは1つもしていない。識別子は伏せ、形と件数のみ記録する。

### 12-1. U-A2 は事実だった ✅ **確認**

**これまで二次情報 (フォーラム投稿) だけを根拠にしていた最大の懸念が裏付けられた。**

```
GET /v1/apps/{id}/appInfos  →  count = 2
  appStoreState=READY_FOR_SALE  state=READY_FOR_DISTRIBUTION
  appStoreState=REJECTED        state=REJECTED
```

**アプリは本当に `appInfo` を複数持つ。** `infos.first` を取る実装だったら
`READY_FOR_SALE` の record に書き込んでいた — 成功を返して何も変わらない、
という当初から警戒していた失敗そのもの。
`AppInfosApi.editable` が状態で絞る設計は**必要だった**ことが確定した。

### 12-2. U-A4 解決 ✅ 両方とも埋まる。ただし語彙が違う

```
GET /v1/apps/{id}/appStoreVersions  →  count = 11
  appStoreState=READY_FOR_SALE   appVersionState=READY_FOR_DISTRIBUTION
  appStoreState=REJECTED         appVersionState=REJECTED
```

**両方のフィールドが常に埋まっていて、値の語彙が違う** —
`READY_FOR_SALE` ⇄ `READY_FOR_DISTRIBUTION`。別名ではなく別の状態機械。
`filter[appStoreState]` が受け付けるのは前者なので、
**分岐も前者に揃える**という実装の判断はこれで正当化された。

### 12-3. ⚠️ **新しい問題: `isEditable` が狭すぎる**

このアプリには **`PREPARE_FOR_SUBMISSION` のバージョンも `appInfo` も無い。**
11バージョンのうち10が `READY_FOR_SALE`、1つが `REJECTED`。

つまり **`--doctor` は正しく「書ける場所が無い」と報告した**のだが、
同時に**「却下されたバージョンを直して出し直す」という最も普通の作業が
できない**ことも意味する。Apple は `REJECTED` / `METADATA_REJECTED` /
`DEVELOPER_REJECTED` のバージョンのメタデータ編集を許すはずだが、
実装は `PREPARE_FOR_SUBMISSION` だけを書き込み窓にしている。

**これは推測で広げてはいけない。** どの状態でどのフィールドが編集可能かは
Apple が明文化しておらず、ロケールごとに違うという報告もある (二次)。
広げ方を決めるには**却下状態のバージョンに実際に PATCH を投げて確かめる**
必要があり、それは実アプリへの書き込みになる。→ U-A12。

### 12-4. macOS 版が存在する → U-A7 が実務的な問題になった

`platform=MAC_OS` のバージョンが1つあった。
**`.pkg` を `buildUploads` で上げられるかは未検証**のままなので、
このアプリの macOS 側は現状カバーできていない可能性がある。

### 12-5. U-A9 は検証できなかった

```
GET /v1/apps/{id}/betaGroups  →  count = 0
```

TestFlight グループが1つも無いので、`isInternalGroup` が返るかどうかは
**確かめられなかった**。実装は「不明なら外部扱い」で安全側に倒してある。

### 12-6. 未検証のまま残ったもの

| # | 事項 |
|---|---|
| U-A12 | **却下状態のバージョンにメタデータを PATCH できるか** (12-3)。実アプリへの書き込みが要る |
| U-A5 / U-A6 | スクショの分割転送と `ipadPro13` の対応先。書き込みが要る |
| U-A7 | `.pkg` を `buildUploads` で上げられるか (12-4) |
| U-A9 | `isInternalGroup` が返るか (12-5)。グループを作らないと確かめられない |

---

## 13. buildUploads の実アカウント検証 (2026-09-04)

polygon の `.ipa` (29MB) を実アカウントに投げた。**転送と確定は完全に動いた。**
拒否されたのは Apple の業務ルールで、実装の欠陥ではない。

```
created build upload …  for 78
reserved PolyWallet.ipa (6 chunks)
uploaded 5242880 bytes ×5 + 3778537 bytes   ← 29MB / 6チャンク
committed the archive
→ Apple が処理して拒否:
   90062: CFBundleShortVersionString [1.4.7] は承認済みの [1.4.9] より
          高くなければならない
   90478: 1.4.9 は新規ビルド受付を終了している
   90186: train version '1.4.7' は受付終了
```

**Apple は宣言値ではなく `.ipa` 内の Info.plist を読む。** `buildUploads` に
`cfBundleShortVersionString` を宣言させるのに、検証は実ファイルに対して行う。
つまり**宣言はメタデータであって真実ではない**。上げ直すにはビルドし直すしかない。

### 13-1. 仕様の読み落としが2件、実データで露見した

どちらも**モックでは絶対に見つからない** — モックは渡されたものをそのまま返すので。

**(1) `app` リレーションが必須だった**

```
POST /v1/buildUploads → 409 ENTITY_ERROR.RELATIONSHIP.REQUIRED
  You must provide a value for the relationship 'app'
```

仕様の `BuildUploadCreateRequest` は `attributes.required` と
`relationships.required` を**別々に**持つ。前者だけ見て後者を見落としていた。
`uti` / `assetType` の enum 見落とし (0節) と**同じ形の誤り**。
スキーマは1箇所読んで分かった気にならないこと。

**(2) `SHA_256` は仕様の enum にあるが、ストアが拒否する**

バイトを送らずに3通り試した結果:

| 送った形 | Apple |
|---|---|
| `file` のみ / `SHA_256` | ❌ `ENTITY_ERROR.ATTRIBUTE.INVALID` |
| `file` のみ / **`MD5`** | ✅ **形は受理** (`CONTENT_NOT_UPLOADED` で止まる = 別の理由) |
| `file` + `composite` / `SHA_256` | ❌ `ATTRIBUTE.INVALID` |

→ **`MD5` 必須。`composite` は不要。** 既定を `SHA_256` にしていたのが誤りだった。
`ChecksumAlgorithm` に両方あるのは仕様どおりだが、**動くのは片方だけ**。

> **バイトを送らずに検証できたのが効いた。** 予約だけ作って PATCH を3通り
> 投げれば属性検証は走る。29MB を3回送っていたら10分近く掛かっていた。

### 13-2. `DELETE /v1/buildUploads/{id}` は状態を選ぶ

- `AWAITING_UPLOAD` → 削除できた
- `FAILED` → **`STATE_ERROR.INVALID_STATE` で削除できない**

つまり**失敗したアップロードの記録は消せない**。
実装の `_deleteQuietly` (転送失敗時) は前者に当たるので機能するが、
処理段階で拒否されたものは残る。

アカウント全体では `AWAITING_UPLOAD` が27件溜まっていた。
**放置された予約が溜まるのはこの API の通常の姿**で、
Transporter 経由でも同じことが起きているとみられる。

### 13-3. 未検証のまま残ったもの

| # | 事項 |
|---|---|
| U-A13 | **ビルドが実際に COMPLETE まで通るか。** バージョンを上げ直したビルドでしか確かめられない |
| U-A7 | `.pkg` (macOS) が上げられるか。polygon には macOS 版がある |
| U-A3 の残り | `ASSET_DESCRIPTION` / `ASSET_SPI` が必要な場面があるか。本体だけで**予約と転送と確定は通った** |
