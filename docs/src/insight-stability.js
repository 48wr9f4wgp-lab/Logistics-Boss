export function bindInsightStability(sim) {
  const panel = document.getElementById('insightPanel');
  const toggle = document.getElementById('insightToggle');
  if (!panel || !toggle) return { update() {} };

  let preferredCompact = panel.classList.contains('compact');
  let enforcing = false;

  function syncToggleText() {
    const compact = panel.classList.contains('compact');
    const hasOffers = !sim.state.activeContract && (sim.state.contractOffers || []).length > 0;
    const label = compact ? (hasOffers ? '契約' : '開く') : '閉じる';
    if (toggle.textContent !== label) toggle.textContent = label;
    toggle.setAttribute('aria-expanded', String(!compact));
    toggle.setAttribute('aria-label', compact ? (hasOffers ? '契約を選ぶ' : '案内を開く') : '案内を閉じる');
  }

  function enforcePreferredState() {
    if (enforcing) return;
    const currentCompact = panel.classList.contains('compact');
    if (currentCompact !== preferredCompact) {
      enforcing = true;
      panel.classList.toggle('compact', preferredCompact);
      enforcing = false;
    }
    syncToggleText();
  }

  // Capture the user's intent before ui.js runs its own click handler.
  // The actual DOM state is authoritative even if ui.js' private flag drifted.
  toggle.addEventListener('pointerdown', () => {
    preferredCompact = !panel.classList.contains('compact');
  }, { capture: true });

  toggle.addEventListener('click', () => {
    queueMicrotask(enforcePreferredState);
  });

  const observer = new MutationObserver(() => {
    if (enforcing) return;
    queueMicrotask(enforcePreferredState);
  });
  observer.observe(panel, { attributes: true, attributeFilter: ['class'] });

  function update() {
    // main.js calls this after ui.render(). Correct transient writes in the
    // same animation frame so Safari never paints a 契約/閉じる flicker.
    enforcePreferredState();
  }

  enforcePreferredState();
  return { update };
}
