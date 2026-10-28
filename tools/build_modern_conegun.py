"""Original CEDAR pneumatic carbine and anatomically posed support hand.
Offline Blender authoring; output is a finite, opaque game mesh, never runtime CSG.
Run: blender --background --factory-startup --python tools/build_modern_conegun.py
"""
from pathlib import Path
import bpy, math, json, hashlib, os
from mathutils import Vector, Matrix
ROOT=Path(__file__).resolve().parents[1]
OUT=Path(os.environ.get('CEDAR_OUTPUT_DIR',str(ROOT/'assets/level1/weapons/cedar')))
PREVIEW=Path('/workspace/scratch/weapon-147')
OUT.mkdir(parents=True,exist_ok=True);PREVIEW.mkdir(parents=True,exist_ok=True)
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
# Author in game coordinates: right=X, up=Y, muzzle=-Z. Convert to Blender Z-up.
def cv(v):return Vector((v[0],-v[2],v[1]))
def srgb(h):
 return tuple(((int(h[i:i+2],16)/255+.055)/1.055)**2.4 if int(h[i:i+2],16)/255>.04045 else int(h[i:i+2],16)/255/12.92 for i in (0,2,4))
def material(name,h,metal=0,rough=.65):
 m=bpy.data.materials.new(name);m.diffuse_color=(*srgb(h),1);m.use_nodes=True
 p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(*srgb(h),1);p.inputs['Metallic'].default_value=metal;p.inputs['Roughness'].default_value=rough
 return m
M={
 'metal':material('Graphite | anodised receiver','3b454d',.65,.45),
 'olive':material('Muted olive | ceramic shell','66745a',.05,.58),
 'rubber':material('Grip | soft charcoal polymer','222b30',.0,.76),
 'brass':material('Satin titanium | pressure fittings','b3a48a',.55,.42),
 'amber':material('Safety | restrained amber','e4a04f',.08,.52),
 'skin':material('Carolina | warm fair skin','d7a391',0,.59),
 'nails':material('Natural nails | soft rose','cc9890',0,.38),
 'sleeve':material('Charcoal hoodie | woven cuff','35363c',0,.9),
 'cone':material('Pine cone | small loaded rounds','8d6544',0,.84),
}
G={k:[] for k in M};HAND=[]
def finish(o,k,name,bevel=0,smooth=False):
 o.name=name;o.data.materials.append(M[k]);G[k].append(o)
 if bevel:
  mod=o.modifiers.new('Machined radii','BEVEL');mod.width=bevel;mod.segments=2;mod.affect='EDGES'
  bpy.context.view_layer.objects.active=o;bpy.ops.object.modifier_apply(modifier=mod.name)
 if smooth:
  for poly in o.data.polygons:poly.use_smooth=True
 return o
def box(name,p,size,k,bevel=.003,rotate=None):
 bpy.ops.mesh.primitive_cube_add(size=1,location=cv(p));o=bpy.context.object;o.dimensions=(size[0],size[2],size[1]);bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
 if rotate:o.rotation_euler=rotate
 return finish(o,k,name,bevel)
def tube(name,p0,p1,r0,r1,k,n=24):
 a,b=cv(p0),cv(p1);d=b-a;bpy.ops.mesh.primitive_cone_add(vertices=n,radius1=r0,radius2=r1,depth=d.length,location=(a+b)/2);o=bpy.context.object;o.rotation_euler=d.to_track_quat('Z','Y').to_euler();return finish(o,k,name,0,True)
def sphere(name,p,scale,k,segments=24,rings=12):
 bpy.ops.mesh.primitive_uv_sphere_add(segments=segments,ring_count=rings,radius=1,location=cv(p));o=bpy.context.object;o.scale=(scale[0],scale[2],scale[1]);bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);return finish(o,k,name,0,True)
def mesh(name,verts,faces,k,smooth=False):
 d=bpy.data.meshes.new(name);d.from_pydata([cv(v) for v in verts],[],faces);d.update();o=bpy.data.objects.new(name,d);bpy.context.collection.objects.link(o);return finish(o,k,name,0,smooth)
def hollow(name,z0,z1,outer,inner,y,k):
 verts=[];n=32
 for z,r in [(z0,outer),(z1,outer),(z0,inner),(z1,inner)]:
  verts += [(math.cos(i*math.tau/n)*r,y+math.sin(i*math.tau/n)*r,z) for i in range(n)]
 faces=[]
 for i in range(n):
  j=(i+1)%n;faces += [(i,j,n+j,n+i),(2*n+j,2*n+i,3*n+i,3*n+j),(i,2*n+i,2*n+j,j),(n+j,3*n+j,3*n+i,n+i)]
 return mesh(name,verts,faces,k,True)
def prism(name,outline,xhalf,k,bevel=.003):
 verts=[(x,y,z) for x in (-xhalf,xhalf) for y,z in outline];n=len(outline);faces=[tuple(range(n-1,-1,-1)),tuple(range(n,2*n))]
 for i in range(n):j=(i+1)%n;faces.append((i,j,n+j,n+i))
 o=mesh(name,verts,faces,k);mod=o.modifiers.new('Rounded shell edges','BEVEL');mod.width=bevel;mod.segments=2;bpy.context.view_layer.objects.active=o;bpy.ops.object.modifier_apply(modifier=mod.name);return o
# Functional gun skeleton and bevelled outer shells.
prism('Cedar angled upper receiver',[(.055,.22),(.071,.185),(.071,-.115),(.035,-.15),(-.045,-.13),(-.065,.14),(-.025,.22)],.049,'metal',.006)
prism('Olive rear side shell',[(.044,.205),(.055,.175),(.055,-.075),(.018,-.105),(-.032,-.075),(-.044,.165)],.053,'olive',.004)
# Visible upper charging spine, chamber and folding sights.
box('Steel top spine',(0,.078,.025),(.064,.025,.34),'metal',.004)
box('Inlaid top rail',(0,.097,-.075),(.033,.014,.265),'rubber',.002)
for i in range(11):box('Rail tooth %02d'%i,(0,.107,-.19+i*.022),(.041,.009,.011),'metal',.0015)
box('Rear aperture foot',(0,.119,.055),(.042,.021,.035),'metal',.003)
hollow('Rear peep sight',.040,.052,.013,.007,.142,'metal')
box('Front sight plinth',(0,.086,-.467),(.030,.025,.04),'metal',.002)
box('Fine amber sight',(0,.109,-.467),(.005,.024,.008),'amber',.001)
# Stock is an open, compact shoulder structure rather than a wooden plank.
box('Stock cheek piece',(0,.036,.275),(.083,.055,.145),'rubber',.012)
box('Stock lower strut',(0,-.036,.284),(.040,.026,.15),'metal',.004)
box('Stock butt pad',(0,-.005,.353),(.092,.136,.024),'rubber',.011)
for y in [-.041,-.018,.005,.028]:box('Butt texture band',(0,y,.368),(.072,.005,.002),'metal',.001)
# Rear pistol grip and a real open trigger bow.
prism('Ergonomic rear grip',[(-.035,.117),(-.045,.041),(-.190,.098),(-.186,.158),(-.064,.144)],.028,'rubber',.008)
for i in range(5):box('Rear grip scallop',(0,-.083-i*.017,.125+i*.006),(.058,.006,.028),'metal',.0015)
box('Trigger bow front',(0,-.110,-.005),(.019,.094,.015),'metal',.004)
box('Trigger bow lower',(0,-.155,.040),(.020,.015,.10),'metal',.004)
box('Curved trigger blade',(0,-.098,.030),(.008,.053,.012),'brass',.004)
# Steel pressure barrel, real hollow bore and two shroud bands.
hollow('Pressure barrel',-.11,-.64,.024,.015,.033,'metal')
hollow('Muzzle collar',-.601,-.651,.031,.015,.033,'brass')
hollow('Recessed black muzzle throat',-.648,-.615,.016,.014,.033,'rubber')
# Top/bottom handguard spines with open side ventilation slots.
box('Foregrip upper',(0,.064,-.285),(.090,.025,.285),'olive',.007)
box('Rounded support foregrip',(0,-.031,-.257),(.066,.057,.235),'rubber',.012)
for x in [-.044,.044]:
 for z in [-.169,-.235,-.301,-.367]:box('Open handguard rib',(x,.017,z),(.009,.066,.020),'olive',.004)
 box('Side handguard rail',(x,.043,-.267),(.009,.012,.240),'olive',.003)
for i in range(6):box('Foregrip tactile ridge',(0,-.060,-.160-i*.035),(.079,.006,.012),'metal',.002)
# Small pneumatic reservoir, hose and pressure dial make the design readable.
tube('Reservoir shell',(0,-.090,.025),(0,-.090,.185),.026,.026,'brass',24)
tube('Reservoir valve',(0,-.090,.19),(0,-.090,.216),.016,.016,'metal',20)
for x in [-.048,.048]:
 tube('Satin side fastener',(x-.002,.024,.155),(x+.002,.024,.155),.006,.006,'brass',12)
 tube('Satin forward fastener',(x-.002,.012,-.065),(x+.002,.012,-.065),.006,.006,'brass',12)
box('Left recessed cassette',(-.060,-.006,.026),(.025,.084,.168),'rubber',.005)
box('Cassette lower lip',(-.077,-.046,.026),(.012,.009,.157),'olive',.002)
box('Cassette upper lip',(-.077,.033,.026),(.012,.009,.157),'olive',.002)
for z in [-.054,.105]:box('Cassette end rail',(-.076,-.005,z),(.011,.076,.008),'olive',.002)
# Three small closed pine-cones: pointed profiles and raised overlapping scales.
# They are ammunition, visibly distinct from the smooth acorns in the story.
for row in range(3):
 z=-.025+row*.049;center=Vector((-.077,-.003,z));rings=7;sides=12;vv=[]
 for ring in range(rings):
  t=ring/(rings-1);yy=-.029+t*.058;radius=.014*math.sin(t*math.pi)**.72+.0015
  for j in range(sides):
   angle=j*math.tau/sides
   vv.append(tuple(center+Vector((math.cos(angle)*radius,yy,math.sin(angle)*radius))))
 ff=[]
 for ring in range(rings-1):
  for j in range(sides):q=(j+1)%sides;ff.append((ring*sides+j,ring*sides+q,(ring+1)*sides+q,(ring+1)*sides+j))
 mesh('Pointed pine-cone core',vv,ff,'cone',True)
 for ring in range(5):
  t=(ring+.6)/5.9;yy=-.029+t*.058;rad=.014*math.sin(t*math.pi)**.72+.0015
  for j in range(8):
   angle=j*math.tau/8+ring*.43;out=Vector((math.cos(angle),0,math.sin(angle)));tangent=Vector((-math.sin(angle),0,math.cos(angle)))
   c=center+out*rad+Vector((0,yy,0));up=Vector((0,1,0))
   points=[c-tangent*.005-up*.005,c+tangent*.005-up*.005,c+tangent*.004+up*.002,c+up*.007,c-tangent*.004+up*.002,c+out*.0035]
   mesh('Raised woody pine-cone scale',[tuple(v) for v in points],[(0,1,5),(1,2,5),(2,3,5),(3,4,5),(4,0,5)],'cone')
# Restrained safety switches and tiny panel markings are actual geometry.
box('Amber safety switch',(-.057,.024,.169),(.008,.012,.031),'amber',.002)
box('Battery condition mark',(-.057,.033,-.071),(.003,.007,.024),'amber',.001)
for i in range(3):box('CEDAR indicator',(-.057,.032,.015+i*.016),(.002,.004,.009),'brass',.0007)
# The support hand is built below from the retained CC0 anatomical subset.
# Weapon geometry, materials and hand posing code are original work.
# Join static pieces by material: a bounded draw cost, not hundreds of runtime nodes.
for key,objects in G.items():
 objects=[o for o in objects if o.name in bpy.data.objects]
 if not objects:continue
 if key=='skin':continue
 bpy.ops.object.select_all(action='DESELECT')
 for o in objects:o.select_set(True)
 bpy.context.view_layer.objects.active=objects[0];bpy.ops.object.join();objects[0].name={'metal':'MachinedMetal','olive':'OliveShell','rubber':'PolymerFittings','brass':'SatinHardware','amber':'AmberSafety','nails':'NaturalFingernails','sleeve':'HoodieSleeve','cone':'ConeMagazine'}.get(key,key)
# Bake the nine constant PBR swatches into two tiny embedded atlases. Shared
# opaque material preserves all finishes with only gun/skin/sleeve draw batches.
atlas_color=bpy.data.images.new('CEDAR flat colour atlas',width=16,height=2,alpha=True)
atlas_color.colorspace_settings.name='sRGB'
atlas_rm=bpy.data.images.new('CEDAR roughness metallic atlas',width=16,height=2,alpha=True)
atlas_rm.colorspace_settings.name='Non-Color'
keys=list(M);colour_pixels=[];rm_pixels=[]
def to_srgb(c):return c*12.92 if c<=.0031308 else 1.055*c**(1/2.4)-.055
for yy in range(2):
 for x in range(16):
  key=keys[min(x,len(keys)-1)];src=M[key];principled=src.node_tree.nodes.get('Principled BSDF')
  colour_pixels.extend([*(to_srgb(v) for v in src.diffuse_color[:3]),1])
  rm_pixels.extend([1,float(principled.inputs['Roughness'].default_value),float(principled.inputs['Metallic'].default_value),1])
atlas_color.pixels=colour_pixels;atlas_color.pack()
atlas_rm.pixels=rm_pixels;atlas_rm.pack()
atlas=bpy.data.materials.new('CEDAR shared opaque PBR atlas');atlas.use_nodes=True
nodes=atlas.node_tree.nodes;links=atlas.node_tree.links;principled=nodes.get('Principled BSDF')
tex=nodes.new('ShaderNodeTexImage');tex.image=atlas_color;tex.interpolation='Closest';links.new(tex.outputs['Color'],principled.inputs['Base Color'])
rm=nodes.new('ShaderNodeTexImage');rm.image=atlas_rm;rm.interpolation='Closest'
channels=nodes.new('ShaderNodeSeparateColor');channels.mode='RGB';links.new(rm.outputs['Color'],channels.inputs['Color']);links.new(channels.outputs['Green'],principled.inputs['Roughness']);links.new(channels.outputs['Blue'],principled.inputs['Metallic'])
for obj in [o for o in scene.objects if o.type=='MESH'] if 'scene' in globals() else [o for o in bpy.context.scene.objects if o.type=='MESH']:
 for previous_uv in list(obj.data.uv_layers):obj.data.uv_layers.remove(previous_uv)
 uv=obj.data.uv_layers.new(name='UVMap')
 for polygon in obj.data.polygons:
  old=obj.data.materials[polygon.material_index];idx=next(i for i,key in enumerate(keys) if M[key]==old)
  for loop in polygon.loop_indices:uv.data[loop].uv=((idx+.5)/16,.5)
 obj.data.materials.clear();obj.data.materials.append(atlas)
 for polygon in obj.data.polygons:polygon.material_index=0
all_meshes=[o for o in bpy.context.scene.objects if o.type=='MESH']
for title,group in [('CedarGunAssembly',all_meshes)]:
 bpy.ops.object.select_all(action='DESELECT')
 for obj in group:obj.select_set(True)
 bpy.context.view_layer.objects.active=group[0];bpy.ops.object.join();group[0].name=title

# Pose the licensed anatomical hand around the finished foregrip.
import sys
sys.path.insert(0,str(ROOT/'tools'))
from cedar_anatomical_hand import create_support_hand
hand_info=create_support_hand(atlas,ROOT)
# Logical contact and muzzle sockets exported in real game coordinates.
for name,p in [('MuzzleSocket',(0,.033,-.651)),('SupportPalmSocket',(-.015,-.060,-.235)),('ThumbContact',(-.033,-.011,-.269)),('WristSocket',tuple(hand_info['wrist']))]:
 o=bpy.data.objects.new(name,None);o.location=cv(p);bpy.context.collection.objects.link(o)
# Unexported groundless modelling reference cameras and light rig.
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=32;scene.cycles.use_denoising=False;scene.cycles.max_bounces=5
scene.render.resolution_x=1280;scene.render.resolution_y=800;scene.render.resolution_percentage=100
scene.world.use_nodes=True;scene.world.node_tree.nodes['Background'].inputs['Color'].default_value=(.025,.038,.06,1);scene.world.node_tree.nodes['Background'].inputs['Strength'].default_value=.35
for name,p,power,size in [('Soft key',(-.7,.8,.6),20,1.0),('Cool rim',(.5,.3,-.7),14,.7),('Fill',(-.2,-.3,-.5),8,.6)]:
 d=bpy.data.lights.new(name,'AREA');d.energy=power;d.shape='DISK';d.size=size;o=bpy.data.objects.new(name,d);bpy.context.collection.objects.link(o);o.location=cv(p);o.rotation_euler=(cv((0,0,-.1))-o.location).to_track_quat('-Z','Y').to_euler()
camd=bpy.data.cameras.new('WeaponReferenceCamera');cam=bpy.data.objects.new('WeaponReferenceCamera',camd);bpy.context.collection.objects.link(cam);scene.camera=cam;cam.location=cv((-.95,.43,.85));cam.rotation_euler=(cv((-.04,-.05,-.13))-cam.location).to_track_quat('-Z','Y').to_euler();camd.lens=48
scene.view_settings.view_transform='AgX';scene.render.image_settings.file_format='PNG';scene.render.filepath=str(PREVIEW/'cedar-model.png')
# Export only authored geometry and sockets. No lights/cameras or runtime CSG.
bpy.ops.object.select_all(action='DESELECT')
for o in bpy.context.scene.objects:
 if o.type in {'MESH','EMPTY'}:o.select_set(True)
asset=OUT/'cedar_runtime.glb'
bpy.ops.export_scene.gltf(filepath=str(asset),use_selection=True,export_format='GLB',export_yup=True,export_apply=True,export_animations=False,export_materials='EXPORT')
triangles=sum(len(o.data.loop_triangles) for o in bpy.context.scene.objects if o.type=='MESH')
for o in bpy.context.scene.objects:
 if o.type=='MESH':o.data.calc_loop_triangles()
triangles=sum(len(o.data.loop_triangles) for o in bpy.context.scene.objects if o.type=='MESH')
provenance={'name':'CEDAR compact pneumatic cone carbine','authoring':'Original CEDAR weapon, materials and pose code. Left hand/forearm anatomy derived from explicitly CC0 MakeHuman mesh/weights data, retained as a restricted arm-only source subset. No photographs or generated images used.','output':'assets/level1/weapons/cedar/cedar_runtime.glb','sha256':hashlib.sha256(asset.read_bytes()).hexdigest(),'mesh_objects':sum(o.type=='MESH' for o in scene.objects),'triangles':triangles,'style':{'receiver':'graphite','shell':'muted olive','hardware':'satin titanium','marks':'amber','hand':'female anatomical left hand, fair warm skin, natural short nails, charcoal hoodie cuff'},'dimensions_m':{'barrel_bore_diameter':.030,'gun_length_raw':1.019,'runtime_uniform_scale':.78,'gun_length_runtime':.79482,'receiver_width':.106,'palm_width':.086,'palm_width_runtime':.06708,'continuous_skin_components':hand_info['continuous_skin_components']},'socket_coordinates':{'muzzle':[0,.033,-.651],'palm':[-.015,-.060,-.235],'thumb':[-.033,-.011,-.269]},'tool_sha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),'runtime':'finite opaque mesh; three shared opaque atlas batches; no CSG, postprocessing or texture generation during gameplay'}
provenance['hand_anatomy']=hand_info
provenance['external_sources']=[{'file':'art/level1/cedar/source/'+name,'sha256':hashlib.sha256((ROOT/'art/level1/cedar/source'/name).read_bytes()).hexdigest()} for name in ['left_hand_forearm.json','SOURCES.json']]
provenance['licences']=[{'file':'art/level1/cedar/source/LICENSE.CC0.txt','sha256':hashlib.sha256((ROOT/'art/level1/cedar/source/LICENSE.CC0.txt').read_bytes()).hexdigest()}]
provenance['pose_tool']={'file':'tools/cedar_anatomical_hand.py','sha256':hashlib.sha256((ROOT/'tools/cedar_anatomical_hand.py').read_bytes()).hexdigest()}
provenance['extraction_tool']={'file':'tools/extract_cedar_hand_source.py','sha256':hashlib.sha256((ROOT/'tools/extract_cedar_hand_source.py').read_bytes()).hexdigest()}
notice='CEDAR female support hand / forearm anatomy\nDerived from MakeHuman Community CC0 model and rig DATA, September 2020 release.\nImmutable source commit: a8bc2d54ff0ac92e78ff71431b1023eda42bf482\nSource and licences: art/level1/cedar/source/SOURCES.json (authoring repository).\nWeapon geometry, materials and pose/extraction code are original game work.\n\n'+(ROOT/'art/level1/cedar/source/LICENSE.CC0.txt').read_text()
(OUT/'CEDAR_HAND_CC0.txt').write_text(notice)
provenance['licences'].append({'file':'assets/level1/weapons/cedar/CEDAR_HAND_CC0.txt','sha256':hashlib.sha256((OUT/'CEDAR_HAND_CC0.txt').read_bytes()).hexdigest()})
(OUT/'PROVENANCE.json').write_text(json.dumps(provenance,indent=2)+'\n')
print('CEDAR BUILD:',json.dumps({'triangles':triangles,'bytes':asset.stat().st_size,'meshes':provenance['mesh_objects']}))
# Reference render is an actual model render, not a source/texture to ship.
if os.environ.get('CEDAR_SKIP_RENDER')!='1':bpy.ops.render.render(write_still=True)
