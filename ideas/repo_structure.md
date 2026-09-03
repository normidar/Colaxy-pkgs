# リポジトリ構成: パッケージのグループ化

**ステータス: 見送り中。** 2026-09-03 に「当面は `packages/` 直下の平坦のままでよい」
という判断があったため、実行していない。低リスクなので、やるなら早い方がよい
(7節の理由) という評価自体は変わらない。

調査日: 2026-08-29。更新: 2026-09-03。
パッケージが10個になり、性格の違うものが `packages/` 直下に平坦に並んでいるため、
まとめたいという話から。

---

## 前提と信頼度

| 区分 | 内容 |
|---|---|
| ✅ **検証済み** | 全パッケージの `pubspec.yaml` を読み、Flutter 依存の有無・CLI の有無・URL フィールドの数を確認 |
| ✅ **検証済み** | ルートの `workspace:` / `melos:` の定義を確認 |
| ✅ **検証済み** | S-2 / S-4 を実測で解消 (10節) |
| ⚠️ **未検証** | 移動を実際に試していない。`workspace` グロブの挙動は定義からの推論 |

---

## 1. 現状 (実測・2026-09-03 時点で12個)

| パッケージ | 種別 | CLI | 性格 |
|---|---|---|---|
| `colaxy_icons_launcher` | **純 Dart** | ✅ | リリースツール |
| `colaxy_localization` | **純 Dart** | ✅ | リリースツール |
| `colaxy_store_console` | **純 Dart** | ✅ (`verify`) | リリースツール |
| `colaxy_store_publish` | **純 Dart** | — | リリースツール (**新規**) |
| `colaxy_screenshot` | **Flutter** | — | リリースツール (**例外**) |
| `app_info_tile` | Flutter | — | UI 部品 |
| `app_lang_selector` | Flutter | — | UI 部品 |
| `app_theme_picker` | Flutter | — | UI 部品 |
| `colaxy_adaptive_scaffold` | Flutter | — | UI 部品 |
| `colaxy_tutorial` | Flutter | — | UI 部品 |
| `riverpod_helper` | Flutter | — | UI / 状態管理 |
| `zaim_api` | **純 Dart** | — | **どちらでもない** (外部 API クライアント) |

12個すべてが `packages/` 直下に平坦に並んでいる。

> **5節の分割軸が1つ崩れた。** 調査時は10個で「リリースツール 4 : UI 部品 6」に
> きれいに割れていたが、`zaim_api` は**どちらにも入らない**。
> 外部サービスのクライアントであって、このリポジトリのリリース工程とは無関係。
> 実行するなら `apis/` のような第3グループを作るか、`zaim_api` を直下に残すかの
> 判断が先に要る。**2軸で足りるという前提はもう成り立たない。**
>
> 一方 `colaxy_store_publish` は素直に `tools/` に入る (4節の「将来 store_publish」が
> そのまま該当)。

---

## 2. 「まとめる」の2つの解釈

| 解釈 | 可否 |
|---|---|
| パッケージを**統合**して1つにする | ❌ **技術的に不可能** (3節) |
| **ディレクトリでグループ化**する | ✅ **やる価値がある** (4節) |

---

## 3. パッケージの統合はできない

**決定的な理由: `colaxy_store_console` は Flutter 非依存の純 Dart である。**

これは偶然ではなく意図的な設計。PLAN.md 6-3 で
「**定期実行して自前で貯めるパイプラインに組み込む**用途が主」と判断しており、
CI やサーバーで動かすことが前提になっている。

一方 `colaxy_screenshot` は `RepaintBoundary` + `toImage` で描画するため **Flutter 必須**。

→ 統合すると **サーバーサイドで動かすライブラリが Flutter SDK を要求する**ことになり、
store_console が CI に載らなくなる。

**傘パッケージ (`colaxy_release` が全部を再エクスポート) も同じ理由で不可。**
傘自体が Flutter 依存になるため、問題は解決しない。

> **注意すべき単純化**: 「リリースツール群 = 純 Dart」と考えたくなるが、
> `colaxy_screenshot` が反例。グループ化の軸を Flutter/Dart で引くと
> screenshot だけ仲間外れになる (5節)。

---

## 4. ディレクトリでのグループ化 (推奨)

```
packages/
├── tools/     icons_launcher / localization / screenshot / store_console
│              (+ 将来 store_publish)
└── ui/        app_info_tile / app_lang_selector / app_theme_picker /
               adaptive_scaffold / tutorial / riverpod_helper
```

**利用者への影響はゼロ。** pub.dev のパッケージ名はディレクトリ位置と無関係なので、
移動しても既存の利用者は何も気づかない。

---

## 5. 分割軸の検討

| 軸 | 結果 | 評価 |
|---|---|---|
| Flutter / 純 Dart | screenshot が tools 側で唯一の Flutter | ❌ screenshot が浮く |
| CLI の有無 | screenshot だけ CLI が無い | ❌ 同上 |
| **用途 (リリースツール / UI 部品)** | 綺麗に 4 : 6 に割れる | ✅ **これを採る** |

**用途で割るのが正しい。** `colaxy_screenshot` は Flutter に依存しているが、
やっていることは「ストア用の画像を生成する」で、明確にリリースツール。
実装技術ではなく役割で分類する。

---

## 6. 移動時に踏む具体的な問題

### 6-1. ルートの `workspace` グロブが壊れる

現状:

```yaml
workspace:
  - packages/*
  - packages/*/example
  - example
```

`packages/*` が `packages/tools` にマッチするが、そこに `pubspec.yaml` が無いためエラーになる。

```yaml
workspace:
  - packages/*/*
  - packages/*/*/example
  - example
```

への書き換えが必要。

**melos 側は影響なし。** `packages: - packages/**` と既に再帰グロブになっている。

### 6-2. `repository:` と `homepage:` の URL が全部切れる

全パッケージが以下の形式を持つ (実測):

```yaml
homepage:   https://github.com/normidar/colaxy-pkgs/tree/main/packages/<name>
repository: https://github.com/normidar/colaxy-pkgs/tree/main/packages/<name>
```

→ **24箇所の更新が必要** (2フィールド × 12パッケージ)。
`issue_tracker:` はパスを含まない (`/issues`) ので影響なし。

> 調査時は20箇所だった。**5日で4箇所増えた**ことが 6-3 の「遅らせるほど損」を
> そのまま裏づけている。

### 6-3. 公開済みバージョンのリンクは直せない

pub.dev は**そのバージョンの pubspec に書かれた URL** を表示する。
公開済みバージョンの pubspec は不変なので、**既に publish したバージョンのリンクは
永久に 404 のまま**になる。修正が反映されるのは次に publish するバージョンから。

→ **移動するなら早い方がよい。** 遅らせるほど壊れたリンクを持つバージョンが増える。

### 6-4. `git mv` を使う

履歴を追えるようにするため。移動と内容変更は**別コミットに分ける**こと
(同時にやると git が rename を検出できず、履歴が切れる)。

---

## 7. 名前の統一は諦める

`app_info_tile` / `app_lang_selector` / `app_theme_picker` / `riverpod_helper` に
`colaxy_` 接頭辞が無い。

**しかし pub.dev のパッケージ名は永久で、改名できない。**
揃えるなら新しい名前で publish し直し、旧名を deprecated にするしかない。
4つとも既に公開済み (v0.2.2〜v0.4.1) なので、利用者に移行を強いることになる。

→ **揃えない。** フォルダで分ければ、名前が不揃いでも構造は見える。
名前の一貫性のために既存利用者を動かす価値は無い。

---

## 8. やらないこと

| 除外 | 理由 |
|---|---|
| パッケージの統合 / 傘パッケージ | 3節。Flutter 依存が伝播する |
| 既存パッケージの改名 | 7節。pub.dev の名前は永久 |
| `example/` の構成変更 | 移動と混ぜない。必要なら別途 |
| バージョンの一斉更新 | 移動は publish を伴わない。次のリリース時に自然に反映される |

---

## 9. 実行手順

1. `git mv packages/<name> packages/tools/<name>` (または `ui/`) を全10パッケージに対して実行。
   **このコミットではファイル内容を変更しない。**
2. ルートの `workspace:` を `packages/*/*` と `packages/*/*/example` に書き換え。
3. 各 pubspec の `homepage:` / `repository:` の URL を更新 (20箇所)。
4. `melos bootstrap` → `dart analyze` → `dart test` が全パッケージで通ることを確認。
5. CI 設定にパス直書きがあれば更新 (要確認)。

**完了条件**: 全パッケージで analyze とテストが通り、`melos` のスクリプトが動く。

---

## 10. 未検証事項

| # | 事項 | 状態 |
|---|---|---|
| S-1 | `workspace: packages/*/*` が期待どおり動くか。実際に試していない | **未検証** |
| S-2 | CI 設定 (GitHub Actions など) にパスの直書きがあるか | ✅ **解消。** `.github/workflows/ci.yml` と `Makefile` に `packages/` を含む行はゼロ |
| S-3 | 各パッケージの `example/` が相対パス参照を持っていないか | **未検証** |
| S-4 | `pubspec_overrides.yaml` (melos の `usePubspecOverrides: true`) が相対パスを持つか | ✅ **解消。** コミットされたものは1つも無い。melos が bootstrap 時に生成するので、移動後に再 bootstrap すれば済む |
| **S-5** | **`zaim_api` をどのグループに置くか** | **新規。2軸で割れないので、実行前に判断が要る** (1節) |

---

## 11. 一行まとめ

**ディレクトリでのグループ化は利用者への影響ゼロでやる価値があり、
パッケージの統合は `colaxy_store_console` の Flutter 非依存を壊すので不可。**
軸は Flutter/Dart ではなく**用途**で引く。公開済みバージョンのリンクは直せないので、
やるなら早い方がよい。
