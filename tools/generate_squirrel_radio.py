"""Original nonverbal squirrel radio: voiced chatter, clicks and radio squelch.

Offline source/filter synthesis, not a human voice recording or game sample.
Nine short takes (three speakers), packed into one seekable mono Vorbis file.
Requires numpy, scipy and ffmpeg only when rebuilding the asset.
"""
from pathlib import Path
import math, random, subprocess, tempfile, wave
import numpy as np
from scipy.signal import lfilter, iirpeak

RATE=22050
SLOT=3.2
VOICED=3.0
TARGET=Path(__file__).resolve().parents[1]/'assets/level2/pursuit/chatter.ogg'
VOWELS=[(780,1700,3100),(430,2150,3300),(950,1400,2800),(520,1100,2600)]

def take(speaker,variant):
    rng=random.Random(8671+speaker*311+variant*19)
    result=np.zeros(round(SLOT*RATE))
    # Dispatcher is lower and measured; patrol is sharp and excited; the pilot
    # has rounded, compact phrases. All remain recognizably chittering animals.
    base=[610,410,490][speaker]
    count=[15,12,13][speaker]
    for syllable in range(count):
        start=.19+syllable*(2.56/count)+rng.uniform(-.018,.018)
        length=rng.uniform(.080,.155)
        t=np.arange(round(length*RATE))/RATE
        f0=base*rng.uniform(.78,1.25)*(1+.13*np.sin(2*math.pi*(5+variant)*t))
        f0*=np.linspace(rng.uniform(.85,1.15),rng.uniform(.8,1.3),len(t))
        phase=np.cumsum(f0)/RATE
        source=sum(np.sin(2*math.pi*k*phase)/(k**1.25) for k in range(1,12))
        formants=VOWELS[(syllable+variant+speaker)%len(VOWELS)]
        vocal=np.zeros(len(t))
        for center,weight in zip(formants,[1,.65,.3]):
            b,a=iirpeak(center,center/230,RATE)
            vocal+=weight*lfilter(b,a,source)
        vocal/=max(.001,np.max(np.abs(vocal)))
        envelope=np.sin(np.linspace(0,math.pi,len(t)))**.65
        # Occasional dry incisor clicks and breathy /ch/ consonants.
        noise=np.random.default_rng(syllable+speaker*41+variant*503).normal(0,1,len(t))
        consonant=lfilter([1,-1],[1,-.15],noise)*np.exp(-t*95)*.12
        signal=(vocal*.52+consonant)*envelope
        at=round(start*RATE);result[at:at+len(t)]+=signal
    t=np.arange(len(result))/RATE
    noise=np.random.default_rng(700+speaker*11+variant).normal(0,1,len(t))
    result+=lfilter([1,-.84],[1,-.25],noise)*.013*(t<VOICED)
    for at in [.035,2.86]:
        pulse=np.exp(-np.maximum(0,t-at)*85)*(t>=at)*(t<at+.09)
        result+=pulse*(.09*noise+.07*np.sin(2*math.pi*1370*t))
    result=np.tanh(result*1.18)*.82
    return result

def main():
    signal=np.concatenate([take(s,v) for s in range(3) for v in range(3)])
    TARGET.parent.mkdir(parents=True,exist_ok=True)
    with tempfile.TemporaryDirectory() as tmp:
        path=Path(tmp)/'chatter.wav'
        with wave.open(str(path),'wb') as out:
            out.setnchannels(1);out.setsampwidth(2);out.setframerate(RATE)
            out.writeframes(np.round(np.clip(signal,-1,1)*32767).astype('<i2').tobytes())
        subprocess.run(['ffmpeg','-hide_banner','-loglevel','error','-y','-i',str(path),'-c:a','libvorbis','-q:a','2',str(TARGET)],check=True)
    print(f'{TARGET.name}: {len(signal)/RATE:.1f}s, {TARGET.stat().st_size} bytes')
if __name__=='__main__': main()
