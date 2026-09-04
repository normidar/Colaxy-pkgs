# ideas

着手していない構想の置き場。実装計画ではなく**調査の結果と判断の記録**。

各文書は冒頭に「前提と信頼度」を持ち、**何が実測で何が未検証か**を明示する。
`colaxy_store_console` の PLAN.md で「実データでしか分からなかったことが5件あった」
という経験があるため、机上の調査と検証済みの事実を混ぜない。

## 一覧

| 文書 | 内容 | ステータス |
|---|---|---|
| [dart_native_pipeline.md](dart_native_pipeline.md) | **全体構想。** fastlane を使わない Flutter リリースパイプライン。全9段階のステップ | Stage A / 1〜7 + バイナリ完了。**残るは署名のみ** |
| [store_publish.md](store_publish.md) | ストアへの投入層 (Play 側) | **実装済み。書き込み経路まで実アカウント検証済み** |
| [app_store_connect_api.md](app_store_connect_api.md) | **ASC API の投入系の実測。** 公式 OpenAPI 4.4.1 を読んだ結果と、Stage 5〜8 の設計 | **実装済み。読み取りは実アカウント検証済み** |
| [firebase_reporting.md](firebase_reporting.md) | Firebase のレポート/管理情報を読むパッケージ | **保留 (作らない)** |
| [repo_structure.md](repo_structure.md) | パッケージのディレクトリグループ化 | 未着手・低リスク・見送り中 |

## 読む順

1. **[dart_native_pipeline.md](dart_native_pipeline.md)** — 何を目指しているかと、そこまでの全段階
2. **[store_publish.md](store_publish.md)** — Play 側の投入層。実装済みの内容と、実装して分かったこと
3. **[app_store_connect_api.md](app_store_connect_api.md)** — Apple 側の実測。Stage 5 以降の設計はここから引いた
4. 残り2つは独立した話題

## 現状の要約 (2026-09-03 更新)

- 生成側 (アイコン・スクショ・メタデータ) と監視側 (ストア API) は**完成済み**
- 全パッケージで `Process.run` の使用が**ゼロ**
- **`colaxy_store_publish` を作成し、Play 側の投入を実装した** (リスティング / 画像 /
  aab / トラック)。`fastlane supply` の置き換えは**コード上は完了**
- ただし**実アカウントに対して1度も叩いていない**。`colaxy_store_console` で
  「モックでは検出できない誤りが5件」出た前例があるので、**ここは未完了**とみなす
- **Stage 4 (投入前の検証) は完了。** ネットワーク不要なので実アカウント検証を待たない。
  **fastlane では原理的にできなかった部分**で、既に `colaxy_localization` の欠陥を1件
  見つけている ([dart_native_pipeline.md](dart_native_pipeline.md) 4-A)
- **Stage A (ASC 側の調査) も完了。** 公式 OpenAPI 4.4.1 を読み、
  Play 側と信頼度が揃った。**最大の発見は「壁 A の消滅」** —
  Apple もバイナリを API で上げられるようになっていた (`buildUploads`、WWDC25)。
  この ideas フォルダが前提にしていた記述が1つ古くなっていた
- **Apple 側も Stage 5〜7 + バイナリ投入まで実装済み。**
  `colaxy_store_publish` の `src/app_store/` に入れた。**共通の型は作っていない** —
  Play はトランザクションを持ち Apple は持たないので、包むと嘘になる
- **`supply` / `deliver` / `pilot` に加え、Transporter と altool も要らなくなった**
- **残るのは iOS のコード署名 (壁 B) だけ。** ここは `security` / `xcodebuild` を
  薄く呼ぶ層で、Dart 化する価値は無い
- **実データ検証を開始した (2026-09-04)。** `colaxy_store_console` の `.env` の
  実資格情報で両ストアの読み取り経路を叩いた。**Play の `--doctor` は一発で通った**
- **二次情報だった U-A2 が事実だと確認できた** — `appInfo` は本当に複数あり、
  状態が違う。`infos.first` を取る実装なら公開中の record に書き込んでいた
- **U-6 完全解決: Play のエディットは有効期間ちょうど2時間。**
  長い投入は1エディットに収まらない可能性がある
- **Play は書き込み経路まで通った。** 実アプリに `--dry-run` を実行し、
  `listings.update` / `images.deleteall` / `images.upload` を staging して
  **Google 自身の検証が受理**、そして破棄。残るは `commit` だけ
- **実データが実装の誤りを1件暴いた。** 403 を認証エラーに丸めていたため、
  「8枚を超えている」という検証エラーに「権限を確認しろ」と誤診していた。
  Google は権限エラーと検証エラーを同じ 403・理由なしで返す。401 のみを
  認証扱いにしていた `colaxy_store_console` が正しかった
- **Apple もバイナリ投入の転送・確定まで動いた** (29MB / 6チャンク)。
  今回のビルドは Apple にバージョン理由で拒否されたが、それは業務ルールで
  実装の欠陥ではない。**Transporter も altool も使っていない**
- **実データが仕様の読み落としを2件暴いた。** `app` リレーションの必須と、
  `SHA_256` が enum にあるのにストアが拒否すること。どちらもモックでは
  原理的に見つからない
- **残るは Play の `commit`、Apple のメタデータ/スクショ書き込み、そして署名**

## 書き方の約束

- 冒頭に「前提と信頼度」を置き、✅ 検証済み / ⚠️ 未検証 を分ける
- **推測で表を埋めない。** 分からないものは「未検証事項」の節に列挙する
- 判断は理由とセットで書く。「やらないこと」も明記する
- 相互参照は相対リンクで張る
