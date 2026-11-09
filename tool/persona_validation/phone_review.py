import subprocess,pathlib,xml.etree.ElementTree as ET,re,sys
ADB=['C:/AndroidSDK_New/platform-tools/adb.exe','-s','R5KL20LRNSN']
OUT=pathlib.Path(__file__).parent/'out'
def run(*args):return subprocess.check_output(ADB+list(args))
def ensure_app():
 focus=run('shell','dumpsys','window','windows').decode('utf-8',errors='replace')
 line=next((l for l in focus.splitlines() if 'mCurrentFocus=' in l),'')
 if 'com.ahnlee.jidoapp' not in line:
  run('shell','am','start','-n','com.ahnlee.jidoapp/com.example.jidoapp.MainActivity')

def state():
 ensure_app()
 result=run('shell','uiautomator','dump','/sdcard/review.xml')
 if b'dumped' not in result.lower():raise RuntimeError('Screen is busy; no touch performed')
 return ET.fromstring(run('shell','cat','/sdcard/review.xml'))
def tap(text):
 root=state();nodes=[n for n in root.iter('node') if (n.get('text') or '').split('\n')[0]==text or (n.get('content-desc') or '').split('\n')[0]==text]
 if not nodes:raise ValueError('Not visible: '+text)
 b=list(map(int,re.findall(r'\d+',nodes[0].get('bounds'))));run('shell','input','tap',str((b[0]+b[2])//2),str((b[1]+b[3])//2))
def snapshot(name):
 root=state();(OUT/(name+'.png')).write_bytes(run('exec-out','screencap','-p'))
 for n in root.iter('node'):
  label=n.get('text') or n.get('content-desc')
  if label:print(label[:110],n.get('bounds'))
if __name__=='__main__':
 action=sys.argv[1]
 if action=='tap':tap(sys.argv[2]);snapshot(sys.argv[3])
 elif action=='snap':snapshot(sys.argv[2])
 elif action=='back':run('shell','input','keyevent','4');snapshot(sys.argv[2])
 elif action=='swipe':ensure_app();run('shell','input','swipe','80',sys.argv[2],'80',sys.argv[3],'450');snapshot(sys.argv[4])
