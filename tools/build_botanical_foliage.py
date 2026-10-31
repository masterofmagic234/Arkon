#!/usr/bin/env python3
"""Bake opaque interiors and narrow cutout fringes from authored foliage alpha.

Offline only: pip install Pillow numpy shapely mapbox-earcut. Generated geometry
keeps original atlas coordinates and card planes. Each LOD is derived from its
own filtered coverage, preserving small holes until they become subpixel.
"""
from pathlib import Path
import argparse,json
import numpy as np
from PIL import Image
from shapely.geometry import box, Polygon
from shapely.ops import unary_union
import mapbox_earcut

ROOT=Path(__file__).resolve().parents[1]
def polygons(g):
    if g.is_empty:return []
    return [g] if isinstance(g,Polygon) else [p for p in g.geoms if isinstance(p,Polygon)]
def geometry(mask):
    runs=[]
    for y,row in enumerate(mask):
        edges=np.diff(np.r_[False,row,False].astype(np.int8));starts=np.flatnonzero(edges==1);ends=np.flatnonzero(edges==-1)
        runs.extend(box(int(a),y,int(b),y+1) for a,b in zip(starts,ends))
    return unary_union(runs)
def triangles(g,n):
    vertices=[];indices=[]
    for p in polygons(g):
        rings=[np.asarray(p.exterior.coords)[:-1]]+[np.asarray(r.coords)[:-1] for r in p.interiors]
        xy=np.concatenate(rings);end=np.cumsum([len(r) for r in rings]).astype(np.uint32)
        idx=mapbox_earcut.triangulate_float64(xy,end)
        offset=len(vertices);vertices.extend((xy/n).tolist());indices.extend((idx+offset).tolist())
    return {'xy':vertices,'indices':indices,'area':g.area/(n*n)}
def build(out):
    source=Image.open(ROOT/'assets/level1/botanical/foliage_atlas.png').getchannel('A')
    tiles=[]
    for tile in range(6):
        levels=[]
        for n in [256,128,64,32,16,8,4]:
            alpha=np.asarray(source.resize((n*3,n*2),Image.Resampling.BOX))
            col,row=tile%3,tile//3;coverage=geometry(alpha[row*n:(row+1)*n,col*n:(col+1)*n]>=97)
            clip=box(n*.01,n*.01,n*.99,n*.99)
            epsilon=max(.08,n/128)
            padding=epsilon+.06
            core=coverage.buffer(-padding,join_style=2).simplify(epsilon,preserve_topology=True).intersection(clip)
            # Keep interiors inside coverage; avoid adding every stair-step
            # vertex back after simplification unless it actually protrudes.
            if not coverage.covers(core):core=core.intersection(coverage)
            outer=coverage.buffer(padding,join_style=2).simplify(epsilon,preserve_topology=True).intersection(clip)
            if not outer.covers(coverage.intersection(clip)):outer=outer.union(coverage.intersection(clip))
            edge=outer.difference(core)
            levels.append({'resolution':n,'core':triangles(core,n),'edge':triangles(edge,n)})
        tiles.append(levels)
        print('tile',tile,[(l['resolution'],round(l['core']['area'],3),round(l['edge']['area'],3),sum(len(l[k]['indices'])//3 for k in ['core','edge'])) for l in levels],flush=True)
    out.write_text(json.dumps({'source':'foliage_atlas.png','tiles':tiles},separators=(',',':'))+'\n')
if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--output',type=Path,required=True);build(p.parse_args().output)
