# FLOTRA 未公開・自動梱包の見た目成長試作

## 判断
小さな手梱包台→白/黄の門型機械の形の差は、390通常全体と375短画面で確認できる。実購入に連動する視覚的成長の第一候補。成熟4棟の全体画面でも形/白色は残るが小さく、封函動作の細部は判別しづらい。倉庫全体の見やすさが解決したとは扱わない。まだ公開/採用ではない。

## 実装
基準は main a6f885e4f70ed3122fc1c776c3c6fa0661ca954a。product変更は growth_view.gd のみ。
- 既存 auto_pack 実購入と非legacy状態にだけ自動機械を表示
- 2.48×1.96の本体は既存2.6×2.2の設置枠内。白い筐体、黄の門型フレーム、開いた中央作業部
- 実pack_jobsの貨物ID/remainingを読み、その実在貨物の位置へ封函ヘッドを合わせる。処理中だけ緑の帯、未稼働は消灯。pause中に時計だけで動かさない
- 新しい貨物、搬送能力、価格、セーブschema、処理能力、経済、カメラ設定を追加しない
- PR156の大型モデル/close-cameraは流用せず、PR153/schema4も不使用

## 検証
専用profile、app.persistence_enabled=false、保存無効。実際にgrowth_1/2を完了して稼いだ状態からbuy_upgrade("auto_pack")で240を引くbefore/after。375×567と390×844。実稼働24フレームは50msずつdomainを進めて採取。mp4は20fps＝domain時間1倍の1.2秒サンプルであり、壁時計性能計測ではない。
成熟は正当domain操作由来のlate fixtureを既存codecでimport。390×844と375×667。同じ実購入済みdomainの旧rendererと試作rendererを比較。
全キャプチャでrefresh前後のexport_release_stateバイト同一、保存無効をassert。実貨物1の進捗に追従し、処理終了後の11フレームは停止/消灯。pauseでもヘッド位置不変。
実画素を確認済み。描画呼び出しは序盤76→73、成熟87→84（旧梱包モデルを隠すため）。これはnative llvmpipeの単一画面比較で、性能合格の主張ではない。

## 未検証
WebGL再export、browser/iPhone/Safariの速度、実機タッチ、全レイアウト/回転、長時間プレイ、全aggregate suite。公開・push・PR・mergeなし。

## ファイル
FLOTRA_unpublished_auto_pack_before_after.png は実画像をリサイズせず並べ、説明を外側に追加。元PNGはそのまま保持。390-active-detail.png は既存の設備選択フレームで形を確認した画像。actual-packing-cycle-1x.mp4 は上述24フレーム。result.jsonに各画面の状態と検証結果。

## 再開
同じmainから隔離worktreeを作り visual-growth.patch を適用。Godot公式4.7.2でimportし tests/release/visual_growth_capture.gd を実行。helper fvgを同梱するが、記載のworkspace絶対パスは再開先に合わせる。既存late fixtureの参照先も同様。専用XDG profileと保存無効を保つ。再開先ではまず画像を見て採否を判断し、公開工程へ進まない。

## 最終focused回帰
- visual_material_roles: 8,436 checks / failures 0。最初の起動はfixture環境変数不足でtimeoutし、正しい既存fixtureを指定して再実行成功
- growth_view_smoke: 388,233 checks / failures 0。geometry/cache/triangle/batch parityのheadless検証。GPU readback/速度測定ではない
- growth_controls_comfort: PASS []
これらはfull aggregate passではない。
