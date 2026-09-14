import fs from 'node:fs';

const assert = (condition, message) => { if (!condition) throw new Error(message); };
const capital = fs.readFileSync(new URL('../src/capital.js', import.meta.url), 'utf8');
const css = fs.readFileSync(new URL('../capital.css', import.meta.url), 'utf8');

assert(capital.includes('id="capitalUnlockLabel"'), 'capital UI must expose a dedicated equipment unlock progress row');
assert(capital.includes('id="capitalMarketLabel"'), 'capital UI must expose a separate commercial tier progress row');
assert(capital.includes('function nextLockedInvestment(invested)'), 'capital UI must calculate the nearest equipment unlock');
assert(capital.includes('あと ${yen(remaining)}'), 'locked investment cards must show remaining investment');
assert(capital.includes('次の設備解禁 · ${nextUnlock.label}'), 'equipment unlock row must name the next unlock');
assert(capital.includes('次の商圏 · ${nextTier.label}'), 'commercial row must name the next market tier');
assert(capital.includes('設備解禁と商圏拡大は別々の進捗'), 'equipment and commercial progression must be explicitly separated');
assert(css.includes('.capitalGoals'), 'capital progression must have dedicated layout styles');
assert(css.includes('.capitalGoal[data-goal="market"] u'), 'market progression must have a distinct progress treatment');

console.log('Capital progression clarity smoke OK');
