"""Optional offline A/B audition. Source clips, not a gameplay/performance claim."""
from pathlib import Path
import argparse,json,subprocess,wave
import numpy as np
ROOT=Path(__file__).resolve().parents[1];RATE=44100

def load(path):
    raw=subprocess.check_output(['ffmpeg','-v','error','-i',str(path),'-ac','2','-ar',str(RATE),'-f','f32le','-'])
    return np.frombuffer(raw,dtype='<f4').reshape(-1,2).astype(np.float64)

def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--output',type=Path,required=True);a=p.parse_args();a.output.mkdir(parents=True,exist_ok=True)
    old=[]
    for t in [.4,.65,.9,1.15]:old.append((t,'assets/shoot.wav','legacy weapon'))
    for t in [2.4,2.8,3.2,3.6]:old.append((t,'assets/level1/audio/step_grass.ogg','legacy repeated footstep'))
    for t in [4.7,5.2,5.7]:old.append((t,'assets/squirrel_hit.wav','legacy hit'))
    old.append((6.7,'assets/level1/audio/squirrel_warn.ogg','legacy warning'))
    new=[];base='assets/level1/audio/polished147/'
    for t,name in [(.4,'launcher_01'),(.8,'launcher_02'),(1.3,'compact_01'),(1.65,'compact_02'),(2.2,'scatter_01'),(2.7,'scatter_02')]:new.append((t,base+name+'.wav',name))
    for family,times in [('stone',[4,4.45,4.9,5.35]),('grass',[6.2,6.65,7.1]),('soil',[7.9,8.35,8.8,9.25])]:
        for i,t in enumerate(times):new.append((t,base+f'step_{family}_{i+1:02}.wav',family+' footfall'))
    for family,t in [('wood',10.2),('metal',10.9),('soft',11.6),('stone',12.3)]:new.append((t,base+f'impact_{family}_01.wav',family+' impact derivative'))
    new.extend([(13.2,base+'ready_01.wav','equipment warning'),(13.7,base+'attack_02.wav','opponent hand-thrown cone release'),(14.6,base+'defeat_01.wav','equipment/body settling')])
    report={'scope':'Peak-matched source-clip audition only. It is not a live gameplay recording, a phone FPS measurement or a claim of subjective listening.','segments':{}}
    mixes={}
    for label,events,duration in [('before',old,8.5),('after',new,16.0)]:
        mixed=np.zeros((round(duration*RATE),2));timeline=[]
        for t,path,description in events:
            clip=load(ROOT/path);start=round(t*RATE);end=min(len(mixed),start+len(clip));mixed[start:end]+=clip[:end-start]
            timeline.append({'seconds':t,'source':path,'description':description})
        mixed*=.7/max(abs(mixed).max(),1e-8);mixes[label]=mixed
        destination=a.output/f'audio-{label}.wav'
        with wave.open(str(destination),'wb')as w:w.setnchannels(2);w.setsampwidth(2);w.setframerate(RATE);w.writeframes(np.round(mixed*32767).astype('<i2').tobytes())
        subprocess.run(['ffmpeg','-v','error','-y','-i',str(destination),'-c:a','libmp3lame','-q:a','2',str(a.output/f'audio-{label}.mp3')],check=True)
        report['segments'][label]={'seconds':duration,'timeline':timeline}
    combined=np.concatenate([mixes['before'],np.zeros((RATE,2)),mixes['after']]);dest=a.output/'audio-before-after.wav'
    with wave.open(str(dest),'wb')as w:w.setnchannels(2);w.setsampwidth(2);w.setframerate(RATE);w.writeframes(np.round(combined*32767).astype('<i2').tobytes())
    subprocess.run(['ffmpeg','-v','error','-y','-i',str(dest),'-c:a','libmp3lame','-q:a','2',str(a.output/'audio-before-after.mp3')],check=True)
    report['after_starts_at']=9.5;(a.output/'audio-audition.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n');print('Source audition written:',a.output)
if __name__=='__main__':main()
