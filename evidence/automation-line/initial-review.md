# FLOTRA：最初の設備ライン（ローカルレビュー用）

## 基準と範囲

- origin URL: `https://github.com/48wr9f4wgp-lab/Logistics-Boss.git`。
- `git ls-remote`、fetch後の `origin/main`、作業HEADはいずれも PR160 merge `027cb20d0bcd34fde6f944f4b3e7e63e21dc9b09`。
- 対象は `flotra-campaign/`。旧 `godot/` ゲームと未採用の棚試作は変更しない。
- workspace/repository内に AGENTS.md / .agents/skills は存在しなかった。root README、campaign README、現行のgrowth/dispatch simulation、view、save/codec、入力・描画テストを確認。
- 使用エンジン: `/workspace/.flotra-tools/bin/godot` = `4.7.2.stable.official.ed1daf0bf`。標準PATHは4.6.3なので使用しない。
- push、PR、merge、公開は未実施。作業は未コミット差分として保持。公開 `docs/godot-jobs-preview` バイナリも変更しない。将来のPRは親の指示後にdraft。

## 採用した最小設計

既存 `auto_pack` 購入（2仕事達成後、240）でコンベア・自動梱包・搬送アームを一括接続する。独立した3購入や配線は追加しない。初期資金100＋序盤報酬140/200＝440から購入すると200が残る。増築や人員との既存の資金選択、繰り返し報酬を維持する。梱包能力も既存の1個/0.7秒のまま。

購入前は手作業台、購入後は既存の黄色い梱包橋に黒い搬送ベルト、青緑の計測ゲート、珊瑚色の搬送アームが現れる。操作盤を低くしてアームを隠さない形に変更。購入説明で3設備が自動接続されることを伝える。

実 `pack_jobs[0].cargo_id` の描画ノードを使い、残り処理時間から投入・搬送（0–35%）、封緘（35–70%）、持ち上げ・受け渡し（70–100%）を決定する。テープとラベルは後半に見える。終了した荷物は既存のpacked/reserved_shipに従う出力側へ置き、既存の運搬員が引き取る。出荷イベントを描画側から発生させない。計測・成形の物理シミュレーションやラベルデータ生成を追加するものではない。

実機参考: [Packsize CVP Impack](https://www.packsize.com/product/cvp-impack) の計測・箱成形・封緘・ラベル付けの順序を小型モデルに簡略化した。実機の寸法・処理速度の再現ではない。

## 互換性・負荷の方針

- 新規セーブキー、schema、設備ID、価格、解放条件、容量、処理速度、経済計算の変更なし。simファイルの変更は購入説明1行のみ。
- 全機構は現行1.6×1.0の梱包セル内。既存の無料4レイアウトに自動追従し、通路の物理処理は変更しない。
- 新規固定14箱メッシュ＋親1ノード。既存MultiMeshへ統合し、ライト、影パス、パーティクル、常時エフェクトを増やさない。
- 稼働中の部品は不透明な単純立体で、低DPRでも色と外形で区別する。全体表示の細部判別には後述の限界がある。
- wall clockやTweenを使わず、同じ保存状態から同じ姿勢を再構成する。停止、旧セーブ復元、reduced motionで勝手に処理が進まない。
- PR160のHUD・仕事/設備の分離・56px phone入力・DPR設定・入力ガードは変更しない。

## 検証と証拠

結果は `evidence/automation-line/` に収録。測定用Webは `/tmp/flotra-line-web/candidate/`、比較公開版は同 `control/`。計測と5画面テスト後の変更は新Godotテストへの箱干渉assert追加のみで、ゲームruntimeは同一。公開用の完全なsource/export qualificationは未実施であり、将来のdraft PR前に現コードから再書き出しする。全て合成・正規操作由来のセーブ、専用一時プロファイルで実施し、ユーザーの実保存には触れていない。

- 新規 `automation_line.gd`: 8,315 checks / 0 failures。実購入、各段階、同一荷物の単調な搬送、機構の範囲と実荷物との非干渉、実出荷数、停止/reduced motion、in-flight保存の完全一致、4レイアウト、未購入旧状態への復元。
- 既存 `visual_growth_only.gd`: 356 checks / 0 failures。実荷物と梱包ヘッド、停止・保存・通路の確認。新旧機械の通路交差比較は既存テストの歴史的比較であり、今回のbaseline性能比較とは別。
- 既存Godot 46 suites＋新規1 suite＝47 suitesのチェック通過。実行中のtest.shに新suite名を挿入したため、最初の45 suites終了後にshellの読込位置がずれてEOFエラーとなった。`bash -n`通過を確認し、未実行末尾（既存readability_inputとNode 9 checks）を同じコマンドで独立実行し終了コード0。新suiteも独立実行で通過。単一の全体ランナーが正常終了したという主張ではない。中断を含むログを保存した。
- 最終Web書き出しの `browser_growth_geometry.cjs`: 375×567、DPR1/2/3の3ケース通過。toolbar変化、向き変更、safe area、touch scroll、配置候補、メニュー復帰を含む既存assertions。390×844 DPR3のproduction表示も同runnerの検証対象。
- 新 `browser_automation_line.cjs`: 390×844、DPR1の購入前後・3工程の5ケース通過。全ケースでpaused、simTime・出荷・資金の不変を確認。実ブラウザ画像はCSS解像度で保存。
- 性能ABBA（公開版A1→変更版B1→変更版B2→公開版A2）: 390×844/DPR3、同一の成熟fixture・初期状態・Chromium/SwiftShader、各variantの配信asset bytes一致を検証。4回とも既存性能基準通過（CPU p95 <100ms、draw calls ≤250、停止中ノード変動≤4、UI-only比のframe間隔基準）。重いテストを同時実行せず、失敗試行の選び直しはしていない。

| 稼働中 | 公開A1 | 変更B1 | 変更B2 | 公開A2 |
|---|---:|---:|---:|---:|
| CPU process中央値 ms | 36.2 | 35.7 | 39.2 | 33.5 |
| CPU process p95 ms | 48.6 | 74.2 | 50.3 | 46.2 |
| frame間隔中央値 ms | 233.3 | 250.0 | 233.4 | 233.3 |
| frame間隔 p95 ms | 250.1 | 283.3 | 266.7 | 266.7 |
| draw calls最大 | 88 | 86 | 86 | 86 |

初期停止中ノード数は1272→1287で設計どおり+15、停止後も各run内で完全固定。draw callsは増えていない。一方CPU p95は変更版で最大74.2msとなり、追加CPUコストがゼロとは言えない。既存基準通過という範囲の結果であり、性能同等の証明ではない。公開版から約4fpsのソフトウェア描画環境なので、この測定から実機の滑らかさは判断できない。

再現:

```sh
GODOT=/workspace/.flotra-tools/bin/godot bash flotra-campaign/test.sh
# 以下もXDG_DATA_HOME / XDG_CONFIG_HOME / XDG_CACHE_HOMEを新しい一時領域へ設定する。
FLOTRA_LINE_FIXTURES=/tmp/line-fixtures /workspace/.flotra-tools/bin/godot --headless --path flotra-campaign --script res://tests/release/automation_line.gd
# export_web.shの出力は公開docsではなく一時ディレクトリに指定し、ローカルHTTPで配信する。
CHROMIUM_EXECUTABLE=/usr/bin/chromium node flotra-campaign/tests/release/browser_automation_line.cjs LOCAL_URL /tmp/line-fixtures /tmp/line-captures
```

ブラウザはPlaywright 1.62.1＋環境に既存のChromium 151.0.7922.173を使用。ブラウザ取得、Library転送、プロキシ迂回は行っていない。Playwright管理版Chromiumの取得制約が解消したという意味ではない。

## 残る限界

DPR1の390px全体表示では設備が小さく、購入による機械化は分かるが3機構の細部の識別は弱い。既存ズームと配置画面の近景ではベルト・梱包橋・珊瑚色アームを確認できる。0.7秒の既存処理は標準2倍速で実時間約0.35秒となり、低FPSで毎工程が画面に現れる保証はない。この制約のために架空の待ち時間は導入していない。

物理iPhone/Safari、実機GPU/発熱/電池、実BFCache復帰は未検証。PR160は承認済み公開版で13ジョブ/desktop14ケース合格、実BFCache復帰1件未検証によりCI全体failureという既知状態を引き継ぐ。今回はBFCacheを偽イベントで置き換えず、GitHub CIも起動しない。

## レビュー対象

- `flotra-campaign/prototype/growth_view.gd`: 3設備と実荷物連動の描画。
- `flotra-campaign/prototype/growth_sim.gd`: 既存購入説明のみ。
- `flotra-campaign/tests/release/automation_line.gd` (+ uid): domain/view境界と保存・配置の回帰。
- `flotra-campaign/tests/release/browser_automation_line.cjs`: 合成fixtureで購入前後・各段階・既存ズーム/配置近景を取得し、停止・資金・出荷を検証。
- `flotra-campaign/test.sh`: 新規Godot suiteの登録。
- 本文書と `evidence/automation-line/`: 測定・画像・再現情報。
