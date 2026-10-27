import sys,glob,re,os
sys.stdout.reconfigure(encoding="utf-8")
d=r'C:\Users\ahnlee123\.claude\projects\C--Users-ahnlee123-Desktop-jidoapp\af83280a-d19f-483c-81d2-6fd653ac591b\tool-results'
for slug in sys.argv[1:]:
    new=open(f'out/{slug}.html',encoding='utf-8').read()
    print(slug,len(new),'rec:',len(re.findall(r'is-rec',new)))
