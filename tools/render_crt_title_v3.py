"""Exact reviewed v3 reference render, scoped to fresh admitted QA evidence."""
import sys,os
sys.dont_write_bytecode=True
from pathlib import Path
import numpy as np, json, wave, hashlib
P=Path(os.environ['BTH_QA_EVIDENCE_DIR']); SR=44100; BPM=112; beat=60/BPM; N=round(64*beat*SR)
assert str(P).lower().startswith('e:\\codexqa\\bth\\runs\\') and P.is_dir()
rng=np.random.default_rng(74416)
tracks={k:np.zeros((N,2)) for k in ['lead','bass','chords','drums']}; events=[]
hook=[57,60,64,66,64,60,59,57,62,66,67,66,62,60,59,57]
scale=[0,2,3,5,7,9,10]; motif=[0,2,4,5,4,2,1,0,3,5,6,5,3,2,1,0]
def source_bridge():
 out=[]
 for s,m in enumerate(motif):
  bar=s//8; bs=s%8; deg=m+(3 if bar%2==0 else 2);chord=[0,3][bar]
  if bs in [0,4]:deg=min([chord,chord+2,chord+4,chord+6],key=lambda n:abs(n-deg))
  elif bs in [1,5]:deg-=1
  off=scale[deg%7]+12*(deg//7)+12
  while off<12:off+=12
  while off>31:off-=12
  out.append(45+off)
 return out
def note(role,pitch,on,dur,amp,pan=0):
 t=np.arange(round(dur*beat*SR))/SR;f=440*2**((pitch-69)/12);phase=2*np.pi*f*t
 if role=='lead':
  harmonics=min(28,int(16000/f)); duty=.25
  y=sum(2*np.sin(np.pi*k*duty)/(np.pi*k)*np.cos(k*phase-np.pi*k*duty) for k in range(1,harmonics+1))
  env=np.minimum(t/.0015,1)*np.minimum((dur*beat-t)/.012,1)*(.92+.08*np.exp(-t*18))
 elif role=='bass':
  y=sum((-1)**((k-1)//2)*np.sin(k*phase)/k**2 for k in [1,3,5,7,9])
  env=np.minimum(t/.006,1)*np.minimum((dur*beat-t)/.045,1)*np.exp(-t*1.7)
 else:
  y=np.sin(phase)+.17*np.sin(3*phase);env=np.minimum(t/.009,1)*np.minimum((dur*beat-t)/.055,1)*np.exp(-t*4)
 y=y*np.maximum(env,0)*amp; idx=(round(on*beat*SR)+np.arange(len(y)))%N
 gains=np.array([np.cos((pan+1)*np.pi/4),np.sin((pan+1)*np.pi/4)])
 np.add.at(tracks[role],idx,y[:,None]*gains)
 events.append(dict(role=role,midi=pitch,onset_beats=on,duration_beats=dur,gain=amp,pan=pan))
for section in range(4):
 off=section*16; seq=source_bridge() if section==2 else hook
 for i,pitch in enumerate(seq):note('lead',pitch,off+i*.5,.43,.27)
 tail=[(8.5,62,1),(10,60,.8),(11.5,59,.8),(13,57,1.5)]
 if section==1:tail=[(8.5,64,.8),(10,62,.8),(11.5,60,.8),(13,59,1.5)]
 if section==2:tail=[(8.5,67,.8),(10,66,.8),(11.5,64,.8),(13,62,1.5)]
 for on,pitch,dur in tail:note('lead',pitch,off+on,dur,.23)
note('lead',69,63.5,.26,.22)
voicings=[[45,52,60],[50,57,66],[54,60,64],[52,59,62]]
for bar in range(16):
 chord=voicings[bar%4];on=bar*4
 for b,p in [(0,chord[0]-12),(1,chord[0]-12),(2,chord[0]-12),(3,chord[0]-12)]: note('bass',p,on+b,.72,.115)
 for j,p in enumerate(chord[1:]):note('chords',p,on+3,.42,.044,-.28 if j==0 else .28)
 for b in [0,2]:
  t=np.arange(round(.16*SR))/SR;phase=2*np.pi*(51*t+2.1*(1-np.exp(-t*55)))
  y=np.sin(phase)*np.exp(-t*23)*np.minimum(t/.001,1)*np.minimum((.16-t)/.02,1)*.19
  idx=(round((on+b)*beat*SR)+np.arange(len(y)))%N;tracks['drums'][idx]+=y[:,None]*.707
 for b in [1,3]:
  t=np.arange(round(.13*SR))/SR;noise=rng.uniform(-1,1,len(t));y=(noise*.75+np.sin(2*np.pi*180*t)*.25)*np.exp(-t*28)*np.minimum(t/.001,1)*np.minimum((.13-t)/.02,1)*.09
  idx=(round((on+b)*beat*SR)+np.arange(len(y)))%N;tracks['drums'][idx]+=y[:,None]*.707
 for b in [.5,1.5,2.5,3.5]:
  t=np.arange(round(.045*SR))/SR; noise=rng.uniform(-1,1,len(t)); noise=np.diff(noise,prepend=noise[0])
  y=noise*np.exp(-t*85)*np.minimum(t/.001,1)*np.minimum((.045-t)/.008,1)*.014
  idx=(round((on+b)*beat*SR)+np.arange(len(y)))%N;tracks['drums'][idx]+=y[:,None]*np.array([.57,.82])
ch=tracks['chords'].copy();tracks['chords']+=np.roll(ch,round(.5*beat*SR),axis=0)[:,::-1]*.08
mix=sum(tracks.values()); gain=min(10**(-16/20)/np.sqrt(np.mean(mix*mix)),10**(-2/20)/np.max(np.abs(mix)));mix*=gain
for a in tracks.values():a*=gain
def write(name,a):
 pcm=np.round(a*32767).astype('<i2')
 with wave.open(str(P/(name+'.wav')),'wb') as w:w.setnchannels(2);w.setsampwidth(2);w.setframerate(SR);w.writeframes(pcm.tobytes())
 return {'frames':len(a),'seconds':len(a)/SR,'peak_dbfs':float(20*np.log10(np.max(abs(a)))),'rms_dbfs':float(20*np.log10(np.sqrt(np.mean(a*a)))),'seam_pcm_units':int(np.max(abs(pcm[0].astype(int)-pcm[-1].astype(int))))}
checks={'mix':write('bth_title_crt_v3',mix),'stems':{k:write(k,a) for k,a in tracks.items()},'hook_midi':hook,'bridge_midi':source_bridge(),'loop_frames':N,'bpm':BPM,'form':['A','A_prime','B','A'],'render_gain':gain}
(P/'score_events.json').write_text(json.dumps({'bpm':BPM,'sample_rate':SR,'loop_beats':64,'events':events},indent=2))
(P/'checks.json').write_text(json.dumps(checks,indent=2))
expected='2412bb82073f500b68cd9a1f95988da970af141282f1dbe15cb077c67ff30028'
actual=hashlib.sha256((P/'bth_title_crt_v3.wav').read_bytes()).hexdigest()
print('Master SHA256:',actual)
assert actual==expected,'Master mismatch; inspect before integration'
