import json,re,sys
for n in ['005','006','007','008','009']:
    try:
        i=json.load(open(f'in/{n}.json',encoding='utf-8'));o=json.load(open(f'out/{n}.json',encoding='utf-8'))
    except Exception as e: print(n,'ERR',e);continue
    bad=0
    if set(map(str,[x['id'] for x in i]))!=set(o):bad+=1;print(n,'keys')
    for x in i:
        v=o.get(str(x['id']),'')
        if not v.strip() or v.count('\n')!=x['en'].count('\n') or sorted(re.findall(r'\{\d+\}',v))!=sorted(re.findall(r'\{\d+\}',x['en'])):bad+=1;print(n,x['id'])
    print(n,len(i),len(o),bad)
