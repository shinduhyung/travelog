import json,sys,re,glob
n=sys.argv[1]
base='C:/Users/ahnlee123/Desktop/jidoapp/tool/l10n/th/'
src=json.load(open(base+'work/in/%s.json'%n,encoding='utf-8'))
out={}
for f in sorted(glob.glob(base+'h%s_part*.json'%n)):
    out.update(json.load(open(f,encoding='utf-8')))
ids=[str(x['id']) for x in src]
miss=[i for i in ids if i not in out]; extra=[k for k in out if k not in ids]
print('missing',miss,'extra',extra)
bad=0
for x in src:
    v=out.get(str(x['id']))
    if v is None: continue
    if not v.strip(): print('empty',x['id']);bad+=1
    if v.count('\n')!=x['en'].count('\n'): print('nl',x['id']);bad+=1
    if sorted(re.findall(r'\{\d+\}',v))!=sorted(re.findall(r'\{\d+\}',x['en'])): print('ph',x['id']);bad+=1
    w=re.findall(r'[A-Za-z]{3,}',v)
    if w: print('lat',x['id'],w)
if not miss and not extra and not bad:
    json.dump(out,open(base+'work/out/%s.json'%n,'w',encoding='utf-8'),ensure_ascii=False,indent=1)
    print('WROTE',n,len(out))
