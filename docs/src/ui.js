function yen(value) {
  return `¥${Math.round(value).toLocaleString('ja-JP')}`;
}

function contractProgressText(contract) {
  if (!contract) return '';
  const current = Math.min(contract.target, contract.progress || 0);
  if (contract.kind === 'ship') return `${Math.floor(current)} / ${contract.target}件`;
  return `${Math.floor(current)} / ${contract.target}秒`;
}

export function bindUi(sim, sceneView) {
  const el = {
    app: document.getElementById('app'),
    money: document.getElementById('money'),
    research: document.getElementById('research'),
    facilityRank: document.getElementById('facilityRank'),
    logisticsRating: document.getElementById('logisticsRating'),
    facilityProgressBar: document.getElementById('facilityProgressBar'),
    shipped: document.getElementById('shipped'),
    orders: document.getElementById('orders'),
    inbound: document.getElementById('inbound'),
    rack: document.getElementById('rack'),
    throughput: document.getElementById('throughput'),
    workers: document.getElementById('workers'),
    status: document.getElementById('status'),
    toast: document.getElementById('toast'),
    reset: document.getElementById('resetBtn'),
    camera: document.getElementById('cameraBtn'),
    flow: document.getElementById('flowBtn'),
    observe: document.getElementById('observeBtn'),
    focusExit: document.getElementById('focusExit'),
    dock: document.getElementById('commandDock'),
    dockToggle: document.getElementById('dockToggle'),
    quickSpeed: document.getElementById('quickSpeedBtn'),
    insightPanel: document.getElementById('insightPanel'),
    insightToggle: document.getElementById('insightToggle'),
    directorLabel: document.getElementById('directorLabel'),
    directorDetail: document.getElementById('directorDetail'),
    directorRecommendation: document.getElementById('directorRecommendation'),
    severityBadge: document.getElementById('severityBadge'),
    contractTitle: document.getElementById('contractTitle'),
    contractBody: document.getElementById('contractBody'),
    contractChoices: document.getElementById('contractChoices'),
    celebration: document.getElementById('celebration'),
    celebrationTitle: document.getElementById('celebrationTitle'),
    celebrationReward: document.getElementById('celebrationReward'),
    staffingLock: document.getElementById('staffingLock'),
    crewStore: document.getElementById('crewStore'),
    crewPick: document.getElementById('crewPick'),
    crewShip: document.getElementById('crewShip'),
    opsCrew: document.getElementById('opsCrew'),
    opsWeakness: document.getElementById('opsWeakness'),
    opsNext: document.getElementById('opsNext'),
    facilityImpact: document.getElementById('facilityImpact'),
    goalZones: document.getElementById('goalZones'),
    goalContracts: document.getElementById('goalContracts'),
    goalThroughput: document.getElementById('goalThroughput'),
    nextStageBar: document.getElementById('nextStageBar'),
    nextStageHint: document.getElementById('nextStageHint'),
    rank1Guide: document.getElementById('rank1Guide'),
    rank1GuideTitle: document.getElementById('rank1GuideTitle'),
    rank1GuideDetail: document.getElementById('rank1GuideDetail'),
  };

  const policyButtons = [...document.querySelectorAll('[data-policy]')];
  const speedButtons = [...document.querySelectorAll('[data-speed]')];
  const upgradeButtons = [...document.querySelectorAll('[data-upgrade]')];
  const perkButtons = [...document.querySelectorAll('[data-perk]')];
  const facilityButtons = [...document.querySelectorAll('[data-facility]')];
  const staffingPlanButtons = [...document.querySelectorAll('[data-staffing-plan]')];
  let toastTimer = 0;
  let celebrationTimer = 0;
  let lastOfferSignature = '';
  let insightCompact = true;
  let flowEnabled = false;
  let dockCompact = true;
  let focusMode = false;

  function toast(text, tone = 'normal') {
    clearTimeout(toastTimer);
    el.toast.textContent = text;
    el.toast.dataset.tone = tone;
    el.toast.classList.add('show');
    toastTimer = setTimeout(() => el.toast.classList.remove('show'), 1450);
  }

  function celebrate(title, reward = '') {
    clearTimeout(celebrationTimer);
    el.celebrationTitle.textContent = title;
    el.celebrationReward.textContent = reward;
    el.celebration.classList.remove('show');
    void el.celebration.offsetWidth;
    el.celebration.classList.add('show');
    try { navigator.vibrate?.([28, 35, 45]); } catch {}
    celebrationTimer = setTimeout(() => el.celebration.classList.remove('show'), 1900);
  }

  function updateInsightToggle() {
    const hasOffers = !sim.state.activeContract && (sim.state.contractOffers || []).length > 0;
    el.insightToggle.textContent = insightCompact ? (hasOffers ? '契約' : '開く') : '閉じる';
    el.insightToggle.setAttribute('aria-expanded', String(!insightCompact));
    el.insightToggle.setAttribute('aria-label', insightCompact ? (hasOffers ? '任意契約を見る' : '分析を開く') : '分析を閉じる');
  }

  function setInsightCompact(compact) {
    insightCompact = Boolean(compact);
    el.insightPanel.classList.toggle('compact', insightCompact);
    updateInsightToggle();
  }

  function setDockCompact(compact) {
    dockCompact = Boolean(compact);
    el.dock.classList.toggle('compact', dockCompact);
    el.dockToggle.textContent = dockCompact ? '管理' : '閉じる';
    el.dockToggle.setAttribute('aria-expanded', String(!dockCompact));
    el.dockToggle.setAttribute('aria-label', dockCompact ? '管理パネルを開く' : '管理パネルを閉じる');
  }

  function setFocusMode(enabled) {
    focusMode = Boolean(enabled);
    el.app?.classList.toggle('focusMode', focusMode);
    el.focusExit.hidden = !focusMode;
    el.observe.classList.toggle('active', focusMode);
    el.observe.setAttribute('aria-pressed', String(focusMode));
    if (focusMode) {
      setDockCompact(true);
      sceneView.resetCamera();
      toast('観察モード');
    }
  }

  function nextQuickSpeed() {
    const current = sim.state.timeScale;
    const next = current === 0 ? 1 : current === 1 ? 2 : current === 2 ? 4 : 1;
    sim.setTimeScale(next);
    render();
    try { navigator.vibrate?.(8); } catch {}
  }

  policyButtons.forEach((button) => {
    button.addEventListener('click', () => {
      sim.setPolicy(button.dataset.policy);
      try { navigator.vibrate?.(10); } catch {}
      render();
    });
  });

  staffingPlanButtons.forEach((button) => {
    button.addEventListener('click', () => {
      const result = sim.setStaffingPlan(button.dataset.staffingPlan);
      if (!result.ok) toast(result.reason, 'warn');
      else { toast('人員配置を変更。しばらく観察しよう', 'good'); try { navigator.vibrate?.(14); } catch {} }
      render();
    });
  });

  speedButtons.forEach((button) => {
    button.addEventListener('click', () => {
      sim.setTimeScale(Number(button.dataset.speed));
      render();
    });
  });

  upgradeButtons.forEach((button) => {
    button.addEventListener('click', () => {
      const type = button.dataset.upgrade;
      const result = sim.purchaseUpgrade(type);
      if (!result.ok) toast(result.reason, 'warn');
      else {
        toast(`設備強化 -${yen(result.cost)}`, 'good');
        try { navigator.vibrate?.(18); } catch {}
      }
      render();
    });
  });

  facilityButtons.forEach((button) => {
    button.addEventListener('click', () => {
      const result = sim.purchaseFacility(button.dataset.facility);
      if (!result.ok) toast(result.reason, 'warn');
      else {
        toast(`施設建設 -${yen(result.cost)}`, 'good');
        try { navigator.vibrate?.([18, 25, 24]); } catch {}
      }
      render();
    });
  });

  perkButtons.forEach((button) => {
    button.addEventListener('click', () => {
      const type = button.dataset.perk;
      const result = sim.purchasePerk(type);
      if (!result.ok) toast(result.reason, 'warn');
      else {
        toast(`研究完了 -${result.cost} RP`, 'good');
        try { navigator.vibrate?.(18); } catch {}
      }
      render();
    });
  });

  el.insightToggle.addEventListener('click', () => { setInsightCompact(!insightCompact); render(); });
  el.observe.addEventListener('click', () => setFocusMode(true));
  el.focusExit.addEventListener('click', () => setFocusMode(false));
  document.addEventListener('keydown', (event) => {
    if (event.key === 'Escape' && focusMode) setFocusMode(false);
  });
  el.dockToggle.addEventListener('click', () => setDockCompact(!dockCompact));
  el.quickSpeed.addEventListener('click', nextQuickSpeed);
  el.flow.addEventListener('click', () => {
    flowEnabled = !flowEnabled;
    sceneView.setFlowMode?.(flowEnabled);
    el.flow.classList.toggle('active', flowEnabled);
    el.flow.setAttribute('aria-pressed', String(flowEnabled));
    toast(flowEnabled ? 'FLOW表示 ON' : 'FLOW表示 OFF');
  });
  el.camera.addEventListener('click', () => sceneView.resetCamera());
  el.reset.addEventListener('click', () => {
    if (!confirm('進行・強化・研究を初期状態へ戻しますか？')) return;
    localStorage.removeItem('logistics_boss_save');
    sim.resetProgress();
    setFocusMode(false);
    setInsightCompact(true);
    setDockCompact(true);
    toast('初期状態へ戻した', 'warn');
    render();
  });

  sim.onEvent((event) => {
    if (event.type === 'shipment') toast(event.text, 'good');
    else if (event.type === 'overflow') toast(event.text, 'warn');
    else if (event.type === 'upgrade' || event.type === 'perk') toast(event.text, 'good');
    else if (event.type === 'contract_complete') {
      toast(event.text, 'good');
      const reward = event.reward ? `${yen(event.reward.cash)}  +${event.reward.research} RP  +${event.reward.rating || 2}評価` : event.text;
      celebrate('CONTRACT COMPLETE', reward);
    } else if (event.type === 'rank_up') {
      toast(event.text, 'good');
      celebrate('FACILITY RANK UP', event.name);
      setDockCompact(false);
    } else if (event.type === 'facility_built') {
      toast(event.text, 'good');
    } else if (event.type === 'milestone') {
      toast(event.text, 'good');
    } else if (event.type === 'contract_failed') toast(event.text, 'warn');
    else if (event.type === 'order' && sim.state.ordersOpen >= 6) toast(event.text);
  });

  function renderContracts() {
    const active = sim.state.activeContract;
    if (active) {
      lastOfferSignature = '';
      el.contractTitle.textContent = active.title;
      const percent = Math.min(100, Math.round((active.progress / Math.max(1, active.target)) * 100));
      el.contractBody.innerHTML = `<div class="contractDesc">${active.desc}</div><div class="contractProgress"><i style="width:${percent}%"></i></div><div class="contractMeta"><span>${contractProgressText(active)}</span><span>残り ${Math.ceil(active.remaining)}秒</span><span>報酬 ${yen(active.reward.cash)} + ${active.reward.research}RP + ${active.reward.rating || 2}評価</span></div>`;
      el.contractChoices.innerHTML = '';
      return;
    }

    const offers = sim.state.contractOffers || [];
    const signature = offers.map((item) => item.id).join(',');
    const isRank1 = sim.state.facilityRank < 2;
    el.contractTitle.textContent = offers.length ? (isRank1 ? `任意契約（${offers.length}件）` : `契約候補（${offers.length}件）`) : '次の契約を準備中';
    el.contractBody.innerHTML = offers.length ? `<div class="contractDesc">${isRank1 ? '追加報酬を狙う場合だけ受注する' : '受けたい契約を選ぶ'}</div>` : '';
    if (signature === lastOfferSignature) return;
    lastOfferSignature = signature;
    el.contractChoices.innerHTML = '';
    for (const offer of offers) {
      const button = document.createElement('button');
      button.type = 'button';
      button.className = 'contractChoice';
      button.innerHTML = `<strong>${offer.title}</strong><span>${offer.desc}</span><small>${yen(offer.reward.cash)} + ${offer.reward.research}RP + ${offer.reward.rating || 2}評価</small>`;
      button.addEventListener('click', () => {
        const result = sim.chooseContract(offer.id);
        if (!result.ok) toast(result.reason, 'warn');
        else {
          toast(`契約開始: ${offer.title}`);
          setDockCompact(true);
        }
        render();
      });
      el.contractChoices.appendChild(button);
    }
  }

  function render() {
    const c = sim.counts();
    const s = sim.state;
    const d = s.director;
    const isRank1 = s.facilityRank < 2;
    el.insightPanel.dataset.stable = d.severity === 0 ? 'true' : 'false';
    el.money.textContent = yen(s.money);
    el.research.textContent = `${s.research} RP`;
    const nextTarget = sim.nextRankTarget();
    el.facilityRank.textContent = `RANK ${s.facilityRank} · ${sim.facilityRankName()}`;
    const zoneGroups = ['intakeStrategy', 'rackStrategy', 'packStrategy'];
    const chosenZones = zoneGroups.filter((group) => Object.keys(sim.facilityInfo).some((key) => sim.facilityInfo[key].group === group && s.facilities[key])).length;
    el.logisticsRating.textContent = nextTarget == null ? `拡張区画 ${chosenZones} / 3` : `Warehouse評価 ${s.logisticsRating} / ${nextTarget}`;
    el.facilityProgressBar.style.width = `${nextTarget == null ? (chosenZones / 3) * 100 : Math.min(100, (s.logisticsRating / nextTarget) * 100)}%`;
    el.app?.classList.toggle('rank2', s.facilityRank >= 2);
    el.app?.classList.toggle('rank1Free', isRank1);
    if (el.rank1Guide) el.rank1Guide.hidden = !isRank1;
    if (el.rank1GuideTitle) el.rank1GuideTitle.textContent = `Warehouse評価 ${s.logisticsRating} / ${nextTarget || 8}`;
    if (el.rank1GuideDetail) el.rank1GuideDetail.textContent = '出荷・処理速度・安定運転・任意契約のどれからでも評価を伸ばせる。運営方針は自由。';
    el.shipped.textContent = s.shipped.toLocaleString('ja-JP');
    el.orders.textContent = s.ordersOpen.toLocaleString('ja-JP');
    el.inbound.textContent = c.inbound.toLocaleString('ja-JP');
    el.rack.textContent = `${c.rack}/${sim.rackCapacity()}箱`;
    el.throughput.textContent = `${s.metrics.perMinute}/分`;
    el.workers.textContent = `${s.workers.length}人`;
    el.status.textContent = s.status;
    const isAlert = s.status.startsWith('⚠');
    el.status.dataset.alert = isAlert ? 'true' : 'false';
    if (focusMode) {
      el.focusExit.textContent = d.severity >= 2 ? `管理へ戻る・${d.label}` : '管理へ戻る';
      el.focusExit.dataset.alert = d.severity >= 2 ? 'true' : 'false';
    }

    const diagnostic = {
      inbound: {
        label: '搬入口に荷物がたまっている',
        detail: `未処理 ${c.inbound}箱 / 上限${sim.inboundMax()}箱`,
        analysis: '受入側の負荷が高い',
      },
      rack: {
        label: '棚がほぼ満杯',
        detail: `棚を ${c.rack}/${sim.rackCapacity()}箱 使用 · 空き${Math.max(0, sim.rackCapacity() - c.rack)}箱`,
        analysis: '保管工程の負荷が高い',
      },
      orders: {
        label: '注文がたまっている',
        detail: `未処理注文 ${s.ordersOpen}件`,
        analysis: '注文量が処理能力を上回っている',
      },
      packed: {
        label: '出荷待ちがたまっている',
        detail: `出荷待ち ${c.packed}箱`,
        analysis: '梱包後の出荷工程が律速になっている',
      },
    };

    let label = d.label;
    let detail = d.detail;
    let analysis = d.severity === 0 ? '大きなボトルネックは見つかっていない' : d.recommendation;
    if (d.severity > 0 && diagnostic[d.key]) {
      ({ label, detail, analysis } = diagnostic[d.key]);
    } else if (isRank1) {
      label = '安定稼働';
      detail = `Warehouse評価 ${s.logisticsRating}/${nextTarget || 8} · 契約は任意`;
      analysis = '大きなボトルネックは見つかっていない';
    } else if (d.severity === 0) {
      const crew = sim.staffingSummary();
      label = chosenZones < 3 ? `Warehouse設計 · 区画${chosenZones}/3` : 'Warehouse安定運転';
      detail = `人員 入荷${crew.store} / ピック${crew.pick} / 出荷${crew.ship}`;
      analysis = chosenZones < 3 ? '未決定区画があり、物流特性をまだ変えられる' : '現在は大きな律速が見つかっていない';
    }
    el.directorLabel.textContent = label;
    el.directorDetail.textContent = detail;
    el.directorRecommendation.textContent = `分析: ${analysis}`;
    el.severityBadge.textContent = d.severity === 0 ? '安定' : d.severity === 1 ? '注意' : d.severity === 2 ? '混雑' : '詰まり';
    el.severityBadge.dataset.level = String(d.severity);

    policyButtons.forEach((button) => button.classList.toggle('active', button.dataset.policy === s.policy));
    speedButtons.forEach((button) => button.classList.toggle('active', Number(button.dataset.speed) === s.timeScale));
    el.quickSpeed.textContent = s.timeScale === 0 ? 'Ⅱ' : `${s.timeScale}×`;

    const crew = sim.staffingSummary();
    const weaknessNames = { inbound: '荷受け', rack: '保管', orders: '注文処理', packed: '出荷口', stable: 'なし' };
    const readiness = sim.fulfillmentReadiness();
    if (el.opsCrew) el.opsCrew.textContent = s.facilityRank >= 2 ? `人員 ${crew.store}·${crew.pick}·${crew.ship}` : '人員 方針運転';
    if (el.opsWeakness) el.opsWeakness.textContent = `弱点 ${weaknessNames[d.key] || d.label}`;
    if (el.opsNext) el.opsNext.textContent = s.facilityRank >= 2 ? `NEXT ${readiness.score}/3` : `NEXT RANK 2`;
    if (el.goalZones) el.goalZones.textContent = `区画 ${readiness.zones}/3`;
    if (el.goalContracts) el.goalContracts.textContent = `契約 ${Math.min(s.completedContracts, 8)}/8`;
    if (el.goalThroughput) el.goalThroughput.textContent = `出荷 ${Math.min(s.metrics.perMinute, 6)}/6分`;
    if (el.nextStageBar) el.nextStageBar.style.width = `${(readiness.score / 3) * 100}%`;
    if (el.nextStageHint) el.nextStageHint.textContent = readiness.ready ? '自動化設計の準備完了 · 次は設備投資へ' : '3条件を満たすと自動化設計の準備完了';

    const impact = sim.decisionImpact();
    if (el.facilityImpact) {
      el.facilityImpact.hidden = !impact;
      if (impact) {
        if (!impact.ready) {
          el.facilityImpact.textContent = `${impact.label}の効果を観測中… ${Math.min(20, Math.floor(impact.elapsed))}/20秒`;
        } else {
          const signed = (n, suffix = '') => `${n > 0 ? '+' : ''}${n}${suffix}`;
          el.facilityImpact.innerHTML = `<strong>${impact.label} · 実測</strong><span>出荷 ${signed(impact.delta.throughput, '/分')}</span><span>棚使用 ${signed(impact.delta.rackPoints, 'pt')}</span><span>入荷待ち ${signed(impact.delta.inbound, '箱')}</span><span>注文 ${signed(impact.delta.orders, '件')}</span>`;
        }
      }
    }

    el.crewStore.textContent = String(crew.store);
    el.crewPick.textContent = String(crew.pick);
    el.crewShip.textContent = String(crew.ship);
    el.staffingLock.textContent = s.facilityRank < 2 ? 'Rank 2で解禁' : s.staffingCooldown > 0 ? `配置替え ${Math.ceil(s.staffingCooldown)}秒` : '変更可能';
    staffingPlanButtons.forEach((button) => {
      button.classList.toggle('active', button.dataset.staffingPlan === s.staffingPlan);
      button.disabled = s.facilityRank < 2 || s.staffingCooldown > 0;
    });

    facilityButtons.forEach((button) => {
      const type = button.dataset.facility;
      const def = sim.facilityInfo[type];
      const built = Boolean(s.facilities[type]);
      const locked = s.facilityRank < def.rank;
      const selectedInGroup = def.group ? Object.keys(sim.facilityInfo).find((key) => sim.facilityInfo[key].group === def.group && s.facilities[key]) : null;
      const conflicting = Boolean(selectedInGroup && selectedInGroup !== type);
      const costNode = button.querySelector('[data-facility-cost]');
      button.classList.toggle('built', built);
      button.classList.toggle('locked', locked);
      button.classList.toggle('chosenOther', conflicting);
      button.disabled = built || locked || conflicting || (!built && s.money < def.cost);
      if (costNode) costNode.textContent = built ? '建設済み' : locked ? `RANK ${def.rank}` : conflicting ? '方針選択済み' : yen(def.cost);
      button.title = def.desc;
    });

    upgradeButtons.forEach((button) => {
      const type = button.dataset.upgrade;
      const def = sim.upgradeInfo[type];
      const level = s.upgrades[type];
      const maxed = level >= def.max;
      const cost = sim.upgradeCost(type);
      const levelNode = button.querySelector('[data-level]');
      const costNode = button.querySelector('[data-cost]');
      if (levelNode) levelNode.textContent = def.max === 1 ? (level ? '解禁済み' : '未研究') : `Lv.${level}/${def.max}`;
      if (costNode) costNode.textContent = maxed ? 'MAX' : yen(cost);
      button.disabled = maxed || (!maxed && s.money < cost);
    });

    perkButtons.forEach((button) => {
      const type = button.dataset.perk;
      const def = sim.perkInfo[type];
      const level = s.perks[type];
      const maxed = level >= def.max;
      const cost = sim.perkCost(type);
      const levelNode = button.querySelector('[data-level]');
      const costNode = button.querySelector('[data-cost]');
      if (levelNode) levelNode.textContent = def.max === 1 ? (level ? '解禁済み' : '未研究') : `Lv.${level}/${def.max}`;
      if (costNode) costNode.textContent = maxed ? 'MAX' : `${cost} RP`;
      button.disabled = maxed || (!maxed && s.research < cost);
      button.title = def.desc;
    });

    renderContracts();
    updateInsightToggle();
  }

  setInsightCompact(true);
  setDockCompact(true);
  render();
  return { render, toast };
}
