# FLOTRA ローカル磨き込み — 2026-10-02

## 結果

Godot 正本の見やすさ、区画選択、物流状態の表現を改善したローカル差分です。公開・push・PR・merge・deploy は行っていません。

基準: `48wr9f4wgp-lab/Logistics-Boss` main `367b9e4177e54a465c6b5ce5c6d1461ab443681f`

### 改善点

- **区画名が読める**: 俯瞰で小さすぎたラベルを固定サイズ化。通常は短い `›` で操作可能を示し、混雑/高負荷時だけ補足。初回ガイドの「ここをタップ」は保持
- **見た場所を選べる**: 出荷ラベルを押すと梱包が開く誤判定を修正。文字の実形状に沿った判定と最低44pxのタップ領域を使用。ラベル外は3Dの区画判定を保持
- **ピンチ/中断が誤タップにならない**: 2本指、取消、focus中断、touchからの重複mouse、UIと現場をまたぐ操作を扱う。UIルーターからの観測を最小限追加
- **荷物と信号が実物流に一致**: 基本倉庫の常置の飾り荷物を除き、空のパレットは設備として残した。梱包中の実ジョブを最大2箱で表示し、残り処理時間に合わせて移動。ランプは処理中/待ちの混雑/停止した空設備を区別
- **無駄な描画更新を抑える**: 表示上限を超える在庫変動で同一メッシュを作り直さない
- **操作の意味を揃える**: 実際に描いている作業動線があるときだけ「動線を隠す」を表示

## セーブと仕様保護

- Domain・経済・永続化コードは無変更。schema 11 を保持
- 未mergeのPR137は取り込んでいない
- すべてのテスト/手動プレイは専用XDGプロファイル。実ユーザーセーブを読込・更新・削除していない
- 現在の公開プレビューは無変更

## 検証

エンジン: **Godot 4.7.2.stable.official.ed1daf0bf**。既存システムの4.6.3を置換せず、公式リリースを別置き使用。

公式配布: https://github.com/godotengine/godot/releases/tag/4.7.2-stable

Linux x86_64 ZIP SHA256: `cadd3204e728a35d3f13adb7fd0d7902636b79f6b95c40c265eb73b6c35329e4`

- 最終コードで既存CI 52本 + 追加既存smoke 8本 + 新規smoke 4本 = **64種類 PASS**
- 新規world入力テストは **171 checks / 0 failures**
- parse/import、runtime startup、save recovery、soak、段階成長、容量追加、HUD、通知、font、入力、区画パネルを確認
- 独立レビューで見つけた「billboardの保守的な矩形が隣区画を奪う」「UIから始まる2本目の指が伝わらない」問題は修正し、独立再テスト済み
- portraitテストは実際の稼働中ピッキング作業をfixtureに追加。元の表示/重なり/画面内assertionは保持
- 新規4本をGodot CI workflowにも追加。remote CIは未実行

途中で実行環境が断続的に切断されたため、最終52本は28本+24本に分けて再開。ログ・変更ファイルは保全し、同じ最終コードで残りを完走しています。

### 実描画

`evidence/before/` と `evidence/after/` は実際の `main.tscn` のLinux OpenGL Compatibility描画です。静止画モックではありません。

- `fresh-390.png`: 初期状態
- `empty-390.png`: 在庫/作業ゼロ
- `busy-390.png`, `busy-progress-390.png`: 実ジョブの進行を含む混雑fixture
- `shipping-panel-390.png`: 出荷区画パネル
- `busy-375.png`, `busy-430.png`: 375×667 / 430×932

比較は同じシナリオ/カメラで行っています。混雑fixtureは診断用の明示的な状態設定で、自然成長・ゲームバランスの証拠ではありません。

### 実操作

隔離した実アプリで、出荷/梱包ラベル選択、開閉と再選択、梱包台増設、1x→2x→4x→停止、停止中の金額/作業位置固定、カメラ回転、俯瞰復帰を確認。

## 未検証・範囲外

- iPhone/Android実機、WebGLブラウザー、Web/native export、端末性能・電池は未検証
- Linux描画やエンジン入力注入を実機touchのPASSとは扱わない
- Rank3のAnnex/Router固有の飾り荷物は今回の基本倉庫演出修正の範囲外
- 64本PASSはローカル結果。公開前には実機確認と公開許可が必要

## 再現と適用

`FLOTRA_local_polish.patch` は上記mainに対する差分。清潔な基準コードへ `git apply --check` で適用可能性を検証したものです。`changed-source/` は同じ変更ファイルのコピー。

Godot 4.7.2でプロジェクトをimportした後、例:

```sh
GODOT_BIN=godot bash godot/tools/run_polish_checks.sh world_zone_input_smoke packing_presentation_smoke presentation_cache_smoke selected_routes_visibility_smoke
GODOT_BIN=godot bash godot/tools/capture_polish.sh build/comparison
```

描画キャプチャはGUIのあるセッションが必要。テストスクリプトは専用プロファイルを作り、エラー診断をexit codeと併せて判定します。
