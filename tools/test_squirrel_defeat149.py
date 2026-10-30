#!/usr/bin/env python3
"""Offline full-skin regression: identity, live clips and articulated defeats.
Scout retains exact149 identity. Guardian154 replaces its rig and clips while
preserving supplied bind sculpt/UV/textures. Both use every vertex, all55
articulated defeat poses, and per-frame skin displacement.
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
 fresh_guardian=kind=='tank'
 if fresh_guardian:
  manifest=json.loads((r.ROOT/'assets/level1/characters/rig154-provenance.json').read_text())
  check(manifest['version']==154 and manifest['inherited_bones']==0 and manifest['inherited_clips']==0 and not manifest['inherited_weights'],'guardian154 retained inherited rig data')
  check(manifest['runtime_sha256']==hashlib.sha256(path.read_bytes()).hexdigest(),'guardian154 manifest does not describe actual runtime GLB')
  check(manifest['tool_sha256']==hashlib.sha256((r.ROOT/manifest['tool']).read_bytes()).hexdigest(),'guardian154 authoring source differs from manifest')
  check(manifest['mesh_source_sha256']==hashlib.sha256((r.ROOT/manifest['mesh_source']).read_bytes()).hexdigest(),'guardian154 unskinned source differs from manifest')
  check(manifest['contacts_sha256']==hashlib.sha256((r.ROOT/'assets/level1/characters/defeat149-contacts.json').read_bytes()).hexdigest(),'guardian154 contact bank differs from manifest')
  extras=g.get('extras',{}).get('acorn_hunter_rig',{})
  check(extras.get('version')==154 and extras.get('source_skeleton_preserved') is False and extras.get('source_weights_preserved') is False and extras.get('source_animations_preserved') is False,'guardian154 runtime lacks explicit fresh-rig identity')
  current_signature=signature(g,b);old_signature=signature(old,ob)
  check(set(current_signature)==set(old_signature),'guardian154 living clip inventory changed')
  check(all(current_signature[name]!=old_signature[name] for name in current_signature),'guardian154 reused an old living clip payload')
 else:check(signature(g,b)==signature(old,ob),kind+' living animation changed')
 for mg,mo in zip(g['meshes'],old['meshes']):
  for p,op in zip(mg['primitives'],mo['primitives']):
   unchanged=['TEXCOORD_0'] if fresh_guardian else p['attributes']
   for key in unchanged:check(payload(g,b,p['attributes'][key])==payload(old,ob,op['attributes'][key]),kind+' changed '+key)
   check(payload(g,b,p['indices'])==payload(old,ob,op['indices']),kind+' triangles changed')
   if fresh_guardian:
    for key in ['JOINTS_0','WEIGHTS_0']:check(payload(g,b,p['attributes'][key])!=payload(old,ob,op['attributes'][key]),'guardian154 reused inherited '+key)
    old_mesh=next(i for i,n in enumerate(old['nodes']) if 'mesh' in n and 'skin' in n)
    ov=r.readacc(old,ob,op['attributes']['POSITION']);canonical=(r.fk(old)[old_mesh]@np.c_[ov,np.ones(len(ov))].T).T[:,:3]
    new_mesh=next(i for i,n in enumerate(g['nodes']) if 'mesh' in n and 'skin' in n)
    nv=r.readacc(g,b,p['attributes']['POSITION']);new_canonical=(r.fk(g)[new_mesh]@np.c_[nv,np.ones(len(nv))].T).T[:,:3]
    check(canonical.shape==new_canonical.shape and np.max(abs(canonical-new_canonical))<.001,'guardian154 changed supplied bind sculpt beyond ground-origin normalization')
 for im,oi in zip(g['images'],old['images']):
  bv=g['bufferViews'][im['bufferView']];ov=old['bufferViews'][oi['bufferView']]
  check(b[bv.get('byteOffset',0):bv.get('byteOffset',0)+bv['byteLength']]==ob[ov.get('byteOffset',0):ov.get('byteOffset',0)+ov['byteLength']],kind+' texture changed')
 if not fresh_guardian:check(g['nodes']==old['nodes'],kind+' rest bones/mesh transforms changed')
 skin=g['skins'][0]
 if fresh_guardian:
  names={n.get('name'):i for i,n in enumerate(g['nodes'])};parents=r.hierarchy(g)
  check('Waist' not in names and 'Hip' not in names,'guardian154 kept inherited split torso hierarchy')
  for chain in [['BoneRoot','Pelvis','Spine01','Spine02','Neck','Head'],['Spine02','Scapula.L','L_Upperarm','L_Forearm','L_Hand'],['Spine02','Scapula.R','R_Upperarm','R_Forearm','R_Hand'],['Pelvis','L_Thigh','L_Calf','L_Foot'],['Pelvis','R_Thigh','R_Calf','R_Foot']]:
   check(all(name in names for name in chain),'guardian154 missing chain '+str(chain))
   check(all(parents[names[child]]==names[parent] for parent,child in zip(chain,chain[1:])),'guardian154 disconnected chain '+str(chain))
  check([g['nodes'][i]['name'] for i in skin['joints']]==manifest['bones'],'guardian154 runtime hierarchy does not match its source manifest')
 else:check(len(skin['joints'])==31,kind+' joint count')
 p=g['meshes'][0]['primitives'][0];v=r.readacc(g,b,p['attributes']['POSITION']);j=r.readacc(g,b,p['attributes']['JOINTS_0']);w=r.readacc(g,b,p['attributes']['WEIGHTS_0']);hp=np.c_[v,np.ones(len(v))];ibm=r.readacc(g,b,skin['inverseBindMatrices']).reshape(-1,4,4).transpose(0,2,1)
 rest=r.fk(g);meshnode=next(i for i,n in enumerate(g['nodes']) if 'mesh'in n and 'skin'in n);restv=(rest[meshnode]@hp.T).T[:,:3];height=np.ptp(restv[:,1]);floor=restv[:,1].min();clips=[];finals=[]
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
  for group in [['pelvis','Hip','Pelvis'],['spine','Spine01'],['chest','Spine02'],['head','Head'],['arm.fore.L','L_Forearm'],['leg.shin.R','R_Calf'],['fingers.L','L_Index1','L_Fingers'],['tail.03','Tail03']]:
   check(max(chain_motion.get(n,0) for n in group)>.035,name+' static anatomical chain '+str(group))
  check(sum(v>.035 for v in chain_motion.values())>=20,name+' too few articulated bones')
  body_gap=float(previous[body,1].min()-floor)
  check(body_gap<height*.04,name+' body floats on tail-only support '+str(body_gap/height))
  finals.append(previous)
  clips.append({'name':name,'samples':samples,'articulated_bones':sum(v>.035 for v in chain_motion.values()),'maximum_vertex_step_fraction':maximum_step/height,'floor_penetration':max(0,-min_y),'final_body_support_gap':body_gap,'final_height_fraction':np.ptp(previous[:,1])/height})
 check(all(np.sqrt(np.mean((finals[i]-finals[k])**2))>height*.035 for i in range(1,len(finals)) for k in range(i+1,len(finals))),kind+' directional finals identical')
 return {'role':kind,'bones':len(skin['joints']),'vertices':len(v),'identity':'retained bind sculpt/UV/triangles/textures; independently authored154 skeleton, weights and clips' if fresh_guardian else 'exact mesh, UV, normals, weights, textures and rest hierarchy preserved','living_clips_preserved':0 if fresh_guardian else 16,'clips':clips}

if __name__=='__main__':
 reports=[audit('scout',r.ROOT/'scout_rigged.glb'),audit('tank',r.ROOT/'assets/level1/characters/tank_squirrel.glb')]
 result={'result':'PASS','models':reports};print(json.dumps(result,indent=2))
 if len(sys.argv)>1:Path(sys.argv[1]).write_text(json.dumps(result,indent=2)+'\n')
 print('SQUIRREL DEFEAT149 OFFLINE: PASS')
