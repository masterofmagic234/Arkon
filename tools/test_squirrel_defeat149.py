#!/usr/bin/env python3
"""Offline full-skin regression: identity, live clips and articulated defeats.
Uses all vertices, all 55 authored poses, and per-frame skin displacement.
Native runtime/terrain acceptance lives in squirrel_defeat149_test.gd.
"""
import hashlib,json,subprocess,sys,tempfile
from pathlib import Path
import numpy as np
import prepare_squirrel_rigs as r
from author_squirrel_defeat149 import signature,payload

def check(ok,why):
 if not ok:raise AssertionError(why)

def audit(kind,path):
 g,b=r.parse(path)
 baseline=subprocess.check_output(['git','show','24e0334:'+str(path.relative_to(r.ROOT))],cwd=r.ROOT)
 with tempfile.NamedTemporaryFile(suffix='.glb') as f:
  f.write(baseline);f.flush();old,ob=r.parse(f.name)
 check(signature(g,b)==signature(old,ob),kind+' living animation changed')
 for mg,mo in zip(g['meshes'],old['meshes']):
  for p,op in zip(mg['primitives'],mo['primitives']):
   for key in p['attributes']:check(payload(g,b,p['attributes'][key])==payload(old,ob,op['attributes'][key]),kind+' changed '+key)
   check(payload(g,b,p['indices'])==payload(old,ob,op['indices']),kind+' triangles changed')
 for im,oi in zip(g['images'],old['images']):
  bv=g['bufferViews'][im['bufferView']];ov=old['bufferViews'][oi['bufferView']]
  check(b[bv.get('byteOffset',0):bv.get('byteOffset',0)+bv['byteLength']]==ob[ov.get('byteOffset',0):ov.get('byteOffset',0)+ov['byteLength']],kind+' texture changed')
 check(g['nodes']==old['nodes'],kind+' rest bones/mesh transforms changed')
 skin=g['skins'][0];check(len(skin['joints'])==(87 if kind=='tank' else 31),kind+' joint count')
 p=g['meshes'][0]['primitives'][0];v=r.readacc(g,b,p['attributes']['POSITION']);j=r.readacc(g,b,p['attributes']['JOINTS_0']);w=r.readacc(g,b,p['attributes']['WEIGHTS_0']);hp=np.c_[v,np.ones(len(v))];ibm=r.readacc(g,b,skin['inverseBindMatrices']).reshape(-1,4,4).transpose(0,2,1)
 rest=r.fk(g);meshnode=next(i for i,n in enumerate(g['nodes']) if 'mesh'in n and 'skin'in n);restv=(rest[meshnode]@hp.T).T[:,:3];height=np.ptp(restv[:,1]);floor=restv[:,1].min();a=r.Author(g,kind);clips=[];finals=[]
 body_joints=np.array([not (any(token in g['nodes'][node]['name'].lower() for token in ['tail','head','neck','jaw']) or g['nodes'][node]['name'].lower().startswith('ear')) for node in skin['joints']]);body=(body_joints[j]*w).sum(1)>.9
 for animation in g['animations']:
  name=animation['name']
  if not name.startswith('death'):continue
  outputs=[r.readacc(g,b,s['output']) for s in animation['samplers']];samples=len(outputs[0]);previous=None;maximum_step=0;min_y=0;chain_motion={};scale_tracks=0
  check(samples>=55,name+' insufficient samples')
  for ch in animation['channels']:
   node=ch['target']['node'];prop=ch['target']['path'];bone=g['nodes'][node]['name']
   if prop=='rotation' and bone in ['root','BoneRoot']:
    keys=outputs[ch['sampler']];check(np.max(np.abs(keys-keys[0]))<.00001,name+' rigid root fall')
   check(prop!='scale',name+' bone stretch')
   if prop=='rotation':
    vals=outputs[ch['sampler']];first=vals[0];angle=2*np.arccos(np.clip(np.abs(vals@first),0,1));chain_motion[bone]=float(angle.max())
  for frame in range(samples):
   pose={}
   for ch in animation['channels']:pose.setdefault(ch['target']['node'],{})[ch['target']['path']]=outputs[ch['sampler']][frame]
   world=r.fk(g,pose);matrices=np.array([world[n]@ibm[i] for i,n in enumerate(skin['joints'])]);dv=(np.einsum('nkij,nj->nki',matrices[j],hp)*w[:,:,None]).sum(1)[:,:3]
   min_y=min(min_y,float(dv[:,1].min()-floor))
   if previous is not None:maximum_step=max(maximum_step,float(np.linalg.norm(dv-previous,axis=1).max()))
   previous=dv
  check(min_y>-.0001,name+' floor penetration '+str(min_y))
  check(maximum_step<height*.20,name+' pose discontinuity '+str(maximum_step/height))
  for group in [['pelvis','Hip'],['spine','Spine01'],['chest','Spine02'],['head','Head'],['arm.fore.L','L_Forearm'],['leg.shin.R','R_Calf'],['fingers.L','L_Index1'],['tail.03','Tail03']]:
   check(max(chain_motion.get(n,0) for n in group)>.035,name+' static anatomical chain '+str(group))
  check(sum(v>.035 for v in chain_motion.values())>=20,name+' too few articulated bones')
  body_gap=float(previous[body,1].min()-floor)
  check(body_gap<height*.04,name+' body floats on tail-only support '+str(body_gap/height))
  finals.append(previous)
  clips.append({'name':name,'samples':samples,'articulated_bones':sum(v>.035 for v in chain_motion.values()),'maximum_vertex_step_fraction':maximum_step/height,'floor_penetration':max(0,-min_y),'final_body_support_gap':body_gap,'final_height_fraction':np.ptp(previous[:,1])/height})
 check(all(np.sqrt(np.mean((finals[i]-finals[k])**2))>height*.035 for i in range(1,len(finals)) for k in range(i+1,len(finals))),kind+' directional finals identical')
 return {'role':kind,'bones':len(skin['joints']),'vertices':len(v),'identity':'exact mesh, UV, normals, weights, textures and rest hierarchy preserved','living_clips_preserved':16,'clips':clips}

if __name__=='__main__':
 reports=[audit('scout',r.ROOT/'scout_rigged.glb'),audit('tank',r.ROOT/'assets/level1/characters/tank_squirrel.glb')]
 result={'result':'PASS','models':reports};print(json.dumps(result,indent=2))
 if len(sys.argv)>1:Path(sys.argv[1]).write_text(json.dumps(result,indent=2)+'\n')
 print('SQUIRREL DEFEAT149 OFFLINE: PASS')
