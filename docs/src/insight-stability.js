export function bindInsightStability(sim) {
  const panel = document.getElementById('insightPanel');
  const toggle = document.getElementById('insightToggle');
  if (!panel || !toggle) return { update() {} };

  let preferredCompact = panel.classList.contains('compact');
  let userMutationUntil = 0;
  let restoring = false;
  let timer = 0;

  function syncToggleText() {
    const compact = panel.classList.contains('compact');
    const hasOffers = !sim.state.activeContract && (sim.state.contractOffers || []).length > 0;
    toggle.textContent = compact ? (hasOffers ? '契約' : '開く') : '閉じる';
    toggle.setAttribute('aria-expanded', String(!compact));
    toggle.setAttribute('aria-label', compact ? (hasOffers ? '契約を選ぶ' : '案内を開く') : '案内を閉じる');
  }

  toggle.addEventListener('pointerdown', () => {
    userMutationUntil = performance.now() + 500;
  }, { capture: true });

  toggle.addEventListener('click', () => {
    queueMicrotask(() => {
      preferredCompact = panel.classList.contains('compact');
      syncToggleText();
    });
  });

  const observer = new MutationObserver(() => {
    if (restoring) return;
    const currentCompact = panel.classList.contains('compact');
    if (performance.now() <= userMutationUntil) {
      preferredCompact = currentCompact;
      syncToggleText();
      return;
    }
    if (currentCompact === preferredCompact) return;

    // Bottleneck severity is volatile simulation data. It may update the label,
    // but it must never open/close the panel without a user action.
    restoring = true;
    panel.classList.toggle('compact', preferredCompact);
    queueMicrotask(() => {
      restoring = false;
      syncToggleText();
    });
  });
  observer.observe(panel, { attributes: true, attributeFilter: ['class'] });

  function update(dt) {
    timer += Math.max(0, Number(dt) || 0);
    if (timer < 0.25) return;
    timer = 0;
    syncToggleText();
  }

  syncToggleText();
  return { update };
}
