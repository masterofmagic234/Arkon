"""Original, deterministic PCM sound design; no runtime synthesis or recordings."""
from pathlib import Path
import math, random, struct, wave

TARGET=Path(__file__).resolve().parents[1]/'assets/level2/pursuit'
RATE=22050
def save(name, duration, sample):
    random.seed(731)
    frames=bytearray()
    for i in range(round(duration*RATE)):
        t=i/RATE
        value=sample(t,random.uniform(-1,1))
        frames.extend(struct.pack('<h',round(max(-.96,min(.96,value))*32767)))
    with wave.open(str(TARGET/(name+'.wav')),'wb') as out:
        out.setnchannels(1);out.setsampwidth(2);out.setframerate(RATE);out.writeframes(frames)

if __name__=='__main__':
    TARGET.mkdir(parents=True,exist_ok=True)
    tau=math.tau
    # Integer cycles make the rotor loop continuous at both boundaries.
    save('rotor',2.0,lambda t,n:(.28*math.sin(tau*88*t)+.13*math.sin(tau*176*t)+.07*math.sin(tau*352*t)+n*.09)*(.32+.68*(.5+.5*math.sin(tau*16*t))**3))
    save('radio',.55,lambda t,n:(.33*math.sin(tau*(760 if t<.19 else 1120)*t)+n*.04)*min(1,t*50)*max(0,1-t/.55)*(1 if t<.19 or t>.27 else 0))
    save('impact',.7,lambda t,n:(n*.55*math.exp(-t*12)+.3*math.sin(tau*78*t)*math.exp(-t*17)+n*.12*math.exp(-t*3))*min(1,t*250))
