const assert = require('node:assert/strict');

// A previously cached v0.28 document can request the current app at its old URL.
// It has no estate shortcut. The ordinary menu must still start and run the game.
async function checkCachedShell(browser, url) {
  const context = await browser.newContext({viewport:{width:390,height:844},isMobile:true,hasTouch:true});
  try {
    await context.route(url, async route => {
      const response = await route.fetch();
      const html = (await response.text())
        .replace(/<button id="estate"[\s\S]*?<\/button>/, '')
        .replace(/app\.mjs\?v=[0-9.]+/, 'app.mjs?v=0.28');
      await route.fulfill({response,body:html});
    });
    const page = await context.newPage(), errors = [];
    page.on('pageerror', error => errors.push(error.message));
    await page.goto(url);
    assert.deepEqual(errors, [], 'cached document must not crash startup');
    assert.equal(await page.locator('#estate').count(), 0);
    await page.waitForFunction(() => document.querySelector('#orderAction').onclick !== null);
    await page.getByRole('button', {name:'材料費 ¥600 で受注する',exact:true}).click();
    await page.locator('#controls summary').click();
    await page.getByRole('button', {name:'出荷まで早送り',exact:true}).click();
    await page.waitForFunction(() => document.querySelector('#cash').textContent === '¥7,619');
    await page.getByRole('button', {name:'管理',exact:true}).click();
    await page.getByRole('button', {name:'社長の夢',exact:true}).click();
    await page.getByRole('button', {name:'赤いクーペを買う · ¥6,000',exact:true}).click();
    await page.getByRole('button', {name:'赤いクーペを買う · 所有済み',exact:true}).waitFor();
    await page.reload();
    await page.waitForFunction(() => document.querySelector('#cash').textContent === '¥1,619');
    await page.getByRole('button', {name:'管理',exact:true}).click();
    await page.getByRole('button', {name:'社長の夢',exact:true}).click();
    await page.getByRole('button', {name:'赤いクーペを買う · 所有済み',exact:true}).waitFor();
    assert.deepEqual(errors, []);
    console.log(browser.browserType().name() + ' cached shell passed: start, dispatch, purchase, reload.');
  } finally {await context.close();}
}
module.exports = {checkCachedShell};
