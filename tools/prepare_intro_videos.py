#!/usr/bin/env python3
"""Build and validate the four silent, chronological Godot Theora clips.

Runtime consumes only OGV. Source MP4 hashes tie the export to the reviewed
Carolina redraw. FFmpeg is an authoring/build dependency, never a game one.
"""
from pathlib import Path
import argparse,hashlib,json,math,subprocess

ROOT=Path(__file__).resolve().parents[1]
MANIFEST=ROOT/'assets/intro_video_manifest.json'
OUT=ROOT/'assets/intro_video'

def motion_frames(path,count,fps):
    raw=subprocess.check_output(['ffmpeg','-v','error','-i',str(path),'-vf',f'scale=160:90,fps={fps}',
        '-pix_fmt','gray','-f','rawvideo','pipe:1'])
    stride=160*90
    assert len(raw)%stride==0,(path.name,'partial decoded frame')
    assert abs(len(raw)//stride-count)<=1,(path.name,'CFR timeline frame coverage',len(raw)//stride,count)
    return [raw[i:i+stride] for i in range(0,len(raw),stride)]

def delta(a,b):
    return sum(abs(x-y) for x,y in zip(a,b))/len(a)

def probe(path):
    result=json.loads(subprocess.check_output([
        'ffprobe','-v','error','-count_frames','-select_streams','v:0',
        '-show_entries','stream=width,height,avg_frame_rate,r_frame_rate,nb_read_frames:format=duration',
        '-of','json',str(path)]))
    stream=result['streams'][0]
    rate=stream['avg_frame_rate'] if stream['avg_frame_rate']!='0/0' else stream['r_frame_rate']
    numerator,denominator=map(int,rate.split('/'))
    return {'width':stream['width'],'height':stream['height'],
            'frames':int(stream['nb_read_frames']),'fps':numerator/denominator,
            'duration':float(result['format']['duration'])}

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check',action='store_true',help='validate existing outputs')
    args=parser.parse_args()
    manifest=json.loads(MANIFEST.read_text());OUT.mkdir(parents=True,exist_ok=True)
    report=[]
    previous=None
    for index,clip in enumerate(manifest['clips']):
        source=ROOT/clip['source'];target=OUT/(source.stem+'.ogv')
        assert hashlib.sha256(source.read_bytes()).hexdigest()==clip['sha256'],f'unreviewed source: {source.name}'
        if not args.check:
            subprocess.run(['ffmpeg','-v','error','-y','-i',str(source),'-map','0:v:0',
                '-vf','scale=1280:720:flags=lanczos,setsar=1','-fps_mode','passthrough',
                '-c:v','libtheora','-q:v','9','-g',str(clip['fps']*2),'-an',str(target)],check=True)
        actual=probe(target)
        # Theora may represent identical consecutive pictures as compact repeat
        # packets. ffprobe counts decoded pictures, not their full timeline;
        # FFmpeg versions differ in whether those repeated pictures are counted.
        # Preserve the hashed source and runtime timeline, require a real
        # decoded picture for at least 90% of source frames, then reconstruct
        # the CFR timeline below for the existing motion/boundary checks. Ogg's
        # terminal granule can round by one frame; longer truncation is rejected.
        assert math.ceil(clip['frames']*.9)<=actual['frames']<=clip['frames'],(source.name,'decoded picture coverage',actual)
        assert abs(round(actual['duration']*clip['fps'])-clip['frames'])<=1,(source.name,'timeline frame coverage',actual)
        assert (actual['width'],actual['height'])==(1280,720),(source.name,actual)
        assert abs(actual['fps']-clip['fps'])<.001,(source.name,actual)
        assert abs(actual['duration']-clip['frames']/clip['fps'])<=1.0/clip['fps']+.0001,(source.name,actual)
        assert 10_000<target.stat().st_size<20_000_000,target
        decoded=motion_frames(target,clip['frames'],clip['fps'])
        boundary=delta(previous,decoded[0]) if previous is not None else 0.
        loop=delta(decoded[-1],decoded[0])
        largest=max(delta(a,b) for a,b in zip(decoded,decoded[1:]))
        assert boundary<.8,(target.name,'discontinuous scene boundary',boundary)
        if index in [1,3]:assert loop<.8,(target.name,'discontinuous reading loop',loop)
        assert largest<2.5,(target.name,'abrupt frame change',largest)
        previous=decoded[-1]
        report.append({'file':target.name,**actual,'timeline_frames':len(decoded),'expected_frames':clip['frames'],'bytes':target.stat().st_size,
            'boundary_delta':boundary,'loop_delta':loop,'max_frame_delta':largest,
            'sha256':hashlib.sha256(target.read_bytes()).hexdigest()})
        print(f"INTRO VIDEO: {target.name} {len(decoded)} timeline frames ({actual['frames']} decoded pictures) @ {actual['fps']:g}, {actual['width']}x{actual['height']}",flush=True)
        print(f'INTRO MOTION: boundary={boundary:.4f}, loop={loop:.4f}, max-frame={largest:.4f}',flush=True)
    (OUT/'compiled.json').write_text(json.dumps({'artwork_version':manifest['artwork_version'],'clips':report},indent=2)+'\n')
    print('INTRO VIDEOS: PASS (4 complete clips)',flush=True)

if __name__=='__main__':main()
