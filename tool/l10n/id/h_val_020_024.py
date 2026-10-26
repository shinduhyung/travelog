import json,re,sys
for n in sys.argv[1:]:
    i=json.load(open(f'in/{n}.json',encoding='utf-8'));o=json.load(open(f'out/{n}.json',encoding='utf-8'))
    ids={str(x['id']) for x in i}
    print(n,len(i),len(o),ids==set(o))
    for x in i:
        t=o.get(str(x['id']),'')
        if not t.strip():print('empty',x['id'])
        if x['en'].count('\n')!=t.count('\n'):print('nl',x['id'])
        if sorted(re.findall(r'\{\d+\}',x['en']))!=sorted(re.findall(r'\{\d+\}',t)):print('ph',x['id'])
