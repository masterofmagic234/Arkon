"""Original procedural park sound assets. Offline authoring; no DSP on device."""
from pathlib import Path
import subprocess
import numpy as np

RATE = 24000
OUT = Path('assets/level1/audio')
OUT.mkdir(parents=True, exist_ok=True)
rng = np.random.default_rng(7112026)

def colored(n, low, high):
    frequencies = np.fft.rfftfreq(n, 1/RATE)
    spectrum = np.fft.rfft(rng.normal(0,1,n))
    mask = (frequencies>=low)&(frequencies<=high)
    spectrum *= mask / np.maximum(frequencies,low)**0.45
    wave = np.fft.irfft(spectrum,n)
    return wave / max(np.std(wave),1e-8)

def save(name, wave, loop=False):
    if wave.ndim == 1: wave = np.column_stack([wave,wave])
    wave = np.tanh(wave)*0.72
    if not loop:
        fade = min(len(wave)//5,120)
        wave[:fade] *= np.linspace(0,1,fade)[:,None]
        wave[-fade:] *= np.linspace(1,0,fade)[:,None]
    pcm = (wave*32767).astype('<i2').tobytes()
    subprocess.run(['ffmpeg','-y','-loglevel','error','-f','s16le','-ar',str(RATE),'-ac','2','-i','pipe:0','-c:a','libvorbis','-q:a','3',str(OUT/(name+'.ogg'))],input=pcm,check=True)

n=RATE*24; t=np.arange(n)/RATE
wind=[]
for channel in range(2):
    gust = 0.14+0.065*np.sin(2*np.pi*t/24+channel*0.8)+0.035*np.sin(2*np.pi*t/8+channel)
    wind.append(colored(n,65,2200)*gust + colored(n,2200,6500)*0.018)
save('park_wind',np.column_stack(wind),True)
water=[]
for channel in range(2):
    wave = colored(n,250,5500)*0.065
    for i in range(96):
        start=int((i*0.25+channel*0.09)*RATE)%n
        length=int(RATE*0.17)
        tt=np.arange(length)/RATE
        bubble=np.sin(2*np.pi*(380*tt+700*tt*tt))*np.exp(-tt*23)*0.025
        idx=(np.arange(length)+start)%n
        wave[idx]+=bubble
    water.append(wave)
save('garden_water',np.column_stack(water),True)
n=int(RATE*0.7);t=np.arange(n)/RATE
chirp=np.zeros(n)
for start,f in [(0.03,1600),(0.2,1900),(0.4,1450)]:
    env=np.exp(-((t-start)/0.045)**2)
    chirp+=np.sin(2*np.pi*(f*t+90*np.sin(t*25)))*env*0.16
save('squirrel_warn',chirp+colored(n,900,5000)*0.025)
n=int(RATE*1.8);t=np.arange(n)/RATE
creak=(np.sin(2*np.pi*(105*t+24*np.sin(t*3)))+0.35*np.sin(2*np.pi*330*t))*np.sin(np.pi*t/1.8)**2*0.07
creak+=colored(n,100,2300)*(np.exp(-t*16)*0.20+np.exp(-((t-1.5)/0.055)**2)*0.13)
save('gate_open',creak)
n=int(RATE*0.34);t=np.arange(n)/RATE
save('cone_throw',colored(n,300,7500)*np.sin(np.pi*t/0.34)**2*0.18)
for name,band in [('step_grass',(180,4300)),('step_gravel',(700,7000))]:
    n=int(RATE*0.27);t=np.arange(n)/RATE
    envelope=(1-np.exp(-t*140))*np.exp(-t*22)
    save(name,colored(n,*band)*envelope*0.25+np.sin(2*np.pi*90*t)*np.exp(-t*45)*0.10)
print('Park audio generated:', len(list(OUT.glob('*.ogg'))),'original Vorbis assets.')
