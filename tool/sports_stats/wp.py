import sys,requests,io,pandas as pd
UA={'User-Agent':'TravelogResearch/1.0 (leeahn137@gmail.com)'}
def tables(title):
    r=requests.get('https://en.wikipedia.org/w/api.php',params=dict(action='parse',page=title,prop='text|revid',format='json',redirects=1),headers=UA,timeout=60).json()
    h=r['parse']['text']['*']
    return r['parse']['revid'],pd.read_html(io.StringIO(h))
if __name__=='__main__':
    rev,t=tables(sys.argv[1]);print('rev',rev,'ntables',len(t))
    for i,x in enumerate(t):
        print(i,x.shape,list(map(str,x.columns))[:8])
