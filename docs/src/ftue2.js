const app = document.getElementById('app');
const guide = document.getElementById('rank1Guide');
const guideTitle = document.getElementById('rank1GuideTitle');
const guideDetail = document.getElementById('rank1GuideDetail');
const guideButton = document.getElementById('rank1GuideButton');
const facilityRank = document.getElementById('facilityRank');
const logisticsRating = document.getElementById('logisticsRating');
const contractTitle = document.getElementById('contractTitle');
const contractBody = document.getElementById('contractBody');
const directorLabel = document.getElementById('directorLabel');
const directorRecommendation = document.getElementById('directorRecommendation');
const directorAction = document.getElementById('directorAction');
const ftueStep = document.getElementById('ftueStep');

let scheduled = false;

function scheduleSync() {
  if (scheduled) return;
  scheduled = true;
  requestAnimationFrame(() => {
    scheduled = false;
    sync();
  });
}

function ratingProgress() {
  const snapshot = window.__logisticsBossFreedom?.snapshot?.();
  if (snapshot) return { current: snapshot.rating, target: 8 };
  const text = logisticsRating?.textContent || '';
  const match = text.match(/(\d+)\s*\/\s*(\d+)/);
  return match ? { current: Number(match[1]), target: Number(match[2]) } : { current: 0, target: 8 };
}

function neutralAnalysis() {
  const label = directorLabel?.textContent || '';
  if (label.includes('搬入口')) return '分析：受入側の負荷が高い';
  if (label.includes('棚')) return '分析：保管工程の負荷が高い';
  if (label.includes('注文')) return '分析：注文量が処理能力を上回っている';
  if (label.includes('出荷待ち')) return '分析：梱包後の出荷工程が律速になっている';
  return '分析：大きなボトルネックは見つかっていない';
}

function setText(node, text) {
  if (node && node.textContent !== text) node.textContent = text;
}

function sync() {
  if (!app || !facilityRank || !logisticsRating || !guide) return;

  const isRank1 = facilityRank.textContent.trim().startsWith('RANK 1');
  app.classList.toggle('rank1Free', isRank1);
  app.classList.remove('rank1Ftue');
  guide.hidden = !isRank1;
  if (!isRank1) return;

  const progress = ratingProgress();
  setText(logisticsRating, `Warehouse評価 ${progress.current} / ${progress.target}`);

  const guideTag = guide.querySelector('small');
  setText(guideTag, 'OPERATIONS');
  setText(guideTitle, `Warehouse評価 ${progress.current} / ${progress.target}`);
  setText(guideDetail, '出荷・処理速度・安定運転・任意契約のどれからでも評価を伸ばせる。運営方針は自由。');
  guideButton.hidden = true;
  guide.dataset.tone = 'normal';

  // Director is an analyst, not an instruction engine.
  if (directorAction) directorAction.hidden = true;
  if (ftueStep) ftueStep.hidden = true;
  setText(directorRecommendation, neutralAnalysis());

  const activeContract = Boolean(contractBody?.querySelector('.contractProgress'));
  if (!activeContract && /契約を選ぶ/.test(contractTitle?.textContent || '')) {
    const count = (contractTitle.textContent.match(/(\d+)件/) || [])[1];
    setText(contractTitle, count ? `任意契約（${count}件）` : '任意契約');
    const desc = contractBody?.querySelector('.contractDesc');
    setText(desc, '追加報酬を狙う場合だけ受注する');
  }
}

const observer = new MutationObserver(scheduleSync);
observer.observe(app, {
  subtree: true,
  childList: true,
  characterData: true,
  attributes: true,
  attributeFilter: ['class', 'hidden', 'aria-expanded'],
});
window.addEventListener('load', scheduleSync, { once: true });
setInterval(scheduleSync, 500);
scheduleSync();
