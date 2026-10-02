# FLOTRA: Blender導入・梱包ワークベンチ

> この文書はローカル検証完了時点の記録。レビュー用コード公開とGitHub CIの最新状況は対応するDraft PRを参照。

## 完了したこと

クラウド環境に既設の **Blender 4.3.2** を実際に使い、梱包台を1点制作した。箱型の台・モニター・画面の3つの旧プリミティブを、脚・下棚・面取り天板・作業側に向いた端末を持つ1つのGLBへ置き換え、**Godot 4.7.2の本番main sceneにローカル統合済み**。

- 基点: `a5c3504229e042495c274bd4cbda5200fe71f6a3`（PR138後のmain）
- ローカル作業枝: `local/blender-packing-station`
- 正本は `godot/`。GDD、経済、保存処理、schema 11、荷物所有、ゲーム進行は変更なし
- ユーザーPCへのインストール、push、PR作成、merge、公開・配信はしていない
- PR137の未承認GDD変更は混ぜていない

## 素材の仕様・選定理由

既存の梱包ゾーンは入出庫の流れの中心で、梱包中の実荷物が載る。ここを選ぶと、新しい装飾物や見せかけの生産設備を増やさず、既存の動作を読み取りやすい形にできる。

| 項目 | 結果 |
|---|---:|
| 三角形 | 304（目標500以下） |
| exported vertices | 624 |
| mesh / material surface | 1 / 1 |
| テクスチャ / 追加ライト / アニメーション | 0 / 0 / 0 |
| GLB | 約25 KB |
| 編集可能なBlender原本 | 約466 KB |
| 天板高さ | 1.032 m（既存の実荷物底面1.04 mより下） |
| 手動LOD / 自動LOD | なし |

既存のnavy / steel / amber / cyan配色を頂点カラーで保持。材質は共有し、フレームごとの再生成は行わない。元の3プリミティブは36 trianglesなので、素材単体の三角形は268増加し、material surfaceは3から1へ減った。

304 trianglesの単独配置に複数LODを追加する根拠は現段階ではない。必要性はiPhone実機計測後に判断する。

## 検証

- Blender生成・GLB出力・`.blend`再読込: PASS
- Godot 4.7.2 parse/import: PASS
- CIに列挙される52スクリプト + 既存presentation 4本 + 今回追加1本、計 **57/57 PASS**（全件隔離profile、エラー文字列も失敗扱い）
- main scene 120フレームのheadless起動: PASS
- 公式Godot 4.7.2 Web templatesによるローカルWeb release export: PASS（HTML / WASM / PCK生成。ブラウザ・実機検証や公開ではない）
- 375×667 / 390×844 / 430×932の実Godot描画: PASS（クラウドLinux）
- 最大待ち荷物の表示、近接検査画像: PASS
- `git diff --check`: PASS
- 独立レビュー: 最終差分に未解決の指摘なし

独立レビューで最初の案の下棚・左脚が待ち荷物と重なる問題を検出した。荷物の位置は変えずに脚と棚を内側へ寄せて修正。現在の回帰テストは最大12荷物と12本のテープの全boundsを、モデルの各triangle boundsに対し5 mm余裕で検査する。独立検証でも7,296件のtriangle比較と480件の元部品比較が通った。

GodotはこのGLBのCOLOR_0を取り込んでもmaterialの頂点カラー表示フラグが初期状態では無効だったため、post-importで一度だけ有効化。素材が白一色に戻る回帰もテストしている。

## before / after 描画負荷

環境: Linuxクラウド、Mesa llvmpipe（LLVM 19.1.7, 256 bits）、GL Compatibility。実main sceneに同じ合成状態を与え、Domainを停止、390×844、各状態60フレームwarmup + 180フレーム計測。基点・最終版各3回を交互順で測定。測定中にテストスイートは並走させていない。

各runの中央値を、さらに3runで中央値化した結果:

| 状態 | draw calls 前→後 | 描画primitives 前→後 | frame wall ms p50 前→後 | p95 前→後 |
|---|---:|---:|---:|---:|
| 荷物なし | 1186 → 1179 | 76840 → 77924 | 35.002 → 36.081 | 42.637 → 44.783 |
| 混雑fixture | 1449 → 1442 | 91506 → 92590 | 38.515 → 39.467 | 45.141 → 47.001 |

上記counterはshadow等を含むscene全体。素材単体のtriangle数とは違う。draw callsは7減った一方、描画primitivesは1084増え、今回のsoftware rendererではp50が約1 ms増えた。**高速化したとは扱わない**。共有クラウドのCPU描画・停止状態の診断であり、iPhoneのFPSや継続プレイの性能を証明するものではない。

VSync無効を要求したが、このMesa driverはVSync変更非対応と警告する。raw logに記録した。

## スクリーンショットの意味

- `before-*/busy-390.png` / `after-*/busy-390.png`: 実際の製品main scene・通常の縦画面カメラ、同一合成状態
- `workbench-inspection.png`: **比較用の近接検査カメラ**。製品カメラ設定を変更したものではない
- `capacity-backlog-430.png`: 上限を超える待ち数量を与え、capped visual全量で干渉を確認

混雑時の「高負荷」ラベルが密になる点は基点にもある既存UI。今回の素材統合でUIを拡張・変更していない。

## 再利用・納品

`art/blender/` に編集原本、生成スクリプト、仕様、ライセンス・再生成手順。`godot/assets/models/` にruntime GLBとimport設定。新しいsmokeはCIのpresentation regression項目へ追加済み。

バンドルに差分パッチ、変更ファイル、検証ログ、before/after画像、描画計測JSONを同梱。パッチ適用先は上記基点。原本はゲームのresource path外にあるため、ゲームの起動・exportにBlenderは不要。

## 残る確認

- iPhone実機・native iOS export / GPU / memory / touch体験: 未検証
- 現物での最終画風・視認性の承認
- 公開は別途承認後
