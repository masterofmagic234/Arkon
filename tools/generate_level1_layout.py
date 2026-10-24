"""Author the lake estate from macro spaces, not four rectangular sectors.

Outputs committed Godot data/collision and actor positions. Python is never
needed on the device. Run from repository root; --check verifies reproducibility.
"""
from pathlib import Path
import math,re,sys
from collections import deque
W,H,CELL=88,64,1.8
WALL_HEIGHT=2.05
ORIGIN=(-(W-1)*CELL/2,-(H-1)*CELL/2)
grid=[['#']*W for _ in range(H)]
hub_bridge=[(35,43),(40,42),(41,37),(44,30),(51,28),(55,28)]
def ellipse(cx,cy,rx,ry,value='.'):
 for y in range(H):
  for x in range(W):
   if ((x-cx)/rx)**2+((y-cy)/ry)**2<=1:grid[y][x]=value
def block(x0,y0,x1,y1,value='#'):
 for y in range(y0,y1+1):
  for x in range(x0,x1+1):grid[y][x]=value
def trail(points,radius=1.7):
 for a,b in zip(points,points[1:]):
  for y in range(H):
   for x in range(W):
    dx,dy=b[0]-a[0],b[1]-a[1];t=max(0,min(1,((x-a[0])*dx+(y-a[1])*dy)/(dx*dx+dy*dy)))
    if (x-a[0]-dx*t)**2+(y-a[1]-dy*t)**2<=radius*radius:grid[y][x]='.'
# Four irregular outdoor rooms; the lake is negative space and a global view.
ellipse(22,48,17,13);ellipse(34,42,5,4);ellipse(23,18,17,13);ellipse(20,7,8,4)
ellipse(65,19,18,14);ellipse(65,48,18,12)
trail([(20,39),(20,28)],2);trail([(37,16),(51,16)],2)
trail([(66,29),(66,41)],2)
trail([(34,28),(32,39)],1.4) # moon wicket, opened from the far side
trail(hub_bridge,2)
trail([(36,45),(51,45)],2) # return footbridge, released by the oak seal
# Make the real bottlenecks explicit, with wide landing areas on either side.
block(18,34,22,34);grid[34][20]='.'
block(44,14,44,18);grid[16][44]='.'
block(44,27,44,33);grid[30][44]='.'
block(64,35,68,35);grid[35][66]='.'
block(30,34,34,34);grid[34][32]='.'
block(44,43,44,47);grid[45][44]='.'
# Architecture and cover have purpose: two flanks, a sight break, or a reward.
cover_rects=[(10,40,12,43),(17,45,18,47),(24,40,24,43),
          (10,12,11,15),(34,10,35,14),(35,23,37,25),
          (56,10,58,13),(58,13,61,13),(65,20,65,24),
          (70,18,74,18),(76,27,78,29),(55,24,57,25),
          (55,42,57,44),(72,51,74,53),(63,47,65,49),(35,38,37,40)]
for r in cover_rects:block(*r)
# Small ring islands interrupt straight lines without creating dead ends.
ellipse(28,24,1,1,'#');ellipse(76,9,1,1,'#')
# Two actual water bodies. Every water sample remains blocked in physics/nav.
moon=lambda x,y:((x-23)/6)**2+((y-20)/5)**2<=1
lake=lambda x,y:((x-43)/10)**2+((y-38)/14)**2<=1
def water_at(x,y):
 return (moon(x,y) or lake(x,y)) and not any(a<=x<=c and b<=y<=d for a,b,c,d in cover_rects)
for y in range(H):
 for x in range(W):
  if moon(x,y):grid[y][x]='#'
items={
 'Player':(10,54),'Acorn01':(17,50),'Acorn02':(27,41),
 'Acorn03':(20,7),'Acorn04':(69,13),'Acorn05':(79,24),'Acorn06':(64,46),
 'Key01':(12,38),'Key02':(34,22),'Key03':(60,28),
 'Squirrel01':(22,46),'Squirrel02':(14,41),'Squirrel03':(28,13),
 'Squirrel04':(68,18),'Squirrel05':(64,43),
 'FakePineCone':(9,21),'Exit':(9,55),'Secret':(8,18),
}
gates=[('Door01',20,34,90,1),('Door02',44,30,0,1),('Door03',66,35,90,3),
       ('MoonWicket',32,34,90,0),('ReturnGate',44,45,0,0),('NorthWicket',44,16,0,0)]
# Surface routes are independent polylines. The quiet alternatives are grass.
paths=[[(10,54),(17,50),(19,52),(22,52),(24,48),(28,43),(27,39),(20,37),(20,34),(20,29)],
       [(17,50),(12,49),(8,46),(8,40),(12,38),(17,38),(20,37)],
       [(20,29),(16,27),(13,23),(13,18),(14,14),(17,10),(20,7),(25,9),(30,14),(33,18),(34,22),(32,27),(29,29),(20,29)],
       [(32,27),(34,28),(32,32),(32,34),(32,39),(28,43)],
       [(33,18),(37,16),(44,16),(51,16),(54,18),(59,19),(62,16),(64,12),(69,13),(74,14),(78,18),(79,24),(74,26),(69,28),(60,28),(60,23),(59,19)],
       [(69,28),(66,31),(66,35),(66,40),(69,43),(72,47),(70,53),(64,55),(58,52),(59,47),(63,45),(64,46)],
       [(59,47),(53,45),(48,45),(44,45),(38,45),(32,47),(24,48)],
       [(74,26),(80,24),(80,16),(78,11)],
       [(28,43),(31,43),(33,42),(34,41)],
       hub_bridge+[(60,28)]]
# Validate the graph, gate ordering, and that no authored target is in masonry.
for n,(x,y) in items.items():assert grid[y][x]=='.',(n,x,y)
def reachable(start,closed):
 seen={start};q=deque([start])
 while q:
  x,y=q.popleft()
  for p in [(x-1,y),(x+1,y),(x,y-1),(x,y+1)]:
   a,b=p
   if 0<=a<W and 0<=b<H and grid[b][a]=='.' and p not in closed and p not in seen:seen.add(p);q.append(p)
 return seen
closed={(x,y) for _,x,y,_,_ in gates}
assert items['Key01'] in reachable(items['Player'],closed)
assert items['Key02'] not in reachable(items['Player'],closed)
assert items['Key03'] not in reachable(items['Player'],closed)
closed.remove((20,34));closed.remove((44,30))
seen=reachable(items['Player'],closed)
assert items['Key02'] in seen and items['Key03'] in seen
assert items['Acorn06'] not in seen
closed.remove((66,35))
assert all(p in reachable(items['Player'],set()) for p in items.values())
old=Path('scripts/level_data.gd').read_text();prefix=old[:old.index('const CANONICAL_MAP :=')]
prefix=re.sub(r'const PARK_WALL_HEIGHT := [^\n]+',f'const PARK_WALL_HEIGHT := {WALL_HEIGHT}',prefix)
if 'const PARK_WALL_HEIGHT' not in prefix:prefix=prefix.replace('const CELL_SIZE := 1.8','const CELL_SIZE := 1.8\nconst PARK_WALL_HEIGHT := '+str(WALL_HEIGHT))
prefix=re.sub(r'const MAP_WIDTH := \d+',f'const MAP_WIDTH := {W}',prefix)
prefix=re.sub(r'const MAP_HEIGHT := \d+',f'const MAP_HEIGHT := {H}',prefix)
prefix=re.sub(r'const MAP_WORLD_ORIGIN := Vector2\([^\n]+',f'const MAP_WORLD_ORIGIN := Vector2({ORIGIN[0]:.1f}, {ORIGIN[1]:.1f})',prefix)
vec=lambda p:f'Vector2i({p[0]},{p[1]})'
prefix=re.sub(r'const DOOR_CELLS := \[[^\n]+','const DOOR_CELLS := ['+', '.join(vec((x,y)) for _,x,y,_,_ in gates[:3])+']',prefix)
data=prefix+'const CANONICAL_MAP := [\n'+''.join('    "'+''.join(row)+'",\n' for row in grid)+']\n\n'
data+='const PARK_CELLS := {\n'+''.join(f'    "{n}": {vec(p)},\n' for n,p in items.items())+'}\n'
data+='\nconst PATH_ROUTES := [\n'+''.join('    ['+','.join(map(vec,p))+'],\n' for p in paths)+']\n'
data+='const PATH_CELLS := PATH_ROUTES[0]\n'
data+='const COVER_RECTS := ['+','.join(f'Rect2i({a},{b},{c-a+1},{d-b+1})' for a,b,c,d in cover_rects)+']\n'
data+='const WATER_ROWS := [\n'+''.join('    "'+''.join('~' if grid[y][x]=='#' and water_at(x,y) else '.' for x in range(W))+'",\n' for y in range(H))+']\n'
data+='const GATE_APPROACH := [Vector2i(20,35),Vector2i(43,30),Vector2i(66,34)]\n'
data+='const SHORTCUT_CELLS := [Vector2i(32,34),Vector2i(44,45),Vector2i(44,16)]\n'
data+='const RETURN_BRIDGE_CELL := Vector2i(44,45)\n'
data+='const HUB_BRIDGE := ['+','.join(map(vec,hub_bridge))+']\n'
data+='const ZONE_GATE_LINKS := [[0,1,"Door01"],[0,1,"MoonWicket"],[0,2,"Door02"],[1,2,"NorthWicket"],[2,3,"Door03"],[0,3,"ReturnGate"]]\n'
data+='const MOON_CENTER := Vector2i(23,20)\nconst LAKE_CENTER := Vector2i(43,38)\nconst OAK_CELL := Vector2i(64,48)\nconst OBSERVATORY_CELL := Vector2i(20,7)\nconst TOWER_CELL := Vector2i(36,39)\n'
data+='''
static func park_position(id: String, height: float = 0.0) -> Vector3:
    var p := cell_center_world(PARK_CELLS[id])
    p.y = height
    return p

static func episode_at(world: Vector3) -> int:
    var c := world_to_cell(world.x,world.z)
    if c.x>=34 and c.y>=27 and c.y<=40: return 0 if c.x<44 else 2
    if c.y>=34: return 0 if c.x<44 else 3
    return 1 if c.x<44 else 2

static func is_pond(cell: Vector2i) -> bool:
    if cell.x<0 or cell.y<0 or cell.x>=MAP_WIDTH or cell.y>=MAP_HEIGHT: return false
    return WATER_ROWS[cell.y][cell.x]=="~"

static func on_gravel(world: Vector3) -> bool:
    var p := Vector2(world.x,world.z)
    for route in PATH_ROUTES:
        for i in range(1,route.size()):
            var a3 := cell_center_world(route[i-1])
            var b3 := cell_center_world(route[i])
            var a := Vector2(a3.x,a3.z)
            var b := Vector2(b3.x,b3.z)
            if p.distance_squared_to(Geometry2D.get_closest_point_to_segment(p,a,b))<1.45: return true
    return false
'''
pos=lambda x,y,h=0:f'Vector3({ORIGIN[0]+x*CELL:.3f}, {h}, {ORIGIN[1]+y*CELL:.3f})'
# Merge horizontal collision runs. Dense forest interiors cost no thousands of
# nodes; visible boundary geometry remains a separate, spatially culled layer.
def wall_height(x,y):
 if water_at(x,y):return .6
 for index,(a,b,c,d) in enumerate(cover_rects):
  if a<=x<=c and b<=y<=d and index in [0,14,15]:return 3.0
 return WALL_HEIGHT
runs=[]
for y in range(H):
 x=0
 while x<W:
  if grid[y][x]!='#':x+=1;continue
  height=wall_height(x,y);a=x;x+=1
  while x<W and grid[y][x]=='#' and wall_height(x,y)==height:x+=1
  runs.append((a,x-1,y,height))
shapes=sorted({(b-a+1,height) for a,b,y,height in runs})
lines=['[gd_scene load_steps='+str(5+len(shapes))+' format=3]',
 '[ext_resource type="Script" path="res://scripts/level1_layout_editor.gd" id="1_editor"]',
 '[ext_resource type="Script" path="res://scripts/level1_door.gd" id="2_door"]']
for length,height in shapes:
 lines.append(f'[sub_resource type="BoxShape3D" id="Run_{length}_{round(height*100)}"]\nsize = Vector3({length*CELL:.3f}, {height}, 1.8)')
lines+=['[sub_resource type="BoxShape3D" id="GateShape"]\nsize = Vector3(0.22, 2.0, 1.8)',
 '[sub_resource type="BoxShape3D" id="ProximityShape"]\nsize = Vector3(3.8, 3, 3.8)',
 '[node name="Level1Layout" type="Node3D"]\nscript = ExtResource("1_editor")',
 '[node name="Walls" type="Node3D" parent="."]']
for a,b,y,height in runs:
 n=f'MapRun_{a:02}_{y:02}'
 lines += [f'[node name="{n}" type="StaticBody3D" parent="Walls"]\nposition = {pos((a+b)/2,y,height*.5)}',
 f'[node name="Collision" type="CollisionShape3D" parent="Walls/{n}"]\nshape = SubResource("Run_{b-a+1}_{round(height*100)}")']
lines+=['[node name="Doors" type="Node3D" parent="."]']
for n,x,y,angle,key in gates:
 lines += [f'[node name="{n}" type="Node3D" parent="Doors"]\nposition = {pos(x,y)}\nrotation_degrees = Vector3(0, {angle}, 0)\nscript = ExtResource("2_door")\nrequired_key = {key}\nextra_required_key = {2 if n=="Door03" else 0}',
 f'[node name="Pivot" type="Node3D" parent="Doors/{n}"]\nposition = Vector3(0, 0, -0.9)',
 f'[node name="Leaf" type="StaticBody3D" parent="Doors/{n}/Pivot"]\nposition = Vector3(0, 1.0, 0.9)',
 f'[node name="Collision" type="CollisionShape3D" parent="Doors/{n}/Pivot/Leaf"]\nshape = SubResource("GateShape")',
 f'[node name="Proximity" type="Area3D" parent="Doors/{n}"]\nposition = Vector3(0, 1, 0)\ncollision_layer = 0\ncollision_mask = 4',
 f'[node name="CollisionShape3D" type="CollisionShape3D" parent="Doors/{n}/Proximity"]\nshape = SubResource("ProximityShape")']
for n in ['Floor','Props','Pickups','Enemies']:lines.append(f'[node name="{n}" type="Node3D" parent="."]')
scene='\n\n'.join(lines)+'\n'
s=Path('game.tscn').read_text()
for n,(x,y) in items.items():
 if n in ('Exit','Secret'):continue
 h=.9 if n=='Player' else (.95 if n.startswith('Squirrel') else .6)
 s=re.sub(r'(\[node name="'+n+r'"[^\n]+\]\n)position = Vector3\([^\n]+',lambda m:m[1]+'position = '+pos(x,y,h),s)
s=re.sub(r'(\[node name="Player"[^\n]+\]\nposition = Vector3\([^\n]+\n)(rotation_degrees = Vector3\([^\n]+\n)+',r'\1',s)
s=s.replace('position = '+pos(*items['Player'],.9),'position = '+pos(*items['Player'],.9)+'\nrotation_degrees = Vector3(0, -55, 0)')
outputs={'scripts/level_data.gd':data,'scenes/level1_layout.tscn':scene,'game.tscn':s}
for path,content in outputs.items():
 if '--check' in sys.argv:assert Path(path).read_text()==content,('stale generated layout',path)
 else:Path(path).write_text(content)
print(f'Lake estate: {W}x{H} / {W*CELL:.0f}x{H*CELL:.0f}m; {sum(r.count(".") for r in grid)} walkable cells; {len(runs)} collision runs; 3 gates + 3 real shortcuts.')
