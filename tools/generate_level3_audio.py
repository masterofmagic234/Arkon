#!/usr/bin/env python3
"""Deterministic original diner foley/ambience; offline NumPy + ffmpeg only."""
from pathlib import Path
import subprocess, tempfile, wave
import numpy as np
SR=24000
RNG=np.random.default_rng(31717)
OUT=Path(__file__).resolve().parents[1]/'assets/level3/audio'
OUT.mkdir(parents=True,exist_ok=True)
def noise(n): return RNG.standard_normal(n)
def smooth(x,n): return np.convolve(x,np.ones(n)/n,mode='same')
def write(name,x,loop=False):
    x=np.nan_to_num(x)
    x=x/max(1.0,float(np.max(np.abs(x)))*1.04)
    if not loop:
        fade=min(120,len(x)//10)
        x[:fade]*=np.linspace(0,1,fade);x[-fade:]*=np.linspace(1,0,fade)
    with tempfile.NamedTemporaryFile(suffix='.wav') as tmp:
        with wave.open(tmp.name,'wb') as w:
            w.setnchannels(1);w.setsampwidth(2);w.setframerate(SR);w.writeframes((np.clip(x,-1,1)*32767).astype('<i2').tobytes())
        subprocess.run(['ffmpeg','-hide_banner','-loglevel','error','-y','-i',tmp.name,'-c:a','libvorbis','-q:a','4',str(OUT/(name+'.ogg'))],check=True)
    print(name,len(x)/SR)
def loop_noise(seconds):
    n=int(seconds*SR);x=noise(n+SR)
    x[:SR]=x[:SR]*np.linspace(0,1,SR)+x[n:n+SR]*np.linspace(1,0,SR)
    return x[:n]
t=np.arange(16*SR)/SR
rain=loop_noise(16);rain=0.13*(rain-smooth(rain,13))+0.24*smooth(rain,280)
# No isolated thunder peaks or surprise transients in the exploration loop.
write('rain',rain,True)
t=np.arange(8*SR)/SR
hum=.23*np.sin(2*np.pi*60*t)+.06*np.sin(2*np.pi*120*t)+.02*np.sin(2*np.pi*180*t)
hum*=.85+.07*np.sin(2*np.pi*.375*t)
write('fridge',hum+.014*smooth(loop_noise(8),5),True)
for name,duration in [('pistol',.20),('shotgun',.34),('enemy_shot',.18)]:
 t=np.arange(int(duration*SR))/SR;n=noise(len(t));dry=n-smooth(n,9)
 attack=np.minimum(1,t/.0008)
 tail=np.exp(-t/(.032 if name!='shotgun' else .062))
 x=.72*dry*attack*tail+.34*np.sin(2*np.pi*(105*t-95*t*t))*np.exp(-t/.052)
 if name=='shotgun': x+=.14*smooth(n,18)*np.exp(-t/.14)
 write(name,x)
t=np.arange(int(.30*SR))/SR
write('door',.12*smooth(noise(len(t)),8)*np.exp(-t/.06)+.28*np.sin(2*np.pi*(150*t-160*t*t))*np.exp(-t/.045)+.10*np.sin(2*np.pi*740*t)*np.exp(-t/.035))
t=np.arange(int(.42*SR))/SR
write('glass',(noise(len(t))-smooth(noise(len(t)),20))*.24*np.exp(-t/.075)+sum(.14*np.sin(2*np.pi*f*t)*np.exp(-t/(.05+i*.023)) for i,f in enumerate([1821,2435,3719,4217])))
t=np.arange(int(.16*SR))/SR
write('step',.32*smooth(noise(len(t)),7)*np.exp(-t/.023)+.13*np.sin(2*np.pi*150*t)*np.exp(-t/.021))
t=np.arange(int(.24*SR))/SR
write('bat',.20*noise(len(t))*np.exp(-((t-.026)/.023)**2)+.32*np.sin(2*np.pi*90*t)*np.exp(-t/.04))
t=np.arange(int(.28*SR))/SR
write('pickup',.20*np.sin(2*np.pi*660*t)*np.exp(-t/.12)+.16*np.sin(2*np.pi*990*t)*np.exp(-np.maximum(0,t-.09)/.10)*(t>.09))
# A quiet original 90 BPM radio loop: E minor / Cmaj7 / Am7 / Bm7,
# plucked electric-piano partials, round bass and restrained brushed percussion.
seconds=32;n=SR*seconds;radio=np.zeros(n);beat=2/3
chords=[[52,55,59,62],[48,52,55,59],[45,48,52,55],[47,50,54,57]]
def note(midi,length,gain=.14):
 t=np.arange(int(length*SR))/SR;f=440*2**((midi-69)/12)
 return gain*(np.sin(2*np.pi*f*t)+.25*np.sin(2*np.pi*2*f*t)*np.exp(-t/1.1)+.10*np.sin(2*np.pi*3*f*t))*np.exp(-t/.80)*np.minimum(1,t/.007)
def add(at,signal):
 start=int(at*SR)%n;end=start+len(signal)
 if end<=n: radio[start:end]+=signal
 else: radio[start:]+=signal[:n-start];radio[:end-n]+=signal[n-start:]
for b in range(48):
 chord=chords[(b//6)%4]
 if b%3==0:
  for i,pitch in enumerate(chord): add(b*beat+i*.026,note(pitch+12,2.6,.055))
 if b%2==0: add(b*beat,note(chord[0]-12,.8,.20))
 if b%4==2: add(b*beat,note(chord[2]+24,.7,.048))
 t=np.arange(int(.08*SR))/SR;brush=(noise(len(t))-smooth(noise(len(t)),11))*.025*np.exp(-t/.023)
 add((b+.5)*beat,brush)
 if b%4==0:
  t=np.arange(int(.18*SR))/SR;add(b*beat,.10*np.sin(2*np.pi*(65*t-22*t*t))*np.exp(-t/.046))
write('diner_radio',radio,True)
