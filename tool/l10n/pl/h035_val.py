import json,re,sys
for n in sys.argv[1:]:
    b='C:/Users/ahnlee123/Desktop/jidoapp/tool/l10n/pl/work/'
    i=json.load(open(b+'in/'+n+'.json',encoding='utf-8'))
    o=json.load(open(b+'out/'+n+'.json',encoding='utf-8'))
    ids={str(x['id']):x['en'] for x in i}
    print(n,len(i),len(o),set(ids)==set(o))
    for k,e in ids.items():
        v=o.get(k,'')
        if not v.strip(): print('empty',k)
        if e.count('\n')!=v.count('\n'): print('nl',k)
        if re.findall(r'\{\d+\}',e)!=re.findall(r'\{\d+\}',v) and sorted(re.findall(r'\{\d+\}',e))!=sorted(re.findall(r'\{\d+\}',v)): print('ph',k)
        if re.search(r'\n ',v): print('sp',k)
