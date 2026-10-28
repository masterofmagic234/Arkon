"""Inspect the shipped PCM, not just the sound-bank declarations. Stdlib+FFmpeg."""
from pathlib import Path
import array,hashlib,json,math,subprocess,sys,wave
ROOT=Path(__file__).resolve().parents[1]
PROVENANCE=ROOT/'assets/level1/audio/polished147/PROVENANCE.json'

def rms(a):return math.sqrt(sum(x*x for x in a)/max(1,len(a)))
def db(x):return 20*math.log10(max(x,1e-12))
def check(ok,why):
    if not ok:raise AssertionError(why)

def main():
    p=json.loads(PROVENANCE.read_text());rows=[];pcm_hashes=set();data_by_name={}
    check(hashlib.sha256((ROOT/p['tool']).read_bytes()).hexdigest()==p['tool_sha256'],'offline editing tool differs from provenance')
    check(p['generator']['total_credits']==28,'authoring budget metadata changed')
    check(len(p['assets'])==35,'prepared inventory changed')
    for source in p['generator']['takes']:
        path=ROOT/source['source_file'];check(hashlib.sha256(path.read_bytes()).hexdigest()==source['sha256'],'immutable original take changed: '+str(path))
    for record in p['assets']:
        path=ROOT/record['file'];raw=path.read_bytes();check(hashlib.sha256(raw).hexdigest()==record['sha256'],'prepared waveform/provenance mismatch: '+str(path))
        importer=Path(str(path)+'.import').read_text()
        check('compress/mode=0' in importer and 'force/8_bit=false' in importer and 'edit/normalize=false' in importer,'lossless authored import contract changed: '+str(path))
        with wave.open(str(path),'rb') as w:
            check(w.getsampwidth()==2 and w.getframerate()==44100,'unexpected PCM encoding: '+str(path))
            channels=w.getnchannels();samples=w.getnframes();payload=w.readframes(samples)
        values=array.array('h',payload)
        if sys.byteorder!='little':values.byteswap()
        a=[x/32768 for x in values]
        check(samples==record['samples'] and channels==record['channels'],'header duration/channels differ from provenance')
        check(.20<=samples/44100<=4.0,'empty/unbounded source silence: '+str(path))
        check(max(abs(x)for x in a)<.505,'PCM headroom lost: '+str(path))
        check(db(rms(a))>-45,'inaudibly empty generated take: '+str(path))
        # Decode and oversample through an independent resampler. This catches
        # intersample overshoots hidden by an integer-sample peak check.
        out=subprocess.check_output(['ffmpeg','-v','error','-i',str(path),'-af','aresample=176400:filter_size=32','-f','f32le','-'])
        oversampled=array.array('f',out)
        if sys.byteorder!='little':oversampled.byteswap()
        true_peak=max(abs(x)for x in oversampled)
        check(db(true_peak)<=-5.7,'decoded true-peak margin lost: '+str(path))
        dc=max(abs(sum(a[c::channels])/samples)for c in range(channels))
        check(dc<.003,'DC offset could click: '+str(path))
        if record['loop']:
            edge=max(abs(a[c]-a[-channels+c])for c in range(channels))
            check(edge<.025,'audible hard loop seam: '+str(path))
        else:
            check(max(abs(x)for x in a[:channels]+a[-channels:])<.001,'one-shot edge click: '+str(path))
        h=hashlib.sha256(payload).hexdigest();check(h not in pcm_hashes,'identical duplicate variation: '+str(path));pcm_hashes.add(h)
        data_by_name[path.stem]=a
        rows.append({'file':record['file'],'seconds':samples/44100,'channels':channels,'true_peak_dbfs':db(true_peak),'rms_dbfs':db(rms(a)),'pcm_sha256':h})
    for family in ['stone','grass','soil']:
        names=[x for x in data_by_name if x.startswith('step_'+family+'_')]
        check(len(names)>=3,'not enough original footfall variations for '+family)
    report={'result':'PASS','files':len(rows),'actual_pcm_bytes':sum((ROOT/a['file']).stat().st_size for a in rows),'max_true_peak_dbfs':max(a['true_peak_dbfs']for a in rows),'assets':rows,'scope':'Actual PCM/independent decode/oversampling, immutable sources, variation, level and seam checks. Subjective listening is not inferred.'}
    if '--output' in sys.argv:
        i=sys.argv.index('--output');Path(sys.argv[i+1]).write_text(json.dumps(report,indent=2)+'\n')
    print('WOODLAND AUDIO ASSETS: PASS — 35 decoded PCM takes, true-peak headroom, source pins, variation and click-free loops')

if __name__=='__main__':main()
