# マチコバ！ v0.11 — 工場の質感と働く姿を磨く

Title-local / 2026-10-31 / existing development Pages / visual refinement

## Authority and goal

The user explicitly liked the current graphics and requested further refinement: 「グラフィックいい感じもっとブラッシュアップして行こう」. Preserve the approved miniature-workshop direction and improve what is visible at normal mobile scale: material separation, contact/light and the real work performed by the three workers.

## Visual reference and current behavior

The current renderer was introduced in v0.9 and remains the v0.10 scene. It already has recognisable machines, job-linked basic motion, cutaway walls/windows, a truck and original code-drawn props. The next pass strengthens broad readable surfaces and working poses; it does not establish a new art direction.

- Approved direction reference / CURRENT before this pass: `evidence/forge-v09-mobile-20261031.jpg` and `evidence/forge-v09-working-20261031.jpg` (GitHub-backed, actually viewed this turn). The old heading on those images is historical; current naming remains マチコバ！.
- Current named scene also viewed by the renderer and visual reviewer: `machikoba-v092-mobile.jpg` in this workspace. Geometry and scene framing are unchanged in v0.10. This image is a local convenience, not the sole durable reference.
- WORKING_HEAD base: `b6afc956a1948c841810535d45197f8923b29e4b`; tested code baseline: `f9683d1be3569623e6c03cd2ab01faaf01fbd8c1` plus its public verification record.

## Files and boundaries

Renderer: `docs/forge-preview/workshop.mjs`. Integration: cache-version references and footer in `app.mjs` / `index.html`. Documentation/evidence under `factory-prototype`. A bounded render-state helper/test may be added only if needed to verify a real work/pickup distinction. The model, save namespace/schema, economy, scheduling, order guidance, main-screen layout and existing hit regions remain unchanged.

No new production behavior, shipping rewards, permanent effects, dependency/CDN art downloads or native release work. Static architecture stays cached; no per-frame random particles or broad flashing effects.

## Acceptance

- Keep the orange cutter, blue-green drill, blue-grey lathe and wooden inspection surface readable. Use larger reflective metal bands, cast-paint edges and restrained wear within existing machinery geometry.
- Strengthen soft window light/mullion shadows, wall contact and layered shadows beneath equipment/people without obscuring free floor cells or selection routes.
- Show a working person's hands toward the actual assigned machine, and distinguish plate versus shaft cargo. Show cargo only after the modeled pickup location has been reached if that state can be derived unambiguously from the current job/path. Do not add pickup state to saves.
- Workpieces and moving details are based on actual jobs. Preserve depth ordering, optional labels, label/hull picking, upgrades, placement and overview controls.
- Paused/reduced-motion frames remain still; rendering leaves model state unchanged. Static-cache reuse and the existing 30fps drawing cap remain in force.
- Compare fresh, working and upgraded/expanded scenes at mobile scale. Verify the public scene and accept → skip → dispatch after normal CI/merge/Pages, including short mobile layouts and selection.

## Verification and recovery

Use the existing 58 regression tests and module syntax checks, local Canvas renders for before/after review, read-only/paused/reduced-motion checks and the bounded public journey. If pickup depiction changes, verify its boundary cases against actual assigned paths. Do not treat cloud rendering as physical iPhone/Safari performance validation.

Revert this render/integration change and redeploy the existing development Pages to recover. Save data requires no conversion. The pre-change local files are preserved in `forge-v011-baseline`; unrelated old FLOTRA branches remain outside this title's scope.

## Implemented and locally verified

The renderer now has readable metal reflections/paint edges, visible wood grain, clipped window-light panes/mullion shadows, wall contacts and layered equipment/person shadows. Workwear proportions and short working arms were refined after comparing the first candidate. `workerVisualState()` derives pickup/carry/work from the actual remaining path and references; it changes no game state. Work surfaces and incoming stock use real parts, with no permanent dummy material on an empty incoming pallet.

All 66 tests pass, including eight new tests in `tests/workshop-state.test.mjs`; module syntax checks pass. The real-path investigation covered 180 jobs / 14,820 walking ticks with no pickup-cell revisits or classification errors. Root and a separate visual reviewer inspected fresh, working, carrying and upgraded/expanded comparisons. The existing direction and machine distinctions are preserved, with no blocking visual issue found.

Local NAPI Canvas probes confirm state unchanged, paused frames stable, reduced-motion frames stable, active work animating and static-cache reuse. Mean cached drawing was approximately 3.70ms in that local probe; this is neither an iPhone measurement nor a frame-rate guarantee. Public browser validation follows deployment and is recorded separately below when complete.
