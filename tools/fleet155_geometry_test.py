#!/usr/bin/env python3
"""Inspect committed Camry-derived GLB bytes; no engine or authoring code execution.

Checks source topology/UV retention, actual structural shape changes, rigid round
grounded wheel assemblies, glass paint exclusions and mobile geometry budgets.
"""
from __future__ import annotations
import argparse,hashlib,json,struct
from pathlib import Path
import numpy as np

ROOT=Path(__file__).resolve().parents[1]

def sha(path):return hashlib.sha256(Path(path).read_bytes()).hexdigest()

def require(value,message):
    if not value:raise AssertionError(message)

class GLB:
    def __init__(self,path):
        self.raw=Path(path).read_bytes()
        require(self.raw[:4]==b'glTF' and struct.unpack_from('<II',self.raw,4)==(2,len(self.raw)),'Invalid GLB envelope '+str(path))
        n,tag=struct.unpack_from('<II',self.raw,12)
        require(tag==0x4e4f534a,'Missing GLB JSON')
        self.doc=json.loads(self.raw[20:20+n]);size,tag=struct.unpack_from('<II',self.raw,20+n)
        require(tag==0x004e4942 and 28+n+size==len(self.raw),'Invalid GLB BIN envelope')
        self.binary=memoryview(self.raw)[28+n:]
    def accessor(self,index):
        a=self.doc['accessors'][index];v=self.doc['bufferViews'][a['bufferView']]
        dtype={5121:'u1',5123:'<u2',5125:'<u4',5126:'<f4'}[a['componentType']]
        width={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4}[a['type']]
        size=np.dtype(dtype).itemsize
        return np.ndarray((a['count'],width),dtype=dtype,buffer=self.binary,
            offset=v.get('byteOffset',0)+a.get('byteOffset',0),strides=(v.get('byteStride',size*width),size)).copy()
    def primitive(self,index):return self.doc['meshes'][0]['primitives'][index]
    def attribute(self,surface,name):return self.accessor(self.primitive(surface)['attributes'][name])

def inspect(manifest):
    donor=GLB(ROOT/manifest['donor_runtime'])
    require(sha(ROOT/manifest['tool'])==manifest['tool_sha256'],'Authoring provenance tool differs from manifest')
    require(sha(ROOT/manifest['source_rar'])==manifest['source_rar_sha256'],'User original Camry archive changed')
    require(sha(ROOT/manifest['donor_runtime'])==manifest['donor_runtime_sha256'],'Actual donor differs from provenance')
    require(manifest['all_main_vehicle_geometry_from_user_camry'] is True,'Fleet must derive from user Camry')
    require(len(manifest['variants'])==3,'Expected patrol and two derivatives')
    source=[donor.attribute(i,'POSITION') for i in range(3)]
    source_uv=[donor.attribute(i,'TEXCOORD_0') for i in range(3)]
    source_indices=[donor.accessor(donor.primitive(i)['indices']) for i in range(3)]
    source_normals=donor.attribute(0,'NORMAL')
    rows=[]
    for variant in manifest['variants']:
        path=ROOT/variant['file'];g=GLB(path)
        require(sha(path)==variant['sha256'],'Actual fleet GLB differs from manifest '+variant['id'])
        primitives=g.doc['meshes'][0]['primitives']
        require(len(primitives)==3,'Fleet draw surfaces changed')
        positions=[g.attribute(i,'POSITION') for i in range(3)]
        triangles=sum(len(g.accessor(p['indices']))//3 for p in primitives)
        require(63813<=triangles<=67000,'Unexpected mobile triangle budget')
        for i in range(3):
            require(np.array_equal(g.attribute(i,'TEXCOORD_0')[:len(source_uv[i])],source_uv[i]),'Source UVs changed')
            require(np.array_equal(g.accessor(primitives[i]['indices'])[:len(source_indices[i])],source_indices[i]),'Source triangle topology changed')
            normals=g.attribute(i,'NORMAL')
            require(np.isfinite(positions[i]).all() and np.isfinite(normals).all(),'Nonfinite actual geometry')
            require(np.allclose(np.linalg.norm(normals,axis=1),1,atol=.01),'Actual normals not normalized')
        scale=float(variant['scale_metres_per_unit'])
        require(abs(scale-4.882830619812012)<1e-5,'Variant changes donor unit scale')
        all_positions=np.concatenate(positions)
        minimum=all_positions.min(axis=0);maximum=all_positions.max(axis=0)
        actual_size=(maximum-minimum)*scale
        require(np.allclose(actual_size,variant['dimensions_metres'],atol=1e-5),'Actual fitted dimensions differ from manifest')
        require(abs(float(minimum[1])*scale)<.001,'Actual mesh AABB below/above floor')
        colors=g.attribute(0,'COLOR_0')
        require(len(colors)==len(positions[0]),'Missing actual semantic color attributes')
        source_parts=manifest['source_parts'][0]
        for node in [55,60,66]:
            part=next(p for p in source_parts if p['node']==node)
            mask=colors[part['start']:part['start']+part['count']]
            require(np.max(mask[:,0])<.01 and np.min(mask[:,2])>.99,'Glass or mirrored pink reflections receive body paint')
        affine=np.column_stack((source[0],np.ones(len(source[0]))))
        actual_prefix=positions[0][:len(source[0])]
        fitted=np.linalg.lstsq(affine,actual_prefix,rcond=None)[0]
        residual=float(np.sqrt(np.mean(np.square(affine@fitted-actual_prefix)))*scale)
        changed=int(np.count_nonzero(np.linalg.norm(actual_prefix-source[0],axis=1)>1e-7))
        if variant['id']!='patrol':
            require(changed>5000,'Derivative retains essentially unchanged source shape')
            require(residual>.003,'Derivative only applies whole-object affine resize')
        wheels=[]
        for wheel in variant['wheels']:
            ids=np.concatenate([np.arange(start,start+count) for start,count in wheel['body_vertex_ranges']])
            original=source[0][ids];actual=positions[0][ids]
            delta=actual-original;translation=delta.mean(axis=0)
            rigid_error=float(np.max(np.abs(delta-translation))*scale)
            require(rigid_error<1e-5,'Wheel assembly was bent/stretched '+variant['id']+'/'+wheel['name'])
            require(np.array_equal(g.attribute(0,'NORMAL')[ids],source_normals[ids]),'Rigid wheel normals changed')
            start,count=wheel['tire_body_vertex_range'];tire=positions[0][start:start+count]
            extents=np.ptp(tire,axis=0)*scale
            roundness=float(extents[1]/extents[2])
            require(.97<roundness<1.03,'Actual tire is oval '+variant['id']+'/'+wheel['name'])
            ground=float(tire[:,1].min()*scale)
            require(abs(ground)<.002,'Actual tire floats/sinks '+variant['id']+'/'+wheel['name'])
            wheels.append({'name':wheel['name'],'actual_ground_min_metres':ground,'actual_yz_diameters_metres':[float(extents[1]),float(extents[2])],'roundness_ratio':roundness,'rigid_translation_metres':(translation*scale).tolist(),'maximum_nonrigid_error_metres':rigid_error})
        if variant['id']=='patrol':
            wheel_ids=np.concatenate([np.arange(start,start+count) for wheel in variant['wheels'] for start,count in wheel['body_vertex_ranges']])
            nonwheel=np.ones(len(source[0]),dtype=bool);nonwheel[wheel_ids]=False
            require(np.array_equal(actual_prefix[nonwheel],source[0][nonwheel]),'Patrol changed donor body outside declared rigid wheel corrections')
            for i in [1,2]:require(np.array_equal(positions[i],source[i]),'Patrol donor lens geometry changed')
        rows.append({'id':variant['id'],'file':variant['file'],'actual_sha256':sha(path),'triangles':triangles,'surfaces':3,'source_uvs_and_triangle_prefix_exact':True,'actual_dimensions_metres':actual_size.tolist(),'actual_changed_body_vertices':changed,'best_whole_affine_fit_residual_metres':residual,'glass_and_mirror_gate_excluded':True,'wheels':wheels,'patrol_body_exact_except_rigid_grounded_wheels':True if variant['id']=='patrol' else None})
    return rows

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--manifest',type=Path,default=ROOT/'assets/level2/fleet155/manifest.json')
    parser.add_argument('--output',type=Path,default=Path('/tmp/fleet155-geometry/report.json'))
    args=parser.parse_args();args.output.parent.mkdir(parents=True,exist_ok=True)
    report={'result':'RUNNING','scope':'Nonexecuting inspection of actual GLB buffers and retained current Camry donor; geometry/UV/topology/wheel invariants, not subjective appearance or phone rendering.','manifest_sha256':sha(args.manifest)}
    try:
        report['variants']=inspect(json.loads(args.manifest.read_text()));report['result']='PASS'
    except Exception as error:
        report.update(result='FAIL',failure=str(error));raise
    finally:args.output.write_text(json.dumps(report,indent=2)+'\n')
    print('FLEET155 GEOMETRY: PASS')

if __name__=='__main__':main()
