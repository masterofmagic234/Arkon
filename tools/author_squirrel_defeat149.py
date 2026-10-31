#!/usr/bin/env python3
"""Replace only defeat clips in reviewed 1.47 skins; preserve every living clip.

No Blender/Godot import or network required. Actual weighted vertices provide
floor correction. Existing meshes, textures, UVs, joints and weights survive
byte-for-byte at accessor/image level. Outputs are deterministic.
"""
import copy, hashlib, json, sys
from pathlib import Path
import prepare_squirrel_rigs as rig
import numpy as np

def contact_bank(g,b):
 """Lower skin envelope, authored at 30Hz with each actual weighted surface.
 Grid cells keep their four lowest vertices; runtime rays are cached by X/Z.
 """
 primitive=g['meshes'][0]['primitives'][0];attrs=primitive['attributes']
 v=rig.readacc(g,b,attrs['POSITION']);j=rig.readacc(g,b,attrs['JOINTS_0']);w=rig.readacc(g,b,attrs['WEIGHTS_0'])
 hp=np.c_[v,np.ones(len(v))];skin=g['skins'][0];ibm=rig.readacc(g,b,skin['inverseBindMatrices']).reshape(-1,4,4).transpose(0,2,1)
 rest=rig.fk(g);meshnode=next(i for i,n in enumerate(g['nodes']) if 'mesh' in n and 'skin' in n)
 restv=(rest[meshnode]@hp.T).T[:,:3];floor=restv[:,1].min();height=np.ptp(restv[:,1]);names={n.get('name'):i for i,n in enumerate(g['nodes'])};anchor=rest[names.get('pelvis',names.get('Pelvis'))][:3,3].copy();anchor[1]=floor
 clips={}
 for a in g['animations']:
  if not a['name'].startswith('death'):continue
  poses=[];count=g['accessors'][a['samplers'][0]['input']]['count'];values=[rig.readacc(g,b,s['output']) for s in a['samplers']]
  for frame in range(count):
   pose={}
   for ch in a['channels']:pose.setdefault(ch['target']['node'],{})[ch['target']['path']]=values[ch['sampler']][frame]
   world=rig.fk(g,pose);m=np.array([world[n]@ibm[i] for i,n in enumerate(skin['joints'])]);dv=(np.einsum('nkij,nj->nki',m[j],hp)*w[:,:,None]).sum(1)[:,:3]-anchor
   # .09 of source height is a small local support patch, not a mesh bbox.
   cells=np.floor(dv[:,[0,2]]/(height*.09)).astype(int);order=np.argsort(dv[:,1]);seen=set();points=[]
   for k in order:
    key=tuple(cells[k])
    if key not in seen:seen.add(key);points.append(np.round(dv[k]/height,5).tolist())
   poses.append(points)
  clips[a['name']]=poses
 return {'clips':clips,'sample_hz':30,'duration':1.8,'coordinates':'actor-relative, divided by original weighted rest height'}

def payload(g,b,index):
 a=g['accessors'][index];v=g['bufferViews'][a['bufferView']]
 return bytes(b[v.get('byteOffset',0):v.get('byteOffset',0)+v['byteLength']])

def signature(g,b):
 return {a['name']:hashlib.sha256(b''.join(payload(g,b,s[k]) for s in a['samplers'] for k in ['input','output'])+json.dumps(a['channels'],sort_keys=True).encode()).hexdigest() for a in g['animations'] if not a['name'].startswith('death')}

def main():
 records=[];contacts={}
 tank_only='--tank-only' in sys.argv
 if tank_only:
  prior=json.loads((rig.ROOT/'assets/level1/characters/rig149-provenance.json').read_text())
  contacts=json.loads((rig.ROOT/'assets/level1/characters/defeat149-contacts.json').read_text())
 for kind,path in [('scout',rig.ROOT/'scout_rigged.glb'),('tank',rig.ROOT/'assets/level1/characters/tank_squirrel.glb')]:
  if tank_only and kind=='scout':records.append(next(row for row in prior['models'] if row['model']=='scout'));continue
  original=path.read_bytes();g,b=rig.parse(path);living=signature(g,b)
  g['animations']=[a for a in g['animations'] if not a['name'].startswith('death')]
  rig.animate(g,b,kind,only_defeat=True)
  temporary=path.with_name(path.name+'.defeat149.tmp');rig.compact(g,b,temporary);temporary.replace(path)
  gg,bb=rig.parse(path);assert signature(gg,bb)==living,'Living clips changed'
  contacts[kind]=contact_bank(gg,bb)
  record=rig.report_model(path,kind,rig.SCOUT_SOURCE if kind=='scout' else rig.TANK_SOURCE)
  record['path']=str(path.relative_to(rig.ROOT));record['runtime_path']='res://'+record['path']
  reviewed=json.loads((rig.ROOT/'assets/level1/characters/rig147-provenance.json').read_text())
  record['previous_runtime_sha256']=next(item['sha256'] for item in reviewed['runtime'] if item['role']==kind);record['living_clip_payloads_preserved']=living;records.append(record)
 report={'version':149,'supersedes_runtime_hashes':'rig147-provenance.json (original source, skin and identity record retained)','tool':{'file':'tools/prepare_squirrel_rigs.py','sha256':hashlib.sha256(Path(rig.__file__).read_bytes()).hexdigest()},'refresh_tool':{'file':'tools/author_squirrel_defeat149.py','sha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest()},'models':records,'operations':['Preserve reviewed anatomical skins, all mesh/UV/texture accessors and 16 living animation payloads.','Replace root-roll death with knee buckle, pelvic collapse, arm brace, head/ear/finger and six-link tail settle.','Five 1.8s sampled directional clips; root orientation held constant at rest; no scale animation, physics ragdoll or runtime skin editing.','Every defeat keys every joint at authored/rest pose, releasing prior aim, run pelvis, toe and finger transforms through the live transition.','Guardian defeat arms use minimal rest-space swing to preserve forearm volume under deep elbow bends; original skin, bone lengths and elbow/paw targets remain intact.','Offline real-skin floor contact; runtime limited ground support adjustment and pose-continuous transition.']}
 contact_path=rig.ROOT/'assets/level1/characters/defeat149-contacts.json'
 temporary=contact_path.with_name(contact_path.name+'.tmp');temporary.write_text(json.dumps(contacts,separators=(',',':'))+'\n');temporary.replace(contact_path)
 report['contact_envelope']={'file':str(contact_path.relative_to(rig.ROOT)),'sha256':hashlib.sha256(contact_path.read_bytes()).hexdigest(),'bytes':contact_path.stat().st_size,'sampling':'30 Hz; lowest real weighted vertex per small XZ support patch; cached static ground rays only during collapse'}
 provenance=rig.ROOT/'assets/level1/characters/rig149-provenance.json';temporary=provenance.with_name(provenance.name+'.tmp');temporary.write_text(json.dumps(report,indent=2)+'\n');temporary.replace(provenance)
 print(json.dumps({'result':'BUILT','models':[{k:r[k] for k in ['model','bytes','bones','vertices','triangles','max_weight_error']} for r in records]},indent=2))

if __name__=='__main__':main()
