import fs from 'node:fs';

const assert = (condition, message) => { if (!condition) throw new Error(message); };
const capital = fs.readFileSync(new URL('../src/capital.js', import.meta.url), 'utf8');
const ergonomics = fs.readFileSync(new URL('../src/ergonomics.js', import.meta.url), 'utf8');
const css = fs.readFileSync(new URL('../capital.css', import.meta.url), 'utf8');

assert(capital.includes('id="capitalUnlockLabel"'), 'capital UI must expose a dedicated equipment unlock progress row');
assert(capital.includes('id="capitalMarketLabel"'), 'capital UI must expose a separate commercial tier progress row');
assert(capital.includes('function nextLockedInvestment(invested)'), 'capital UI must calculate the nearest equipment unlock');
assert(capital.includes('あと ${yen(remaining)}'), 'locked investment cards must show remaining investment');
assert(capital.includes('次の設備解禁 · ${nextUnlock.label}'), 'equipment unlock row must name the next unlock');
assert(capital.includes('次の商圏 · ${nextTier.label}'), 'commercial row must name the next market tier');
assert(capital.includes('設備解禁と商圏拡大は別々の進捗'), 'equipment and commercial progression must be explicitly separated');
assert(ergonomics.includes("dockMini.insertAdjacentElement('afterend', capitalGoals)"), 'capital goals must be promoted out of the scrolling capital panel');
assert(css.includes('.capitalGoals'), 'capital progression must have dedicated layout styles');
assert(css.includes('.capitalGoal[data-goal="market"] u'), 'market progression must have a distinct progress treatment');
assert(css.includes('#commandDock:not(.compact) .capitalGoals{position:sticky'), 'capital goals must remain visible while the management sheet scrolls');
assert(css.includes('#commandDock.compact>.capitalGoals{display:none}'), 'promoted capital goals must hide when the management sheet is compact');
assert(css.includes('top:86px') || css.includes('top:84px'), 'sticky capital goals must sit below the pinned management header');

console.log('Capital progression clarity smoke OK');
