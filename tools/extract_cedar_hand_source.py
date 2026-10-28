"""Original extraction code; inputs are explicitly CC0 asset data, not GPL code."""
import json,hashlib,argparse
from pathlib import Path
parser=argparse.ArgumentParser(description='Extract only CC0 left-hand/forearm data, never upstream code.')
parser.add_argument('--upstream-dir',type=Path,required=True)
parser.add_argument('--output-dir',type=Path,default=Path(__file__).resolve().parents[1]/'art/level1/cedar/source')
args=parser.parse_args();p=args.upstream_dir;dest=args.output_dir;dest.mkdir(parents=True,exist_ok=True)
expected={'base.obj':'8e761e6624b8f54536409135d1636da63b32486a90d4897f84e121d144f6fb4c','default_weights.mhw':'0f3641d651ae3d00ad6b4ccee43142edb109d3bd909d27d9e4139ef1beed8625','default.mhskel':'99f179bce0aa850b45d4191a1d0d234c5851f881c057439470ded3bddf729a24','LICENSE.ASSETS.md':'f6089cba01cb570a24712b41ab8a586ccd3cc5ef53dc266ca50b95c288956d2c'}
for name,sha in expected.items():assert hashlib.sha256((p/name).read_bytes()).hexdigest()==sha, name+' upstream checksum differs'
V=[];groups={};group=''
for line in (p/'base.obj').read_text().splitlines():
 if line.startswith('v '): V.append([float(n) for n in line.split()[1:4]])
 elif line.startswith('g '): group=line[2:];groups[group]=[]
 elif line.startswith('f '): groups[group].append([int(n.split('/')[0])-1 for n in line.split()[1:]])
rig=json.loads((p/'default.mhskel').read_text()); weights=json.loads((p/'default_weights.mhw').read_text())['weights']
faces=[f for f in groups['body'] if all(V[i][0]>3.3 for i in f)];ids=sorted({i for f in faces for i in f});mapping={i:j for j,i in enumerate(ids)}
def avg(ids):return [sum(V[i][a] for i in ids)/len(ids) for a in range(3)]
bones={n:b for n,b in rig['bones'].items() if n.endswith('.L') and any(k in n for k in ['finger','metacarpal','wrist','lowerarm','upperarm'])}
needed={j for b in bones.values() for j in [b['head'],b['tail']]}
source={'license':'CC0-1.0','vertices':[V[i] for i in ids],'faces':[[mapping[i] for i in f] for f in faces],'original_vertex_ids':ids,'joints':{j:avg(rig['joints'][j]) for j in sorted(needed)},'helpers':{j:avg(sorted({i for f in groups[j] for i in f})) for j in ['joint-l-hand','joint-l-elbow','joint-l-finger-2-1','joint-l-finger-3-1','joint-l-finger-5-1']},'bones':bones,'weights':{n:[[mapping[i],amount] for i,amount in entries if i in mapping and amount>0] for n,entries in weights.items() if n in bones}}
(dest/'left_hand_forearm.json').write_text(json.dumps(source,separators=(',',':'))+'\n')
(dest/'LICENSE.CC0.txt').write_bytes((p/'LICENSE.ASSETS.md').read_bytes())
(dest/'.gdignore').write_text('')
commit='a8bc2d54ff0ac92e78ff71431b1023eda42bf482';base='https://raw.githubusercontent.com/makehumancommunity/makehuman/'+commit+'/'
paths={'base.obj':'makehuman/data/3dobjs/base.obj','default_weights.mhw':'makehuman/data/rigs/default_weights.mhw','default.mhskel':'makehuman/data/rigs/default.mhskel','LICENSE.ASSETS.md':'LICENSE.ASSETS.md'}
manifest={'project':'MakeHuman Community','commit':commit,'license':'CC0-1.0','scope':'Only left hand and forearm body topology, joint centres and local weights extracted. No upstream program code used.','upstream_files':[{'file':n,'url':base+rel,'sha256':hashlib.sha256((p/n).read_bytes()).hexdigest()} for n,rel in paths.items()],'extracted_file':'art/level1/cedar/source/left_hand_forearm.json','extracted_sha256':hashlib.sha256((dest/'left_hand_forearm.json').read_bytes()).hexdigest(),'license_file':'art/level1/cedar/source/LICENSE.CC0.txt','license_sha256':hashlib.sha256((dest/'LICENSE.CC0.txt').read_bytes()).hexdigest(),'source_vertices':len(ids),'source_faces':len(faces),'extraction':'Body-group faces with all original vertex x > 3.3; original vertex indices retained for audit. Rest joint/helper centres are arithmetic means from official rig data.'}
(dest/'SOURCES.json').write_text(json.dumps(manifest,indent=2)+'\n');print(json.dumps({k:manifest[k] for k in ['extracted_sha256','license_sha256','source_vertices','source_faces']},indent=2))
