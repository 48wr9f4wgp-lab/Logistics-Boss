# FLOTRA capacity repair and diagnosis change packet
Date: 2026-09-21 / scope: title-local / state: development candidate, not deployed
Base: main b63d60a7d506a80ef8efe8e005c4e9196d21fbcb
Authority: user's 実行 after the 2026-09-21 audit. Project v2.4 locks remain.
Goal: restore the preserved cumulative-capacity and staffing WIP, correct audited defects, and determine the actual constraint before choosing a workload change.
Non-goals: production release, preview replacement, save reset, fees/services, new platform, arbitrary infinite upgrades, Rank3 redesign.
Existing behavior: PR132/schema10; two forklifts plus one transfer belt; current slice remains VERTICAL_SLICE and production UNDECIDED.
Candidate scope: source-only WIP 23 files, related tests/CI, GDD/Art Bible/state docs. Schema11 is a candidate only.
Candidate balance hypotheses: packing cells max3 (12000/18000/27000), dispatch lanes max2 (16000/24000), existing real cargo reservation. Numbers remain testable hypotheses, not human acceptance.
Explicit staffing delta: all three authoritative pools can be edited as a draft, applied once with existing30s cooldown; current jobs remain intact. Same-tab reselection preserves draft. Active work labels follow current task, next role takes effect visually after completion.
Acceptance:
- Domain conserves cargo/cash/ownership across save/load; schema10 migration without free equipment.
- Draft cancel/stale/invalid rejection is atomic, same-tab reselection does not reset edits.
- Active work and role display agree during reassignment.
- New meaningful tests execute in CI with isolated saves.
- A controlled baseline and one-factor comparisons distinguish arrivals/orders/staff/equipment limits; do not infer demand shortage from flat output alone.
- At least one non-fork investment shows a sustained operational benefit under an appropriate declared workload, with truthfully reported limits.
- No claim of human fun or native-device acceptance from tests/stills.
Visual basis: reopened CURRENT/WIP screenshots; no art-direction redesign until TARGET image is verified. Preserve existing layout and physical manager-role design.
Recovery: immutable uploaded source patch preserved. Build candidate from pinned main, retain current schema10 preview. Schema11 requires compatible forward repair after adoption; never roll back blindly to schema9 or delete player saves.
Next: restore candidate, repair defects and docs, instrument and measure, choose only evidence-supported changes, publish a draft PR for review. No preview merge/deployment approval is included.
