# ideas

着手していない構想の置き場。実装計画ではなく**調査の結果と判断の記録**。

各文書は冒頭に「前提と信頼度」を持ち、**何が実測で何が未検証か**を明示する。
`colaxy_store_console` の PLAN.md で「実データでしか分からなかったことが5件あった」
という経験があるため、机上の調査と検証済みの事実を混ぜない。

## 一覧

| 文書 | 内容 | ステータス |
|---|---|---|
| [dart_native_pipeline.md](dart_native_pipeline.md) | **全体構想。** fastlane を使わない Flutter リリースパイプライン。全9段階のステップ | 構想 |
| [store_publish.md](store_publish.md) | ストアへの投入層。上記 Stage 1〜3 の実装計画 | **優先度高・未着手** |
| [firebase_reporting.md](firebase_reporting.md) | Firebase のレポート/管理情報を読むパッケージ | **保留 (作らない)** |
| [repo_structure.md](repo_structure.md) | パッケージのディレクトリグループ化 | 未着手・低リスク |

## 読む順

1. **[dart_native_pipeline.md](dart_native_pipeline.md)** — 何を目指しているかと、そこまでの全段階
2. **[store_publish.md](store_publish.md)** — 最初に手を付けるべきものの詳細
3. 残り2つは独立した話題

## 現状の要約

- 生成側 (アイコン・スクショ・メタデータ) と監視側 (ストア API) は**完成済み**
- 全パッケージで `Process.run` の使用が**ゼロ**
- **投入だけが fastlane (Ruby) に依存**しており、そこが唯一の穴
- Play 側は API・認証・変換テーブルが揃っている。**未知は App Store Connect 側だけ**

## 書き方の約束

- 冒頭に「前提と信頼度」を置き、✅ 検証済み / ⚠️ 未検証 を分ける
- **推測で表を埋めない。** 分からないものは「未検証事項」の節に列挙する
- 判断は理由とセットで書く。「やらないこと」も明記する
- 相互参照は相対リンクで張る
