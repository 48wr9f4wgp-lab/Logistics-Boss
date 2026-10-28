# Real-restoration focus repair

Run 40443750171 got past real native BFCache restoration and strict storage
checks, then failed the zero-console-error gate when Tab traversed stale paths
into the freed StartTrial node. The fail is retained. Adopt only the exact
`layout_hud.gd` focus-ring fix from PR161 head `c214b6e`; all its other product
changes remain separate. Clear surviving links before replacing a modal and
before rebuilding its ring, exclude FOCUS_NONE controls, release an invalid
owner and focus an eligible button. No economy, cargo or save-bridge changes.

`focus_ring_lifecycle.gd` checks real protection-modal transition and Tab/Enter.
The old source fails the stale-link checks; the fix passes 12 checks without
engine errors or campaign-state mutation. Official Web bytes were rebuilt and
recorded prospectively. The exact previous camera/caption expectations still
apply to the new PCK and fresh CI remains required. This is not phone validation.
