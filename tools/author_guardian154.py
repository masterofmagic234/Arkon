#!/usr/bin/env python3
"""Fresh guardian skeleton, surface weights and pose-authored animation library.

Only the unskinned bind mesh and its UV/materials are reused. No source joint,
weight or animation data is read. IK and skin sampling happen offline; the
phone loads one ordinary skinned GLB and the existing AnimationPlayer.
"""
from __future__ import annotations
import copy, hashlib, json, math
from pathlib import Path
import numpy as np
from scipy.sparse import coo_matrix
from scipy.sparse.csgraph import dijkstra
from scipy.spatial import cKDTree
from scipy.spatial.transform import Rotation as R, Slerp
import prepare_squirrel_rigs as io

ROOT=Path(__file__).resolve().parents[1]
SOURCE=ROOT/'art/level1/guardian154/bind-mesh.glb'
OUTPUT=ROOT/'assets/level1/characters/tank_squirrel.glb'
CLIPS={'idle':2.4,'walk':.72,'run':.46,'turn_left':.7,'turn_right':.7,
 'alert':.65,'aim':1.2,'fire':.52,'melee':.62,'charge_tell':.85,
 'charge':1.05,'stomp_tell':.75,'stomp':.65,'recover':1.2,'hit':.24,
 'stunned':1.1,'death':1.8,'death_forward':1.8,'death_back':1.8,
 'death_left':1.8,'death_right':1.8}

def ss(a,b,x):
 t=np.clip((x-a)/(b-a),0,1);return t*t*(3-2*t)

# Anatomical landmarks in the retained sculpt, metres, forward +Z. The pelvis
# owns both the torso and hind legs; there is no inherited sibling Waist rig.
BONES=[('BoneRoot',None,(0,0,0)),('Pelvis','BoneRoot',(0,.210,0)),
 ('Spine01','Pelvis',(0,.290,.043)),('Spine02','Spine01',(0,.405,.090)),
 ('Neck','Spine02',(0,.493,.145)),('Head','Neck',(0,.570,.210)),
 ('Jaw','Head',(0,.521,.308)),('Brow.L','Head',(.060,.614,.300)),
 ('Brow.R','Head',(-.060,.614,.300)),('Ear.L','Head',(.085,.698,.215)),
 ('Ear.R','Head',(-.085,.698,.215))]
for side,sign in [('L',1),('R',-1)]:
 BONES.extend([(f'Scapula.{side}','Spine02',(sign*.105,.438,.125)),
  (f'{side}_Upperarm',f'Scapula.{side}',(sign*.166,.466,.172)),
  (f'{side}_Forearm',f'{side}_Upperarm',(sign*.215,.252,.220)),
  (f'{side}_Hand',f'{side}_Forearm',(sign*.164,.084,.284)),
  (f'{side}_Fingers',f'{side}_Hand',(sign*.164,.040,.333)),
  (f'{side}_Thigh','Pelvis',(sign*.127,.150,.044)),
  (f'{side}_Calf',f'{side}_Thigh',(sign*.156,.062,.080)),
  (f'{side}_Foot',f'{side}_Calf',(sign*.144,.031,.019)),
  (f'{side}_ToeBase',f'{side}_Foot',(sign*.171,.027,.115))])
# The sculpt has an asymmetric planted stance. Fit the NEW right-side chain
# to the actual elbow/ankle rather than mirroring left landmarks through fur.
right_landmarks={
 'Scapula.R':(-.105,.450,.065),'R_Upperarm':(-.1484,.4852,.06395),
 'R_Forearm':(-.245,.2597,.02852),'R_Hand':(-.2536,.07652,.1087),
 'R_Fingers':(-.263,.035,.149),'R_Thigh':(-.1556,.1451,-.071),
 'R_Calf':(-.1894,.08395,-.0962),'R_Foot':(-.1571,.04956,-.2008),
 'R_ToeBase':(-.2076,.02663,-.1331)}
BONES=[(n,p,right_landmarks.get(n,v)) for n,p,v in BONES]
for name,parent,pos in [('Tail01','Pelvis',(-.020,.230,-.110)),
 ('Tail02','Tail01',(-.130,.150,-.340)),('Tail03','Tail02',(-.160,.350,-.480)),
 ('Tail04','Tail03',(-.160,.600,-.430)),('Tail05','Tail04',(-.130,.760,-.230)),
 ('TailTip','Tail05',(-.100,.600,-.075))]:BONES.append((name,parent,pos))

def skeleton(g,b):
 g['nodes']=[{'name':'GuardianMesh154','mesh':0,'skin':0}]
 names={};positions={}
 for name,parent,p in BONES:
  names[name]=len(g['nodes']);positions[name]=np.array(p,float)
  g['nodes'].append({'name':name,'translation':(positions[name]-positions[parent] if parent else positions[name]).tolist()})
  if parent:g['nodes'][names[parent]].setdefault('children',[]).append(names[name])
 joints=list(names.values());g['scenes']=[{'nodes':[0,names['BoneRoot']]}];g['scene']=0
 inverse=[]
 for name in names:
  m=np.eye(4);m[:3,3]=-positions[name];inverse.append(m.T.reshape(-1))
 g['skins']=[{'name':'GuardianAnatomicalSkin154','joints':joints,'skeleton':names['BoneRoot'],
  'inverseBindMatrices':io.addacc(g,b,inverse,'MAT4')}]
 return names,positions

def weights(g,b,names,pos):
 p=g['meshes'][0]['primitives'][0];v=io.readacc(g,b,p['attributes']['POSITION'])
 f=io.readacc(g,b,p['indices']).reshape(-1,3);x,y,z=v.T
 _,inv=np.unique(np.round(v*1e6).astype(np.int64),axis=0,return_inverse=True)
 n=inv.max()+1;points=np.zeros((n,3));np.add.at(points,inv,v);points/=np.bincount(inv)[:,None]
 edges=inv[f[:,[0,1,1,2,2,0]]].reshape(-1,2);edges=np.unique(np.sort(edges,axis=1),axis=0)
 length=np.linalg.norm(points[edges[:,0]]-points[edges[:,1]],axis=1)
 graph=coo_matrix((np.r_[length,length],(np.r_[edges[:,0],edges[:,1]],np.r_[edges[:,1],edges[:,0]])),shape=(n,n)).tocsr()
 seeds=[[(0,.25,.18),(0,.40,.16),(0,.24,-.03)],[(0,.59,.34),(0,.65,.20)],
  [(-.16,.30,-.55),(-.16,.66,-.45),(-.07,.19,-.27)],
  [(.22,.33,.23),(.19,.13,.30),(.17,.045,.34)],
  [(-.25,.33,.035),(-.26,.13,.10),(-.265,.035,.15)],
  [(.18,.065,.10),(.13,.13,.02)], [(-.21,.055,-.16),(-.17,.13,-.07)]]
 tree=cKDTree(points);dist=[]
 for group in seeds:
  ids=tree.query(np.array(group))[1];d=dijkstra(graph,indices=ids,directed=False).min(0)
  fallback=np.linalg.norm(points[:,None,:]-np.array(group)[None,:,:],axis=2).min(1)+.35
  dist.append(np.where(np.isfinite(d),d,fallback))
 dist=np.stack(dist,axis=1)[inv]
 scores=np.exp(-np.clip(dist-dist.min(1,keepdims=True),0,20)/.025)
 scores[:,1]*=ss(.437,.515,y)*ss(.075,.17,z)
 tailgate=ss(-.015,.09,-z);scores[:,2]*=tailgate
 scores[:,2]+=40*ss(.11,.24,-z)*ss(.22,.40,y)
 # The low underside of the curled tail is a disconnected surface island.
 # Its geodesic fallback must not bind it to the pelvis simply because it is
 # low. The right hind paw ends forward of this tail-only rear band.
 scores[:,2]+=120*ss(.22,.30,-z)
 # The asymmetric right heel extends behind its ankle to Z=-.25. It is
 # below the tail underside (Y~.15): keep the entire low heel/toe pad in
 # the hind-leg region rather than allowing the rear band to capture it.
 rear_paw=ss(.085,.125,-x)*(1-ss(.055,.095,y))*(1-ss(-.08,-.025,z))
 scores[:,2]*=1-rear_paw
 scores[:,6]+=100*rear_paw
 for k,sign in [(3,1),(4,-1)]:scores[:,k]*=ss(.095,.155,sign*x)*(1-ss(.445,.535,y))
 for k,sign in [(5,1),(6,-1)]:scores[:,k]*=ss(.055,.11,sign*x)*(1-ss(.16,.25,y))
 scores/=scores.sum(1,keepdims=True);W=np.zeros((len(v),len(names)));joints=g['skins'][0]['joints']
 def assign(chain,region,end):
  seg=[(pos[a],pos[chain[i+1]] if i+1<len(chain) else np.array(end)) for i,a in enumerate(chain)]
  dist=[]
  for start,end in seg:
   axis=end-start;q=np.clip(((v-start)@axis)/max(axis@axis,1e-9),0,1)
   dist.append(np.sum((v-start-q[:,None]*axis)**2,axis=1))
  delta=np.stack(dist,axis=1);radius=.0006 if chain[0]=='Pelvis' else .00012
  w=1/(delta+radius)**2;w/=w.sum(1,keepdims=True)
  for i,name in enumerate(chain):W[:,joints.index(names[name])]+=w[:,i]*region
 assign(['Pelvis','Spine01','Spine02','Neck'],scores[:,0],(0,.56,.20))
 assign(['Tail01','Tail02','Tail03','Tail04','Tail05','TailTip'],scores[:,2],(-.10,.53,-.09))
 for side,k,sign in [('L',3,1),('R',4,-1)]:
  assign([f'Scapula.{side}',f'{side}_Upperarm',f'{side}_Forearm',f'{side}_Hand',f'{side}_Fingers'],scores[:,k],(sign*.164,.015,.36))
  assign([f'{side}_Thigh',f'{side}_Calf',f'{side}_Foot',f'{side}_ToeBase'],scores[:,k+2],(sign*.171,.024,.17))
 head=scores[:,1];remaining=head.copy()
 for name,mask in [('Jaw',ss(.295,.335,z)*(1-ss(.528,.557,y))*.85),
  ('Ear.L',ss(.68,.735,y)*ss(.01,.05,x)),('Ear.R',ss(.68,.735,y)*ss(.01,.05,-x)),
  ('Brow.L',np.exp(-np.sum((v-pos['Brow.L'])**2,axis=1)/.00032)*.65),
  ('Brow.R',np.exp(-np.sum((v-pos['Brow.R'])**2,axis=1)/.00032)*.65)]:
  part=remaining*mask;W[:,joints.index(names[name])]+=part;remaining-=part
 W[:,joints.index(names['Head'])]+=remaining
 ji,ww=io.smooth_skin(v,f,W,6)
 p['attributes']['JOINTS_0']=io.addacc(g,b,ji,'VEC4',5123,34962)
 p['attributes']['WEIGHTS_0']=io.addacc(g,b,ww,'VEC4',5126,34962)
 return v,ji,ww

# Pose controls are intentionally explicit. They describe distinct silhouettes,
# not a shared sine-wave gesture applied to the old animation tracks.
REST={'hips':[0,0,0],'pelvis':[0,0,0],'spine':[0,0,0],'chest':[0,0,0],'neck':[0,0,0],
 'head':[0,0,0],'jaw':2.,'ears':0.,'brow':0.,'tail':[0,0,0],'tail_base':[0,0,0],
 'left_hand':[.164,.084,.284],'right_hand':[-.2536,.07652,.1087],
 'left_foot':[.144,.031,.019],'right_foot':[-.1571,.04956,-.2008],
 'finger':0.,'toe':0.}
CROUCH={'hips':[0,-.080,-.035],'spine':[23,0,0],'chest':[20,0,0],
 'neck':[-15,0,0],'head':[-12,0,0],'jaw':15.,'ears':-24.,'brow':-12.,
 'left_hand':[.193,.062,.404],'right_hand':[-.193,.062,.404],
 'left_foot':[.158,.031,-.014],'right_foot':[-.169,.04956,-.217],
 'tail':[-10,0,0],'finger':-13.,'toe':-6.}
EXPOSED={'hips':[0,.012,-.014],'spine':[-14,0,0],'chest':[-12,0,0],
 'neck':[9,0,0],'head':[6,0,0],'jaw':18.,'ears':-8.,'brow':5.,
 'left_hand':[.247,.235,.168],'right_hand':[-.247,.235,.168],
 'tail':[9,0,0],'finger':12.}
FLIGHT={**CROUCH,'hips':[0,-.025,0],'spine':[28,0,0],'chest':[12,0,0],
 'left_hand':[.21,.16,.465],'right_hand':[-.21,.16,.465],
 'left_foot':[.15,.087,-.045],'right_foot':[-.17,.10,-.24],
 'jaw':24.,'tail':[-17,0,0]}
LAND={**CROUCH,'hips':[0,-.08,.012],'spine':[27,0,0],'chest':[22,0,0],
 'left_hand':[.205,.060,.435],'right_hand':[-.205,.060,.435],
 'head':[-20,0,0],'jaw':12.,'tail':[10,0,0]}

def control(**changes):return {**copy.deepcopy(REST),**copy.deepcopy(changes)}
def interpolate(keys,t):
 for i in range(len(keys)-1):
  ta,a=keys[i];tb,c=keys[i+1]
  if t<=tb:
   u=float(ss(ta,tb,t));a=control(**a);c=control(**c)
   return {k:(np.array(a[k])*(1-u)+np.array(c[k])*u).tolist() for k in REST}
 return control(**keys[-1][1])

class PoseAuthor:
 def __init__(self,g,names,pos):
  self.g=g;self.names=names;self.pos=pos;self.parents=io.hierarchy(g);self.rest=io.fk(g);self.pose={}
  source,buffer=io.parse(SOURCE);primitive=source['meshes'][0]['primitives'][0]
  vertices=io.readacc(source,buffer,primitive['attributes']['POSITION'])
  tail=vertices[(vertices[:,2]<-.14)&(vertices[:,1]>.24)]
  _,axes=np.linalg.eigh(np.cov(tail.T));normal=axes[:,0]
  if normal@(tail.mean(0)-pos['Tail01'])<0:normal=-normal
  axis=np.cross(normal,[0,1,0]);axis/=np.linalg.norm(axis)
  self.dead_tail_basis=R.from_rotvec(axis*math.acos(np.clip(normal[1],-1,1))).as_matrix()
 def rotate(self,name,degrees):self.pose.setdefault(self.names[name],{})['rotation']=R.from_euler('xyz',degrees,degrees=True).as_quat().tolist()
 def shift(self,name,delta):
  i=self.names[name];self.pose.setdefault(i,{})['translation']=(np.array(self.g['nodes'][i]['translation'])+delta).tolist()
 def aim(self,bone,child,direction,normal,restnormal):
  def frame(axis,n):
   axis=axis/np.linalg.norm(axis);n=n-axis*np.dot(n,axis)
   if np.linalg.norm(n)<1e-7:n=np.cross(axis,[1,0,0])
   n/=np.linalg.norm(n);return np.column_stack([axis,n,np.cross(axis,n)])
  i,c=self.names[bone],self.names[child];world=io.fk(self.g,self.pose)
  a=frame(self.pos[child]-self.pos[bone],restnormal);z=frame(direction,normal)
  parent=world[self.parents[i]][:3,:3]
  self.pose.setdefault(i,{})['rotation']=R.from_matrix(np.linalg.inv(parent)@z@a.T).as_quat().tolist()
 def ik(self,chain,goal,pole):
  a,b,c=chain;world=io.fk(self.g,self.pose);hip=world[self.names[a]][:3,3]
  u=self.pos[b]-self.pos[a];v=self.pos[c]-self.pos[b];la=np.linalg.norm(u);lb=np.linalg.norm(v)
  goal=np.array(goal);d=goal-hip;distance=np.linalg.norm(d);d/=max(distance,1e-8)
  length=np.clip(distance,abs(la-lb)+.001,(la+lb)*.995)
  pole=np.array(pole,float);pole-=d*np.dot(pole,d);pole/=max(np.linalg.norm(pole),1e-8)
  along=(la*la-lb*lb+length*length)/(2*length)
  elbow=hip+d*along+pole*math.sqrt(max(la*la-along*along,0))
  actual_goal=hip+d*length;normal=np.cross(elbow-hip,actual_goal-elbow)
  rn=np.cross(u,v)
  if np.linalg.norm(rn)<1e-7:rn=np.cross(u,pole)
  self.aim(a,b,elbow-hip,normal,rn)
  self.aim(b,c,actual_goal-elbow,normal,rn)
  world=io.fk(self.g,self.pose);parent=world[self.names[b]][:3,:3]
  self.pose.setdefault(self.names[c],{})['rotation']=R.from_matrix(np.linalg.inv(parent)).as_quat().tolist()
 def pose_at(self,name,t):
  self.pose={};ph=t*math.tau
  if name=='charge_tell':p=interpolate([(0,{}),(.30,CROUCH),(.73,{**CROUCH,'hips':[0,-.094,-.050],'jaw':23.}),(1,CROUCH)],t)
  elif name=='charge':p=interpolate([(0,CROUCH),(.12,FLIGHT),(.60,FLIGHT),(.85,LAND),(1,LAND)],t)
  elif name=='recover':p=interpolate([(0,LAND),(.28,EXPOSED),(.72,{**EXPOSED,'jaw':12.}),(1,EXPOSED)],t)
  elif name=='stomp_tell':p=interpolate([(0,{}),(.65,{**EXPOSED,'left_hand':[.25,.43,.28],'right_hand':[-.25,.43,.28],'jaw':26.}),(1,{**EXPOSED,'left_hand':[.25,.43,.28],'right_hand':[-.25,.43,.28],'jaw':26.})],t)
  elif name=='stomp':p=interpolate([(0,{**EXPOSED,'left_hand':[.25,.43,.28],'right_hand':[-.25,.43,.28]}),(.34,LAND),(.60,{**LAND,'hips':[0,-.09,0]}),(1,EXPOSED)],t)
  elif name in ['walk','run']:
   amp=.065 if name=='walk' else .10;lift=.025 if name=='walk' else .043
   p=control(hips=[0,-.022+.006*math.cos(ph*2),0],spine=[5,0,1.2*math.sin(ph)],chest=[4,1.5*math.sin(ph),0],head=[-3,-1.5*math.sin(ph),0])
   for side,off,sign in [('left',0,1),('right',.5,-1)]:
    for limb,phase in [('foot',(t+off)%1),('hand',(t+off+.5)%1)]:
     stance=phase<.62;q=phase/.62 if stance else (phase-.62)/.38
     z=amp*(1-2*q) if stance else amp*(-1+2*q);y=0 if stance else lift*math.sin(math.pi*q)
     base=np.array(REST[f'{side}_{limb}']);base[1]+=y;base[2]+=z;p[f'{side}_{limb}']=base.tolist()
   p['tail']=[2*math.sin(ph-.7),3*math.sin(ph-1.2),1.5*math.sin(ph)]
  elif name.startswith('death'):
   sign=1 if name in ['death','death_forward','death_left'] else -1
   lateral=name in ['death_left','death_right'];roll=sign*59 if lateral else sign*12
   fall={'hips':[sign*.035 if lateral else 0,-.145,-.012],
    'pelvis':[10 if name!='death_back' else -13,0,roll*.22],
    'spine':[38 if name!='death_back' else -36,0,roll*.38],
    'chest':[24 if name!='death_back' else -27,0,roll*.30],
    'head':[22,sign*8,-sign*12],'jaw':9.,'ears':-28.,'brow':3.,
    'left_hand':[.23,.055,.39],'right_hand':[-.23,.055,.39],
    'left_foot':[.21,.037,.10],'right_foot':[-.21,.037,.10],
    'tail':[10,sign*12,sign*55],'finger':16.}
   if name=='death_back':
    # The sculpt's chest already leans forward in bind space. A modest
    # negative rotation only sits it upright on its tail. Counter that lean
    # before rolling the connected torso onto its back; release both paws to
    # the sides and lay the curled tail aside rather than using it as a chair.
    fall.update(pelvis=[-3,0,-2],spine=[-82,0,-3],chest=[-38,0,-2],
     head=[30,-5,8],left_hand=[.26,.055,-.16],right_hand=[-.28,.055,-.18],
     tail=[0,0,0],tail_base=[90,70,0])
   brace={**CROUCH,'left_hand':[.24,.06,.40],'right_hand':[-.24,.06,.40],'jaw':22.}
   settled={**fall,'head':[28,sign*12,-sign*17],'jaw':5.,'tail':[15,sign*16,sign*65]}
   if name=='death_back':settled.update(head=[34,-7,10],tail=[0,0,0],tail_base=[88,78,4])
   p=interpolate([(0,{}),(.18,brace),(.52,fall),(.83,settled),(1,settled)],t)
  elif name=='hit':p=interpolate([(0,{}),(.24,{'spine':[-11,0,-4],'chest':[-14,0,5],'head':[-13,0,-7],'jaw':27.,'ears':-28.}),(1,{})],t)
  elif name=='stunned':p=control(**EXPOSED);p['head']=[12,3*math.sin(ph),6*math.sin(ph)];p['jaw']=12+5*math.sin(ph)
  elif name in ['fire','melee']:
   p=interpolate([(0,{}),(.28,{**EXPOSED,'right_hand':[-.21,.38,.36],'jaw':20.}),(.60,{**CROUCH,'right_hand':[-.14,.11,.47]}),(1,{})],t)
  elif name=='aim':p=control(**EXPOSED)
  elif name in ['turn_left','turn_right','alert']:
   turn=(-1 if name=='turn_left' else 1)*math.sin(math.pi*t)
   p=control(head=[-3,22*turn,0],chest=[0,7*turn,0],jaw=10 if name=='alert' else 2.)
  else:p=control(chest=[.7*math.sin(ph),0,.3*math.sin(ph+.4)],head=[-.6*math.sin(ph),1.1*math.sin(ph-.3),0],jaw=2+1.2*math.sin(ph))
  self.shift('Pelvis',np.array(p['hips']))
  for bone,key in [('Pelvis','pelvis'),('Spine01','spine'),('Spine02','chest'),('Neck','neck'),('Head','head')]:self.rotate(bone,p[key])
  self.rotate('Jaw',[p['jaw'],0,0])
  for side,sign in [('L',1),('R',-1)]:
   self.rotate(f'Ear.{side}',[p['ears'],0,sign*p['ears']*.3]);self.rotate(f'Brow.{side}',[0,0,sign*p['brow']])
   label='left' if side=='L' else 'right'
   self.rotate(f'Scapula.{side}',[0,0,sign*2*float(ss(.05,.20,p[f'{label}_hand'][1]))])
   self.ik([f'{side}_Upperarm',f'{side}_Forearm',f'{side}_Hand'],p[f'{label}_hand'],[sign*.65,0,-1])
   self.ik([f'{side}_Thigh',f'{side}_Calf',f'{side}_Foot'],p[f'{label}_foot'],[sign*.25,0,1])
   self.rotate(f'{side}_Fingers',[p['finger'],0,0]);self.rotate(f'{side}_ToeBase',[p['toe'],0,0])
  for k,bone in enumerate(['Tail01','Tail02','Tail03','Tail04','Tail05','TailTip']):
   d=np.array(p['tail'])*(.58 if k==0 else .15 if k<4 else .09)
   if not name.startswith('death'):d+=np.array([.65*math.sin(ph-k*.55),.9*math.sin(ph-k*.6),0])
   elif k>0:d+=np.array([8*math.sin(math.pi*float(np.clip((t-.07*k)/.70,0,1))),0,0])
   self.rotate(bone,np.array(p['tail_base']) if bone=='Tail01' and name=='death_back' else d)
  if name.startswith('death'):
   # The sculpted curl has a broad fur plane. Settle that plane beside the
   # body, thin axis upwards, so a thick hanging tail cannot prop the torso
   # off the ground. This is baked once, with joint follow-through; the phone
   # performs no PCA, IK, contact solver or procedural pose overlay.
   flatten=float(ss(.22,.82,t))
   for bone in ['Tail02','Tail03','Tail04','Tail05','TailTip']:
    index=self.names[bone];q=self.pose[index]['rotation']
    self.pose[index]['rotation']=Slerp([0,1],R.from_quat([q,[0,0,0,1]]))([flatten]).as_quat()[0].tolist()
   world=io.fk(self.g,self.pose);index=self.names['Tail01']
   support_basis=self.dead_tail_basis
   if name=='death_back':
    # The low hinge and asymmetric curl need a slight outward roll to let
    # the back and paws take weight before the fur's wide lower rim does.
    support_basis=R.from_euler('z',-10,degrees=True).as_matrix()@support_basis
   local=np.linalg.inv(world[self.names['Pelvis']][:3,:3])@support_basis
   q=self.pose[index]['rotation'];target=R.from_matrix(local).as_quat()
   self.pose[index]['rotation']=Slerp([0,1],R.from_quat([q,target]))([flatten]).as_quat()[0].tolist()
  return self.pose

def bake(g,b,names,pos,v,ji,ww):
 a=PoseAuthor(g,names,pos);hp=np.c_[v,np.ones(len(v))];skin=g['skins'][0]
 ibm=io.readacc(g,b,skin['inverseBindMatrices']).reshape(-1,4,4).transpose(0,2,1)
 allposes={};metrics={}
 for name,duration in CLIPS.items():
  times=np.linspace(0,duration,max(17,math.ceil(duration*30)+1),dtype=np.float32);poses=[];floors=[]
  for t in times/duration:
   pose=copy.deepcopy(a.pose_at(name,float(t)));world=io.fk(g,pose)
   m=np.array([world[n]@ibm[i] for i,n in enumerate(skin['joints'])]);dv=(np.einsum('nkij,nj->nki',m[ji],hp)*ww[:,:,None]).sum(1)
   air=.095*math.sin(math.pi*np.clip((t-.06)/.79,0,1)) if name=='charge' else 0.
   lift=air-float(dv[:,1].min());pose[names['BoneRoot']]={'translation':[0,lift,0]};floors.append(lift);poses.append(pose)
  ta=io.addacc(g,b,times,'SCALAR');samplers=[];channels=[]
  for node in skin['joints']:
   for prop,typ in [('rotation','VEC4'),('translation','VEC3')]:
    default=g['nodes'][node].get(prop,[0,0,0,1] if prop=='rotation' else [0,0,0])
    values=np.array([p.get(node,{}).get(prop,default) for p in poses],dtype=np.float32)
    if prop=='rotation':
     for i in range(1,len(values)):
      if values[i-1]@values[i]<0:values[i]*=-1
    samplers.append({'input':ta,'output':io.addacc(g,b,values,typ),'interpolation':'LINEAR'})
    channels.append({'sampler':len(samplers)-1,'target':{'node':node,'path':prop}})
  g.setdefault('animations',[]).append({'name':name,'samplers':samplers,'channels':channels,'extras':{'authoring':'guardian154 independent explicit anatomical poses +offline paw IK','sample_rate':30,'in_place':True}})
  allposes[name]=poses;metrics[name]={'frames':len(poses),'duration':duration,'root_y_min':min(floors),'root_y_max':max(floors)}
 return metrics

def main():
 g,b=io.parse(SOURCE);assert 'skins' not in g and 'animations' not in g
 names,pos=skeleton(g,b);v,ji,ww=weights(g,b,names,pos);metrics=bake(g,b,names,pos,v,ji,ww)
 g['extras']={'acorn_hunter_rig':{'version':154,'source_skeleton_preserved':False,
  'source_weights_preserved':False,'source_animations_preserved':False,'forward':'+Z',
  'actor_origin':'pelvis projected to ground','authoring':'explicit full-body keyed phase poses; offline paw IK; real skin floor envelopes'}}
 io.compact(g,b,OUTPUT)
 from author_squirrel_defeat149 import contact_bank
 gg,bb=io.parse(OUTPUT);contacts=ROOT/'assets/level1/characters/defeat149-contacts.json'
 bank=json.loads(contacts.read_text());bank['tank']=contact_bank(gg,bb);contacts.write_text(json.dumps(bank,separators=(',',':'))+'\n')
 manifest={'version':154,'replaces':'rig149-provenance.json tank only; original files retained as historical source evidence',
  'mesh_source':str(SOURCE.relative_to(ROOT)),'mesh_source_sha256':hashlib.sha256(SOURCE.read_bytes()).hexdigest(),
  'runtime_path':str(OUTPUT.relative_to(ROOT)),'runtime_sha256':hashlib.sha256(OUTPUT.read_bytes()).hexdigest(),
  'tool':str(Path(__file__).relative_to(ROOT)),'tool_sha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
  'bones':list(names),'inherited_bones':0,'inherited_weights':False,'inherited_clips':0,
  'vertices':len(v),'triangles':len(io.readacc(gg,bb,gg['meshes'][0]['primitives'][0]['indices']))//3,
  'max_weight_error':float(abs(ww.sum(1)-1).max()),'clips':metrics,
  'contacts_sha256':hashlib.sha256(contacts.read_bytes()).hexdigest()}
 (ROOT/'assets/level1/characters/rig154-provenance.json').write_text(json.dumps(manifest,indent=2)+'\n')
 print(json.dumps({'result':'BUILT','bones':len(names),'vertices':len(v),'clips':len(CLIPS),'bytes':OUTPUT.stat().st_size}))

if __name__=='__main__':main()
