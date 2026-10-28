"""Independent PCM acceptance for the native staged sound recording.

python3 tools/check_woodland_audio_recording.py native-mix.avi native-audio-report.json --output mix-check.json
Requires FFmpeg, not NumPy/SciPy. This is deliberately not a gameplay claim.
"""
from pathlib import Path
import argparse,array,json,math,subprocess,sys

def check(ok,why):
    if not ok:raise AssertionError(why)
def db(x):return 20*math.log10(max(x,1e-12))
def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('recording',type=Path);p.add_argument('timeline',type=Path);p.add_argument('--output',type=Path,required=True);a=p.parse_args()
    timeline=json.loads(a.timeline.read_text());rate=48000
    raw=subprocess.check_output(['ffmpeg','-v','error','-i',str(a.recording),'-vn','-ac','2','-ar',str(rate),'-f','f32le','-'])
    samples=array.array('f',raw)
    if sys.byteorder!='little':samples.byteswap()
    check(len(samples)>rate*2*10,'native audio timeline was cut short')
    def region(start,end):return samples[round(start*rate)*2:round(end*rate)*2]
    def rms_channels(start,end):
        y=region(start,end);return [math.sqrt(sum(v*v for v in y[c::2])/max(1,len(y)//2))for c in [0,1]]
    times={}
    for e in timeline['events']:times.setdefault(e['kind'],[]).append(e['seconds'])
    check(timeline['dropped_paused']>=1,'no paused input rejection exercised')
    local_t=times['shoot'][0];left_t,right_t=times['enemy_shoot'][:2]
    local=rms_channels(local_t+.015,local_t+.22);left=rms_channels(left_t+.015,left_t+.22);right=rms_channels(right_t+.015,right_t+.22)
    check(min(local)>.01,'actual local weapon PCM missing')
    check(abs(local[0]-local[1])/max(local)<.03,'head-locked player weapon is off centre')
    check(left[0]>left[1]*1.25,'left enemy shot did not pan left')
    check(right[1]>right[0]*1.25,'right enemy shot did not pan right')
    peak=max(abs(v)for v in samples);check(db(peak)<=-.8,'overlapping shot mix exceeded the scene ceiling')
    burst=region(170/30+.015,170/30+.25);check(max(abs(v)for v in burst)>.8,'stress burst never reached the limiter')
    pause_peak=max(abs(v)for v in region(205/30+.2,235/30-.1));check(pause_peak<1e-5,'sound continued while gameplay was paused')
    mute_peak=max(abs(v)for v in region(9.2,9.9));check(mute_peak<1e-5,'sound continued after mute')
    report={'result':'PASS','decoded_seconds':len(samples)/(rate*2),'channels':2,'rate':rate,'peak_dbfs':db(peak),'local_channel_rms':local,'left_shot_channel_rms':left,'right_shot_channel_rms':right,'left_ratio':left[0]/left[1],'right_ratio':right[1]/right[0],'pause_peak':pause_peak,'mute_peak':mute_peak,'scope':'Actual Godot native mixer PCM, including listener panning, overload limiting, pause and mute. Staged effects, not a full gameplay replay or subjective listening.'}
    a.output.write_text(json.dumps(report,indent=2)+'\n');print('WOODLAND AUDIO RECORDING: PASS — real stereo positions, centred player shot, overload ceiling and silent pause/mute')
if __name__=='__main__':main()
