# FLOTRA portrait readability repair — 2026-09-21
Scope: title-local, source candidate on PR136. User authority: OK after current-HEAD visual audit.
Base: 1da82cb055009b0f6c1a27d172bc531f28afccd6.
Goal: remove evidenced feedback/control overlap, clipped pressure text, stale staffing guidance and excessive overview labels; improve portrait framing/material separation.
Non-goals: economy, logistics, saves/schema, new equipment, main merge/deployment, production approval, literal reproduction of TARGET Rank3 scale.
Evidence: all13 PNGs in uploaded growth15 ZIP, SHA256 0553a5cb53fdd8f81e0db813a66d3fb1fc51b3f2184436045533f838989bc055. TARGET: reattached JPEG SHA256 5303409d35e0f5e465b43cf4fdb07a3b5a5ebc98b50eab776262bd1de91f1eb2, viewed.
Existing behavior: bottom camera controls cover measurement text; one-line English pressure banner clips; current staffing instructions cite obsolete OPERATIONS path; always-visible worker labels compete with zones.
Files: selected_work_routes, game_hud_release, game_hud_mobile, warehouse_view, warehouse_view_mobile, zone_interaction_view, visual_composition_fix; targeted actual-main readability test and capture/CI fixtures.
Acceptance: result/control rectangles do not intersect at375/390/430px; management/zone overlays retain input ownership; pressure banner fits with wave info; staffing entry matches current UI; operational targets/equipment centers remain on screen in overview; role text remains truthful when revealed; no domain or save change.
Tests: import/compile, targeted full-main layout/projection regression, existing staffing/growth/UI/visual gates; CI-rendered capture generation. Headless projection checks are geometry evidence only, not visual acceptance. iPhone motion/performance remains unverified.
Recovery: revert this source-only change on the feature branch; no player save intervention. Existing deployed schema10 stays untouched.
