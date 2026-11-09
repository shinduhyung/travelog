#!/bin/sh
# Fast audit: every screen once with max (widest text of all languages), ar
# (right-to-left) and th (tall script); then only the screens that overflowed
# get checked in every real language to find which ones break.
# usage: AUDIT_DEVICE=<serial> sh tool/l10n/overflow_audit/screen_pass.sh
cd /c/Users/ahnlee123/Desktop/jidoapp
export PATH="$LOCALAPPDATA/Android/Sdk/platform-tools:$PATH"
D=tool/l10n/overflow_audit
L=$D/run_${AUDIT_DEVICE%%:*}.log
python -I $D/make_max.py >> $L 2>&1
echo "=== screening (max,ar,th) start $(date)" >> $L
python -I $D/drive.py --langs max,ar,th --retry >> $L 2>&1
FLAGGED=$(python -I -c "
import json
ids = []
for line in open('$D/results.jsonl', encoding='utf-8'):
    r = json.loads(line)
    if r.get('tier') == 3 and any(v.get('overflow') for v in r.get('langs', {}).values()):
        ids.append(r['id'])
print(','.join(dict.fromkeys(ids)))")
echo "=== flagged: ${FLAGGED:-none} $(date)" >> $L
if [ -n "$FLAGGED" ]; then
  ALL=$(python -I -c "
import json
m = json.load(open('build/l10n/languages.json', encoding='utf-8'))
print(','.join(e['code'] for e in m['languages'] if e['code'] != 'en'))")
  python -I $D/drive.py --langs "$ALL" --only "$FLAGGED" >> $L 2>&1
fi
echo "=== screen_pass done $(date)" >> $L
