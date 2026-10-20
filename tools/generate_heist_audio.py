"""Small deterministic mechanical/bell cues; no external sound sources."""
from pathlib import Path
import math
import struct
import subprocess
import tempfile
import wave

ROOT = Path(__file__).resolve().parents[1] / 'assets/level1/audio'
RATE = 22050

def make(name, duration, notes):
    samples = []
    for i in range(int(duration * RATE)):
        t = i / RATE
        value = 0.0
        for frequency, start, length, volume in notes:
            u = t - start
            if not 0 <= u < length:
                continue
            envelope = min(u / .006, 1) * math.exp(-u * 5 / length) * min((length-u)/.04, 1)
            value += volume * envelope * (math.sin(math.tau*frequency*u) + .24*math.sin(math.tau*frequency*2.76*u))
        samples.append(struct.pack('<h', int(max(-.95, min(.95, value))*32767)))
    with tempfile.TemporaryDirectory() as folder:
        source = Path(folder) / 'cue.wav'
        with wave.open(str(source), 'wb') as output:
            output.setparams((1, 2, RATE, 0, 'NONE', 'not compressed'))
            output.writeframes(b''.join(samples))
        subprocess.run(['ffmpeg','-v','error','-y','-i',str(source),'-c:a','libvorbis','-q:a','3',str(ROOT/f'{name}.ogg')],check=True)

if __name__ == '__main__':
    make('heist_dial', .28, [(880,0,.20,.30),(1760,.025,.20,.08)])
    make('heist_solved', 1.8, [(f,i*.14,1.2,.24) for i,f in enumerate([523.25,659.25,783.99,1046.5])])
    make('heist_bell', 2.1, [(f,0,2,.28/(i+1)) for i,f in enumerate([660,1323,1830])])
    make('heist_alarm', 1.4, [(f,i*.23,.30,.22) for i,f in enumerate([440,660,440,660,440])])
