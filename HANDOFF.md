# FLOTRA current development handoff

Date: 2026-10-24 JST / scope: title-local

## Active development

- 開発ルート: `FLOTRA_ACTIVE_DEVELOPMENT.md`。ユーザーの「やろう」で後発版中心の一本化を承認。
- Active source: `flotra-campaign/`。実装と保存契約: `flotra-campaign/README.md`。
- iPhone/iOS・縦画面・タッチ優先・LITE・VERTICAL_SLICE。
- PRODUCTION_DECISION=UNDECIDED / RELEASE_APPROVAL=NOT_REQUESTED。
- 共通ルールは日本語v2.5三本。旧GDDのゲーム仕様を後発版へ混ぜない。

## Shared baseline / recovery

- Repository: `48wr9f4wgp-lab/Logistics-Boss` / branch: `main`。再開時に最新headを取得。
- 整理開始baseline: `18535f16340eff59bc21b6abd49338ff91dd6ac0`。
- 後発版URL: https://48wr9f4wgp-lab.github.io/Logistics-Boss/godot-jobs-preview/
- 従来版 `godot/` と `/godot-preview/` を保全。PR165は従来版へのGLB導入のみ。
- PR165検証source `b302a67e84b286a5362b7250e30d6a6b8844d8ef`: 6系統CI成功。
- PR161: Draft、head `c214b6e2b6919d7525642874e40c2c0d9eaf2d18`。未合流・性能未認定。
- アトラスの未共有作業・実行中セッションは未確認。既存変更を破棄しない。
- 旧README/HANDOFFは `docs/history/*before_unification_2026-10-24.md` に保全。

## Verified scope / limits

入口の整理だけではゲーム・価格・保存形式・公開URL・CIは変わらない。
従来版と後発版の保存は分離。資金・設備・貨物の相互移行は行わない。
TARGETはスペース内の元PNGを回収し閲覧済み。`docs/visual/TARGET_RECOVERY_2026-10-24.md` を参照。
旧Git内PNGは破損のまま保全。過去の別JPEGとのバイト同一性は主張しない。
後発版へのモデル設置・アート目標との一致・iPhone実機性能は未検証。

## Next

対応表に沿い、後発版でのGLB読込基盤とPR161固定headの機能を検証する。
TARGET実画像へのアクセスgateは解消。後発版CURRENTの画像と比較して配置・UI・アートを判断する。
機能・保存・import検証を継続する。通常開発の承認はv2.5に従って継承し、
App Store公開・新規配布・費用・削除とは分離する。
