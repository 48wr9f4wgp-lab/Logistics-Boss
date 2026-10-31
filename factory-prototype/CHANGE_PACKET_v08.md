# FORGE v0.8 — 投資の効果を見せる
Title-local / 2026-10-31 / engineering preview

Goal: 「もう一件稼いで設備を改良・職人を育てたい」という判断を支える。投資前に加工時間と検品品質の変化を示し、工場でも改良段階を見分けられる。
Scope: existing equipment/worker/quick cards, machine level badges, shared processing calculation, tests/docs/evidence. No prices, routing, scheduling, save schema, new systems or native release changes. Existing dev Pages only.

Acceptance:
- 設備の改良前後に1個あたりの基準加工時間、検品台には調整なしで扱える品質の目安。技能1・運搬/担当待ちを除く条件を明示し、注文全体の短縮保証にしない。
- 職人の研修前後は現在の設備と本人の技能/指導状態を使った工程別時間、検品品質の目安。設備レベルを併記。最高段階では架空の次段階や価格を表示しない。
- 費用、購入後の手元、不足額が分かる。無資金時は購入ボタン無効、既存モデルの再検証も維持。反映は次の作業割当から（進行中の残り時間は書き換えない）。
- 同じ計算関数を実際の作業割当に使い、既存結果と一致。既存セーブに追加項目なし。
- 工場内の各設備にLv表示と改良段階の印。既存の機械ヒット領域・ラベル選択を維持。

Checks: shared formula vs assigned work including quality/mentoring/level/skill; actual upgrade/training payment and in-flight job behavior; existing regression suite; Chromium 390×844 equipment preview → purchase → changed stats/level badge and worker preview/training. Current visual evidence/forge-v07-skip-20261031.jpg viewed; existing code art preserved, small feedback pass only.
Rollback: revert PR and redeploy existing dev Pages. Save schema/key and underlying economics unchanged. Physical iPhone and player enjoyment remain unverified.
