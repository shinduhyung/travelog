// One Leonardo generation, run in the Leonardo tab: set window.LEO_PROMPT first, then run this file.
// Guards (all must hold, else nothing is clicked): model gpt-image-2, quality LOW, 1:1, SMALL (1024x1024),
// quantity 1, 6 reference images, Generate button reads exactly "Generate 8". After the click it waits for the
// credit balance to drop and a new image to appear; a drop other than 8 returns "STOP: ..." so the caller halts.
// Returns {ok, url, before, after} or a string starting with "STOP:" / "WAIT:".
await (async () => {  // top-level await: the javascript tool returns the result, not a pending promise
  // The prompt box and Generate button are only rendered while the feed is scrolled to the top.
  document.querySelectorAll('*').forEach(el => { if (el.scrollTop > 0) el.scrollTop = 0; });
  window.scrollTo(0, 0);
  await new Promise(r => setTimeout(r, 1500));
  const q = new URL(location.href).searchParams;
  const bad = [];
  if (q.get('model') !== 'gpt-image-2') bad.push('model ' + q.get('model'));
  if (q.get('quality') !== 'LOW') bad.push('quality ' + q.get('quality'));
  if (q.get('aspectRatio') !== '1:1') bad.push('ratio ' + q.get('aspectRatio'));
  if (q.get('size') !== 'SMALL') bad.push('size ' + q.get('size'));
  if (q.get('quantity') !== '1') bad.push('quantity ' + q.get('quantity'));
  if (document.querySelectorAll('img[alt^="Image Reference "][alt$=" thumbnail"]').length !== 6) bad.push('refs');
  if (bad.length) return 'STOP: settings ' + bad.join(', ');
  const credits = () => +((document.body.innerText.match(/AI Creation[\s\S]{0,40}?([\d,]{3,7})/) || [])[1] || '0').replace(/,/g, '');
  const imgs = () => [...document.querySelectorAll('img')].map(i => i.src.split('?')[0])
    .filter(s => /cdn\.leonardo\.ai\/users\/.*\/generations\//.test(s));
  const ta = document.querySelector('textarea');
  if (!ta || !window.LEO_PROMPT) return 'STOP: no prompt box or LEO_PROMPT';
  Object.getOwnPropertyDescriptor(HTMLTextAreaElement.prototype, 'value').set.call(ta, window.LEO_PROMPT);
  ta.dispatchEvent(new Event('input', {bubbles: true}));
  await new Promise(r => setTimeout(r, 800));
  if (ta.value !== window.LEO_PROMPT) return 'STOP: prompt not set';
  // The button can take a few seconds to re-render after the prompt changes; wait up to 10 s before judging it.
  let btn, label = '';
  for (let i = 0; i < 20 && label !== 'Generate 8'; i++) {
    btn = [...document.querySelectorAll('button')].find(b => /^\s*Generate/.test(b.innerText));
    label = btn ? btn.innerText.replace(/\s+/g, ' ').trim() : '';
    if (label !== 'Generate 8') await new Promise(r => setTimeout(r, 500));
  }
  if (label !== 'Generate 8') return 'STOP: button reads "' + label + '"';
  if (btn.disabled) return 'WAIT: button disabled';
  const before = credits(), seen = new Set(imgs());
  btn.click();
  for (let i = 0; i < 90; i++) {
    await new Promise(r => setTimeout(r, 2000));
    const fresh = imgs().find(s => !seen.has(s));
    const after = credits();
    if (fresh && after !== before) {
      if (before - after !== 8) return 'STOP: credits dropped by ' + (before - after);
      return {ok: true, url: fresh, before, after};
    }
  }
  return 'WAIT: no new image after 180 s (before ' + before + ', now ' + credits() + ')';
})();
