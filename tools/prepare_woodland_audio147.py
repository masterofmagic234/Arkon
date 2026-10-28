"""Offline editing of immutable generated foley; no oscillator/noise synthesis.

Run from the repository root. Runtime one-shots are short mono PCM WAVs;
ambience keeps a crossfaded loop. SciPy/FFmpeg are authoring dependencies only.
"""
from pathlib import Path
import hashlib,json,subprocess,wave
import numpy as np
from scipy.signal import butter,sosfilt,resample_poly,find_peaks

ROOT=Path(__file__).resolve().parents[1]
SOURCE=ROOT/'art/level1/audio147/source'
OUT=ROOT/'assets/level1/audio/polished147'
RATE=44100
OUT.mkdir(parents=True,exist_ok=True)
records=[]

def load(name,channels=1):
    raw=subprocess.check_output(['ffmpeg','-v','error','-i',str(SOURCE/f'{name}.mp3'),'-ac',str(channels),'-ar',str(RATE),'-f','f32le','-'])
    a=np.frombuffer(raw,dtype='<f4').astype(np.float64)
    return a if channels==1 else a.reshape(-1,channels)

def filter_(a,lo=0,hi=18000):
    b=np.array(a,copy=True)
    if lo:b=sosfilt(butter(2,lo,'highpass',fs=RATE,output='sos'),b,axis=0)
    if hi<RATE/2:b=sosfilt(butter(2,hi,'lowpass',fs=RATE,output='sos'),b,axis=0)
    return b

def pitch(a,ratio):
    # Resampling a recording changes its pitch/time together, not its source.
    return resample_poly(a,1000,round(ratio*1000),axis=0)

def cut(a,start,end):return a[max(0,int(start*RATE)):min(len(a),int(end*RATE))].copy()

def mix(parts):
    n=max(len(a) for a,g in parts);out=np.zeros(n)
    for a,g in parts:out[:len(a)]+=a*g
    return out

def tame(a,ratio=7):
    # Gentle offline transient compression; all audible material is recorded.
    rms=max(float(np.sqrt(np.mean(a*a))),1e-8);threshold=rms*ratio
    mag=np.abs(a);over=mag>threshold
    out=a.copy();out[over]=np.sign(a[over])*(threshold+np.log1p((mag[over]-threshold)/threshold)*threshold*.35)
    return out

def fade(a,start=.002,end=.018):
    a=a.copy();n=min(int(start*RATE),len(a));m=min(int(end*RATE),len(a))
    if n:a[:n]*=np.linspace(0,1,n).reshape((-1,)+(1,)*(a.ndim-1))
    if m:a[-m:]*=np.linspace(1,0,m).reshape((-1,)+(1,)*(a.ndim-1))
    return a

def true_peak(a):return max(float(np.max(np.abs(resample_poly(a,4,1,axis=0)))),1e-9)

def save(name,a,sources,operations,peak=-8,rms=None,loop=False):
    a=np.asarray(a,dtype=np.float64);a-=np.mean(a,axis=0)
    if not loop:a=fade(a)
    if rms is not None:a*=10**(rms/20)/max(float(np.sqrt(np.mean(a*a))),1e-8)
    ceiling=10**(peak/20);a*=min(1.0,ceiling/true_peak(a)) if rms is not None else ceiling/true_peak(a)
    pcm=np.round(np.clip(a,-.999,.999)*32767).astype('<i2');path=OUT/f'{name}.wav'
    with wave.open(str(path),'wb') as w:
        w.setnchannels(1 if pcm.ndim==1 else pcm.shape[1]);w.setsampwidth(2);w.setframerate(RATE);w.writeframes(pcm.tobytes())
    decoded=pcm.astype(np.float64)/32768
    records.append({'file':str(path.relative_to(ROOT)),'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'source_takes':sources,'editing':operations,'sample_rate':RATE,'channels':1 if pcm.ndim==1 else pcm.shape[1],'seconds':len(pcm)/RATE,'peak_dbfs':20*np.log10(max(float(np.abs(decoded).max()),1e-9)),'true_peak_dbfs':20*np.log10(true_peak(decoded)),'rms_dbfs':20*np.log10(max(float(np.sqrt(np.mean(decoded*decoded))),1e-9)),'loop':loop,'samples':len(pcm)})
    return decoded

def events(a,minimum_relative=.16):
    block=441;n=len(a)//block;env=np.sqrt(np.mean(a[:n*block].reshape(n,block)**2,axis=1));env=np.convolve(env,np.ones(3)/3,'same')
    peaks,_=find_peaks(env,distance=45,prominence=max(env.max()*.065,.0002))
    chosen=sorted(sorted(peaks,key=lambda k:env[k],reverse=True)[:4])
    return [p*.01 for p in chosen if env[p]>=env.max()*minimum_relative]

cone=filter_(cut(load('cone'),0,.72),65,13500)
scatter=filter_(cut(load('scatter'),0,.95),55,12500)
impact=filter_(cut(load('impact'),.015,.65),80,12500)
for i,ratio in enumerate([1.0,.985]):
    save(f'launcher_{i+1:02}',tame(pitch(cone,ratio),10),['cone'],['trim to close shot/bolt tail','highpass65Hz, lowpass13.5kHz',f'pitch/time ratio{ratio}','gentle transient compression','true-peak headroom'],peak=-6)
    save(f'compact_{i+1:02}',tame(pitch(filter_(cone,230,10500),1.10+i*.025),8),['cone'],['derived compact sibling weapon, no new synthetic tone','shorter pitched take, narrower low end','true-peak headroom'],peak=-7)
    save(f'scatter_{i+1:02}',tame(pitch(scatter,1-i*.035),10),['scatter'],['trim natural scatter blast/action tail','highpass55Hz, lowpass12.5kHz','two subtle pitch/time takes','true-peak headroom'],peak=-6)

steps={}
for family in ['stone','grass','soil']:
    take=filter_(load('step_'+family),70,11500);points=events(take)
    steps[family]=[]
    for i,point in enumerate(points):
        excerpt=cut(take,point-.052,point+(.34 if family=='grass' else .28))
        steps[family].append(excerpt)
        save(f'step_{family}_{i+1:02}',tame(excerpt,6),['step_'+family],[f'independent strong footfall around{point:.2f}s','trim heel/sole/rustle, preserve attack','highpass70Hz, lowpass11.5kHz','gentle transient compression, short edge fades'],peak=-11,rms=-24)

# The multi-material prompt produced one clean impact rather than four events.
# These are explicit sound-design derivatives of that single take, not claims
# of separately recorded materials. Distinct EQ/decay and real grit/rustle layers
# provide material feedback while retaining natural, non-tonal source texture.
for i,ratio in enumerate([1.0,1.045]):
    stone=mix([(filter_(pitch(impact,ratio),180,14500),1),(cut(steps['stone'][i],0,.12),.13)])
    wood=filter_(pitch(impact,.76+i*.035),80,3200)
    metal=filter_(pitch(impact,1.16+i*.035),450,11000)
    dry=metal.copy()
    for count in range(1,5):
        delay=int(RATE*.017*count)
        if delay<len(metal):metal[delay:]+=dry[:-delay]*(.22**count)
    soft=mix([(filter_(pitch(impact,.78+i*.02),45,1350),1),(steps['grass'][i],.06)])
    soil=mix([(filter_(pitch(impact,.9+i*.03),100,4500),.55),(steps['soil'][i],.5)])
    for family,a in [('stone',stone),('wood',wood),('metal',metal),('soft',soft),('soil',soil)]:
        layers={'stone':['step_stone'],'soft':['step_grass'],'soil':['step_soil']}.get(family,[])
        save(f'impact_{family}_{i+1:02}',tame(a,7),['impact',*layers],[f'{family} impact derivative: material EQ, subtle time/pitch change','metal uses short low-level recorded-signal reflections, no oscillator','gentle transient control, true-peak headroom'],peak=-10 if family=='soft' else -11,rms=-25)

for i in range(2):
    click=mix([(filter_(pitch(impact,1.4+i*.08),900,6500),.26),(cut(steps['grass'][i],0,.24),.55)])
    save(f'ready_{i+1:02}',tame(cut(click,0,.28),6),['impact','step_grass'],['short equipment/rustle telegraph from recorded impact and foliage foley','filtered/transient-controlled, no whistle or generated sine'],peak=-13,rms=-27)
    motion=mix([(filter_(cut(cone,.13,.48),350,6500),.4),(pitch(steps['grass'][i],1.12),.6)])
    save(f'attack_{i+1:02}',tame(motion,6),['cone','step_grass'],['air/cloth attack movement from tails/rustle','no duplicated muzzle transient'],peak=-12,rms=-27)
    settle=mix([(filter_(pitch(impact,.70+i*.025),55,1800),.5),(steps['soil'][i],.5)])
    save(f'defeat_{i+1:02}',tame(settle,7),['impact','step_soil'],['soft body/equipment settling','no human scream or synthetic animal chirp'],peak=-12,rms=-27)

for name,channels,lo,hi,target in [('wind',2,120,6500,-30),('water',1,160,10000,-28)]:
    a=filter_(load(name,channels),lo,hi);a=tame(a,4)
    fade_len=int(.16*RATE)
    # True equal-gain overlap makes a continuous natural loop; preserve stereo
    # in the global breeze, mono in the spatial irrigation emitter.
    blend=np.linspace(0,1,fade_len).reshape((-1,)+(1,)*(a.ndim-1))
    seam=a[-fade_len:]*(1-blend)+a[:fade_len]*blend
    a=np.concatenate([seam,a[fade_len:-fade_len]],axis=0)
    a=np.roll(a,len(a)//2,axis=0)
    save(f'ambience_{name}',a,[name],['real generated field-recording texture','gentle high/lowpass and transient control','160ms loop crossfade and seam rotation','quiet headroom-controlled mix'],peak=-16,rms=target,loop=True)

generation=json.loads((ROOT/'art/level1/audio147/generation.json').read_text())
for take in generation['takes']:
    path=ROOT/take['source_file'];take['sha256']=hashlib.sha256(path.read_bytes()).hexdigest();take['bytes']=path.stat().st_size
provenance={'version':1,'purpose':'Modern cone-weapon and outdoor material foley for Level1','generator':generation,'tool':'tools/prepare_woodland_audio147.py','tool_sha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),'source_export':'art/level1/* excluded; raw MP3s never loaded by gameplay','runtime_processing':'sample selection, slight pitch/gain, spatial mixing and one scene-local peak limiter; no synthesis','quality_scope':'PCM decoding, event coverage, headroom, variation, loop seams and actual runtime mixing are verified; subjective listening is not claimed by an audio-input-incapable agent.','impact_source_note':'One generated impact event; material variants are explicitly edited derivatives, not independent recording claims.','assets':records}
(OUT/'PROVENANCE.json').write_text(json.dumps(provenance,ensure_ascii=False,indent=2)+'\n')
print(json.dumps({'files':len(records),'bytes':sum((ROOT/r['file']).stat().st_size for r in records),'step_counts':{k:len(v) for k,v in steps.items()},'max_true_peak_dbfs':max(r['true_peak_dbfs'] for r in records)},indent=2))
