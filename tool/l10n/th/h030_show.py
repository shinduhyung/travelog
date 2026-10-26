import json,sys
n,a,b=sys.argv[1],int(sys.argv[2]),int(sys.argv[3])
d=json.load(open('C:/Users/ahnlee123/Desktop/jidoapp/tool/l10n/th/work/in/%s.json'%n,encoding='utf-8'))
for x in d[a:b]: print(x['id'],'|',x['en'].replace('\n','\n'),'|',x.get('landmark',''))
