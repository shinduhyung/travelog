import json,re,sys
n=sys.argv[1]
b='C:/Users/ahnlee123/Desktop/jidoapp/tool/l10n/vi/'
o={}
for p in sys.argv[2:]:
    o.update(json.load(open(b+p,encoding='utf-8')))
i=json.load(open(b+f'work/in/{n}.json',encoding='utf-8'))
bad=0
if set(map(str,[x['id'] for x in i]))!=set(o):print('keys',set(map(str,[x['id'] for x in i]))^set(o));bad+=1
for x in i:
    v=o.get(str(x['id']),'')
    if not v.strip() or v.count('\n')!=x['en'].count('\n') or sorted(re.findall(r'\{\d+\}',v))!=sorted(re.findall(r'\{\d+\}',x['en'])):bad+=1;print('bad',x['id'])
    if re.search(r'\b(the|and|of|with)\b',v):print('eng?',x['id'],v[:60])
print(len(i),len(o),bad)
if not bad:
    json.dump(o,open(b+f'work/out/{n}.json','w',encoding='utf-8'),ensure_ascii=False,indent=1);print('written')
