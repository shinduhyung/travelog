"""Group overflow results by code location: python -I summary.py [--since N]"""
import collections, json, os, re, sys
sys.stdout.reconfigure(encoding='utf-8')
HERE = os.path.dirname(os.path.abspath(__file__))
locs = collections.defaultdict(lambda: {'langs': set(), 'entries': set(), 'px': 0, 'msg': ''})
nav = collections.Counter(); untrans = collections.defaultdict(set); n = 0
latest = {}
for line in open(os.path.join(HERE, 'results.jsonl'), encoding='utf-8'):
    r = json.loads(line)
    latest[(r['id'], r.get('tier'))] = r  # a retry replaces the earlier result
for r in latest.values():
    n += 1
    if not r.get('nav_ok'):
        nav[(r.get('nav_fail') or '')[:90]] += 1
    for lang, v in r.get('langs', {}).items():
        for o in v.get('overflow', []):
            msg, _, where = o.partition(' @ ')
            # First lib/ frame is the widget that overflowed.
            m = re.search(r'(lib/[\w/]+\.dart):(\d+)', where)
            key = f'{m.group(1)}:{m.group(2)}' if m else where[:120]
            px = re.search(r'by ([\d.]+) pixels', msg)
            L = locs[key]; L['langs'].add(lang); L['entries'].add(r['id']); L['msg'] = msg[:80]
            L['px'] = max(L['px'], float(px.group(1)) if px else 0)
        for u in v.get('untranslated', []):
            untrans[u].add(r['id'])
print(f'{n} results, {sum(1 for _ in nav.elements())} nav failures, {len(locs)} overflow locations')
for k, L in sorted(locs.items(), key=lambda kv: -len(kv[1]['langs'])):
    print(f"{k}  max {L['px']:.0f}px  langs={','.join(sorted(L['langs']))}  e.g. {sorted(L['entries'])[0]}")
print('\nuntranslated:')
for u, ids in sorted(untrans.items()):
    print(f'  {u!r}  ({len(ids)} screens, e.g. {sorted(ids)[0]})')
print('\nnav failures:')
for k, c in nav.most_common(30):
    print(f'  {c}x {k}')
