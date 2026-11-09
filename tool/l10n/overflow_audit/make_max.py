"""Builds build/overflow_audit/max.json: for every string, the widest
translation across all languages (wide East Asian characters count double,
combining marks zero). One pass with this catalog (drive.py --langs max)
shows the worst case of every language at once.

usage: python -I tool/l10n/overflow_audit/make_max.py
"""
import json
import os
import unicodedata

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, '..', '..', '..'))
SRC = os.path.join(REPO, 'build', 'l10n')
OUT = os.path.join(REPO, 'build', 'overflow_audit', 'max.json')


def width(s):
    w = 0
    for ch in s:
        if unicodedata.combining(ch):
            continue
        w += 2 if unicodedata.east_asian_width(ch) in 'WF' else 1
    return w


def main():
    manifest = json.load(open(os.path.join(SRC, 'languages.json'), encoding='utf-8'))
    best = {'messages': {}, 'countries': {}}
    for entry in manifest['languages']:
        if entry['code'] in ('en', 'ar'):  # ar is checked on its own (right-to-left)
            continue
        data = json.load(open(os.path.join(SRC, entry['file']), encoding='utf-8'))
        for part in best:
            for key, value in data.get(part, {}).items():
                old = best[part].get(key)
                if old is None or width(value) > width(old):
                    best[part][key] = value
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, 'w', encoding='utf-8') as f:
        json.dump(best, f, ensure_ascii=False)
    print(f"{len(best['messages'])} messages, {len(best['countries'])} countries -> {OUT}")


if __name__ == '__main__':
    main()
