// Quality gate for the resume site. Plain node + playwright (no test runner).
// Run: node tests/quality.spec.js   (needs `playwright` and its Chromium)
const http = require('http'), fs = require('fs'), path = require('path');
const { chromium } = require('playwright');
const ROOT = path.resolve(__dirname, '..'), OUT = path.join(__dirname, 'screenshots');
// shortcut: dashes already on the page are Alan's to rule (CLAUDE.md rule 5); fail only if the count grows. Set to 0 once he rules.
const DASH_BASELINE = 12;
const TYPES = { '.html': 'text/html', '.json': 'application/json', '.txt': 'text/plain' };
const results = [], seen = {};
const check = async (name, fn) => {
  try { const note = await fn(); results.push([name, 'PASS', note || '']); }
  catch (e) { results.push([name, 'FAIL', e.message]); }
};

const server = http.createServer((q, r) => {
  const u = q.url.split('?')[0];
  const f = path.join(ROOT, u === '/' ? 'index.html' : decodeURI(u));
  if (!f.startsWith(ROOT) || !fs.existsSync(f) || fs.statSync(f).isDirectory()) { r.writeHead(404); return r.end(); }
  r.writeHead(200, { 'content-type': TYPES[path.extname(f)] || 'application/octet-stream' }); fs.createReadStream(f).pipe(r);
});

(async () => {
  await new Promise(r => server.listen(0, '127.0.0.1', r));
  const base = `http://127.0.0.1:${server.address().port}`;
  const browser = await chromium.launch();
  fs.mkdirSync(OUT, { recursive: true });
  const errors = [];
  const ctx = await browser.newContext({ viewport: { width: 390, height: 844 }, hasTouch: true });
  const page = await ctx.newPage();
  page.on('console', m => { if (m.type() === 'error') errors.push(m.text()); });
  page.on('pageerror', e => errors.push(String(e)));
  await page.goto(base, { waitUntil: 'networkidle' });

  await check('page loads, no console errors', () => {
    // shortcut: ignore blocked-resource noise only (offline font host), not script errors
    const real = errors.filter(e => !/ERR_(NAME_NOT_RESOLVED|INTERNET_DISCONNECTED|BLOCKED)|Failed to load resource/.test(e));
    if (real.length) throw new Error(real.join(' | '));
    return errors.length ? `${errors.length} network-only error(s) ignored` : '';
  });

  await check('no horizontal scroll at 390px', async () => {
    const [sw, cw] = await page.evaluate(() => [document.documentElement.scrollWidth, document.documentElement.clientWidth]);
    if (sw > cw) throw new Error(`scrollWidth ${sw} > ${cw}`);
  });

  await check('tap targets at least 44px', async () => {
    const bad = await page.evaluate(() => [...document.querySelectorAll('a[href],button,input,select,summary')].flatMap(el => {
      const b = el.getBoundingClientRect(); if (!b.width && !b.height) return [];
      return b.width < 44 || b.height < 44 ? [`${(el.textContent || el.href).trim().slice(0, 30)} ${Math.round(b.width)}x${Math.round(b.height)}`] : [];
    }));
    if (bad.length) throw new Error(`${bad.length} under 44px: ${bad.join('; ')}`);
  });

  for (const scheme of ['light', 'dark']) {
    await check(`${scheme} mode renders`, async () => {
      const p = await ctx.newPage(); await p.emulateMedia({ colorScheme: scheme });
      await p.goto(base, { waitUntil: 'networkidle' });
      await p.screenshot({ path: path.join(OUT, `${scheme}.png`), fullPage: true });
      const bg = await p.evaluate(() => getComputedStyle(document.body).backgroundColor);
      const text = await p.evaluate(() => document.body.innerText.length);
      await p.close(); if (text < 500) throw new Error('page nearly empty');
      seen[scheme] = bg;
      return `body bg ${bg}` + (scheme === 'dark' && seen.light === bg ? ' (NOTE: same as light, site has no dark styles)' : '');
    });
  }

  await check('no em or en dashes in visible text (ratchet)', async () => {
    const hits = await page.evaluate(() => (document.body.innerText.match(/[^\n]*[–—][^\n]*/g) || []));
    if (hits.length > DASH_BASELINE) throw new Error(`${hits.length} lines > baseline ${DASH_BASELINE}: ${hits.slice(0, 3).join(' / ')}`);
    return `${hits.length} lines with dashes (baseline ${DASH_BASELINE})`;
  });

  await check('links under 400 (external soft-fail)', async () => {
    const hrefs = await page.evaluate(() => [...new Set([...document.querySelectorAll('a[href]')].map(a => a.href))]);
    const soft = [], hard = [];
    for (const h of hrefs) {
      if (/^(mailto|tel):/.test(h)) continue;
      const internal = h.startsWith(base);
      try {
        const r = await fetch(h, { redirect: 'follow', signal: AbortSignal.timeout(15000), headers: { 'user-agent': 'Mozilla/5.0 resume-quality-gate' } });
        if (r.status >= 400) (internal ? hard : soft).push(`${h} ${r.status}`);
      } catch (e) { (internal ? hard : soft).push(`${h} ${e.message}`); }
    }
    if (hard.length) throw new Error(hard.join('; '));
    return soft.length ? `SOFT-FAIL external: ${soft.join('; ')}` : `${hrefs.length} links ok`;
  });

  await check('resume.json valid and name/title match index.html', async () => {
    const j = JSON.parse(fs.readFileSync(path.join(ROOT, 'resume.json'), 'utf8')).basics;
    const html = await page.evaluate(() => document.body.innerText.replace(/\s+/g, ' '));
    for (const k of ['name', 'label']) if (!html.includes(j[k])) throw new Error(`"${j[k]}" (${k}) not on page`);
  });

  await check('llms.txt exists', () => { if (fs.statSync(path.join(ROOT, 'llms.txt')).size < 50) throw new Error('empty'); });

  await check('print is at most 2 Letter pages', async () => {
    const p = await ctx.newPage(); await p.goto(base, { waitUntil: 'networkidle' }); await p.emulateMedia({ media: 'print' });
    const pdf = await p.pdf({ format: 'Letter', printBackground: true }); await p.close();
    const n = (pdf.toString('latin1').match(/\/Type\s*\/Page[^s]/g) || []).length;
    if (n > 2) throw new Error(`${n} pages`);
    return `${n} page(s)`;
  });

  await browser.close(); server.close();
  for (const [n, s, note] of results) console.log(`${s}  ${n}${note ? '  :: ' + note : ''}`);
  process.exit(results.some(r => r[1] === 'FAIL') ? 1 : 0);
})();
