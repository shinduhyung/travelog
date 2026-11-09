"""Drive the debug app over adb: reach each inventory entry in English, then
check it in every language for RenderFlex overflow and untranslated text.

usage: python -I tool/l10n/overflow_audit/drive.py [--only id,id] [--langs de,id] [--retry] [--shard 0/4]
Results are appended to results.jsonl; entries already there are skipped
(--retry re-runs entries whose navigation failed or that had overflows).
"""
import argparse, html, json, os, re, subprocess, sys, time

sys.stdout.reconfigure(encoding='utf-8')
HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, '..', '..', '..'))
DEVICE = os.environ.get('AUDIT_DEVICE', '192.168.0.6:5555')
PKG = 'com.ahnlee.jidoapp'
RESULTS = os.path.join(HERE, 'results.jsonl')
CALIB = os.path.join(HERE, 'calib.json')
SHOTS = os.path.join(REPO, 'build', 'overflow_audit')
SCROLL_PAGES = 4
# Widest scripts and longest translations first; the rest run on high-risk entries.
TIER1 = ['el', 'fr', 'de', 'id', 'ru', 'vi', 'th', 'ar']
RISK_ORDER = {'high': 0, 'medium': 1, 'low': 2}

ap = argparse.ArgumentParser()
ap.add_argument('--only')
ap.add_argument('--langs')
ap.add_argument('--retry', action='store_true')
ap.add_argument('--tier', type=int, choices=[1, 2], default=1)
ap.add_argument('--all', action='store_true', help='tier 2 on every entry, not only high risk')
ap.add_argument('--shard', help='i/n: this device takes every n-th entry starting at i (devices via AUDIT_DEVICE)')
args = ap.parse_args()

manifest = json.load(open(os.path.join(REPO, 'build/l10n/languages.json'), encoding='utf-8'))
LANGS = [e for e in manifest['languages'] if e['code'] != 'en']
# Pseudo-language: the widest translation of each string (make_max.py).
MAX = {'code': 'max', 'path': os.path.join(REPO, 'build/overflow_audit/max.json')}
if args.langs:
    wanted = args.langs.split(',')
    LANGS = ([MAX] if 'max' in wanted else []) + [e for e in LANGS if e['code'] in wanted]
elif args.tier == 1:
    LANGS = sorted((e for e in LANGS if e['code'] in TIER1), key=lambda e: TIER1.index(e['code']))
else:
    LANGS = [e for e in LANGS if e['code'] not in TIER1]
# Tier 3 = the max/ar/th screening pass; other --langs runs are tier 0.
TIER = (3 if 'max' in args.langs.split(',') else 0) if args.langs else args.tier
os.makedirs(SHOTS, exist_ok=True)


def adb(*a, timeout=60):
    try:
        return subprocess.run(['adb', '-s', DEVICE, *a], capture_output=True, text=True,
                              encoding='utf-8', errors='replace', timeout=timeout).stdout
    except subprocess.TimeoutExpired:
        return ''


def run_as(cmd):
    return adb('shell', f"run-as {PKG} sh -c '{cmd}'")


# ---------- catalogs (short UI strings only, to keep memory small) ----------
_catalogs = {}


def catalog(code):
    if code not in _catalogs:
        entry = next(e for e in LANGS if e['code'] == code)
        data = json.load(open(entry.get('path') or os.path.join(REPO, 'build/l10n', entry['file']),
                              encoding='utf-8'))
        msgs = {k: v for k, v in data['messages'].items() if len(k) <= 120}
        _catalogs[code] = (msgs, set(msgs.values()) | set(data.get('countries', {}).values()))
    return _catalogs[code]


# ---------- screen reading ----------
NODE = re.compile(r'<node [^>]*>')
ATTR = re.compile(r'(\w[\w-]*)="([^"]*)"')


def nodes():
    adb('shell', 'uiautomator', 'dump', '/sdcard/u.xml')
    xml = adb('shell', 'cat', '/sdcard/u.xml')
    out = []
    for m in NODE.finditer(xml):
        a = dict(ATTR.findall(m.group(0)))
        label = (html.unescape(a.get('text') or '') or html.unescape(a.get('content-desc') or '')
                 or html.unescape(a.get('hint') or ''))
        b = re.findall(r'\d+', a.get('bounds', ''))
        if len(b) == 4:
            x1, y1, x2, y2 = map(int, b)
            out.append({'label': label, 'lines': [l.strip() for l in label.split('\n') if l.strip()],
                        'xy': ((x1 + x2) // 2, (y1 + y2) // 2), 'area': (x2 - x1) * (y2 - y1),
                        'w': x2 - x1, 'h': y2 - y1,
                        'click': a.get('clickable') == 'true',
                        'scroll': a.get('scrollable') == 'true'})
    return out


def find(target, contains=False):
    found = nodes()
    best = None
    for n in found:
        hit = any((target in l) if contains else (l == target) for l in n['lines'])
        if hit and (best is None or n['area'] < best['area']):
            best = n
    if best is None and not contains:
        # Flutter often merges a header into one label ("Next Adventure"):
        # fall back to a whole-word match.
        word = re.compile(r'(?<!\w)' + re.escape(target) + r'(?!\w)')
        for n in found:
            if any(word.search(l) for l in n['lines']) and (best is None or n['area'] < best['area']):
                best = n
    if best is None and not contains:
        low = target.lower()
        for n in found:
            if any(l.lower() == low for l in n['lines']) and (best is None or n['area'] < best['area']):
                best = n
    return best


def find_sideways(target, contains):
    """Looks inside horizontal rows (category chips, continent tabs) on the
    current page by swiping each wide, short scrollable left."""
    rows = [n for n in nodes() if n['scroll'] and n['w'] >= 600 and n['h'] < 700]
    for row in rows:
        x, y = row['xy']
        for _ in range(5):
            adb('shell', 'input', 'swipe', '950', str(y), '150', str(y), '300')
            time.sleep(0.7)
            n = find(target, contains)
            if n:
                return n
    return None


def tap(xy):
    adb('shell', 'input', 'tap', str(xy[0]), str(xy[1]))
    time.sleep(2.0)


def swipe_up(fast=False):
    adb('shell', 'input', 'swipe', '540', '1750', '540', '650', '150' if fast else '250')
    time.sleep(0.5 if fast else 0.8)


def swipe_down(fast=True):
    adb('shell', 'input', 'swipe', '540', '650', '540', '1750', '150' if fast else '250')
    time.sleep(0.5 if fast else 0.8)


# ---------- app control ----------
def logcat_clear():
    adb('logcat', '-c')


def logcat():
    return adb('logcat', '-d', '-s', 'flutter:*')


def set_language(code, timeout=25):
    logcat_clear()
    run_as(f'echo {code} > files/l10n_audit_cmd')
    end = time.time() + timeout
    while time.time() < end:
        if f'[AUDIT] ready {code}' in logcat():
            return True
        time.sleep(0.7)
    return False


def wait_until_usable():
    """Waits while the phone is locked; the audit never unlocks it."""
    warned = False
    while True:
        if 'mWakefulness=Awake' not in adb('shell', 'dumpsys', 'power'):
            adb('shell', 'input', 'keyevent', 'KEYCODE_WAKEUP')
            time.sleep(1.5)
        if 'isKeyguardShowing=true' not in adb('shell', 'dumpsys', 'window'):
            return
        if not warned:
            print('!! phone is locked - unlock it to continue', flush=True)
            warned = True
        time.sleep(10)


def app_in_front():
    return PKG in adb('shell', 'dumpsys', 'activity', 'activities').split('topResumedActivity', 1)[-1][:300]


def restart():
    wait_until_usable()
    adb('shell', 'am', 'force-stop', PKG)
    logcat_clear()
    adb('shell', 'monkey', '-p', PKG, '-c', 'android.intent.category.LAUNCHER', '1')
    # The saved language may be anything; switching to English proves the app is up.
    time.sleep(5)
    if not set_language('en', timeout=50):
        return False
    end = time.time() + 20
    while time.time() < end:
        if find('My Trips') or find('Countries'):
            return True
        time.sleep(2)
    return False


TAB_X = {'My Trips': 150, 'Countries': 360, 'Cities': 555, 'Explore': 748, 'Flights': 940}
calib = json.load(open(CALIB, encoding='utf-8')) if os.path.exists(CALIB) else {}


BASIC_STEPS = ('tab', 'tap', 'tap_contains', 'scroll_to', 'back', 'swipe_tab', 'type_text')


NAV_LABELS = set(TAB_X)
QUOTED = re.compile(r"'([^']{2,40})'")


def desc_kind(step):
    """Which heuristic can resolve an icon-only step, or None."""
    if 'tap_first_list_item' in step:
        return 'first'
    d = (step.get('tap_desc') or '').lower()
    if 'fab' in d or 'floating' in d:
        return 'fab'
    if 'appbar' in d and ('menu' in d or 'icon' in d or 'button' in d):
        return 'appbar'
    if QUOTED.search(step.get('tap_desc') or '') and any(
            w in d for w in ('right of', 'next to', 'beside', 'header', 'under ', 'left of')):
        return 'anchored'
    return None


def resolve_desc(step):
    kind = desc_kind(step)
    ns = nodes()
    blank = [n for n in ns if n['click'] and not n['lines'] and n['area'] < 300 * 300]
    if kind == 'fab':
        c = [n for n in blank if n['xy'][0] > 780 and 1450 < n['xy'][1] < 2250]
        return max(c, key=lambda n: n['xy'][1])['xy'] if c else None
    if kind == 'appbar':
        c = [n for n in blank if n['xy'][1] < 380]
        return max(c, key=lambda n: n['xy'][0])['xy'] if c else None
    if kind == 'first':
        # List rows/cards: wide and tall, never a dropdown or filter pill.
        c = [n for n in ns if n['click'] and n['lines'] and 400 < n['xy'][1] < 1950
             and n['w'] >= 700 and n['h'] >= 150 and n['area'] < 1080 * 900
             and not (set(n['lines']) & NAV_LABELS)]
        return min(c, key=lambda n: n['xy'][1])['xy'] if c else None
    if kind == 'anchored':
        desc = step['tap_desc']
        label = QUOTED.search(desc).group(1)
        anchor = next((n for n in ns if label in n['lines']), None) or next(
            (n for n in ns if any(label in l for l in n['lines'])), None)
        if anchor is None:
            return None
        ax, ay = anchor['xy']
        if 'under ' in desc.lower():
            c = [n for n in blank + [n for n in ns if n['click'] and n is not anchor]
                 if ay < n['xy'][1] < ay + 260]
            return min(c, key=lambda n: n['xy'][1] - ay)['xy'] if c else None
        left = 'left of' in desc.lower()
        c = [n for n in blank if abs(n['xy'][1] - ay) < 90 and (n['xy'][0] < ax if left else n['xy'][0] > ax)]
        return min(c, key=lambda n: abs(n['xy'][0] - ax))['xy'] if c else None
    return None


def step_ready(entry, step):
    plain = json.dumps(step, ensure_ascii=False)
    return (any(k in step for k in BASIC_STEPS) or plain in calib
            or f"{entry['id']}::{plain}" in calib or desc_kind(step) is not None)


def do_step(entry, step):
    """Returns None on success, else a failure description."""
    # calib.json maps a step (as JSON) or "<entry id>::<step>" to tap coordinates.
    plain = json.dumps(step, ensure_ascii=False)
    for key in (f"{entry['id']}::{plain}", plain):
        if key in calib:
            tap(calib[key])
            return None
    if 'tab' in step:
        tap((TAB_X[step['tab']], 2080))
        return None
    if step.get('back'):
        adb('shell', 'input', 'keyevent', '4')
        time.sleep(1.5)
        return None
    if 'type_text' in step:
        # Types into the focused field (search boxes only; never forms that save data).
        adb('shell', 'input', 'text', step['type_text'].replace(' ', '%s'))
        time.sleep(2.5)
        return None
    if 'swipe_tab' in step:
        adb('shell', 'input', 'swipe', '900', '1200', '150', '1200', '250')
        time.sleep(1.5)
        return None
    if desc_kind(step):
        for attempt in range(4):
            xy = resolve_desc(step)
            if xy:
                tap(xy)
                return None
            swipe_up()
        return f'unresolved: {step}'
    target = step.get('tap') or step.get('tap_contains') or step.get('scroll_to')
    if target is None:
        return f'uncalibrated step {step}'
    contains = 'tap_contains' in step
    for attempt in range(8):
        n = find(target, contains)
        if n:
            if 'scroll_to' not in step:
                tap(n['xy'])
            return None
        swipe_up()
    # Not in the vertical list: back to the top, then try horizontal rows page by page.
    for _ in range(8):
        swipe_down()
    for attempt in range(6):
        n = find(target, contains) or find_sideways(target, contains)
        if n:
            if 'scroll_to' not in step:
                tap(n['xy'])
            return None
        swipe_up()
    return f'not found: {target}'


def overflow_lines(log):
    out = []
    for line in log.splitlines():
        i = line.find('[OVERFLOW]')
        if i >= 0:
            out.append(line[i + 11:].strip())
    return out


def check_language(entry, code, scroll, read_text, forward=True):
    """Checks one language. Scrollable screens are swept top→bottom or
    bottom→top (alternating per language), so no sweep back is needed."""
    if not app_in_front():
        return {'error': 'app not in front'}
    if not set_language(code, timeout=60 if code == 'max' else 25):
        return {'error': 'language switch timeout'}
    msgs, values = catalog(code)
    untranslated = set()
    for n in (nodes() if read_text else []):
        for l in n['lines']:
            if l not in values and l in msgs and msgs[l] != l:
                untranslated.add(l)
    for _ in range(SCROLL_PAGES if scroll else 0):
        swipe_up() if forward else swipe_down(fast=False)
    overflows = sorted(set(overflow_lines(logcat())))
    if overflows:
        adb('shell', 'screencap', '-p', '/sdcard/s.png')
        adb('pull', '/sdcard/s.png', os.path.join(SHOTS, f"{entry['id']}__{code}.png"))
    return {'overflow': overflows, 'untranslated': sorted(untranslated)}


def load_inventory():
    entries = []
    for name in sorted(os.listdir(HERE)):
        if name.startswith('screens') and name.endswith('.json'):
            entries += json.load(open(os.path.join(HERE, name), encoding='utf-8'))
    return entries


def done_ids():
    done = {}
    if os.path.exists(RESULTS):
        for line in open(RESULTS, encoding='utf-8'):
            r = json.loads(line)
            done[(r['id'], r.get('tier', 0))] = r
    return done


def needs_retry(r):
    return not r.get('nav_ok') or any(v.get('overflow') for v in r.get('langs', {}).values())


def push_max():
    adb('push', MAX['path'], '/data/local/tmp/l10n_audit_max.json', timeout=300)
    run_as('cp /data/local/tmp/l10n_audit_max.json files/l10n_audit_max.json')
    adb('shell', 'rm', '/data/local/tmp/l10n_audit_max.json')


def main():
    if MAX in LANGS:
        push_max()
    entries = load_inventory()
    if args.only:
        wanted = set(args.only.split(','))
        entries = [e for e in entries if e['id'] in wanted]
    done = done_ids()
    def is_done(e):
        r = done.get((e['id'], TIER)) or done.get((e['id'], 0))
        return r is not None and not (args.retry and needs_retry(r))
    todo = [e for e in entries if args.only or not is_done(e)]
    if TIER == 2 and not args.all:
        todo = [e for e in todo if e.get('risk') == 'high']
    seen = set()
    todo = [e for e in todo if not (e['id'] in seen or seen.add(e['id']))]
    # Entries whose navigation failed before, or that rely on icon descriptions,
    # go last so a run produces real results first.
    def failed_before(e):
        r = done.get((e['id'], TIER)) or done.get((e['id'], 0))
        return r is not None and not r.get('nav_ok')
    todo.sort(key=lambda e: (failed_before(e), any('tap_desc' in st for st in e.get('path', [])),
                             RISK_ORDER.get(e.get('risk'), 1)))
    todo = [e for e in todo if e.get('path') and not e.get('unsafe')]
    ready = [e for e in todo if all(step_ready(e, st) for st in e['path'])]
    print(f'{len(todo) - len(ready)} entries wait for calibration (calib.json)', flush=True)
    todo = ready
    if args.shard:
        i, n = map(int, args.shard.split('/'))
        todo = todo[i::n]
    print(f'{len(todo)} entries to check, {len(LANGS)} languages', flush=True)
    for i, entry in enumerate(todo, 1):
        started = time.time()
        result = {'id': entry['id'], 'tier': TIER, 'file': entry.get('file'), 'nav_ok': False, 'langs': {}}
        if restart() and set_language('en'):
            fail = None
            for step in entry['path']:
                fail = do_step(entry, step)
                if fail:
                    break
            result['nav_fail'] = fail
            result['nav_ok'] = fail is None
            if fail is None:
                for n, lang in enumerate(LANGS):
                    result['langs'][lang['code']] = check_language(
                        entry, lang['code'], entry.get('scroll'), read_text=n == 0,
                        forward=n % 2 == 0)
        else:
            result['nav_fail'] = 'app did not start'
        result['secs'] = round(time.time() - started)
        with open(RESULTS, 'a', encoding='utf-8') as f:
            f.write(json.dumps(result, ensure_ascii=False) + '\n')
        bad = sorted({o for v in result['langs'].values() for o in v.get('overflow', [])})
        print(f"[{i}/{len(todo)}] {entry['id']}: nav={'ok' if result['nav_ok'] else result.get('nav_fail')}"
              f" overflow={len(bad)} {result['secs']}s", flush=True)


if __name__ == '__main__':
    main()
