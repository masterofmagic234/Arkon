#!/usr/bin/env python3
"""Offline anatomical squirrel skinning and complete sampled animation library.

Preserves the supplied mesh/UV/texture identities. Scout: replaces the old wrong-
axis rigid skin. Tank: preserves its 78-joint source skeleton and finger weights,
adds a dedicated tail/ear/jaw rig, and removes tail-to-upper-arm contamination.
NumPy/SciPy are offline authoring dependencies; Godot only loads the finished GLB.
"""
from __future__ import annotations
import argparse, copy, hashlib, json, math, struct, subprocess, sys
from pathlib import Path
import numpy as np
from scipy.sparse import coo_matrix
from scipy.sparse.csgraph import dijkstra
from scipy.spatial import cKDTree
from scipy.spatial.transform import Rotation as Rot
ROOT=Path(__file__).resolve().parents[1]
SCOUT_SOURCE=ROOT/'Meshy_AI_Acorn_Guardian_0923182156_texture (1).glb'
TANK_SOURCE=ROOT/'assets/level1/characters/source/tank_original.glb'
CLIPS={'idle':2.4,'walk':.72,'run':.46,'turn_left':.7,'turn_right':.7,'alert':.65,'aim':1.2,'fire':.52,'melee':.62,'charge_tell':.85,'charge':1.05,'stomp_tell':.75,'stomp':.65,'recover':1.2,'hit':.24,'stunned':1.1,'death':1.8,'death_forward':1.8,'death_back':1.8,'death_left':1.8,'death_right':1.8}

def parse(path):
 raw=Path(path).read_bytes();size,kind=struct.unpack_from('<II',raw,12);return json.loads(raw[20:20+size]),bytearray(raw[28+size:])
def write(path,g,b):
 g['buffers'][0]['byteLength']=len(b);b.extend(b'\0'*(-len(b)%4));js=json.dumps(g,separators=(',',':'),ensure_ascii=False).encode();js+=b' '*(-len(js)%4)
 Path(path).parent.mkdir(parents=True,exist_ok=True);Path(path).write_bytes(struct.pack('<4sII',b'glTF',2,28+len(js)+len(b))+struct.pack('<II',len(js),0x4e4f534a)+js+struct.pack('<II',len(b),0x004e4942)+b)
def readacc(g,b,i):
 a=g['accessors'][i];v=g['bufferViews'][a['bufferView']];dt=np.dtype({5121:'u1',5123:'<u2',5125:'<u4',5126:'<f4'}[a['componentType']]);n={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4,'MAT4':16}[a['type']]
 return np.ndarray((a['count'],n),dtype=dt,buffer=b,offset=v.get('byteOffset',0)+a.get('byteOffset',0),strides=(v.get('byteStride',dt.itemsize*n),dt.itemsize)).copy()
def addacc(g,b,x,kind,ctype=5126,target=None):
 dtype={5121:'u1',5123:'<u2',5125:'<u4',5126:'<f4'}[ctype];x=np.asarray(x,dtype=dtype);b.extend(b'\0'*(-len(b)%4));off=len(b);raw=x.tobytes();b.extend(raw);v={'buffer':0,'byteOffset':off,'byteLength':len(raw)}
 if target:v['target']=target
 g.setdefault('bufferViews',[]).append(v);a={'bufferView':len(g['bufferViews'])-1,'componentType':ctype,'count':len(x),'type':kind}
 if kind=='SCALAR':a.update(min=[float(x.min())],max=[float(x.max())])
 if kind=='VEC3':a.update(min=x.min(axis=0).astype(float).tolist(),max=x.max(axis=0).astype(float).tolist())
 g.setdefault('accessors',[]).append(a);return len(g['accessors'])-1

def mat(node):
 if 'matrix'in node:return np.array(node['matrix']).reshape(4,4).T
 m=np.eye(4);m[:3,:3]=Rot.from_quat(node.get('rotation',[0,0,0,1])).as_matrix()@np.diag(node.get('scale',[1,1,1]));m[:3,3]=node.get('translation',[0,0,0]);return m

def hierarchy(g):
 return {c:i for i,n in enumerate(g['nodes']) for c in n.get('children',[])}
def fk(g,overrides=None):
 parents=hierarchy(g);cache={};overrides=overrides or {}
 def world(i):
  if i not in cache:
   n=g['nodes'][i];m=mat(n)
   if i in overrides:
    d=overrides[i]
    if 'rotation'in d:m[:3,:3]=Rot.from_quat(d['rotation']).as_matrix()@np.diag(n.get('scale',[1,1,1]))
    if 'translation'in d:m[:3,3]=d['translation']
   cache[i]=(world(parents[i]) if i in parents else np.eye(4))@m
  return cache[i]
 for i in range(len(g['nodes'])):world(i)
 return cache

def smoothstep(a,b,x):
 t=np.clip((x-a)/(b-a),0,1);return t*t*(3-2*t)
def segment_weights(vertices,segments):
 out=[]
 for a,b in segments:
  ab=b-a;t=np.clip(((vertices-a)@ab)/max(ab@ab,1e-9),0,1);d=((vertices-a-t[:,None]*ab)**2).sum(1)
  out.append(1/(d+.004)**2)
 w=np.stack(out,axis=1);return w/w.sum(axis=1,keepdims=True)

def smooth_skin(v,faces,weights,passes=4,equivalent_groups=None):
 # Weld only coincident POSITION samples for weights; do not weld the render
 # mesh or alter its UV/normal seams. Shared positions get identical skinning.
 _,inverse=np.unique(np.round(v*1e6).astype(np.int64),axis=0,return_inverse=True);n=inverse.max()+1;count=np.bincount(inverse)
 w=np.zeros((n,weights.shape[1]));np.add.at(w,inverse,weights);w/=count[:,None]
 edges=inverse[faces[:,[0,1,1,2,2,0]]].reshape(-1,2);edges=np.vstack([edges,edges[:,::-1],np.stack([np.arange(n),np.arange(n)],1)])
 adjacency=coo_matrix((np.ones(len(edges)),(edges[:,0],edges[:,1])),shape=(n,n)).tocsr();adjacency.data[:]=1;degree=np.asarray(adjacency.sum(1)).ravel()
 for _ in range(passes):w=.72*w+.28*(adjacency@w)/degree[:,None]
 weights=w[inverse]
 # Static finger children have the same skin matrix as their hand in these
 # clips. At a mixed limb/body boundary aggregate that equivalent group before
 # the four-weight budget, avoiding a discontinuous fifth-weight dropout.
 for representative,members in equivalent_groups or []:
  total=weights[:,members].sum(1);outside=1-total;mask=(outside>.035)&(total>.005)
  weights[np.ix_(mask,members)]=0;weights[mask,representative]=total[mask]
 j=np.argsort(weights,axis=1)[:,-4:][:,::-1];w=np.take_along_axis(weights,j,axis=1);w[w<.0005]=0;w/=w.sum(1,keepdims=True)
 return j.astype(np.uint16),w.astype(np.float32)

SCOUT_BONES=[
 ('root',None,(0,0,0)),('pelvis','root',(0,.52,.38)),('spine','pelvis',(0,.78,.40)),('chest','spine',(0,1.03,.43)),('neck','chest',(0,1.19,.49)),('head','neck',(.02,1.36,.55)),('jaw','head',(.01,1.25,.77)),
 ('ear.L','head',(-.18,1.57,.50)),('ear.R','head',(.18,1.57,.50)),
 ('arm.upper.L','chest',(-.23,1.01,.42)),('arm.fore.L','arm.upper.L',(-.38,.77,.42)),('hand.L','arm.fore.L',(-.49,.64,.43)),('fingers.L','hand.L',(-.53,.57,.45)),
 ('arm.upper.R','chest',(.23,1.01,.42)),('arm.fore.R','arm.upper.R',(.38,.77,.42)),('hand.R','arm.fore.R',(.49,.64,.43)),('fingers.R','hand.R',(.53,.57,.45)),
 ('leg.thigh.L','pelvis',(-.23,.49,.37)),('leg.shin.L','leg.thigh.L',(-.27,.26,.36)),('foot.L','leg.shin.L',(-.27,.075,.39)),('toe.L','foot.L',(-.27,.045,.57)),
 ('leg.thigh.R','pelvis',(.23,.49,.37)),('leg.shin.R','leg.thigh.R',(.27,.26,.36)),('foot.R','leg.shin.R',(.27,.075,.39)),('toe.R','foot.R',(.27,.045,.57)),
 ('tail.01','pelvis',(.03,.47,.15)),('tail.02','tail.01',(.10,.43,-.22)),('tail.03','tail.02',(.13,.72,-.59)),('tail.04','tail.03',(.13,1.12,-.58)),('tail.05','tail.04',(.13,1.36,-.32)),('tail.tip','tail.05',(.13,1.15,-.12)),
]

def build_scout(output):
 g,b=parse(SCOUT_SOURCE);g=copy.deepcopy(g);p=g['meshes'][0]['primitives'][0];v=readacc(g,b,p['attributes']['POSITION']);lo=v.min(0);hi=v.max(0);v=(v-[float((lo[0]+hi[0])/2),float(lo[1]),float((lo[2]+hi[2])/2)])*(1.85/(hi[1]-lo[1]));faces=readacc(g,b,p['indices']).reshape(-1,3)
 p['attributes']['POSITION']=addacc(g,b,v,'VEC3',target=34962)
 g['nodes']=[{'name':'ScoutMesh','mesh':0,'skin':0}];g['scenes']=[{'nodes':[0]}];g['scene']=0;names={};positions={}
 for name,parent,pos in SCOUT_BONES:
  i=len(g['nodes']);names[name]=i;positions[name]=np.array(pos,float);local=positions[name]-(positions[parent] if parent else np.zeros(3));g['nodes'].append({'name':name,'translation':local.tolist()})
  if parent:g['nodes'][names[parent]].setdefault('children',[]).append(i)
 g['scenes'][0]['nodes'].append(names['root']);joints=list(names.values());g['skins']=[{'name':'ScoutAnatomicalSkin147','joints':joints,'skeleton':names['root']}]
 ibm=[]
 for name in names:
  m=np.eye(4);m[:3,3]=-positions[name];ibm.append(m.T.reshape(-1))
 g['skins'][0]['inverseBindMatrices']=addacc(g,b,ibm,'MAT4')
 # Surface-geodesic regions keep a resting hand close to its haunch from
 # dragging the hip when lifted. Euclidean-only masks bleed across that narrow
 # contact; the actual mesh route through the shoulder separates the regions.
 unique,inverse=np.unique(np.round(v*1e6).astype(np.int64),axis=0,return_inverse=True)
 points=np.zeros((len(unique),3));np.add.at(points,inverse,v);points/=np.bincount(inverse)[:,None]
 edges=inverse[faces[:,[0,1,1,2,2,0]]].reshape(-1,2);edges=np.unique(np.sort(edges,axis=1),axis=0);length=np.linalg.norm(points[edges[:,0]]-points[edges[:,1]],axis=1)
 rows=np.r_[edges[:,0],edges[:,1]];cols=np.r_[edges[:,1],edges[:,0]];cost=np.r_[length,length];graph=coo_matrix((cost,(rows,cols)),shape=(len(points),len(points))).tocsr();tree=cKDTree(points)
 seeds=[[(0,.60,.59),(0,.90,.60),(0,.53,.14)],[(0,1.31,.83),(.10,1.48,.60)],[(0,.42,-.24),(.15,.90,-.74),(.14,1.42,-.50)],
        [(-.52,.50,.45),(-.42,.76,.42),(-.29,.96,.43)],[(.52,.50,.45),(.42,.76,.42),(.29,.96,.43)],
        [(-.27,.07,.49),(-.35,.35,.45)],[(.27,.07,.49),(.35,.35,.45)]]
 distances=[]
 for group in seeds:
  ids=tree.query(np.array(group))[1];dist=dijkstra(graph,indices=ids,directed=False).min(axis=0);fallback=np.min(np.linalg.norm(points[:,None,:]-np.array(group)[None,:,:],axis=2),axis=1)
  distances.append(np.where(np.isfinite(dist),dist,fallback+1.0))
 distances=np.stack(distances,axis=1)[inverse];score=np.exp(-np.clip(distances-distances.min(1,keepdims=True),0,10)/.055)
 x,y,z=v.T;score[:,1]*=smoothstep(1.04,1.25,y);score[:,2]*=smoothstep(.0,.18,-z)
 for idx,side in [(3,x<0),(4,x>=0)]:
  outer=smoothstep(.31,.445,abs(x));upper=smoothstep(.68,.90,y);score[:,idx]*=side*smoothstep(.40,.54,y)*(1-smoothstep(1.0,1.18,y))*(outer*(1-upper)+upper)*smoothstep(.14,.24,abs(x))
 for idx,side in [(5,x<0),(6,x>=0)]:score[:,idx]*=side*(1-smoothstep(.42,.68,y))*smoothstep(.06,.15,abs(x))
 score[:,2]+=1000*smoothstep(.0,.18,-z)*smoothstep(.45,.70,y)
 score/=score.sum(1,keepdims=True);torso,head,tail,arm_l,arm_r,leg_l,leg_r=score.T;weights=np.zeros((len(v),len(joints)))
 def assign(chain,blend,ends=None):
  segments=[]
  for i,name in enumerate(chain):
   start=positions[name];end=positions[chain[i+1]] if i+1<len(chain) else (np.array(ends) if ends is not None else start+np.array([0,.10,0]));segments.append((start,end))
  w=segment_weights(v,segments)
  for i,name in enumerate(chain):weights[:,joints.index(names[name])]+=w[:,i]*blend
 assign(['pelvis','spine','chest','neck'],torso,(0,1.37,.56))
 assign(['tail.01','tail.02','tail.03','tail.04','tail.05','tail.tip'],tail,(.13,1.04,-.06))
 for suffix,arm_blend,leg_blend in [('L',arm_l,leg_l),('R',arm_r,leg_r)]:
  assign(['arm.upper.'+suffix,'arm.fore.'+suffix,'hand.'+suffix,'fingers.'+suffix],arm_blend,positions['fingers.'+suffix]+np.array([0,-.04,.03]))
  assign(['leg.thigh.'+suffix,'leg.shin.'+suffix,'foot.'+suffix,'toe.'+suffix],leg_blend,positions['toe.'+suffix]+np.array([0,0,.09]))
 ear_l=smoothstep(1.48,1.62,y)*(1-smoothstep(-.03,.04,x));ear_r=smoothstep(1.48,1.62,y)*smoothstep(-.04,.03,x)
 jaw=smoothstep(.70,.83,z)*(1-smoothstep(1.27,1.37,y))*.55
 for name,blend in [('ear.L',ear_l),('ear.R',ear_r),('jaw',jaw)]:weights[:,joints.index(names[name])]+=head*blend
 weights[:,joints.index(names['head'])]+=head*np.clip(1-ear_l-ear_r-jaw,0,1);weights/=weights.sum(1,keepdims=True)
 ji,ww=smooth_skin(v,faces,weights,14);p['attributes']['JOINTS_0']=addacc(g,b,ji,'VEC4',5123,34962);p['attributes']['WEIGHTS_0']=addacc(g,b,ww,'VEC4',5126,34962)
 for material in g.get('materials',[]):material.setdefault('pbrMetallicRoughness',{}).update(metallicFactor=0,roughnessFactor=.92)
 add_frame(g,0,np.array([0,0,-.38]));g['animations']=[];animate(g,b,'scout');compact(g,b,output)
 return report_model(output,'scout',SCOUT_SOURCE)

def add_frame(g,angle,translation):
 scene=g['scenes'][g.get('scene',0)];old=scene['nodes'];i=len(g['nodes']);g['nodes'].append({'name':'AnatomicalFrame147','children':old,'rotation':Rot.from_euler('y',angle).as_quat().tolist(),'translation':translation.tolist()});scene['nodes']=[i]

def complete_tank(output):
 g,b=parse(output);skin=g['skins'][0];world=fk(g);names={n.get('name'):i for i,n in enumerate(g['nodes'])};pel=world[names['Pelvis']][:3,3];head=world[names['Head']][:3,3];front=head-pel;angle=-math.atan2(front[0],front[2]);R=Rot.from_euler('y',angle).as_matrix();translation=-R@np.array([pel[0],0,pel[2]]);add_frame(g,angle,translation);world=fk(g);meshnode=next(i for i,n in enumerate(g['nodes']) if'mesh'in n and'skin'in n);meshworld=world[meshnode]
 extra=[('Tail01','Pelvis',(-.02,.23,-.11)),('Tail02','Tail01',(-.13,.15,-.34)),('Tail03','Tail02',(-.16,.35,-.48)),('Tail04','Tail03',(-.16,.60,-.43)),('Tail05','Tail04',(-.13,.76,-.23)),('TailTip','Tail05',(-.10,.60,-.075)),('Ear.L','Head',(.085,.685,.22)),('Ear.R','Head',(-.085,.685,.22)),('Jaw','Head',(0,.515,.31))]
 for name,parent,pos in extra:
  desired=np.eye(4);desired[:3,3]=pos;local=np.linalg.inv(world[names[parent]])@desired;i=len(g['nodes']);g['nodes'].append({'name':name,'translation':local[:3,3].tolist(),'rotation':Rot.from_matrix(local[:3,:3]).as_quat().tolist()});g['nodes'][names[parent]].setdefault('children',[]).append(i);names[name]=i;skin['joints'].append(i);world[i]=desired
 oldibm=readacc(g,b,skin['inverseBindMatrices']);ibm=list(oldibm)
 for name,_,_ in extra:ibm.append((np.linalg.inv(world[names[name]])@meshworld).T.reshape(-1))
 skin['inverseBindMatrices']=addacc(g,b,ibm,'MAT4')
 p=g['meshes'][0]['primitives'][0];v=readacc(g,b,p['attributes']['POSITION']);faces=readacc(g,b,p['indices']).reshape(-1,3);vv=(meshworld@np.column_stack([v,np.ones(len(v))]).T).T[:,:3];oldj=readacc(g,b,p['attributes']['JOINTS_0']);oldw=readacc(g,b,p['attributes']['WEIGHTS_0']);weights=np.zeros((len(v),len(skin['joints'])))
 for k in range(4):np.add.at(weights,(np.arange(len(v)),oldj[:,k]),oldw[:,k])
 x,y,z=vv.T
 # Source humanoid auto-weights leak hands/upper arms onto the chest/acorn
 # harness. Refine those branch boundaries before preserving finger detail.
 arm_indices=[k for k,node in enumerate(skin['joints']) if any(token in g['nodes'][node].get('name','').lower() for token in ['upperarm','forearm','hand','pinky','ring','mid','index','thumb','elbow'])]
 inner=.075+.065*smoothstep(.12,.35,y);outer=inner+.075;side_factor=smoothstep(inner,outer,abs(x))
 removed=np.zeros(len(v))
 for index in arm_indices:
  name=g['nodes'][skin['joints'][index]]['name'];side='L' if name.startswith('L_') else 'R';palm=world[names[side+'_Hand']][:3,3];distance=np.linalg.norm(vv-palm,axis=1);palm_factor=1-smoothstep(.13,.22,distance)
  distal=any(token in name.lower() for token in ['hand','pinky','ring','mid','index','thumb'])
  factor=palm_factor if distal else np.maximum(side_factor,palm_factor)
  removed+=weights[:,index]*(1-factor);weights[:,index]*=factor
 core=['Pelvis','Spine01','Spine02','Head'];coresegs=[(world[names[core[i]]][:3,3],world[names[core[min(i+1,3)]]][:3,3]+(np.array([0,.12,.04]) if i==3 else 0)) for i in range(4)];cw=segment_weights(vv,coresegs)
 for i,n in enumerate(core):weights[:,skin['joints'].index(names[n])]+=removed*cw[:,i]
 # Auto-rigged toe/thigh weights also reach into the central tail base.
 # Keep true side legs; return impossible midline leg weights to the pelvis.
 leg_indices=[k for k,node in enumerate(skin['joints']) if any(token in g['nodes'][node].get('name','').lower() for token in ['thigh','calf','foot','toe','knee'])]
 central=smoothstep(.045,.13,abs(x));removed_leg=weights[:,leg_indices].sum(1)*(1-central);weights[:,leg_indices]*=central[:,None];weights[:,skin['joints'].index(names['Pelvis'])]+=removed_leg
 tailnames=[x[0] for x in extra[:6]]
 def distance_to_segments(points, segments):
  ds=[]
  for a,c in segments:
   ab=c-a;t=np.clip(((points-a)@ab)/max(ab@ab,1e-9),0,1);ds.append(np.linalg.norm(points-a-t[:,None]*ab,axis=1))
  return np.min(np.stack(ds),axis=0)
 tail_segments=[(world[names[tailnames[i]]][:3,3],world[names[tailnames[i+1]]][:3,3]) for i in range(5)]
 body_segments=[]
 for chain in [['Pelvis','Spine01','Spine02','Head'],['L_Thigh','L_Calf','L_Foot','L_ToeBase'],['R_Thigh','R_Calf','R_Foot','R_ToeBase'],['L_Upperarm','L_Forearm','L_Hand'],['R_Upperarm','R_Forearm','R_Hand']]:
  body_segments.extend((world[names[a]][:3,3],world[names[c]][:3,3]) for a,c in zip(chain,chain[1:]))
 dt=distance_to_segments(vv,tail_segments);db=distance_to_segments(vv,body_segments)
 tail=smoothstep(-.015,.11,db-dt)*smoothstep(.005,.10,-z)
 weights*=1-tail[:,None];segs=[(world[names[n]][:3,3],world[names[tailnames[min(i+1,5)]]][:3,3]+(np.array([0,-.08,.01]) if i==5 else 0)) for i,n in enumerate(tailnames)];tw=segment_weights(vv,segs)
 for i,n in enumerate(tailnames):weights[:,skin['joints'].index(names[n])]+=tail*tw[:,i]
 # Ear and lower muzzle articulation is local and softly feathered, leaving
 # source facial/eye/finger weighting intact everywhere else.
 for n,_,pos in extra[6:]:
  d=np.linalg.norm(vv-np.array(pos),axis=1);blend=(1-smoothstep(.025,.075,d))*(1-tail)*(.65 if n=='Jaw' else .9);weights*=1-blend[:,None];weights[:,skin['joints'].index(names[n])]+=blend
 groups=[]
 for side in ['L','R']:
  members=[k for k,node in enumerate(skin['joints']) if g['nodes'][node].get('name','').startswith(side+'_') and any(token in g['nodes'][node].get('name','').lower() for token in ['hand','pinky','ring','mid','index','thumb'])];groups.append((skin['joints'].index(names[side+'_Hand']),members))
 ji,ww=smooth_skin(v,faces,weights,24,groups);p['attributes']['JOINTS_0']=addacc(g,b,ji,'VEC4',5123,34962);p['attributes']['WEIGHTS_0']=addacc(g,b,ww,'VEC4',5126,34962)
 g['animations']=[];animate(g,b,'tank');compact(g,b,output);return report_model(output,'tank',TANK_SOURCE)

class Author:
 def __init__(self,g,kind):
  self.g=g;self.kind=kind;self.names={n.get('name'):i for i,n in enumerate(g['nodes'])};self.rest=fk(g);self.parents=hierarchy(g);self.pose={};self.root=self.names['root' if kind=='scout' else 'BoneRoot'];self.skin=g['skins'][0]
 def key(self,scout,tank):return scout if self.kind=='scout' else tank
 def node(self,name):return self.names.get(name)
 def offset(self,name,xyz):
  if name not in self.names:return
  i=self.names[name];node=self.g['nodes'][i];r=Rot.from_quat(node.get('rotation',[0,0,0,1])).as_matrix();global_basis=self.rest[i][:3,:3];global_basis=global_basis/np.linalg.norm(global_basis,axis=0)
  delta=Rot.from_euler('xyz',xyz).as_matrix();local_offset=global_basis.T@delta@global_basis;self.pose.setdefault(i,{})['rotation']=Rot.from_matrix(r@local_offset).as_quat().tolist()
 def shift(self,i,delta):
  parent=self.rest[self.parents[i]] if i in self.parents else np.eye(4);d=np.linalg.inv(parent[:3,:3])@np.array(delta);self.pose.setdefault(i,{})['translation']=(np.array(self.g['nodes'][i].get('translation',[0,0,0]))+d).tolist()
 def ik(self,upper,lower,end,goal,flatten=True,toe=0,pole_hint=None):
  a,b,c=[self.names[n] for n in [upper,lower,end]];rest=self.rest;world=fk(self.g,self.pose);hip=world[a][:3,3];ru=rest[b][:3,3]-rest[a][:3,3];rl=rest[c][:3,3]-rest[b][:3,3];la=np.linalg.norm(ru);lb=np.linalg.norm(rl);goal=np.array(goal);v=goal-hip;d=np.clip(np.linalg.norm(v),abs(la-lb)+.001,(la+lb)*.993);direction=v/max(np.linalg.norm(v),1e-8)
  restline=rest[c][:3,3]-rest[a][:3,3];pole=rest[b][:3,3]-rest[a][:3,3]-restline*np.dot(rest[b][:3,3]-rest[a][:3,3],restline)/max(restline@restline,1e-8)
  if pole_hint is not None:pole=np.array(pole_hint,float)
  pole-=direction*(pole@direction)
  if np.linalg.norm(pole)<1e-5:pole=np.array([0,0,1.0])-direction*direction[2]
  pole/=np.linalg.norm(pole);along=(la*la-lb*lb+d*d)/(2*d);height=math.sqrt(max(la*la-along*along,0));knee=hip+direction*along+pole*height
  if pole_hint is None:
   self.orient_segment(a,b,knee-hip);world=fk(self.g,self.pose);self.orient_segment(b,c,goal-world[b][:3,3])
  else:
   # A full anatomical bend frame also fixes axial twist. Shortest-arc-only
   # aiming can jump by 180 degrees as a deeply folded bone passes antipodal
   # to its rest direction, even with an otherwise stable knee pole.
   normal=np.cross(knee-hip,goal-knee);restnormal=np.cross(ru,rl)
   if np.linalg.norm(restnormal)<1e-7:restnormal=np.cross(ru,np.array(pole_hint))
   if self.kind=='tank' and self.g['nodes'][a].get('name') in ['L_Upperarm','R_Upperarm']:
    # The guardian's bulky forearm skin cannot tolerate arbitrary axial roll.
    # Keep the smallest swing from its real rest orientation while solving
    # the same elbow/paw targets; preserve the full anatomical plane for legs.
    self.orient_segment_swing(a,b,knee-hip,restnormal)
    world=fk(self.g,self.pose);self.orient_segment_swing(b,c,goal-world[b][:3,3],restnormal)
   else:
    self.orient_segment_plane(a,b,knee-hip,normal,restnormal)
    world=fk(self.g,self.pose);self.orient_segment_plane(b,c,goal-world[b][:3,3],normal,restnormal)
  if flatten:
   world=fk(self.g,self.pose);parent=world[self.parents[c]][:3,:3];target=Rot.from_euler('x',toe).as_matrix()@rest[c][:3,:3];self.pose.setdefault(c,{})['rotation']=Rot.from_matrix(np.linalg.inv(parent)@target).as_quat().tolist()
 def orient_segment(self,i,child,direction):
  world=fk(self.g,self.pose);u=world[child][:3,3]-world[i][:3,3];u/=np.linalg.norm(u);v=direction/max(np.linalg.norm(direction),1e-9);axis=np.cross(u,v);dot=np.clip(u@v,-1,1)
  delta=np.eye(3) if np.linalg.norm(axis)<1e-8 else Rot.from_rotvec(axis/np.linalg.norm(axis)*math.acos(dot)).as_matrix();parent=world[self.parents[i]][:3,:3] if i in self.parents else np.eye(3);new=np.linalg.inv(parent)@delta@world[i][:3,:3];self.pose.setdefault(i,{})['rotation']=Rot.from_matrix(new).as_quat().tolist()
 def orient_segment_plane(self,i,child,direction,normal,restnormal):
  def frame(axis,n):
   axis=axis/max(np.linalg.norm(axis),1e-9);n=n-axis*np.dot(axis,n);n=n/max(np.linalg.norm(n),1e-9)
   return np.column_stack([axis,n,np.cross(axis,n)])
  restframe=frame(self.rest[child][:3,3]-self.rest[i][:3,3],restnormal);target=frame(direction,normal)
  world=fk(self.g,self.pose);parent=world[self.parents[i]][:3,:3]
  local=np.linalg.inv(parent)@target@restframe.T@self.rest[i][:3,:3]
  self.pose.setdefault(i,{})['rotation']=Rot.from_matrix(local).as_quat().tolist()
 def orient_segment_swing(self,i,child,direction,restnormal):
  world=fk(self.g,self.pose);u=self.rest[child][:3,3]-self.rest[i][:3,3];u/=np.linalg.norm(u)
  v=direction/max(np.linalg.norm(direction),1e-9);axis=np.cross(u,v);dot=np.clip(u@v,-1,1)
  if np.linalg.norm(axis)<1e-7:
   delta=np.eye(3) if dot>0 else Rot.from_rotvec(restnormal/np.linalg.norm(restnormal)*math.pi).as_matrix()
  else:delta=Rot.from_rotvec(axis/np.linalg.norm(axis)*math.acos(dot)).as_matrix()
  parent=world[self.parents[i]][:3,:3]
  self.pose.setdefault(i,{})['rotation']=Rot.from_matrix(np.linalg.inv(parent)@delta@self.rest[i][:3,:3]).as_quat().tolist()
 def make(self,kind,t):
  if kind.startswith('death'):return self.defeat(kind,t)
  self.pose={};phase=t*math.tau;wave=math.sin(phase);chest=self.key('chest','Spine02');spine=self.key('spine','Spine01');head=self.key('head','Head');pelvis=self.key('pelvis','Pelvis');Lup=self.key('arm.upper.L','L_Upperarm');Rup=self.key('arm.upper.R','R_Upperarm');Llow=self.key('arm.fore.L','L_Forearm');Rlow=self.key('arm.fore.R','R_Forearm')
  # Subtle connected breath and delayed tail follow-through, not whole-root wobble.
  self.offset(chest,(.012*wave,0,.005*math.sin(phase+.6)));self.offset(head,(-.008*wave,.026*math.sin(phase),.008*wave))
  tails=['tail.01','tail.02','tail.03','tail.04','tail.05','tail.tip'] if self.kind=='scout' else ['Tail01','Tail02','Tail03','Tail04','Tail05','TailTip']
  for j,n in enumerate(tails):self.offset(n,(.013*math.sin(phase-j*.55),.018*math.sin(phase-j*.45),.009*math.sin(phase-j*.6)))
  for side,sign in [('L',1),('R',-1)]:self.offset(self.key('ear.'+side,'Ear.'+side),(.018*math.sin(phase+.4*sign),0,.025*sign*math.sin(phase+.6)))
  if kind=='charge':
   # One committed power-lunge matches the guardian's locked 10 m/s dash.
   # It is not a short-legged run sped up to an implausible ten cycles/second.
   tuck=math.sin(math.pi*smoothstep(.06,.94,t))
   self.offset(chest,(.16*tuck,0,.012*wave));self.offset(head,(-.07*tuck,0,0))
   self.shift(self.names[pelvis],(0,-(.025 if self.kind=='tank' else .06)*(1-tuck),0))
   for side in ['L','R']:
    leg=[f'leg.thigh.{side}',f'leg.shin.{side}',f'foot.{side}'] if self.kind=='scout' else [f'{side}_Thigh',f'{side}_Calf',f'{side}_Foot']
    goal=self.rest[self.names[leg[2]]][:3,3].copy();goal[1]+=(.045 if self.kind=='tank' else .075)*tuck;goal[2]-=(.035 if self.kind=='tank' else .07)*tuck
    self.ik(*leg,goal,toe=.16*tuck)
    if self.kind=='tank':
     arm=[f'{side}_Upperarm',f'{side}_Forearm',f'{side}_Hand'];goal=self.rest[self.names[arm[2]]][:3,3].copy();goal[1]+=.07*tuck;goal[2]+=.055*tuck;self.ik(*arm,goal,toe=-.10*tuck)
    else:
     self.offset(f'arm.upper.{side}',(-.7*tuck,0,.06*tuck if side=='L' else -.06*tuck));self.offset(f'arm.fore.{side}',(-.4*tuck,0,0))
  elif kind in ['walk','run']:
   run=kind!='walk';amp=(.24 if run else .19) if self.kind=='scout' else (.10 if run else .065);lift=(.10 if run else .06) if self.kind=='scout' else (.035 if run else .022)
   self.shift(self.names[pelvis],(0,(-.085 if run else -.06)+(.008 if run else .004)*math.cos(phase*2) if self.kind=='scout' else -.025+.006*math.cos(phase*2),0));self.offset(chest,((.15 if kind=='charge' else .035 if run else .008),.025*wave, .025*wave));self.offset(head,(-.055 if kind=='charge' else 0,-.025*wave,0))
   for side,offset in [('L',0),('R',.5)]:
    p=(t+offset)%1;stance=p<.60;z=amp*(1-2*p/.60) if stance else -amp+2*amp*((p-.60)/.40);up=0 if stance else lift*math.sin(math.pi*(p-.60)/.40)
    chain=[f'leg.thigh.{side}',f'leg.shin.{side}',f'foot.{side}'] if self.kind=='scout' else [f'{side}_Thigh',f'{side}_Calf',f'{side}_Foot'];goal=self.rest[self.names[chain[2]]][:3,3].copy();goal[1]+=up;goal[2]+=z;self.ik(*chain,goal,toe=(-.12*math.sin(math.pi*p/.60) if stance else .08))
    if self.kind=='tank':
     chain=[f'{side}_Upperarm',f'{side}_Forearm',f'{side}_Hand'];p=(t+offset+.5)%1;stance=p<.6;z=amp*(1-2*p/.6) if stance else -amp+2*amp*((p-.6)/.4);up=0 if stance else lift*.85*math.sin(math.pi*(p-.6)/.4);goal=self.rest[self.names[chain[2]]][:3,3].copy();goal[1]+=up;goal[2]+=z;self.ik(*chain,goal,toe=.04*wave)
    else:
     self.offset(f'arm.upper.{side}',((-.20 if side=='L' else .20)*wave,0,0));self.offset(f'arm.fore.{side}',(-.12-.06*math.sin(phase+offset*math.tau),0,0));self.offset(f'hand.{side}',(.03*wave,0,0));self.offset(f'toe.{side}',(.06*math.sin(phase+offset*math.tau),0,0))
  elif kind in ['turn_left','turn_right','alert']:
   sign=-1 if kind=='turn_left' else 1;ease=math.sin(math.pi*t) if kind!='alert' else smoothstep(0,.45,t)
   self.offset(head,(.015*wave,sign*.21*ease,sign*.045*ease));self.offset(chest,(0,sign*.065*ease,0))
  elif kind in ['aim','fire','melee','charge_tell','stomp_tell','stomp']:
   pulse=math.sin(math.pi*t);ease=smoothstep(0,.35,t);strike=math.exp(-((t-.60)/.16)**2)
   if kind=='aim':self.offset(Rup,(-2.02 if self.kind=='scout' else -.74,0,-.07));self.offset(Rlow,(.10 if self.kind=='scout' else -.35,0,0));self.offset(Lup,(-.36,0,.08));self.offset(Llow,(-.40,0,0));self.offset(head,(-.04,0,0))
   elif kind in ['fire','melee']:
    swing=((2.02 if self.kind=='scout' else .80)*(1-smoothstep(.12,.88,t))+.36*strike) if kind=='fire' else (.45*ease+1.0*strike);self.offset(Rup,(-swing,.12*pulse,-.08));self.offset(Rlow,((.10 if kind=='fire' else -.65)*(1-strike),0,0));self.offset(Lup,(-.25-.20*strike,0,.08));self.offset(chest,(.07*strike,.13*pulse,0));self.offset(head,(-.03, -.07*pulse,0))
   elif kind=='charge_tell':self.offset(chest,(.14*ease,0,0));self.offset(head,(-.08*ease,0,0));self.offset(Lup,(-.13*ease,0,.08*ease));self.offset(Rup,(-.13*ease,0,-.08*ease))
   else:
    raise_=(ease if kind=='stomp_tell' else 1-smoothstep(.08,.55,t));self.offset(Lup,(-.95*raise_,0,.10*raise_));self.offset(Rup,(-.95*raise_,0,-.10*raise_));self.offset(Llow,(-.22*raise_,0,0));self.offset(Rlow,(-.22*raise_,0,0));self.offset(chest,(-.07*raise_+.09*strike,0,0))
  elif kind=='recover':self.offset(chest,(.08+.018*wave,0,0));self.offset(head,(-.04,.02*wave,0));self.offset(Lup,(.025*wave,0,0));self.offset(Rup,(-.025*wave,0,0))
  elif kind=='hit':
   impulse=math.sin(math.pi*t);self.offset(chest,(-.095*impulse,0,.035*impulse));self.offset(head,(-.07*impulse,0,-.04*impulse));self.offset(Lup,(.12*impulse,0,.035*impulse));self.offset(Rup,(.12*impulse,0,-.035*impulse))
  elif kind in ['stunned','death']:
   e=smoothstep(0,.8,t) if kind=='death' else 1.0;self.offset(chest,(.08*e,0,.035*math.sin(phase)*e));self.offset(head,(.12*e,0,-.07*e));self.offset(Lup,(-.12*e,0,-.1*e));self.offset(Rup,(-.12*e,0,.1*e))
   if kind=='death':self.offset(self.g['nodes'][self.root]['name'],(-.15*e,0,1.30*e))
  if self.kind=='scout':
   curl=.13 if kind=='aim' else (.13*(1-smoothstep(.28,.46,t)) if kind=='fire' else .045*wave if kind=='idle' else 0)
   self.offset('fingers.R',(-curl,0,0));self.offset('fingers.L',(-.025*math.sin(phase+.8),0,0))
  if kind=='alert':self.offset(self.key('jaw','Jaw'),(.035*math.sin(phase*2)**2,0,0))
  return self.pose

 def defeat(self,kind,t):
  """Authored weight transfer: recoil, knees give way, brace, hip contact,
  then wrist/head/tail settle. Root has NO rotation, and bone lengths/skin
  are unchanged. Each directional fall is a different articulated pose.
  Values are in the real model's world units, not normalized actor height.
  """
  self.pose={};tank=self.kind=='tank';unit=.46 if tank else 1.0
  side=-1 if kind=='death_left' else 1
  if kind in ['death','death_forward']:pitch=1.0;roll=.36
  elif kind=='death_back':pitch=-1.25;roll=1.2
  else:pitch=.28;roll=1.18*side
  recoil=math.sin(math.pi*smoothstep(0,.18,t))*(1-smoothstep(.15,.28,t))
  kneel=smoothstep(.10,.40,t);fall=smoothstep(.25,.66,t)
  contact=smoothstep(.52,.72,t);settle=smoothstep(.67,1.0,t)
  bounce=math.sin(math.pi*smoothstep(.62,.83,t))*(1-smoothstep(.78,.91,t))
  # The guardian source has sibling Pelvis and Waist branches under Hip.
  # Move their shared anatomical hip, never just its leg-only Pelvis branch.
  pel=self.key('pelvis','Hip');spine=self.key('spine','Spine01');chest=self.key('chest','Spine02');head=self.key('head','Head')
  self.shift(self.names[pel],(unit*(-.15*roll*fall),-unit*(.25*kneel+.18*fall-.012*bounce),unit*(.16*pitch*fall)))
  self.offset(pel,(pitch*(.72*fall+.09*recoil),.07*roll*fall,roll*(.68*fall+.05*recoil)))
  self.offset(spine,((.23 if pitch>=0 else -.30)*kneel+.17*pitch*fall,-.08*roll*fall,roll*.18*fall))
  self.offset(chest,(.12*pitch*recoil+.18*pitch*fall-.035*bounce,.08*roll*fall,roll*(.23*fall+.06*recoil)))
  # Head lags the torso, then rests at a distinct angle. No endless dead breath.
  muzzle_release=.35*settle if tank and kind in ['death','death_forward'] else 0
  self.offset(head,(.08*pitch*recoil-.13*contact+.19*settle-muzzle_release,.13*roll*settle,.04*roll*recoil-.11*roll*contact+.06*bounce))
  self.offset(self.key('neck','NeckTwist01'),(-.08*fall,0,.04*roll*fall))
  for s in ['L','R']:
   sign=1 if s=='L' else -1
   leg=[f'leg.thigh.{s}',f'leg.shin.{s}',f'foot.{s}'] if not tank else [f'{s}_Thigh',f'{s}_Calf',f'{s}_Foot']
   foot=self.rest[self.names[leg[2]]][:3,3].copy()
   foot+=unit*np.array([(.055*sign-.06*roll)*fall,.015*kneel,.22*kneel+(-.15*pitch+.05*sign)*fall])
   # A fixed anatomical knee pole prevents a deep crouch crossing the nearly
   # straight rest-line singularity and snapping to the opposite knee bend.
   outward=np.sign(self.rest[self.names[leg[0]]][0,3])
   self.ik(*leg,foot,toe=.20*pitch*contact+.07*sign*settle,pole_hint=(outward,0,0))
   arm=[f'arm.upper.{s}',f'arm.fore.{s}',f'hand.{s}'] if not tank else [f'{s}_Upperarm',f'{s}_Forearm',f'{s}_Hand']
   palm=self.rest[self.names[arm[2]]][:3,3].copy()
   # Forepaws reach for support before the torso touches down. Separate hands,
   # asymmetrical elbows and a relaxed lower wrist preserve readable anatomy.
   armfall=smoothstep(.16,.57 if sign*roll>0 else .66,t)
   palm[0]+=unit*(.12*sign-.16*roll)*armfall
   palm[1]+=-unit*(.47 if not tank else .09)*armfall+unit*.018*bounce
   palm[2]+=unit*(.30*pitch+.08*sign)*armfall
   self.ik(*arm,palm,flatten=False,pole_hint=(np.sign(palm[0]),-.15,-.35))
   self.offset(self.key(f'hand.{s}',f'{s}_Hand'),(.16*settle,-.06*sign*settle,.12*sign*settle))
   if not tank:self.offset(f'fingers.{s}',(-.14*contact+.08*settle,.025*sign*settle,0))
   else:
    for finger in ['Pinky','Ring','Mid','Index','Thumb']:
     for segment in [1,2,3]:
      self.offset(f'{s}_{finger}{segment}',(-(.035+.025*segment)*(contact-.35*settle),0,.018*sign*settle))
   self.offset(self.key('ear.'+s,'Ear.'+s),(.13*contact-.045*settle,0,.09*sign*contact))
  tails=['tail.01','tail.02','tail.03','tail.04','tail.05','tail.tip'] if not tank else ['Tail01','Tail02','Tail03','Tail04','Tail05','TailTip']
  for j,n in enumerate(tails):
   lag=smoothstep(.30+j*.045,.77+j*.04,t)
   follow=math.sin(math.pi*smoothstep(.44+j*.035,.83+j*.025,t))*(1-settle)
   self.offset(n,(-.14*pitch*lag+.055*follow, .10*roll*lag, -.12*roll*lag+.025*follow))
  # The thick source curl must keep its arc length and volume. Lay its curved
  # plane down from the base, retaining the six small delayed bends above;
  # straightening this particular fur mesh would pull skin across the curl.
  lag=smoothstep(.40,.96,t);world=fk(self.g,self.pose);i=self.names[tails[0]]
  u=world[self.names[tails[2]]][:3,3]-world[i][:3,3]
  v=world[self.names[tails[4]]][:3,3]-world[i][:3,3]
  normal=np.cross(u,v)
  if hasattr(self,'tail_plane_rest_normal'):
   normal=world[i][:3,:3]@np.linalg.inv(self.rest[i][:3,:3])@self.tail_plane_rest_normal
  normal/=max(np.linalg.norm(normal),1e-8)
  # Fixed side per take: choosing the nearest plane normal every sample can
  # switch sign at a nearly vertical curl and make a half-turn discontinuity.
  up=np.array([0,1 if roll>=0 else -1,0]);axis=np.cross(normal,up)
  if np.linalg.norm(axis)>1e-7:
   delta=Rot.from_rotvec(axis/np.linalg.norm(axis)*math.acos(np.clip(normal@up,-1,1))*lag).as_matrix()
   parent=world[self.parents[i]][:3,:3];local=np.linalg.inv(parent)@delta@world[i][:3,:3]
   self.pose.setdefault(i,{})['rotation']=Rot.from_matrix(local).as_quat().tolist()
  # Preserve the supplied thick curl while resting the torso as well as the
  # tail. These modest base angles were measured on all actual skin vertices;
  # a plane-only fit can leave the scout propped above ground on its fur.
  correction=((.2,-.2) if kind in ['death','death_forward'] else (.4,.4) if kind=='death_back' else (.5,0) if kind=='death_right' else (0,0)) if not tank else ((.1,.2) if kind in ['death','death_forward'] else (0,.1) if kind=='death_right' else (0,0))
  world=fk(self.g,self.pose);delta=Rot.from_euler('xz',np.array(correction)*lag).as_matrix()
  parent=world[self.parents[i]][:3,:3];local=np.linalg.inv(parent)@delta@world[i][:3,:3]
  self.pose.setdefault(i,{})['rotation']=Rot.from_matrix(local).as_quat().tolist()
  self.offset(self.key('jaw','Jaw'),(.025*contact,0,0))
  return self.pose

def animate(g,b,kind,only_defeat=False):
 a=Author(g,kind);skin=g['skins'][0];worldrest=a.rest;meshnode=next(i for i,n in enumerate(g['nodes']) if 'mesh'in n and'skin'in n);primitive=g['meshes'][g['nodes'][meshnode]['mesh']]['primitives'][0];v=readacc(g,b,primitive['attributes']['POSITION']);ji=readacc(g,b,primitive['attributes']['JOINTS_0']);ww=readacc(g,b,primitive['attributes']['WEIGHTS_0']);ibm=readacc(g,b,skin['inverseBindMatrices']).reshape(-1,4,4).transpose(0,2,1);hp=np.column_stack([v,np.ones(len(v))]);restfloor=float((worldrest[meshnode]@hp.T)[1].min())
 # The sculpted fur curl is not exactly coplanar with its guide joints. Use
 # its actual weighted volume's thin principal axis for final support.
 tailj=np.array(['tail' in g['nodes'][n].get('name','').lower() for n in skin['joints']])
 tailpoints=(worldrest[meshnode]@hp.T).T[:,:3][(tailj[ji]*ww).sum(1)>.8]
 _,axes=np.linalg.eigh(np.cov(tailpoints.T));a.tail_plane_rest_normal=axes[:,0]
 for name,duration in CLIPS.items():
  if only_defeat and not name.startswith('death'):continue
  count=max(17,math.ceil(duration*30)+1);times=np.linspace(0,duration,count,dtype=np.float32);poses=[]
  for t in times/duration:
   pose=copy.deepcopy(a.make(name,float(t)));world=fk(g,pose)
   # Offline floor contact correction uses the real weighted mesh, including
   # tail and paw tips. It becomes a small baked root translation track.
   matrices=np.array([world[j]@ibm[i] for i,j in enumerate(skin['joints'])]);transformed=np.einsum('nkij,nj->nki',matrices[ji],hp);deformed=(transformed*ww[:,:,None]).sum(1)
   airborne=(.10 if kind=='tank' else .18)*math.sin(math.pi*float(np.clip((t-.10)/.78,0,1))) if name=='charge' else 0
   delta=restfloor+airborne-float(deformed[:,1].min());rootnode=a.root;parent=world[a.parents[rootnode]][:3,:3] if rootnode in a.parents else np.eye(3);base=np.array(pose.get(rootnode,{}).get('translation',g['nodes'][rootnode].get('translation',[0,0,0])));pose.setdefault(rootnode,{})['translation']=(base+np.linalg.inv(parent)@np.array([0,delta,0])).tolist();poses.append(pose)
  ta=addacc(g,b,times,'SCALAR');channels=[];samplers=[]
  for node in skin['joints']:
   for prop,typ,size in [('rotation','VEC4',4),('translation','VEC3',3)]:
    default=g['nodes'][node].get(prop,[0,0,0,1] if prop=='rotation' else [0,0,0]);values=np.array([p.get(node,{}).get(prop,default) for p in poses],dtype=np.float32)
    # A terminal pose must own every joint. In the guardian source Pelvis
    # (legs) and Waist (torso) are siblings under Hip: a run's -.025 Pelvis
    # translation otherwise survives a Hip-driven collapse indefinitely.
    # Constant rest keys also release the previous aim, toes and finger pose.
    if not name.startswith('death') and np.max(abs(values-np.array(default)))<1e-6:continue
    if prop=='rotation':
     for i in range(1,len(values)):
      if values[i-1]@values[i]<0:values[i]*=-1
    oa=addacc(g,b,values,typ);samplers.append({'input':ta,'output':oa,'interpolation':'LINEAR'});channels.append({'sampler':len(samplers)-1,'target':{'node':node,'path':prop}})
  g.setdefault('animations',[]).append({'name':name,'samplers':samplers,'channels':channels,'extras':{'sample_rate':30,'in_place':True,'authored_for':kind}})
 g.setdefault('extras',{})['acorn_hunter_rig']={'version':149,'forward':'+Z','actor_origin':'pelvis projected to ground','clips':CLIPS,'rest_mesh_preserved':True,'floor_contact':'offline skinned-mesh minimum, baked root translation','source_skeleton_preserved':kind=='tank','defeat':'directional articulated hip/knee/brace collapse; no root rotation; delayed head/finger/tail settle'}

def compact(g,b,path):
 used=set()
 for m in g['meshes']:
  for p in m['primitives']:used.update(p['attributes'].values());used.add(p['indices'])
 for s in g.get('skins',[]):used.add(s['inverseBindMatrices'])
 for a in g.get('animations',[]):
  for s in a['samplers']:used.update([s['input'],s['output']])
 views={g['accessors'][a]['bufferView'] for a in used};views.update(i['bufferView'] for i in g.get('images',[]));vb={x:i for i,x in enumerate(sorted(views))};ab={x:i for i,x in enumerate(sorted(used))};binary=bytearray();newviews=[]
 for old in sorted(views):
  v=copy.deepcopy(g['bufferViews'][old]);raw=b[v.get('byteOffset',0):v.get('byteOffset',0)+v['byteLength']];binary.extend(b'\0'*(-len(binary)%4));v['byteOffset']=len(binary);v['buffer']=0;binary.extend(raw);newviews.append(v)
 accessors=[]
 for old in sorted(used):a=copy.deepcopy(g['accessors'][old]);a['bufferView']=vb[a['bufferView']];accessors.append(a)
 for m in g['meshes']:
  for p in m['primitives']:p['attributes']={k:ab[v] for k,v in p['attributes'].items()};p['indices']=ab[p['indices']]
 for s in g.get('skins',[]):s['inverseBindMatrices']=ab[s['inverseBindMatrices']]
 for a in g.get('animations',[]):
  for s in a['samplers']:s['input']=ab[s['input']];s['output']=ab[s['output']]
 for image in g.get('images',[]):image['bufferView']=vb[image['bufferView']]
 g['bufferViews']=newviews;g['accessors']=accessors;g['buffers']=[{'byteLength':len(binary)}];write(path,g,binary)

def report_model(path,kind,source):
 g,b=parse(path);p=g['meshes'][0]['primitives'][0];j=readacc(g,b,p['attributes']['JOINTS_0']);w=readacc(g,b,p['attributes']['WEIGHTS_0']);used=np.unique(j[w>.002]);report={'model':kind,'path':str(path),'source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'output_sha256':hashlib.sha256(Path(path).read_bytes()).hexdigest(),'bytes':Path(path).stat().st_size,'bones':len(g['skins'][0]['joints']),'influencing_bones':len(used),'vertices':len(j),'triangles':g['accessors'][p['indices']]['count']//3,'max_weight_error':float(abs(w.sum(1)-1).max()),'clips':{a['name']:{'keys':g['accessors'][a['samplers'][0]['input']]['count'],'tracks':len(a['channels']),'duration':CLIPS[a['name']]} for a in g['animations']},'runtime_rigging':False};return report

def main():
 parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--scout-output',type=Path,default=ROOT/'scout_rigged.glb');parser.add_argument('--tank-output',type=Path);parser.add_argument('--complete-tank',type=Path);parser.add_argument('--report',type=Path);args=parser.parse_args();reports=[]
 if args.complete_tank:reports.append(complete_tank(args.complete_tank))
 else:
  reports.append(build_scout(args.scout_output))
  if args.tank_output:subprocess.run([sys.executable,str(ROOT/'tools/prepare_tank_squirrel.py'),'--output',str(args.tank_output)],check=True);reports.append(report_model(args.tank_output,'tank',TANK_SOURCE))
 if args.report:args.report.parent.mkdir(parents=True,exist_ok=True);args.report.write_text(json.dumps({'rig_version':147,'models':reports},indent=2))
 print(json.dumps({'result':'BUILT','models':reports},indent=2))
if __name__=='__main__':main()
