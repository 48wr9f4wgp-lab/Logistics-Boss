# FLOTRA — UX / Ergonomics Pass 1

Date: 2026-09-14
Status: implementation baseline before next iPhone playtest

## Goal
Refine interaction feel before user playtest so the player evaluates the game, not avoidable interface friction.

## Human-factors principles
- The 3D warehouse remains the visual primary surface.
- Frequent controls stay in the lower thumb-reach zone.
- Frequent touch targets target 44–48 CSS px minimum on iPhone.
- Top-of-screen UI is glance information, not the main interaction zone.
- Management is a bottom sheet, not a mode that replaces the warehouse.
- A purchase never forces the sheet closed.
- The player can deliberately collapse management to observe a purchase, while the measurement remains visible.
- The core capital loop must have information scent: money -> affordable investment -> visible world change -> measured result -> next investment.
- Secondary tools are discoverable but do not compete with the capital loop.
- Stable states compress; alerts expand only the information needed to diagnose the current bottleneck.
- Avoid prescriptive next-action text. Show state, cost, effect and measured consequences; the decision remains with the player.

## Primary mobile interaction path
1. Observe warehouse and bottleneck state.
2. Change operating policy if desired.
3. Open INVEST from the bottom thumb zone.
4. Compare affordable equipment by cost and concrete effect.
5. Buy without losing the management sheet.
6. Optionally collapse the sheet with one tap / downward sheet gesture to watch the warehouse.
7. Keep a compact investment-measurement chip visible during the 25-second before/after window.
8. Read the measured result and decide what to buy next.

## Information hierarchy
### Always visible
- cash
- current operational state / bottleneck
- operating policy
- speed
- FLOW
- investment entry point

### Management sheet
- Capital Expansion first
- cash / invested capital / total assets / revenue per minute
- equipment cards
- investment result
- lower-frequency staffing, facility strategy, research and reset controls below

## Acceptance criteria
- Frequent mobile controls are at least 44 px high and have visible pressed state.
- Compact dock fits on a 390–393 pt portrait iPhone without horizontal scrolling.
- INVEST is reachable by the right thumb and visually indicates when something is affordable.
- Observation mode is not part of the compact primary control row.
- Expanded management keeps a persistent close/invest control row while the body scrolls.
- Buying an upgrade does not auto-close management.
- A player can deliberately switch to observation and still see investment measurement progress/result.
- Primary actionable labels are readable at normal iPhone viewing distance.
- Safe-area insets are respected at top and bottom.
- No FTUE rail or unique prescribed solution is introduced by this pass.
