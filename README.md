# Logistics Boss

**Logistics Boss** は、プレイヤーが自分で荷物を運ぶのではなく、物流拠点へ指示を出し、NPC・設備・物流フローが自律的に動く様子を観察しながら改善していく3D物流管理シミュレーターです。

## Current Core Loop

観察 → ボトルネック発見 → 方針・優先度・設備へ指示 → NPCと物流の流れが変化 → 出荷・報酬 → 研究・設備強化 → 施設拡張

## Product Direction

- 3D世界を主役にし、UIは必要時だけ展開する
- 直接操作の忙しさより、指示・判断・観察の快感を優先する
- 手作業から自動化、大規模物流センターへ成長する景色を報酬にする
- iPhone Safariを主要な実機検証環境として扱う
- GitHub `main` をCanonical baselineとする

## Technology

- Three.js 0.186.0
- Rapier 3D compat 0.20.0
- Static HTML / CSS / JavaScript
- GitHub Pages想定: `main/docs`

## Status

Vertical Slice / Functional Build段階。一般公開品質の完成版ではありません。
