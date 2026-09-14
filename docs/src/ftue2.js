const app = document.getElementById('app');
const guide = document.getElementById('rank1Guide');
const guideTitle = document.getElementById('rank1GuideTitle');
const guideDetail = document.getElementById('rank1GuideDetail');
const guideButton = document.getElementById('rank1GuideButton');
const facilityRank = document.getElementById('facilityRank');
const logisticsRating = document.getElementById('logisticsRating');
const contractTitle = document.getElementById('contractTitle');
const contractBody = document.getElementById('contractBody');
const insightToggle = document.getElementById('insightToggle');
const directorAction = document.getElementById('directorAction');
const severityBadge = document.getElementById('severityBadge');
const quickSpeed = document.getElementById('quickSpeedBtn');

let scheduled = false;
let autoPausedForFirstContract = false;
let guideTarget = 'none';

function scheduleSync() {
  if (scheduled) return;
  scheduled = true;
  requestAnimationFrame(() => {
    scheduled = false;
    sync();
  });
}

function ratingProgress() {
  const text = logisticsRating?.textContent || '';
  const match = text.match(/(\d+)\s*\/\s*(\d+)/);
  return match ? { current: Number(match[1]), target: Number(match[2]) } : { current: 0, target: 8 };
}

function clickSpeed(value) {
  const button = document.querySelector(`[data-speed="${value}"]`);
  button?.click();
}

function setGuide(title, detail, buttonLabel = '', target = 'none', tone = 'normal') {
  if (!guide) return;
  guideTitle.textContent = title;
  guideDetail.textContent = detail;
  guideButton.hidden = !buttonLabel;
  guideButton.textContent = buttonLabel;
  guideTarget = target;
  guide.dataset.tone = tone;
}

function sync() {
  if (!app || !facilityRank || !logisticsRating || !guide) return;

  const isRank1 = facilityRank.textContent.trim().startsWith('RANK 1');
  app.classList.toggle('rank1Ftue', isRank1);
  guide.hidden = !isRank1;
  if (!isRank1) return;

  const progress = ratingProgress();
  const desiredProgress = `Warehouse昇格 ${progress.current} / ${progress.target}`;
  if (logisticsRating.textContent !== desiredProgress) logisticsRating.textContent = desiredProgress;

  const activeContract = Boolean(contractBody?.querySelector('.contractProgress'));
  const hasOffers = /契約を選ぶ/.test(contractTitle?.textContent || '');
  const severity = severityBadge?.textContent?.trim() || '';
  const hasProblem = ['注意', '混雑', '詰まり'].includes(severity);
  const actionVisible = directorAction && !directorAction.hidden;

  if (progress.current === 0 && !activeContract && hasOffers && !autoPausedForFirstContract) {
    if ((quickSpeed?.textContent || '').trim() !== 'Ⅱ') clickSpeed(0);
    autoPausedForFirstContract = true;
  }

  if (activeContract && autoPausedForFirstContract) {
    if ((quickSpeed?.textContent || '').trim() === 'Ⅱ') clickSpeed(1);
    autoPausedForFirstContract = false;
  }

  if (!activeContract && hasOffers) {
    setGuide('今やること：契約を1つ選ぶ', `契約達成でWarehouse昇格が進む · ${progress.current}/${progress.target}`, '契約を見る', 'contract');
    return;
  }

  if (activeContract && hasProblem && actionVisible) {
    const label = directorAction.textContent.trim() || '方針を変える';
    setGuide(`今やること：${label}`, '詰まりを解消したら、また自動運転を観察する', label, 'director', 'warn');
    return;
  }

  if (activeContract) {
    setGuide('今やること：倉庫を観察する', `自動で処理中 · 赤い「詰まり」が出た時だけ対処する · 昇格 ${progress.current}/${progress.target}`);
    return;
  }

  setGuide('今やること：次の契約を待つ', `Warehouse昇格 ${progress.current}/${progress.target} · 準備できたら契約を選ぶ`);
}

guideButton?.addEventListener('click', () => {
  if (guideTarget === 'director') {
    directorAction?.click();
    return;
  }
  if (guideTarget === 'contract') {
    if (insightToggle?.getAttribute('aria-expanded') === 'false') insightToggle.click();
    document.querySelector('.contractArea')?.scrollIntoView?.({ behavior: 'smooth', block: 'nearest' });
  }
});

const observer = new MutationObserver(scheduleSync);
observer.observe(app, { subtree: true, childList: true, characterData: true, attributes: true, attributeFilter: ['class', 'hidden', 'aria-expanded'] });
window.addEventListener('load', scheduleSync, { once: true });
scheduleSync();
