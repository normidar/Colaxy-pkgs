# Colaxy-pkgs 改善点リスト

monorepo 内の全 9 パッケージ + ルート構成を確認した結果の改善候補一覧です。
優先度は **P1 = バグ / 利用者に実害あり**、**P2 = 品質・保守性**、**P3 = あると良い** の 3 段階。

> **ステータス**: ✅ が付いた項目は対応済みです。未着手の項目は下記のまま残っています。
> 対応済みの内容は各パッケージの CHANGELOG.md にも記載しています。

## 監査後に判明した追加の P1（対応済み）

コードを実際にビルド・実行して初めて見つかった、リスト作成時には見えていなかった問題です。
いずれも CI が `analyze` / `test` を実行していなかったため見逃されていました。

| # | 内容 |
|---|------|
| ✅ A-1 | **`riverpod_helper` の `.g.dart` が riverpod 3.x でコンパイルできない。** コミット済みの生成コードが古い riverpod 向けで、`handleValue` が存在せずビルドエラーになる。`package:riverpod_helper/riverpod_helper.dart` を import した瞬間に失敗する状態だった（既存テストが何も import していなかったため気付かれていなかった）。`build_runner` で再生成。 |
| ✅ A-2 | **`colaxy_icons_launcher` の `version.dart` が古い。** pubspec は `0.2.0` なのに生成済み定数は `0.1.0+1` で、テストも失敗していた（main ブランチ時点で再現）。CLI の `--version` が誤った値を返していた。再生成。 |
| ✅ A-3 | **`analysis_options.yaml` の `exclude` に `**.g.dart` があるため、A-1 のコンパイルエラーが `dart analyze` に出てこなかった。** 生成コードを解析対象外にすると、生成コードの破損を検知できない。 |

---

## 0. リポジトリ横断（全パッケージ共通）

| # | 優先度 | 内容 |
|---|--------|------|
| ✅ 0-1 | **P1** | **CI が analyze / test を一切実行していない。** `.github/workflows/ci.yml` は `melos run format` と `melos run fix` の差分チェックのみ。`melos run analyze` と `melos run test` をジョブに追加すべき。 |
| ✅ 0-2 | **P1** | **`melos run test` が Flutter パッケージで動作しない。** ルート `pubspec.yaml` の melos スクリプトが `melos exec -- dart test` になっているが、`flutter_test` に依存するパッケージ（9 個中 7 個）は `flutter test` でないと実行できない。`packageFilters.flutter` で振り分けるか `melos exec -- flutter test` にする。 |
| ⚠️ 0-3 | **P1** | **`riverpod_lint` のルールが一度も実行されていない。** 8 パッケージが `analyzer.plugins: - custom_lint` を宣言しているのに `custom_lint` が未依存だった。調査の結果、`riverpod_lint` 3.x は **custom_lint を廃止して Dart 標準の `analysis_server_plugin` に移行済み**であり、この宣言はそもそも無意味だったことが判明。→ 死んだ宣言は削除済み。有効化には workspace ルートの `analysis_options.yaml` にトップレベル `plugins: {riverpod_lint: ^3.1.0}` を書く必要があるが、**Dart 3.12.2 では `dart analyze` がハングして終了しない**ため未有効化（ルートの analysis_options.yaml にコメントで手順を記載）。新しい Dart / riverpod_lint での検証が必要。 |
| ✅ 0-4 | **P2** | **パッケージ配下の `.github/` が完全に死んでいる。** `packages/*/. github/workflows/check.yml` と `packages/*/.github/dependabot.yml` はサブディレクトリにあるため GitHub 上で一切実行されない（9 セット存在）。ルート `.github/` に集約して、パッケージ側は削除する。 |
| ⏳ 0-5 | **P2** | **`Makefile` が `fvm` 前提だが、リポジトリは `mise` を採用している。** 8 個の Makefile がすべて `fvm dart ...` を呼ぶため、mise 環境ではそのまま動かない。また `git_branch_clean` が参照する `sh_scripts/git_branch_clean.sh` はリポジトリに存在しない。melos スクリプトに一本化するのが望ましい。 |
| ✅ 0-6 | **P2** | **テストがほぼプレースホルダー。** → `riverpod_helper`(16件) / `colaxy_adaptive_scaffold`(9件) / `colaxy_localization`(8件) / `colaxy_tutorial`(6件, 新規) / `app_lang_selector`(2件) に実テストを追加。`app_info_tile` / `app_theme_picker` / `colaxy_screenshot` は未着手。<br>原文:  `app_info_tile` / `app_lang_selector` / `app_theme_picker` / `colaxy_screenshot` / `riverpod_helper` の `test/main_test.dart` は中身が空の `// Implement the test`。`colaxy_localization` は `test('test1', () {})`。`colaxy_tutorial` に至っては `test/` ディレクトリ自体が無く、`melos run test` の `dirExists: test` フィルタで**黙ってスキップ**される。 |
| ✅ 0-7 | **P2** | **依存バージョンの `any` 指定。** `auto_exporter: any`、`flutter_lints: any`、`very_good_analysis: any` が多数。破壊的変更を拾ってしまうのでキャレット制約に統一する。 |
| ✅ 0-8 | **P2** | **`flutter_lints` と `very_good_analysis` の二重依存。** `analysis_options.yaml` は `very_good_analysis` しか include していないので、`flutter_lints` は未使用依存（app_info_tile / app_lang_selector / colaxy_adaptive_scaffold / colaxy_screenshot / colaxy_tutorial / riverpod_helper）。 |
| 0-9 | **P2** | **`environment.flutter: '>=1.17.0'` が実態と乖離。** `NavigationBar`、`Color.withValues`、`WidgetStateProperty` など Flutter 3.x 系 API を使っているのに下限が 1.17.0。正しい下限（3.27 以上目安）に更新する。 |
| ✅ 0-10 | **P2** | **pubspec メタデータが不揃い。** `repository` 欠落: `app_lang_selector`, `colaxy_localization`。`homepage` 欠落: `colaxy_icons_launcher`, `colaxy_tutorial`。`issue_tracker` はほぼ全パッケージで欠落。さらに `app_lang_selector` の `issue_tracker` は `.../tree/main/packages/app_lang_selector/issues` という**存在しない URL**。`documentation` も全パッケージ未設定。 |
| ✅ 0-11 | **P2** | **URL の大文字小文字が不統一。** `normidar/colaxy-pkgs` と `normidar/Colaxy-pkgs` が混在（後者: colaxy_icons_launcher, colaxy_localization, colaxy_tutorial）。 |
| ✅ 0-12 | **P3** | **ルートに `analysis_options.yaml` が無い。** 各パッケージがほぼ同一内容の 14 行をコピーしている。ルートに共通設定を置き、各パッケージから `include: ../../analysis_options.yaml` するとドリフトを防げる。実際 `app_theme_picker` だけ `specify_nonobvious_property_types: ignore` が、`colaxy_tutorial` だけ `public_member_api_docs` の除外が無い、という差分が発生している。 |
| 0-13 | **P3** | **バージョン番号のビルド番号運用。** `0.1.0+4` のような `+N` は pub.dev では非推奨（アプリ用の慣習）。パッチバージョンに寄せた方がセマンティックバージョニングとして素直。 |
| 0-14 | **P3** | **ルート README が 2 行しかない。** パッケージ一覧・pub.dev バッジ・簡単な用途説明の表があると入口として機能する。 |
| 0-15 | **P3** | CONTRIBUTING.md / CODE_OF_CONDUCT.md / SECURITY.md が `colaxy_icons_launcher` にしか無い。ルートに 1 セット置いて共有する。 |

---

## 1. `app_lang_selector`

| # | 優先度 | 内容 |
|---|--------|------|
| ✅ 1-1 | **P1** | **`PkgsAssetLoader` のマージ順が逆。** `lib/src/pkgs_asset_loader.dart:25` の `{...localeData, ...packageDatas}` はパッケージ側のキーがアプリ側のキーを**上書き**する。アプリが自分の翻訳をパッケージより優先できないので `{...packageDatas, ...localeData}` にすべき。 |
| ✅ 1-2 | **P1** | **翻訳キーが名前空間化されていない。** `select_lang_page` / `follow_system` / `select_lang` がフラット。`colaxy_tutorial` は `colaxy_tutorial:xxx` 形式を採っており不統一。1-1 と組み合わさるとアプリ側の同名キーを破壊する。 |
| ✅ 1-3 | **P1** | **`Radio` の `groupValue` / `onChanged` は Flutter 3.32 以降 deprecated**（`app_lang_select_page.dart:68, 85`）。`RadioGroup` への移行が必要。mise.toml は Flutter 3.44.2 を固定しているため、既に deprecation 警告が出る状態。 |
| ✅ 1-4 | **P2** | **`ListTile.onTap` と `Radio.onChanged` にロジックが重複コピーされている**（`app_lang_select_page.dart:60-97`）。3 箇所同じ「Intl.defaultLocale 設定 → setLocale → setLang」がベタ書き。プライベートメソッドに抽出する。 |
| ✅ 1-5 | **P2** | **`langsNameMap` が公開かつミュータブル。** トップレベル `final Map` なので利用者が書き換えられる。`Map.unmodifiable` でラップするか非公開にする。 |
| ✅ 1-6 | **P2** | **`LangCode.hashCode` が `^` 実装。** `Object.hash(languageCode, countryCode)` を使う（衝突しやすい実装）。また `operator ==` に `identical` の早期リターンが無い。 |
| 1-7 | **P2** | **UI が 38 言語の表示名を持つのに、同梱翻訳は 13 ロケールのみ。** `langsNameMap` にあってアセットに無い言語（pl, nl, uk, sv, hi 等）はページ自体が未翻訳のまま表示される。 |
| ✅ 1-8 | **P2** | **`AppLangSelectTile` の `final _ = ref.watch(...)` は破棄される値のリビルド目的**。意図が読み取りづらいので `ref.watch` の結果を使うか、コメントで明示する。同じパターンが `app_info_tile` / `app_theme_picker` / `colaxy_tutorial` にも散在。 |
| 1-9 | **P2** | `SelectingLang` が `String?` を保持しているが、実体はロケール。`Locale`（または `LangCode`）型にした方が型安全。文字列 `'system_system'` というマジック値も定数化すべき。 |
| 1-10 | **P3** | 検索フィルタ（言語数が 38 あるので）、現在の言語のハイライト、RTL 言語の考慮。 |

---

## 2. `app_theme_picker`

| # | 優先度 | 内容 |
|---|--------|------|
| ✅ 2-1 | **P1** | **翻訳キー `theme` と `tile_title` が完全に汎用名。** `colaxy_tutorial` も `colaxy_tutorial:tile_title` を持つため、アプリ側で `tile_title` を定義していると衝突する（1-1 のマージ順と合わせて実害）。`app_theme_picker:` プレフィクスを付ける。 |
| 2-2 | **P1** | **モック 80 個超がプロダクションコードに同梱されている。** `lib/src/mocks/theme_mocks.dart`（約 80 クラス）と `lib/src/mocks/overrides.dart`（約 80 個の provider override）が `lib/` から export されており、アプリのバイナリに乗る。テスト用途なら別パッケージか `FlexScheme` を引数に取る 1 クラスに畳める（`class FixedThemeMock extends ThemePod { FixedThemeMock(this.scheme); }`）。 |
| 2-3 | **P2** | **`ThemeModePod` のデフォルトが `ThemeMode.light`**（`theme_mode_pod.dart`）。プラットフォーム標準に合わせるなら `ThemeMode.system` が妥当。`orElse` も同様。 |
| 2-4 | **P2** | **`overrides.dart` に個人向けの残骸。** `// sugger for normidar` コメントと `sakuraLightThemeOverrides` が公開 API に混ざっている。 |
| 2-5 | **P2** | **`ThemePod` のデフォルトが `FlexScheme.sakura`。** 汎用パッケージとしては `FlexScheme.material` の方が中立。少なくともコンストラクタ/設定で差し替え可能にする。 |
| 2-6 | **P2** | `PickThemePage` の `AppBar` の `title` に `RiverpodErrorView`（`SingleChildScrollView` + `SelectableText`）を差し込んでいる（`pick_theme_page.dart:32-38`）。AppBar 内でスタックトレース全文を描画するのはレイアウト崩壊の元。 |
| 2-7 | **P2** | `availableSchemes` が `Set<String>`（スキーム名の文字列）。`Set<FlexScheme>` にすれば型安全になり、`m.key.name` の文字列比較も不要。 |
| 2-8 | **P3** | `PickThemePage` の `size` が必須引数。`ThemePickTile` 側にはデフォルト 70 があるので、ページ側にもデフォルトを付けて対称にする。 |
| 2-9 | **P3** | カスタムカラー（`FlexScheme.custom`）を選ぶ UI が無いのに `CustomThemeMock` だけ存在する。 |
| 2-10 | **P3** | `dev_dependencies` に `flutter_lints` が無い一方 `build_test` がある等、他パッケージと構成が揃っていない。 |

---

## 3. `app_info_tile`

| # | 優先度 | 内容 |
|---|--------|------|
| ✅ 3-1 | **P1** | **`'app_name'.tr()` が自パッケージの翻訳ファイルに存在しない**（`app_info_tile.dart:47, 62`）。ホストアプリが `app_name` キーを定義していることが暗黙の前提になっており、未定義なら画面に `app_name` と生表示される。README に必須キーとして明記するか、コンストラクタ引数 `appName` を受け取る形にする。 |
| ✅ 3-2 | **P1** | **翻訳キー `license_hint` / `view_license` が名前空間化されていない**（2-1 と同根）。 |
| ✅ 3-3 | **P2** | **`getAlertDialog` が public インスタンスメソッド。** ウィジェットの公開 API を汚しているので private にするか、独立した `StatelessWidget` に切り出す。 |
| ✅ 3-4 | **P2** | **ハードコードされた `Colors.blue`**（`app_info_tile.dart:66`）。`Theme.of(context).colorScheme.primary` を使うべき。ダークテーマでコントラスト不足になる。 |
| ✅ 3-5 | **P2** | **`AsyncLoading` 時に `Center(child: CircularProgressIndicator())` を返している**が、この widget は `ListTile` として設定リストに並ぶ想定。リスト内でインジケータが中央寄せされ、行の高さも変わってガタつく。`ListTile` のスケルトンを返す方が自然。 |
| ✅ 3-6 | **P2** | `showLicensePage` の `applicationLegalese` / `applicationIcon` を渡せない。オプション引数として公開すると使い勝手が上がる。 |
| 3-7 | **P3** | 翻訳が 7 ロケールのみ（`app_lang_selector` は 13）。パッケージ間でサポートロケールが揃っていない。 |

---

## 4. `colaxy_adaptive_scaffold`

| # | 優先度 | 内容 |
|---|--------|------|
| ✅ 4-1 | **P1** | **タブ切り替えでページの State が毎回破棄される。** `adaptive_scaffold.dart:173` で選択中の 1 ページだけを `body` に渡しているため、スクロール位置・入力内容・`StatefulWidget` の状態が保持されない。`IndexedStack` へ変更する（オプションで遅延生成にする `lazy` フラグを付けると尚良い）。 |
| ✅ 4-2 | **P1** | **`items` が空だと `initState` で例外。** `initialIndex.clamp(0, -1)` は `ArgumentError` を投げる（`adaptive_scaffold.dart:146`）。`assert` はリリースビルドで無効なので、`items.isEmpty` を実行時にハンドリングする必要がある。 |
| 4-3 | **P2** | **アスペクト比でレイアウトを切り替える設計自体が Material 3 のブレークポイント指針に反する。** 縦長のタブレット（例: iPad 縦、比率 0.75）は幅 834px あるのに BottomNavigation になる。`LayoutBuilder` + 幅ベースのブレークポイント（600 / 840dp）を選択肢として追加すべき。 |
| ✅ 4-4 | **P2** | **`MediaQuery.of(context).size`**（`:166`）は MediaQuery のあらゆる変化でリビルドする。`MediaQuery.sizeOf(context)` を使う。 |
| ✅ 4-5 | **P2** | **`Colors.grey[300]` のハードコード**（`:193`）。`Theme.of(context).dividerColor` にする。ダークテーマで浮く。 |
| 4-6 | **P2** | **Drawer モードのときだけ `AppBar` が出る。** Rail / BottomNav モードでは AppBar が無いので、同じアプリでウィンドウをリサイズすると AppBar が出たり消えたりする。`appBar` を利用者が指定できるようにする。 |
| ✅ 4-7 | **P2** | **Drawer ヘッダーの文言 `'Menu'` がハードコード英語**（`:207`）。ローカライズ不可。 |
| ✅ 4-8 | **P2** | **選択変更を外部に通知する手段が無い。** `onDestinationSelected` コールバックと、外部から選択を制御する `controller`／`selectedIndex` を公開すると実用性が上がる。 |
| ✅ 4-9 | **P2** | **`NavigationItem` に `selectedIcon` / `tooltip` / `badge` が無い。** Material の `NavigationDestination` は持っているので、渡せるようにする。 |
| 4-10 | **P2** | `NavigationRail` に `leading` / `trailing`（ロゴや設定ボタン用）を渡せない。`labelType` も `all` 固定。 |
| ✅ 4-11 | **P2** | テストが 1 ケース（縦横切り替え・Drawer モード・items 変更のテストが無い）。バリアント切り替えが本体機能なので、`tester.view.physicalSize` を使った 3 レイアウトのテストは必須級。 |
| ✅ 4-12 | **P3** | `lib/colaxy_adaptive_scaffold.dart` の doc コメントが `/// A Flutter package template.` のままテンプレート文言。 |
| 4-13 | **P3** | `CLAUDE.md` がこのパッケージだけに存在する。リポジトリルートへ移動して全体規約にする。 |

---

## 5. `riverpod_helper`

| # | 優先度 | 内容 |
|---|--------|------|
| ✅ 5-1 | **P1** | **`Prefs.get` / `getOrNull` のフォールバック `_ => prefs.get(key) as T?` が危険**（`prefs.dart:19, 32`）。未サポート型を渡すと `CastError` が実行時に飛ぶ。`set` 側は `throw Exception('Type $T is not supported')` で弾いているのに読み取り側は弾いていない、という非対称。 |
| ✅ 5-2 | **P1** | **`Prefs.updateForcePipe` の `value as T` は value が null のとき必ずクラッシュ**（`prefs.dart:79`）。null 安全性を回復させるかメソッド名の意図をドキュメント化する。 |
| ✅ 5-3 | **P1** | **`Prefs.set` の型判定が `T == bool` の静的型依存。** 呼び出し側で `Prefs.set(key, value)` の `value` が `Object` や `dynamic` 経由だと `T` が `Object` に推論され、実行時に「未サポート」で例外になる。`switch (value)` によるランタイム型判定に変えるべき。 |
| 5-4 | **P2** | **`SharedPreferences.getInstance()` が全メソッドで毎回呼ばれる**（`Prefs` の 7 メソッド + 各 Pod の 3 メソッド × 11 Pod ≒ 40 箇所）。キャッシュ済みインスタンスとはいえ、`SharedPreferencesAsync` / `SharedPreferencesWithCache`（shared_preferences 2.3+ の推奨 API）への移行も検討したい。`shared_preferences: ^2.0.0` という緩い制約も上げるべき。 |
| 5-5 | **P2** | **`prefs_riverpod` と `prefs_alive_riverpod` でほぼ同一のコードが 11 ファイル重複。** さらに **alive 側だけ `map_pod` が無い**という非対称がある。ジェネリックな基底クラス or コード生成でまとめる。 |
| 5-6 | **P2** | **`setValue` が `ref.invalidateSelf()` を呼ぶため、書き込みのたびに SharedPreferences を再読込してローディング状態を経由する。** `state = AsyncData(value)` で楽観更新した方が UI がちらつかない。 |
| ✅ 5-7 | **P2** | **`RiverpodErrorView` がリリースビルドでもスタックトレース全文をユーザーに表示する。** エンドユーザー向けには汎用メッセージ、`kDebugMode` のときだけ詳細、という切り分けが必要。 |
| ✅ 5-8 | **P2** | **`RiverpodErrorView` が `print` を使用**（`riverpod_error_view.dart:21`）。`debugPrint`（長文が切り詰められる）か `FlutterError.reportError` が適切。またビルドメソッド内での副作用（print）は避けるべき。 |
| ✅ 5-9 | **P2** | **`Prefs` が全 static のユーティリティクラスなのにインスタンス化を禁止していない。** `Prefs._();` のプライベートコンストラクタを追加。 |
| ✅ 5-10 | **P2** | **`Prefs.update` の `updater` が非同期関数を取れない。** `FutureOr<T> Function(T?)` にすると使い勝手が広がる。 |
| 5-11 | **P3** | `prefs_map_pod` は JSON 経由で保存しているが、デコード失敗（不正な JSON / 型不一致）が握られていない。 |
| 5-12 | **P3** | `Prefs` にキー一覧取得 / 全消去 / 型付きキー定義（`PrefKey<T>`）が無い。 |
| ✅ 5-13 | **P3** | テストが空。SharedPreferences は `setMockInitialValues` でテストしやすいので、ここは投資対効果が高い。 |

---

## 6. `colaxy_screenshot`

| # | 優先度 | 内容 |
|---|--------|------|
| ✅ 6-1 | **P1** | **未サポートロケールで確実にクラッシュ。** `_iOSLocaleMap` / `_androidLocaleMap` は 6 言語（en/ja/zh/es/pt/tr）しか持たず、`screenshot_service.dart:354, 366, 381, 393, 403` ですべて `!` でアクセスしている。`config.supportedLocales` に ko や fr を入れた瞬間に null 例外。フォールバックか事前バリデーションが必要。 |
| ✅ 6-2 | **P1** | **`ScreenshotConfig.backgroundColor` と `titleStyle`、`ScreenshotPageInfo.titleStyle` / `backgroundColor` が完全に未使用。** `_buildMarketingLayout` は `Color.fromARGB(255, 216, 255, 239)` と `Color.fromARGB(255, 25, 178, 255)`、`fontSize: 48` をハードコードしている。「設定できるように見えて効かない」ので、実装するか削除する。 |
| ✅ 6-3 | **P1** | **`ScreenshotConfig.captureDelay` が `final` でない可変フィールドで、`executeScreenshots` が実行中に書き換えている**（`screenshot_service.dart:80, 88`）。設定オブジェクトの副作用は予測不能。`firstCaptureDelay` を別フィールドで持つのが素直。 |
| ✅ 6-4 | **P1** | **`exit(0)` でプロセスを強制終了**（`:98`）。例外時のクリーンアップも、呼び出し元でのハンドリングもできない。少なくとも `resetJsonConfig()` を `try/finally` に入れる（現状、途中で例外が出ると config が `screenshot` モードのまま残り、次回起動時にまたスクリーンショットモードで立ち上がる）。 |
| ✅ 6-5 | **P2** | **`'assets/app_icons/icon.png'` がホストアプリのアセットパス前提でハードコード**（`:139`）。`ScreenshotConfig` から渡せるようにする。 |
| 6-6 | **P2** | **`setWindowToSize` が 2 箇所に重複実装**（`ScreenshotService.setWindowToSize` と `ScreenshotModeInfo.setWindowToSize`）。マジックナンバー `const rate = 3.3` も両方にコピーされている。 |
| 6-7 | **P2** | **`_macBookProFullScreen` の `Rect.fromLTWH(346.68, 98.2, 2298.82, 1437.32)` が出典不明のマジックナンバー**。device_frame_plus の更新で壊れる。定数の由来をコメント（現状は「device.dart に定義されている」とだけ）以上に明示するか、実行時に導出する。 |
| 6-8 | **P2** | **`ScreenshotModeInfo.all` が `[phone, tablet]` のみで macos を含まない**うえ、どこからも使われていない（デッドコード）。 |
| 6-9 | **P2** | **`static ScreenshotModeInfo phone = ...` がミュータブルな static。** `static const` にすべき（`const ScreenshotModeInfo(...)` なので const 化可能）。 |
| 6-10 | **P2** | **`decodePng(imageBytes)!` / `boundary!` の `!` 連発**（`:180, 186, 336`）。失敗時のエラーメッセージが `Null check operator used on a null value` になり原因が分からない。 |
| 6-11 | **P2** | **`analysis_options.yaml` で `avoid_print` と `avoid_catches_without_on_clauses` を丸ごと無効化している。** ロガー抽象を 1 つ入れれば ignore を外せる。 |
| 6-12 | **P2** | **`getJsonConfig` の `jsonConfig.cast<String, String>()`** は遅延キャストなので、数値やbool が入っていると読み出し時に別の場所で例外になる。 |
| 6-13 | **P2** | **iOS のファイル名が `iphone65` / `ipadPro129` 固定。** App Store Connect の要求サイズは変わるので定数化・設定化したい。 |
| 6-14 | **P3** | Android のスクリーンショットが phone と sevenInch に同一画像を書き込んでいる（`:369-372`）。意図的ならコメントを。 |
| 6-15 | **P3** | `Future.delayed(3秒)` などの固定待機に依存。`WidgetsBinding.instance.endOfFrame` を使っているのだから、フレーム安定を検出する方式にできると高速化できる。 |

---

## 7. `colaxy_tutorial`

| # | 優先度 | 内容 |
|---|--------|------|
| ✅ 7-1 | **P1** | **`test/` ディレクトリが存在しない**ため `melos run test` の `dirExists: test` フィルタで丸ごとスキップされ、CI 上「テストが無い」ことにすら気付けない。 |
| ✅ 7-2 | **P1** | **`_finish()` が `TutorialTool.saveShowedIds` の Future を待っていない**（`tutorial_tool.dart:_finish`）。直後に `Navigator.pushReplacement` するので、保存前に画面が破棄されると「見た」フラグが立たない可能性がある。`unawaited` すら付いていない。 |
| ✅ 7-3 | **P1** | **`showTutorial` の `Future.delayed(300ms, ...)` が await されていない**（fire-and-forget）。呼び出し側は完了を検知できず、`saveShowedIds` の失敗も握り潰される。 |
| 7-4 | **P2** | **`TutorialTool.tutorialVisible` がグローバルな static mutable。** テストや複数画面での制御が難しい。Riverpod provider 化（このリポジトリの他パッケージは全部 Riverpod）に揃える。 |
| 7-5 | **P2** | **`DecideShowingConfig` が定義されているだけでどこからも使われていない**（`lib/src/config/decide_showing_config.dart`）。しかも `colaxy_tutorial.dart` から export すらされていない完全なデッドコード。`VersionRecorder` との連携が未完成に見える。 |
| 7-6 | **P2** | **`VersionRecorder` も未使用**（export はされているが内部から呼ばれない）。しかも `recordVersion` は `info.buildNumber` を保存しているのに、`isRecordedVersionAnd/Or` の引数名は `version`。 |
| 7-7 | **P2** | **`TutorialContent` と `_TutorialPageView` の色がハードコード**（`Colors.white` 背景、`Colors.black` 文字、`Colors.blue` ボタン、`Color.fromARGB(255, 195, 226, 240)`）。ダークテーマで白背景に白文字になる箇所がある。 |
| 7-8 | **P2** | **`_TutorialPageView` にページインジケータ（ドット）が無い。** 何ページあるか分からない UX。 |
| 7-9 | **P2** | **`guardTutorialPage` の `FutureBuilder` にエラーハンドリングが無い**（`snapshot.hasError` 時は `null` 扱いで無限ローディング）。 |
| 7-10 | **P2** | `SharedPreferences` 直叩き。同 monorepo の `riverpod_helper` に `Prefs` があるのに使っていない（`shared_preferences` を直接依存）。 |
| 7-11 | **P2** | `saveShowedIds` の `showed_ids` リストが単調増加で消えない（`resetTutorial` 以外）。 |
| ✅ 7-12 | **P3** | `pubspec.yaml` に `homepage` が無い。`description` は良いが `issue_tracker` も無い。 |
| 7-13 | **P3** | 日本語コメント（`/// ターゲットを作成する。`）と英語 doc が混在。 |

---

## 8. `colaxy_localization`

| # | 優先度 | 内容 |
|---|--------|------|
| ✅ 8-1 | **P1** | **`LocaleApp.getLocaleApps()` が壊れている**（`locale_app.dart:52-64`）。ディレクトリを走査しているのに、見つかった各ディレクトリに対して**常に同じ `const LocaleApp()` を追加**するだけで、どのアプリかの情報を一切保持しない。`LocaleApp` がパスを持つべき。 |
| ✅ 8-2 | **P1** | **`iosLocaleMap[locale]!` が 10 箇所で `!` アクセス**（`locale_unit.dart:83, 98, 117, 124, 131, 138, 145, 155`）。マップに無いロケール（例: `de-DE`, `fr-FR`）を `assets/localizations/` に置いた瞬間、意味不明な null 例外で落ちる。 |
| ✅ 8-3 | **P1** | **`en-US` がメインロケールとしてハードコード**（`locale_app.dart:30` の `firstWhere`、`bin/gen.dart:12`）。`en-US.json` が無いプロジェクトでは `StateError` で落ちる。設定可能にすべき。 |
| ✅ 8-4 | **P1** | **`_json[...]!` が全 getter で必須キー前提**（`_getAppName`, `_getDescription` 等 10 個）。キー欠落時は `Null check operator` になり、どのキーが足りないか分からない。「`$locale` に `store_ios_keywords` がありません」のような明示エラーにすべき。 |
| ✅ 8-5 | **P2** | **`pubspec.yaml` の description が `"'A pkg in Coin Galaxy.'"`** ——クォート二重かつ内容が説明になっていない。pub.dev のスコアにも直結する。 |
| ✅ 8-6 | **P2** | **`bin/gen.dart` に引数解析もエラーハンドリングも無い。** `args` パッケージを使い、`--locales-dir` / `--main-locale` / `--dry-run` を受け取れるようにする。同 monorepo の `colaxy_icons_launcher` は `args` を使っているので揃えられる。 |
| ✅ 8-7 | **P2** | **キーワードのブラックリスト判定が大文字小文字を区別しない実装になっていない**（`locale_unit.dart:_getStoreKeywords`）。`Google` や `iOS` は素通りする。また `'ios'` の部分一致は `radios`・`estudios` 等の正当な単語も誤検出する（`toLowerCase()` + 単語境界での判定が必要）。 |
| 8-8 | **P2** | **文字数チェックが `String.length`（UTF-16 コードユニット）ベース。** 絵文字や結合文字を含むと App Store の実際の文字数と乖離する。`characters` パッケージの grapheme cluster で数えるべき。 |
| ✅ 8-9 | **P2** | **`print` によるログ出力**（`locale_app` / `android_name_localization` / `ios_name_localization` / `locale_unit`）。`print('minimumVersion: $minimumVersion')` などデバッグ残骸も混在。 |
| ✅ 8-10 | **P2** | **`IOSNameLocalization` の例外処理が `catch (e) { print(...) }` で握り潰し。** Info.plist の更新に失敗しても gen コマンドは成功扱いで終了する（終了コード 0）。 |
| ✅ 8-11 | **P2** | **`AndroidNameLocalization._androidLocaleMap[locale]!`** も同じく `!`（`android_name_localization.dart:33`）。en-US が地図に無いのに `values/strings.xml` 分岐でしか救われていない。 |
| 8-12 | **P2** | **`updateManifestAppName` が AndroidManifest.xml の全コメントを削除する**（`_removeComments`）。利用者が書いたコメントが黙って消える破壊的操作。 |
| 8-13 | **P2** | **`AndroidNameLocalization.fitLocale` が `strings.xml` を丸ごと上書き**する。既存の他の string リソースが消える。 |
| 8-14 | **P2** | **`LocaleUnit.metadataDir` などパスがすべてカレントディレクトリ相対のハードコード**（`fastlane/metadata`, `android/app/src/main`, `ios/Runner`）。設定可能にする。 |
| 8-15 | **P3** | テストが `test('test1', () {})` の 1 行。XML 変換や文字数バリデーションは純粋関数なのでテストしやすい。 |
| ✅ 8-16 | **P3** | `pubspec.yaml` に `repository` / `issue_tracker` が無い。 |

---

## 9. `colaxy_icons_launcher`

| # | 優先度 | 内容 |
|---|--------|------|
| 9-1 | **P1** | **README が 17 行しかなく、使い方が一切書かれていない。** 「icons_launcher の fork で SVG 対応を追加した」としか書いておらず、`colaxy_icons_launcher:` の設定キー、`dart run colaxy_icons_launcher:create` の実行方法、対応プラットフォームが不明。pub.dev 上でこの状態は致命的。上流 README の該当部分を取り込むべき。 |
| ✅ 9-2 | **P1** | **`pubspec.yaml` の `maintainer: Mrr Hak`** が fork 元のまま。`maintainer` は pub.dev では非推奨フィールドでもある。 |
| ✅ 9-3 | **P1** | **`homepage` が未設定**（`repository` のみ）。 |
| 9-4 | **P2** | **`exit(1)` による即時終了がライブラリコード内に散在**（`cli_commands.dart`）。ライブラリとして呼ぶと呼び出し元のプロセスごと落ちる。例外を投げて `bin/` 側で `exit` する構造にする。 |
| 9-5 | **P2** | **`late _FlavorHelper _flavorHelper;` というトップレベル可変グローバル**（`cli_commands.dart:20`）。複数回呼ぶと状態が漏れる、テスト不能。 |
| 9-6 | **P2** | **`part` による 2,949 行の巨大な単一ライブラリ。** `src/android.dart`（580行）等が `part of` なので単体テスト不可。 |
| 9-7 | **P2** | **テストが「pubspec の version と `version.dart` の一致」「description の長さ」の 2 件のみ。** アイコン生成・SVG 変換という本体機能のテストがゼロ。fork の唯一の付加価値である `svg_converter.dart`（41行）は最優先でテストすべき。 |
| 9-8 | **P2** | **他パッケージと lint 設定が別系統**（`lints/recommended` vs `very_good_analysis`）。fork 由来だが、monorepo として統一するか、意図的な例外である旨を書く。 |
| 9-9 | **P2** | **`.github/` 配下に上流由来のワークフロー 4 本（publish / close-inactive-issues / auto_author_assign / format-analyze-test）と CODEOWNERS、FUNDING、ISSUE_TEMPLATE が残っている**が、サブディレクトリなので全部動かない（0-4 と同根）。特に `publish.yml` は melos の publish フローと二重管理になる。 |
| 9-10 | **P2** | **`funding: ko-fi.com/mrrhak`** が fork 元のまま。意図的なら README に明記、そうでないなら削除。 |
| 9-11 | **P3** | **`environment.sdk: ">=3.10.0 <4.0.0"`** が他パッケージ（`^3.5.0`）より厳しく、ルートは `>=3.11.0`。統一する。 |
| 9-12 | **P3** | CHANGELOG が 20 行、fork 後の変更履歴がほぼ無い。 |

---

## 10. 残タスク（未着手）

対応済みの項目は上の表で ✅ が付いています。残っている主なものは以下です。

1. **`app_theme_picker` のモック 80 クラス整理**（2-2） — `FlexScheme` を引数に取る 1 クラスに畳む。破壊的変更が大きいので独立した PR が望ましい
2. **`colaxy_icons_launcher` の README 整備**（9-1） — pub.dev 上の見え方として最優先だが、上流 README からの取り込み方針の判断が必要
3. **`riverpod_lint` の有効化**（0-3） — 新しい Dart / riverpod_lint でハングしないことを確認してから
4. **Makefile の `fvm` → `mise` 移行**（0-5） — melos スクリプトへの一本化も含めて方針判断が必要
5. **`riverpod_helper` の prefs pod 重複解消**（5-5） — 11 ファイルの重複と alive 側の `map_pod` 欠落
6. **`environment.flutter` の下限修正**（0-9） — 実際の最低要件の確定が必要
7. **`app_theme_picker` / `colaxy_screenshot` / `app_info_tile` のテスト追加**（0-6 の残り）
8. **ルート README / CONTRIBUTING 等の整備**（0-14, 0-15）

---

## 付録: 当初の優先着手案

短期で効果が大きい順:

1. **CI に analyze と test を追加**（0-1, 0-2） — 以降のすべての修正の安全網になる
2. **`custom_lint` の依存追加**（0-3） — riverpod_lint が動き出し、既存の潜在バグが自動で見つかる
3. **翻訳キーの名前空間統一**（1-2, 2-1, 3-2）と **`PkgsAssetLoader` のマージ順修正**（1-1） — 利用者アプリのキーを壊す実害があり、破壊的変更なので早い方が良い
4. **null 落ちの一掃**（6-1, 8-2, 8-4） — ロケールを 1 つ増やしただけでクラッシュする箇所
5. **`AdaptiveScaffold` の `IndexedStack` 化**（4-1） — 機能的に一番大きな欠落
6. **`Radio` の `RadioGroup` 移行**（1-3） — Flutter 3.44 固定なので deprecation が既に出ている
7. **`colaxy_icons_launcher` の README 整備**（9-1） — pub.dev 上の見え方が最悪の状態
8. **パッケージ配下の死んだ `.github/` と `fvm` 前提 Makefile の整理**（0-4, 0-5）
