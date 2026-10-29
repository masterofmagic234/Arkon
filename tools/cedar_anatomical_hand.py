"""Pose CC0 MakeHuman left-hand/forearm DATA; all authoring code is original.
No upstream MakeHuman program code is imported. See art/level1/cedar/source.
"""
from pathlib import Path
import bpy, json, math, hashlib
from mathutils import Vector, Matrix

def create_support_hand(atlas, root):
    source_dir=Path(root)/'art/level1/cedar/source'
    source_path=source_dir/'left_hand_forearm.json'
    manifest=json.loads((source_dir/'SOURCES.json').read_text())
    assert hashlib.sha256(source_path.read_bytes()).hexdigest()==manifest['extracted_sha256']
    data=json.loads(source_path.read_text())
    assert data['license']=='CC0-1.0'
    V=[Vector(p) for p in data['vertices']]
    groups={'body':data['faces']}
    rig={'bones':data['bones']}
    weights=data['weights']
    def cv(v):return Vector((v[0],-v[2],v[1]))
    def inv(v):return Vector((v[0],v[2],-v[1]))
    def joint(name):return Vector(data['joints'][name])
    def helper(name):return Vector(data['helpers'][name])
    w=helper('joint-l-hand');u=(helper('joint-l-finger-3-1')-w).normalized();v=helper('joint-l-finger-2-1')-helper('joint-l-finger-5-1');v=(v-u*v.dot(u)).normalized();n=u.cross(v).normalized()
    # Anatomical palm orientation and proportions. The hand supports from below;
    # fingers curl naturally around a real ~52mm-wide runtime foregrip.
    YAW=math.radians(15);ROLL=math.radians(25)
    rot=Matrix.Rotation(ROLL,3,'Z')@Matrix.Rotation(YAW,3,'Y');wrist=Vector((-.053,-.115,-.224));scale=.11
    def rest(p):return rot@Vector(((p-w).dot(u),(p-w).dot(n),-(p-w).dot(v)))*scale+wrist
    bones={}
    for name,b in rig['bones'].items():
     if name.endswith('.L') and any(k in name for k in ['finger','metacarpal','wrist','lowerarm','upperarm']):
      bones[name]=(rest(joint(b['head'])),rest(joint(b['tail'])))
    transforms={}
    # Wrist and metacarpals retain the professionally sculpted palm shape.
    for name in bones:transforms[name]=(Matrix.Identity(3),Vector())
    # Rotate the actual forearm towards the camera/charcoal cuff without stretching.
    elbow=rest(helper('joint-l-elbow'));desired=Vector((-.190,-.075,.110)).normalized()*(elbow-wrist).length
    q=(elbow-wrist).rotation_difference(desired).to_matrix()
    for name in ['lowerarm01.L','lowerarm02.L','upperarm01.L','upperarm02.L']:
     transforms[name]=(q,wrist-q@wrist)
    # The angled palm crosses beneath the handguard and puts the knuckles at
    # its far corner. Starting under its centre leaves insufficient finger
    # length for a closed grasp, however aggressively the last joint is bent.
    targets={}
    # The two distal joints solve actual bone lengths, choosing the outside bend.
    # A small proximal lift and lower distal target leave enough length for the
    # last joint to curl inward without driving skin into the handguard.
    end_y={2:0,3:.004,4:.002,5:-.021}
    end_x={2:.032,3:.025,4:.027,5:.036}
    proximal_angles={2:75,3:80,4:80,5:75}
    for finger in range(2,6):
     names=[f'finger{finger}-{i}.L' for i in range(1,4)]
     lengths=[(bones[name][1]-bones[name][0]).length for name in names]
     h=bones[names[0]][0]
     angle=math.radians(proximal_angles[finger]);first=h+Vector((math.cos(angle),math.sin(angle),0))*lengths[0]
     tip=Vector((end_x[finger],end_y[finger],h.z))
     dvec=tip-first;distance=dvec.length;reach=lengths[1]+lengths[2]
     if distance>reach-.0003:tip=first+dvec.normalized()*(reach-.0003);dvec=tip-first;distance=dvec.length
     direction=dvec.normalized();a=(lengths[1]**2-lengths[2]**2+distance**2)/(2*distance);height=max(0,lengths[1]**2-a*a)**.5
     perp=Vector((-direction.y,direction.x,0)).normalized();mid=first+direction*a-perp*height
     points=[h,first,mid,tip]
     targets[finger]=[list(p) for p in points]
     for i,name in enumerate(names):
      rh,rt=bones[name];R=(rt-rh).rotation_difference(points[i+1]-points[i]).to_matrix();transforms[name]=(R,points[i]-R@rh)
    # The thumb lies along the near side of the handguard. Keeping the thumb's
    # metacarpal low avoids the old vertical thumbs-up silhouette and acute tip.
    name='finger1-1.L';head=bones[name][0];points=[head]
    for index,direction in enumerate([Vector((-.011,.026,-.006)),Vector((.001,.025,-.030)),Vector((-.001,.001,-.025))],1):
     b=f'finger1-{index}.L';rh,rt=bones[b];points.append(points[-1]+direction.normalized()*(rt-rh).length);R=(rt-rh).rotation_difference(points[-1]-points[-2]).to_matrix();transforms[b]=(R,points[-2]-R@rh)
    targets[1]=[list(p) for p in points]
    # Only the left hand and forearm are extracted, never a whole unclothed human.
    faces=groups['body'];source_face_count=len(faces);ids=sorted({i for f in faces for i in f});mapping={old:new for new,old in enumerate(ids)}
    vertex_weights={i:[] for i in ids}
    for name,entries in weights.items():
     if name not in transforms:continue
     for i,amount in entries:
      if i in vertex_weights and amount>0:vertex_weights[i].append((name,amount))
    posed=[]
    for i in ids:
     p=rest(V[i]);terms=vertex_weights[i];total=sum(t[1] for t in terms)
     assert total>.70,(i,total)
     value=Vector()
     for name,amount in terms:
      R,T=transforms[name];value+=(R@p+T)*(amount/total)
     posed.append(cv(value))
    mesh=bpy.data.meshes.new('CC0 anatomical left hand and forearm');mesh.from_pydata(posed,[],[[mapping[i] for i in f] for f in faces]);mesh.update();hand=bpy.data.objects.new('FemaleSupportHand',mesh);bpy.context.collection.objects.link(hand);hand.data.materials.append(atlas)
    # The existing atlas includes restrained natural nail/skin finishes. Mark the
    # actual dorsal nail-bed polygons in rest coordinates, rather than adding blobs.
    uv=mesh.uv_layers.new(name='UVMap');nail_faces=0
    for polygon,old_face in zip(mesh.polygons,faces):
     center=sum((rest(V[i]) for i in old_face),Vector())/len(old_face);is_nail=False
     for finger in range(1,6):
      name=f'finger{finger}-3.L';h,t=bones[name];d=(t-h).normalized();length=(t-h).length;along=(center-h).dot(d)/length;back=-(rot@Vector((0,1,0)));back=(back-d*back.dot(d)).normalized();radial=center-h-d*(center-h).dot(d)
      if .50<along<.90 and radial.length>.001 and radial.dot(back)/radial.length>.78 and sum(dict(vertex_weights[i]).get(name,0) for i in old_face)/len(old_face)>.65:is_nail=True;break
     index=6 if is_nail else 5
     if is_nail:nail_faces+=1
     for loop in polygon.loop_indices:uv.data[loop].uv=((index+.5)/16,.5)
    for p in mesh.polygons:p.use_smooth=True
    # Smooth the professional topology, then decimate without remeshing fingers.
    bpy.context.view_layer.objects.active=hand;hand.select_set(True)
    sub=hand.modifiers.new('Anatomical surface continuity','SUBSURF');sub.levels=1;sub.subdivision_type='CATMULL_CLARK';sub.uv_smooth='PRESERVE_BOUNDARIES';bpy.ops.object.modifier_apply(modifier=sub.name)
    dec=hand.modifiers.new('Bounded hand topology','DECIMATE');dec.ratio=.52;bpy.ops.object.modifier_apply(modifier=dec.name)
    # A restrained, smooth skin tint keeps the original opaque atlas/batch.
    # COLOR_0 is multiplied by the common PBR base colour in glTF. No additional
    # texture, transparency, runtime shading pass or skin mesh is introduced.
    tone=hand.data.color_attributes.new(name='SkinTone',type='FLOAT_COLOR',domain='CORNER')
    for polygon in hand.data.polygons:
     is_nail=all(hand.data.uv_layers.active.data[i].uv.x>6/16 for i in polygon.loop_indices)
     for loop_index in polygon.loop_indices:
      if is_nail:colour=(1,1,1,1)
      else:
       point=inv(hand.data.vertices[hand.data.loops[loop_index].vertex_index].co)
       warmth=math.exp(-((point.z+.25)/.065)**2)*.025
       shade=.975-.015*math.sin(point.z*37+point.x*19)
       colour=(shade,min(1,shade-warmth),min(1,shade-warmth*1.2),1)
      tone.data[loop_index].color=colour
    # Tailor an open cuff to the actual posed anatomical forearm cross-sections.
    # The old procedural sleeve would clip the real model's asymmetric muscles.
    for old in list(bpy.data.objects):
     if old.name=='HoodieSleeve':bpy.data.objects.remove(old,do_unlink=True)
    axis=desired.normalized();cross_u=axis.cross(Vector((0,1,0))).normalized();cross_v=axis.cross(cross_u).normalized()
    hand_positions=[inv(hand.matrix_world@vertex.co) for vertex in hand.data.vertices]
    profiles=[]
    profile_t=[.072,.079,.087,.10,.12,.145,.18,.22,.27,.34,.44,.54]
    maximum_skin_t=max((p-wrist).dot(axis) for p in hand_positions)
    for t in profile_t:
     samples=[p for p in hand_positions if abs((p-wrist).dot(axis)-min(t,maximum_skin_t-.008))<.016]
     if samples:
      lo_u=min((p-wrist-axis*t).dot(cross_u) for p in samples);hi_u=max((p-wrist-axis*t).dot(cross_u) for p in samples)
      lo_v=min((p-wrist-axis*t).dot(cross_v) for p in samples);hi_v=max((p-wrist-axis*t).dot(cross_v) for p in samples)
      center=wrist+axis*t+cross_u*((lo_u+hi_u)*.5)+cross_v*((lo_v+hi_v)*.5)
      ru=(hi_u-lo_u)*.5+.0035;rv=(hi_v-lo_v)*.5+.0035
     else:center=wrist+axis*t;ru=.040;rv=.034
     if t>.23:ru+=min(.010,(t-.23)*.035);rv+=min(.008,(t-.23)*.025)
     if t<=.079:ru+=.001;rv+=.001
     profiles.append((center,ru,rv))
    # A bounding ellipse of an asymmetric anatomical section is not the same as
    # the section's bounding rectangle. Fit the actual skin between rings too;
    # otherwise a forearm corner can poke through a seemingly generous sleeve.
    for iteration in range(2):
     for point in hand_positions:
      t=(point-wrist).dot(axis)
      if t<profile_t[0] or t>profile_t[-1]:continue
      i=next(i for i in range(len(profile_t)-1) if profile_t[i]<=t<=profile_t[i+1])
      fraction=(t-profile_t[i])/(profile_t[i+1]-profile_t[i])
      a,ru0,rv0=profiles[i];b,ru1,rv1=profiles[i+1]
      center=a.lerp(b,fraction);ru=ru0*(1-fraction)+ru1*fraction;rv=rv0*(1-fraction)+rv1*fraction
      radial=point-center;required=math.sqrt((radial.dot(cross_u)/ru)**2+(radial.dot(cross_v)/rv)**2)
      if required>.965:
       factor=required/.965
       for ring in [i,i+1]:
        c,r_u,r_v=profiles[ring];profiles[ring]=(c,r_u*factor,r_v*factor)
    vertices=[];faces=[];sides=24
    for ring,(center,ru,rv) in enumerate(profiles):
     for i in range(sides):
      angle=i*math.tau/sides;fold=1+(.012*math.sin(angle*6+ring*.4) if ring>2 else 0)
      vertices.append(cv(center+cross_u*math.cos(angle)*ru*fold+cross_v*math.sin(angle)*rv*fold))
    for ring in range(len(profiles)-1):
     for i in range(sides):q=(i+1)%sides;faces.append((ring*sides+i,ring*sides+q,(ring+1)*sides+q,(ring+1)*sides+i))
    d=bpy.data.meshes.new('Tailored charcoal sleeve and open cuff');d.from_pydata(vertices,[],faces);d.update();sleeve=bpy.data.objects.new('HoodieSleeve',d);bpy.context.collection.objects.link(sleeve);d.materials.append(atlas);layer=d.uv_layers.new(name='UVMap')
    for polygon in d.polygons:
     polygon.use_smooth=True
     for loop in polygon.loop_indices:layer.data[loop].uv=((7.5)/16,.5)
    wrist_bend=math.degrees((rot@Vector((1,0,0))).angle(-desired))
    return {'source_vertices':len(ids),'source_faces':source_face_count,'nail_faces':nail_faces,'wrist':list(wrist),'source_scale':scale,'palm_yaw_degrees':15,'palm_roll_degrees':25,'targets':targets,'continuous_skin_components':1,'pose_revision':150,'wrist_bend_degrees':wrist_bend,'cuff_distance_from_wrist_m':.072,'skin_colour_attribute':'SkinTone','finger_proximal_curl_degrees':proximal_angles,'thumb_posture':'low, along near side of foregrip'}
