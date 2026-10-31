#!/usr/bin/env python3
"""Author three mobile vehicle meshes from the user's original tuned Camry.

The patrol keeps the donor body, normals, UVs and triangles, correcting the
four wheels' inherited unequal ground contacts by rigid translations. The
interceptor and wagon retain donor topology/UVs while reshaping selected body
regions; wheel assemblies move rigidly. Tiny accessories join the existing Body
surface. No new base vehicle or downloaded geometry is introduced.
"""
from __future__ import annotations
import argparse,ctypes,ctypes.util,hashlib,json,struct
from pathlib import Path
import numpy as np

ROOT=Path(__file__).resolve().parents[1]
SOURCE=ROOT/'toyota_camry_2018_point_tuned_clean.rar'
DONOR=ROOT/'assets/level2/camry/camry_runtime.glb'
OUT=ROOT/'assets/level2/fleet155'
SOURCE_SHA='e893dbff97f80866de61e37032b165e2b3fca0141ec58d436c711c1cdce8bf09'
ORIGINAL_GLB_SHA='69532ee1e7817a046ec961a5672248ee3ea9ac0d79b14115cec739a8a934a5d0'
DONOR_SHA='895392105cecb84d10364c0276e4757a83e9715662230b214f813490fa1c7b52'
PAINT_NODES={6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,32,38,39,40,41,43,44,45,53,54,58,59,64,65}
GLASS_NODES={55,60,66}
WHEELS={'front_left':(91,92,93,94),'front_right':(95,96,97,98),'rear_left':(99,100,101,102),'rear_right':(103,104,105,106)}
TIRES={'front_left':94,'front_right':95,'rear_left':101,'rear_right':103}

def sha(raw):return hashlib.sha256(raw).hexdigest()
def load_glb(raw):
    assert raw[:4]==b'glTF' and struct.unpack_from('<II',raw,4)==(2,len(raw))
    n,tag=struct.unpack_from('<II',raw,12);assert tag==0x4e4f534a
    doc=json.loads(raw[20:20+n]);m,tag=struct.unpack_from('<II',raw,20+n)
    assert tag==0x004e4942 and 28+n+m==len(raw)
    return doc,memoryview(raw)[28+n:]

def original_document():
    assert sha(SOURCE.read_bytes())==SOURCE_SHA
    lib=ctypes.CDLL(ctypes.util.find_library('archive'))
    lib.archive_read_new.restype=ctypes.c_void_p
    for name in ['archive_read_support_format_all','archive_read_support_filter_all','archive_read_free']:
        getattr(lib,name).argtypes=[ctypes.c_void_p]
    lib.archive_read_open_filename.argtypes=[ctypes.c_void_p,ctypes.c_char_p,ctypes.c_size_t]
    lib.archive_read_next_header.argtypes=[ctypes.c_void_p,ctypes.POINTER(ctypes.c_void_p)]
    lib.archive_entry_pathname.argtypes=[ctypes.c_void_p];lib.archive_entry_pathname.restype=ctypes.c_char_p
    lib.archive_entry_size.argtypes=[ctypes.c_void_p];lib.archive_entry_size.restype=ctypes.c_int64
    lib.archive_read_data.argtypes=[ctypes.c_void_p,ctypes.c_void_p,ctypes.c_size_t];lib.archive_read_data.restype=ctypes.c_ssize_t
    handle=lib.archive_read_new();lib.archive_read_support_filter_all(handle);lib.archive_read_support_format_all(handle)
    try:
        assert lib.archive_read_open_filename(handle,str(SOURCE).encode(),10240)==0
        entry=ctypes.c_void_p();assert lib.archive_read_next_header(handle,ctypes.byref(entry))==0
        filename=lib.archive_entry_pathname(entry).decode();size=lib.archive_entry_size(entry)
        assert filename.endswith('.glb (1)') and size==28991604
        buffer=ctypes.create_string_buffer(size);offset=0
        while offset<size:
            n=lib.archive_read_data(handle,ctypes.byref(buffer,offset),size-offset)
            assert n>0;offset+=n
        raw=buffer.raw;assert sha(raw)==ORIGINAL_GLB_SHA
        doc,_=load_glb(raw);return doc
    finally:lib.archive_read_free(handle)

def access(doc,binary,index):
    a=doc['accessors'][index];v=doc['bufferViews'][a['bufferView']]
    dtype={5121:'u1',5123:'<u2',5125:'<u4',5126:'<f4'}[a['componentType']]
    width={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4}[a['type']]
    item=np.dtype(dtype).itemsize;stride=v.get('byteStride',item*width)
    return np.ndarray((a['count'],width),dtype=dtype,buffer=binary,offset=v.get('byteOffset',0)+a.get('byteOffset',0),strides=(stride,item)).copy()

def node_surface(i):return 1 if 81<=i<=90 or i in [62,63] else (2 if 67<=i<=80 else 0)

def parts_from_original(doc):
    parts=[[],[],[]];offsets=[0,0,0]
    def visit(index):
        node=doc['nodes'][index]
        if 'mesh' in node:
            surface=node_surface(index)
            for primitive in doc['meshes'][node['mesh']]['primitives']:
                n=doc['accessors'][primitive['attributes']['POSITION']]['count']
                parts[surface].append({'node':index,'name':node['name'],'start':offsets[surface],'count':n})
                offsets[surface]+=n
        for child in node.get('children',[]):visit(child)
    for i in doc['scenes'][doc.get('scene',0)]['nodes']:visit(i)
    return parts

def smooth(lo,hi,value):
    t=np.clip((value-lo)/(hi-lo),0.0,1.0);return t*t*(3-2*t)

def wagon_z_profile(z):
    # Monotone cubic interpolation keeps the roof/window/boot transition
    # continuous, including its derivative. In particular the lower screen
    # follows the new upper body instead of remaining ahead of the roof edge.
    xs=np.array([-.52,-.50,-.43,-.34,-.274,-.12,-.05,.50])
    ys=np.array([-.53,-.51,-.478,-.449,-.407,-.12,-.05,.50])
    h=np.diff(xs);d=np.diff(ys)/h;m=np.zeros(len(xs));m[0]=d[0];m[-1]=d[-1]
    for i in range(1,len(xs)-1):
        w1=2*h[i]+h[i-1];w2=h[i]+2*h[i-1]
        m[i]=(w1+w2)/(w1/d[i-1]+w2/d[i])
    value=np.asarray(z);j=np.clip(np.searchsorted(xs,value,side='right')-1,0,len(xs)-2)
    t=(value-xs[j])/h[j]
    return (2*t**3-3*t**2+1)*ys[j]+(t**3-2*t**2+t)*h[j]*m[j]+(-2*t**3+3*t**2)*ys[j+1]+(t**3-t**2)*h[j]*m[j+1]

def body_warp(points,kind):
    p=np.asarray(points,dtype=np.float64);x,y,z=p.T;q=p.copy()
    if kind=='interceptor':
        q[:,2]=z+.056*(1-smooth(-.16,.10,z))-.016*smooth(.10,.32,z)+.009*(1-smooth(-.45,-.34,z))
        cabin=smooth(.19,.31,y)
        q[:,1]=y-.030*cabin*(.75+.25*smooth(-.20,.05,z))
        arches=np.exp(-((z-.298)/.085)**4)+np.exp(-((z+.278)/.085)**4)
        q[:,0]=x*(1.010-.010*cabin)+np.sign(x)*.004*arches*smooth(.11,.17,np.abs(x))*smooth(.04,.15,y)
    elif kind=='wagon':
        upper=smooth(.14,.205,y)
        q[:,2]=z+upper*(wagon_z_profile(z)-z)
        # Keep the donor roof height. The estate silhouette comes from its
        # long roof and compressed boot deck, not an inflated rear bubble.
        q[:,0]=x*(1-.008*smooth(.23,.33,y))
    else:assert kind=='patrol'
    return q

def changed_normals(points,normals,kind):
    if kind=='patrol':return normals.copy()
    epsilon=1e-5;columns=[]
    for axis in range(3):
        d=np.zeros(3);d[axis]=epsilon
        columns.append((body_warp(points+d,kind)-body_warp(points-d,kind))/(2*epsilon))
    jacobian=np.stack(columns,axis=2)
    assert np.linalg.det(jacobian).min()>.05,'Body remap folded/inverted'
    inv=np.linalg.inv(jacobian);n=np.einsum('ni,nij->nj',normals.astype(np.float64),inv)
    n/=np.maximum(np.linalg.norm(n,axis=1,keepdims=True),1e-12)
    return n.astype('<f4')

def box(points,faces,paint,label,semantic_g=255):
    # Explicit independent faces retain crisp accessory edges and flat normals.
    p=[];n=[];uv=[];ids=[];colors=[]
    for face in faces:
        v=np.asarray([points[i] for i in face],dtype=np.float64)
        normal=np.cross(v[1]-v[0],v[2]-v[0]);normal/=np.linalg.norm(normal)
        start=len(p);p.extend(v);n.extend([normal]*len(v))
        axes=[i for i in range(3) if i!=np.argmax(np.abs(normal))]
        planar=v[:,axes];minimum=planar.min(0);extent=planar.max(0)-minimum
        assert np.all(extent>1e-8),'Degenerate accessory texture coordinates'
        uv.extend(.4+.2*(planar-minimum)/extent)
        colors.extend([(255 if paint else 0,semantic_g,0,255)]*len(v))
        for j in range(1,len(face)-1):ids.extend([start,start+j,start+j+1])
    return {'p':np.asarray(p,dtype='<f4'),'n':np.asarray(n,dtype='<f4'),'uv':np.asarray(uv,dtype='<f4'),'ids':np.asarray(ids,dtype='<u4'),'colors':np.asarray(colors,dtype='u1'),'label':label}

def rectangular(low,high,paint,label,semantic_g=255):
    a=np.asarray(low);b=np.asarray(high)
    points=[(a[0],a[1],a[2]),(b[0],a[1],a[2]),(b[0],b[1],a[2]),(a[0],b[1],a[2]),(a[0],a[1],b[2]),(b[0],a[1],b[2]),(b[0],b[1],b[2]),(a[0],b[1],b[2])]
    return box(points,[(0,3,2,1),(4,5,6,7),(0,4,7,3),(1,2,6,5),(0,1,5,4),(3,7,6,2)],paint,label,semantic_g)

def lightbar(roof_height):
    """A single batched low-profile chamfered housing with six LED chambers."""
    bottom=roof_height+.004;top=bottom+.013;z=-.055
    footprint=[(-.091,-.020),(.091,-.020),(.102,-.009),(.102,.009),(.091,.020),(-.091,.020),(-.102,.009),(-.102,-.009)]
    points=[(x,bottom,z+depth) for x,depth in footprint]+[(x*.975,top,z+depth*.82) for x,depth in footprint]
    faces=[tuple(range(7,-1,-1)),tuple(range(8,16))]+[(i,(i+1)%8,(i+1)%8+8,i+8) for i in range(8)]
    result=[box(points,faces,False,'beacon_chamfered_housing',128)]
    for side in [-1,1]:
        x=side*.065
        result.append(rectangular((x-.009,roof_height-.001,z-.010),(x+.009,bottom,z+.010),False,'beacon_mount',128))
        for j in range(3):
            centre=side*(.017+j*.026)
            result.append(rectangular((centre-.011,bottom+.003,z-.0205),(centre+.011,top-.002,z+.0205),False,('blue' if side<0 else 'red')+'_led_chamber_%d'%j,191 if side<0 else 64))
    return result

def swept_sections(sections,paint,label):
    width=len(sections[0]);points=[p for section in sections for p in section]
    faces=[tuple(range(width-1,-1,-1)),tuple(range((len(sections)-1)*width,len(sections)*width))]
    for i in range(len(sections)-1):
        a=i*width;b=(i+1)*width
        faces.extend((a+j,a+(j+1)%width,b+(j+1)%width,b+j) for j in range(width))
    return box(points,faces,paint,label)

def near_lateral(points,x):
    chosen=points[np.abs(points[:,0]-x)<.018]
    return chosen if len(chosen)>=3 else points[np.argsort(np.abs(points[:,0]-x))[:8]]

def conformal_splitter(front_lip):
    sections=[]
    for x in np.linspace(front_lip[:,0].min()+.003,front_lip[:,0].max()-.003,9):
        near=near_lateral(front_lip,x);front=float(near[:,2].max())
        edge=near[near[:,2]>front-.010];top=float(edge[:,1].min())+.0012
        back=front-.010;front+=.0035
        sections.append([(x,top,back),(x,top-.001,front-.001),(x,top-.004,front),(x,top-.004,back)])
    return swept_sections(sections,False,'conformal_front_lip')

def conformal_ducktail(boot):
    sections=[];half=max(abs(boot[:,0].min()),abs(boot[:,0].max()))
    for x in np.linspace(boot[:,0].min()+.005,boot[:,0].max()-.005,9):
        near=near_lateral(boot,x);rear=float(near[:,2].min());edge=near[near[:,2]<rear+.008]
        contact=float(edge[:,1].max());rise=.004*(1-.4*(abs(x)/half)**4)
        outer=rear-.0015;inner=rear+.010
        sections.append([(x,contact+rise,outer),(x,contact+.0005,inner),(x,contact-.0015,inner),(x,contact+rise-.0018,outer)])
    return swept_sections(sections,True,'moulded_boot_edge_ducktail')

def roof_height(triangles,x,z):
    a=triangles[:,0];b=triangles[:,1];c=triangles[:,2]
    dx1=b[:,0]-a[:,0];dz1=b[:,2]-a[:,2];dx2=c[:,0]-a[:,0];dz2=c[:,2]-a[:,2]
    det=dx1*dz2-dz1*dx2;valid=np.abs(det)>1e-12
    u=np.zeros(len(det));v=np.zeros(len(det))
    u[valid]=((x-a[valid,0])*dz2[valid]-(z-a[valid,2])*dx2[valid])/det[valid]
    v[valid]=(dx1[valid]*(z-a[valid,2])-dz1[valid]*(x-a[valid,0]))/det[valid]
    inside=valid&(u>=-.0001)&(v>=-.0001)&(u+v<=1.0001)
    assert inside.any(),('Rail support lies outside actual donor roof',x,z)
    return float((a[:,1]+u*(b[:,1]-a[:,1])+v*(c[:,1]-a[:,1]))[inside].max())

def subtle_roof_rails(roof_triangles,roof_points):
    result=[]
    zstations=np.linspace(float(roof_points[:,2].min())+.035,float(roof_points[:,2].max())-.025,7)
    for side in [-1,1]:
        x=side*.104;sections=[]
        for z in zstations:
            y=roof_height(roof_triangles,x,float(z))+.004
            sections.append([(x+.0025*np.cos(t),y+.0017*np.sin(t),float(z)) for t in np.linspace(0,2*np.pi,7)[:-1]])
        result.append(swept_sections(sections,False,'conformal_roof_rail_left' if side<0 else 'conformal_roof_rail_right'))
        for z in zstations[[0,3,6]]:
            y=roof_height(roof_triangles,x,float(z))
            result.append(rectangular((x-.0035,y-.001,float(z)-.008),(x+.0035,y+.004,float(z)+.008),False,'attached_rail_foot'))
    return result

def accessories(kind,body,body_parts,roof_points,roof_triangles):
    if kind=='patrol':return []
    if kind=='interceptor':
        def panel(node):
            row=body_parts[node];return body[row['start']:row['start']+row['count']]
        result=[conformal_splitter(panel(10)),conformal_ducktail(panel(16))]
        for side in [-1,1]:
            x=side*.063
            hood=panel(8);nearest=hood[np.argsort((hood[:,0]-x)**2+(hood[:,2]-.30)**2)[:4]]
            y=float(nearest[:,1].mean())
            result.append(rectangular((x-.013,y-.001,.277),(x+.013,y+.0015,.324),False,'flush_hood_vent_left' if side<0 else 'flush_hood_vent_right'))
        return result
    assert kind=='wagon'
    return subtle_roof_rails(roof_triangles,roof_points)

def write_glb(surfaces,path,name):
    data=bytearray();g={'asset':{'version':'2.0','generator':'Arkon Camry donor fleet155'},'bufferViews':[],'accessors':[],'buffers':[],'images':[],'textures':[],'materials':[], 'meshes':[],'nodes':[{'name':name,'mesh':0}],'scenes':[{'nodes':[0]}],'scene':0}
    def put(array,kind,component=5126,normalized=False):
        while len(data)%4:data.append(0)
        vi=len(g['bufferViews']);g['bufferViews'].append({'buffer':0,'byteOffset':len(data),'byteLength':array.nbytes});data.extend(array.tobytes())
        a={'bufferView':vi,'componentType':component,'count':len(array),'type':kind}
        if normalized:a['normalized']=True
        if kind=='VEC3':a.update(min=array.min(0).tolist(),max=array.max(0).tolist())
        i=len(g['accessors']);g['accessors'].append(a);return i
    for filename in ['camry_normal.jpg','camry_basecolor.jpg','camry_rear_emission.jpg','camry_front_emission.jpg']:
        i=len(g['images']);g['images'].append({'uri':'../camry/'+filename});g['textures'].append({'source':i})
    for i,label in enumerate(['Body','RearLenses','FrontLenses']):
        material={'name':label,'doubleSided':True,'normalTexture':{'index':0},'pbrMetallicRoughness':{'baseColorTexture':{'index':1},'metallicFactor':0,'roughnessFactor':.5}}
        if i:material.update(emissiveFactor=[1,1,1],emissiveTexture={'index':2 if i==1 else 3})
        g['materials'].append(material)
    primitives=[]
    for i,s in enumerate(surfaces):
        primitives.append({'attributes':{'POSITION':put(s['p'],'VEC3'),'NORMAL':put(s['n'],'VEC3'),'TEXCOORD_0':put(s['uv'],'VEC2'),'COLOR_0':put(s['colors'],'VEC4',5121,True)},'indices':put(s['ids'],'SCALAR',5125),'material':i})
    g['meshes']=[{'name':name,'primitives':primitives}];g['buffers']=[{'byteLength':len(data)}]
    header=json.dumps(g,separators=(',',':')).encode();header+=b' '*(-len(header)%4);data+=b'\0'*(-len(data)%4)
    raw=struct.pack('<4sII',b'glTF',2,28+len(header)+len(data))+struct.pack('<I4s',len(header),b'JSON')+header+struct.pack('<I4s',len(data),b'BIN\0')+data
    path.write_bytes(raw);return sha(raw)

def build():
    original=original_document();raw=DONOR.read_bytes();assert sha(raw)==DONOR_SHA
    doc,binary=load_glb(raw);parts=parts_from_original(original)
    donor=[]
    for index,primitive in enumerate(doc['meshes'][0]['primitives']):
        attrs=primitive['attributes'];p=access(doc,binary,attrs['POSITION']);colors=np.zeros((len(p),4),dtype='u1');colors[:,3]=255
        assert sum(row['count'] for row in parts[index])==len(p)
        for row in parts[index]:
            sl=slice(row['start'],row['start']+row['count']);colors[sl,0]=255 if index==0 and row['node'] in PAINT_NODES else 0
            colors[sl,2]=255 if index==0 and row['node'] in GLASS_NODES else 0
        donor.append({'p':p,'n':access(doc,binary,attrs['NORMAL']),'uv':access(doc,binary,attrs['TEXCOORD_0']),'ids':access(doc,binary,primitive['indices']).ravel(),'colors':colors})
    low=np.concatenate([s['p'] for s in donor]).min(0);high=np.concatenate([s['p'] for s in donor]).max(0);metres=4.88/(high[2]-low[2])
    body_parts={row['node']:row for row in parts[0]};wheel_indices={}
    for label,nodes in WHEELS.items():
        wheel_indices[label]=np.concatenate([np.arange(body_parts[n]['start'],body_parts[n]['start']+body_parts[n]['count']) for n in nodes])
    OUT.mkdir(parents=True,exist_ok=True);variants=[]
    for kind,name in [('patrol','CamryPatrol'),('interceptor','CamryInterceptor'),('wagon','CamryWagon')]:
        surfaces=[{k:v.copy() for k,v in s.items()} for s in donor]
        wheels=[]
        for s in surfaces:s['p']=body_warp(s['p'],kind).astype('<f4')
        for si,s in enumerate(surfaces):s['n']=changed_normals(donor[si]['p'],donor[si]['n'],kind)
        for label,ids in wheel_indices.items():
            before=donor[0]['p'][ids];centre=(before.min(0)+before.max(0))*.5;translation=np.zeros(3)
            translation[1]=-before[:,1].min()
            if kind!='patrol':
                translation[2]=body_warp(centre[None,:],kind)[0,2]-centre[2]
                if kind=='interceptor':translation[0]=np.sign(centre[0])*.004
            surfaces[0]['p'][ids]=(before+translation).astype('<f4');surfaces[0]['n'][ids]=donor[0]['n'][ids]
            after=surfaces[0]['p'][ids];assert np.max(np.abs((after-before)-translation))<1e-7
            tire=body_parts[TIRES[label]];tire_ids=np.arange(tire['start'],tire['start']+tire['count']);t=surfaces[0]['p'][tire_ids]
            wheels.append({'name':label,'source_nodes':list(WHEELS[label]),'body_vertex_ranges':[[body_parts[n]['start'],body_parts[n]['count']] for n in WHEELS[label]],'tire_body_vertex_range':[tire['start'],tire['count']],'rigid_translation_units':translation.tolist(),'bounds_min_units':after.min(0).tolist(),'bounds_max_units':after.max(0).tolist(),'ground_min_metres':float(after[:,1].min()*metres),'tire_yz_extents_metres':((t.max(0)-t.min(0))[[1,2]]*metres).tolist(),'tire_centre_units':((t.max(0)+t.min(0))*.5).tolist()})
        roof=body_parts[19];roofp=surfaces[0]['p'][roof['start']:roof['start']+roof['count']]
        donor_triangles=surfaces[0]['ids'].reshape(-1,3)
        # The donor roof spans multiple connected parts (outer quarters,
        # centre panel and aperture frames). Raycast the full high shell so
        # rail mounts follow the visible roof, including those seams.
        roof_ids=donor_triangles[np.max(surfaces[0]['p'][donor_triangles][:,:,1],axis=1)>.23]
        roof_triangles=surfaces[0]['p'][roof_ids]
        added=accessories(kind,surfaces[0]['p'],body_parts,roofp,roof_triangles)+lightbar(float(roofp[:,1].max()));accessory_rows=[]
        for a in added:
            s=surfaces[0];offset=len(s['p']);start=len(s['ids'])
            for k in ['p','n','uv','colors']:s[k]=np.concatenate([s[k],a[k]])
            s['ids']=np.concatenate([s['ids'],a['ids']+offset]).astype('<u4')
            accessory_rows.append({'name':a['label'],'body_vertex_start':offset,'vertices':len(a['p']),'body_index_start':start,'triangles':len(a['ids'])//3})
        allp=np.concatenate([s['p'] for s in surfaces]);a=allp.min(0);b=allp.max(0)
        for si,s in enumerate(surfaces):
            d=donor[si];assert np.array_equal(s['ids'][:len(d['ids'])],d['ids']) and np.array_equal(s['uv'][:len(d['uv'])],d['uv'])
            assert np.isfinite(s['p']).all() and np.isfinite(s['n']).all() and np.max(np.abs(np.linalg.norm(s['n'],axis=1)-1))<1e-4
            if kind=='patrol':
                assert all(np.array_equal(s[k][:len(d[k])],d[k]) for k in ['n','uv','ids'])
                keep=np.ones(len(d['p']),dtype=bool)
                if si==0:
                    for ids in wheel_indices.values():keep[ids]=False
                assert np.array_equal(s['p'][:len(d['p'])][keep],d['p'][keep])
        filename=f'camry_{kind}.glb';path=OUT/filename;digest=write_glb(surfaces,path,name)
        changed=sum(np.count_nonzero(np.any(s['p'][:len(d['p'])]!=d['p'],axis=1)) for s,d in zip(surfaces,donor))
        variants.append({'id':kind,'name':name,'file':'assets/level2/fleet155/'+filename,'sha256':digest,'bytes':path.stat().st_size,'source_vertices':sum(len(d['p']) for d in donor),'retained_source_triangles':sum(len(d['ids'])//3 for d in donor),'changed_original_vertices':int(changed),'added_vertices':sum(len(s['p'])-len(d['p']) for s,d in zip(surfaces,donor)),'added_triangles':sum(len(s['ids'])//3-len(d['ids'])//3 for s,d in zip(surfaces,donor)),'total_triangles':sum(len(s['ids'])//3 for s in surfaces),'surfaces':['Body','RearLenses','FrontLenses'],'scale_metres_per_unit':float(metres),'bounds_min_units':a.tolist(),'bounds_max_units':b.tolist(),'dimensions_metres':((b-a)*metres).tolist(),'base_position_metres':(-np.array([(a[0]+b[0])*.5,a[1],(a[2]+b[2])*.5])*metres).tolist(),'roof_source_node':19,'roof_bounds_min_units':roofp.min(0).tolist(),'roof_bounds_max_units':roofp.max(0).tolist(),'roof_height_metres':float(roofp[:,1].max()*metres),'lightbar_width_metres':float(.204*metres),'wheels':wheels,'accessories':accessory_rows,'original_uvs_and_indices_exact':True,'original_geometry_prefix_exact':False,'patrol_body_exact_except_declared_rigid_wheel_ground_corrections':kind=='patrol','whole_object_rescale_only':False,'normal_method':'Donor normals exact for patrol/wheels; inverse Jacobian of smooth body remap for changed panels; new accessory faces use geometric flat normals.'})
        print(f'FLEET155 {kind}: {variants[-1]["total_triangles"]} triangles; {np.round((b-a)*metres,3)} metres; {changed} donor vertices reshaped')
    manifest={'version':155,'tool':'tools/author_camry_fleet155.py','tool_sha256':sha(Path(__file__).read_bytes()),'source_rar':'toyota_camry_2018_point_tuned_clean.rar','source_rar_sha256':SOURCE_SHA,'original_glb_sha256':ORIGINAL_GLB_SHA,'donor_runtime':'assets/level2/camry/camry_runtime.glb','donor_runtime_sha256':DONOR_SHA,'all_main_vehicle_geometry_from_user_camry':True,'original_archive_and_runtime_unchanged':True,'source_parts':parts,'paint_source_nodes':sorted(PAINT_NODES),'vertex_color_contract':{'R':'Full exterior paint coverage from audited source parts; retain restrained original luminance detail. Glass, mirrors and protected trim use R0.','G':'0 donor,1 generic added accessory,.5 beaconhousing,.75 blueLED,.25 redLED (RGBA8quantized). GenericR0 accessories charcoaltrim,R1 painted; beacontriangles independentuniformflash.','B':'Glass-node membership (source55/60mirrors and66glazing).','A':'1'},'variants':variants,'authorship':'Compact: body region remap shortens rear overhang and wheelbase, lowers cabin and flares fenders; rigid donor wheel assemblies, a thin conformal front lip and moulded ducktail sampled from actual donor bumper/boot contours, plus flush hood vents. Wagon: donor upper roof/pillars/glazing and boot remapped by one monotone Z profile, retaining original Y heights and producing a longer roof, coherent steep rear screen and compressed boot deck. Thin rails raycast the actual high donor shell and sit on short attached mounts. Patrol: donor body exact except explicit rigid wheel Y corrections that resolve inherited unequal ground contacts; normals/UVs/triangles unchanged. All3include a batched chamfered six-chamber lightbar and two roofmounts.'}
    (OUT/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
    print('CAMRY FLEET155 AUTHORING: PASS')

if __name__=='__main__':
    argparse.ArgumentParser(description=__doc__).parse_args();build()
