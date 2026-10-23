# FLOTRA（フロトラ）

iPhone / iOS向けの3D物流・倉庫成長ゲーム。Godot 4.7.2 / GDScript。

## 開発の入口（2026-10-24）

開発中心は **`flotra-campaign/`**。
仕事を受ける → 実貨物を出荷して稼ぐ → 設備・人員・棟へ投資 → 自動化と倉庫の成長を見る。

- 状態と機能対応表: [FLOTRA_ACTIVE_DEVELOPMENT.md](FLOTRA_ACTIVE_DEVELOPMENT.md)
- 再開地点: [HANDOFF.md](HANDOFF.md)
- 実装・保存契約: [flotra-campaign/README.md](flotra-campaign/README.md)
- 開発確認先: https://48wr9f4wgp-lab.github.io/Logistics-Boss/godot-jobs-preview/

`godot/` は従来版の保全・比較・素材移植元。既存保存と `/godot-preview/` を保持する。
PR165のトラックは従来版への導入であり、後発版への表示を意味しない。
PR161は後発版の追加改良候補で、Draft・未合流・性能未認定。
旧Three.jsは履歴参照であり、製品開発の中心に戻さない。

LITE / VERTICAL_SLICE / iPhone・iOS / 縦画面・タッチ優先。
PRODUCTION_DECISION=UNDECIDED / RELEASE_APPROVAL=NOT_REQUESTED。
Webは開発確認用。App Store公開やネイティブiOS実機検証は未完了。

旧README・旧HANDOFFは `docs/history/*before_unification_2026-10-24.md` に保全。
