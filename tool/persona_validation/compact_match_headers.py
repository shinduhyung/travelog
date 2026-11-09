"""Move existing landmark match chips into the Cancel / Done header row."""
from pathlib import Path
import re, sys

def mask(source):
    out = list(source)
    i = 0
    while i < len(source):
        if source.startswith('//', i):
            end = source.find('\n', i)
            end = len(source) if end < 0 else end
        elif source.startswith('/*', i):
            end = source.find('*/', i + 2) + 2
            if end == 1: raise ValueError('Unclosed comment')
        elif source[i] in "\"'":
            quote = source[i] * (3 if source.startswith(source[i] * 3, i) else 1)
            end = i + len(quote)
            while end < len(source):
                if source[end] == '\\': end += 2
                elif source.startswith(quote, end):
                    end += len(quote)
                    break
                else: end += 1
        else:
            i += 1
            continue
        for j in range(i, min(end, len(source))):
            if out[j] != '\n': out[j] = ' '
        i = end
    return ''.join(out)

def plan(source):
    clean = mask(source)
    stack, pairs = [], {}
    for i, char in enumerate(clean):
        if char in '([{': stack.append((char, i))
        elif char in ')]}':
            if not stack or stack[-1][0] != {')':'(',']':'[','}':'{'}[char]:
                raise ValueError(f'Unbalanced source at {i}')
            _, opening = stack.pop()
            pairs[opening] = i
    edits = []
    for badge in re.finditer(r'MyMatchBadge\.landmark\s*\(', clean):
        opening = clean.index('(', badge.start())
        end = pairs[opening] + 1
        call = source[badge.start():end]
        start = badge.start()
        ancestors = sorted((o for o, c in pairs.items() if clean[o] == '(' and o < start and c >= end), reverse=True)
        for parent in ancestors:
            name = re.search(r'(\w+)\s*$', clean[:parent])
            if not name or name.group(1) not in {'Align', 'Padding', 'Center'}: break
            start, end = name.start(1), pairs[parent] + 1
        if source[end:].lstrip().startswith(','):
            end += len(source[end:]) - len(source[end:].lstrip()) + 1
        candidates = []
        for row in re.finditer(r'\bRow\s*\(', clean[:start]):
            ro = clean.index('(', row.start())
            rc = pairs[ro]
            if rc >= start or start - rc > 6000: continue
            section = source[ro:rc]
            if ("tr('Cancel')" in section and "tr('Done')" in section) or "tr('Close')" in section or "tr('Done')" in section:
                candidates.append((row.start(), ro, rc))
        if not candidates: raise ValueError(f'No action row before badge at {badge.start()}')
        _, ro, rc = max(candidates)
        children = re.search(r'\bchildren\s*:\s*\[', clean[ro:rc])
        if not children: raise ValueError('No header children')
        co = ro + children.end() - 1
        cc = pairs[co]
        pieces, cursor, begin = [], co + 1, co + 1
        while cursor < cc:
            if clean[cursor] in '([{': cursor = pairs[cursor] + 1
            elif clean[cursor] == ',':
                pieces.append((begin, cursor)); begin = cursor + 1; cursor += 1
            else: cursor += 1
        pieces.append((begin, cc))
        done = [(a,b) for a,b in pieces if "tr('Done')" in source[a:b]]
        cancel = [(a,b) for a,b in pieces if "tr('Cancel')" in source[a:b]]
        if len(done) == 1:
            position = done[0][0]
        else:
            nonempty = [(a,b) for a,b in pieces if source[a:b].strip()]
            position = nonempty[-1][0]
        while source[position].isspace(): position += 1
        indent = re.search(r'\s*$', source[source.rfind('\n',0,position)+1:position]).group()
        edits.extend([(start, end, ''), (position, position, call + ',\n' + indent)])
    return edits

if __name__ == '__main__':
    prepared = []
    for path in Path('lib/screens').glob('*.dart'):
        chosen = [arg for arg in sys.argv[1:] if arg != '--write']
        if chosen and path.name not in chosen: continue
        source = path.read_text(encoding='utf-8')
        if 'MyMatchBadge.landmark(' not in source: continue
        try: edits = plan(source)
        except ValueError as error:
            print(path, 'SKIP', error)
            continue
        print(path, len(edits)//2, 'headers')
        for a,b,value in sorted(edits, reverse=True): source = source[:a] + value + source[b:]
        prepared.append((path, source))
    if '--write' in sys.argv:
        for path, source in prepared: path.write_text(source,encoding='utf-8')
