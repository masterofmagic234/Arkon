#!/usr/bin/env python3
"""Guard the approximate cross-renderer art match; preserve the raw frames.

Compatibility has sRGB light accumulation, different shadow filtering and LDR
limits. This is not a pixel-identity or device-performance test. It catches
missing/clipped views, large palette/exposure drift and changed scene workload.
"""
import argparse,json
from pathlib import Path
from PIL import Image,ImageChops,ImageStat

def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('reference',type=Path)
    parser.add_argument('compatibility',type=Path)
    args=parser.parse_args()
    reference=json.loads((args.reference/'renderer.json').read_text())
    production=json.loads((args.compatibility/'renderer.json').read_text())
    failures=[];views=[]
    if reference['renderer']!='forward_plus' or production['renderer']!='gl_compatibility':failures.append('wrong active renderers')
    if not reference['baked'] or not production['baked']:failures.append('missing 1.40 bake')
    expected={'entry','concept','pond','conservatory','upper','p60-entry','p60-140','scout','guardian'}
    arows={row['view']:row for row in reference['views']}
    brows={row['view']:row for row in production['views']}
    if set(arows)!=expected or set(brows)!=expected:failures.append('incomplete camera coverage')
    for name in sorted(expected & set(arows) & set(brows)):
        a=Image.open(args.reference/(name+'.png')).convert('RGB')
        b=Image.open(args.compatibility/(name+'.png')).convert('RGB')
        if a.size!=b.size:failures.append(name+': dimensions differ');continue
        amean=ImageStat.Stat(a).mean;bmean=ImageStat.Stat(b).mean
        mae=sum(ImageStat.Stat(ImageChops.difference(a,b)).mean)/3
        channel_drift=max(abs(x-y) for x,y in zip(amean,bmean))
        luminance_drift=abs(sum((x-y)*w for x,y,w in zip(amean,bmean,[.2126,.7152,.0722])))/255
        row={'view':name,'mean_error_255':mae,'max_mean_channel_drift_255':channel_drift,'mean_luminance_drift':luminance_drift,'reference_mean_rgb':amean,'compatibility_mean_rgb':bmean}
        views.append(row)
        if mae>24 or channel_drift>18 or luminance_drift>.06:failures.append(name+': exposure/palette mismatch exceeds cross-renderer tolerance')
        for source in [arows[name],brows[name]]:
            if source['calls']>550 or source['triangles']>260000:failures.append(name+': render workload exceeded')
        if abs(arows[name]['triangles']-brows[name]['triangles'])>max(600,arows[name]['triangles']*.01):failures.append(name+': geometry coverage changed')
        if abs(arows[name]['scale_3d']-brows[name]['scale_3d'])>.0001 or arows[name]['msaa']!=brows[name]['msaa']:failures.append(name+': resolution/MSAA changed')
    report={'reference_renderer':reference['renderer'],'production_renderer':production['renderer'],'views':views,'failures':failures,'note':'Approximate 1.40 art match across different lighting pipelines; raw frames retained. No pixel-identity or Adreno FPS claim.'}
    path=args.compatibility.parent/'comparison.json';path.write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps(report,indent=2))
    raise SystemExit(bool(failures))

if __name__=='__main__':main()
