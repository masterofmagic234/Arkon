"""Author the four park episodes and the Godot collision scene from one grid.

Run from the repository root. Output is committed, so no Python runs on Android.
The open park bends clockwise through three real bottlenecks; decorative scenery
is built separately and never changes this gameplay collision contract.
"""
from pathlib import Path
import re

W, H, CELL = 48, 36, 1.8
ORIGIN = (-42.3, -31.5)
grid = [['.' for _ in range(W)] for _ in range(H)]

def block(x0, y0, x1, y1):
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            grid[y][x] = '#'

def disk(cx, cy, r):
    for y in range(H):
        for x in range(W):
            if (x-cx)**2+(y-cy)**2 <= r*r:
                grid[y][x] = '#'

block(0, 0, W-1, 1); block(0, H-2, W-1, H-1)
block(0, 0, 1, H-1); block(W-2, 0, W-1, H-1)
block(24, 1, 24, H-2); block(1, 18, W-2, 18)
# Entrance: staggered hedges reveal the first oak, not a straight corridor.
block(2, 23, 6, 25); block(16, 26, 19, 31)
block(17, 20, 22, 22); disk(9, 28, 0.0)
# Garden: a crescent shore, with paths on both sides and a gazebo beyond it.
disk(10, 9, 3.0); disk(11, 10, 3.0)
block(17, 12, 20, 15); disk(5, 4, 1.0)
# Courtyard: broken walls offer cover and flank routes.
block(29, 5, 29, 12); block(29, 12, 33, 12)
block(38, 4, 42, 5); block(40, 9, 43, 10)
block(27, 15, 30, 16); disk(35, 7, 1.0)
# Final grove: the crown is visible over the hedge before entering.
disk(38, 27, 0.0); block(28, 23, 31, 25)
disk(43, 22, 1.0); block(26, 29, 28, 33)

gates = [(12, 18, 90), (24, 8, 0), (36, 18, 90)]
for x,y,_ in gates: grid[y][x] = '.'
items = {
    'Player': (5, 30),
    'Acorn01': (7, 28), 'Acorn02': (14, 24),
    'Acorn03': (16, 5), 'Acorn04': (34, 9),
    'Acorn05': (42, 14), 'Acorn06': (38, 25),
    'Key01': (20, 24), 'Key02': (19, 6), 'Key03': (43, 13),
    'Squirrel01': (12, 27), 'Squirrel02': (19, 24),
    'Squirrel03': (15, 8), 'Squirrel04': (35, 10),
    'Squirrel05': (36, 24), 'FakePineCone': (5, 7),
    'Exit': (43, 31), 'Secret': (4, 3),
}
for name,(x,y) in items.items():
    assert grid[y][x] == '.', (name, x, y)

def pos(x,y,h=0): return f'Vector3({ORIGIN[0]+x*CELL:.3f}, {h}, {ORIGIN[1]+y*CELL:.3f})'

data_path = Path('scripts/level_data.gd')
s = data_path.read_text()
s = re.sub(r'const MAP_WIDTH := \d+', f'const MAP_WIDTH := {W}', s)
s = re.sub(r'const MAP_HEIGHT := \d+', f'const MAP_HEIGHT := {H}', s)
s = re.sub(r'const MAP_WORLD_ORIGIN := Vector2\([^\n]+', f'const MAP_WORLD_ORIGIN := Vector2({ORIGIN[0]}, {ORIGIN[1]})', s)
s = re.sub(r'const DOOR_CELLS := \[[^\n]+', 'const DOOR_CELLS := ['+', '.join(f'Vector2i({x}, {y})' for x,y,_ in gates)+']', s)
s = s[:s.index('const CANONICAL_MAP :=')] + 'const CANONICAL_MAP := [\n' + ''.join('    "'+''.join(row)+'",\n' for row in grid) + ']\n'
s += '\nconst PARK_CELLS := {\n' + ''.join(f'    "{n}": Vector2i({x}, {y}),\n' for n,(x,y) in items.items()) + '}\n'
s += '\nconst PATH_CELLS := [Vector2i(5,30),Vector2i(7,28),Vector2i(14,27),Vector2i(14,24),Vector2i(20,24),Vector2i(14,23),Vector2i(12,21),Vector2i(12,18),Vector2i(14,15),Vector2i(16,12),Vector2i(17,9),Vector2i(16,5),Vector2i(19,6),Vector2i(21,8),Vector2i(24,8),Vector2i(27,8),Vector2i(32,9),Vector2i(34,9),Vector2i(36,12),Vector2i(42,14),Vector2i(36,16),Vector2i(36,18),Vector2i(35,22),Vector2i(38,25),Vector2i(40,28),Vector2i(43,31)]\n'
s += '''
static func park_position(id: String, height: float = 0.0) -> Vector3:
    var p := cell_center_world(PARK_CELLS[id])
    p.y = height
    return p

static func episode_at(world: Vector3) -> int:
    var c := world_to_cell(world.x, world.z)
    if c.x < 24:
        return 0 if c.y > 18 else 1
    return 3 if c.y > 18 else 2

static func is_pond(cell: Vector2i) -> bool:
    return (Vector2(cell) - Vector2(10, 9)).length() <= 3.0 or (Vector2(cell) - Vector2(11, 10)).length() <= 3.0
'''
s += '\nstatic func on_gravel(world: Vector3) -> bool:\n    var p := Vector2(world.x,world.z)\n    for i in range(1,PATH_CELLS.size()):\n        var a3 := cell_center_world(PATH_CELLS[i-1])\n        var b3 := cell_center_world(PATH_CELLS[i])\n        var a := Vector2(a3.x,a3.z)\n        var b := Vector2(b3.x,b3.z)\n        var line := b-a\n        var closest := a+line*clampf((p-a).dot(line)/maxf(line.length_squared(),0.001),0.0,1.0)\n        if p.distance_squared_to(closest)<1.05: return true\n    return false\n'
data_path.write_text(s)

lines = ['[gd_scene load_steps=9 format=3]',
'[ext_resource type="Script" path="res://scripts/level1_layout_editor.gd" id="1_editor"]',
'[ext_resource type="Script" path="res://scripts/level1_door.gd" id="2_door"]',
'[sub_resource type="BoxShape3D" id="WallShape"]\nsize = Vector3(1.8, 3, 1.8)',
'[sub_resource type="BoxShape3D" id="PondShape"]\nsize = Vector3(1.8, 0.6, 1.8)',
'[sub_resource type="BoxShape3D" id="GateShape"]\nsize = Vector3(0.22, 2.6, 1.8)',
'[sub_resource type="BoxShape3D" id="ProximityShape"]\nsize = Vector3(3.8, 3, 3.8)',
'[sub_resource type="StandardMaterial3D" id="PreviewMat"]\nalbedo_color = Color(0.16, 0.24, 0.18, 1)',
'[sub_resource type="BoxMesh" id="PreviewMesh"]\nsize = Vector3(1.8, 2.3, 1.8)\nmaterial = SubResource("PreviewMat")',
'[node name="Level1Layout" type="Node3D"]\nscript = ExtResource("1_editor")',
'[node name="Walls" type="Node3D" parent="."]']
for y in range(H):
    for x in range(W):
        if grid[y][x] != '#': continue
        pond = ((x-10)**2+(y-9)**2 <= 9 or (x-11)**2+(y-10)**2 <= 9)
        n = f'MapWall_{x:02}_{y:02}'
        lines += [f'[node name="{n}" type="StaticBody3D" parent="Walls"]\nposition = {pos(x,y,0.3 if pond else 1.5)}',
            f'[node name="Collision" type="CollisionShape3D" parent="Walls/{n}"]\nshape = SubResource("'+('PondShape' if pond else 'WallShape')+'")',
            f'[node name="Mesh" type="MeshInstance3D" parent="Walls/{n}"]\nmesh = SubResource("PreviewMesh")\nvisible = false']
lines += ['[node name="Doors" type="Node3D" parent="."]']
for i,(x,y,angle) in enumerate(gates,1):
    n=f'Door{i:02}'
    lines += [f'[node name="{n}" type="Node3D" parent="Doors"]\nposition = {pos(x,y)}\nrotation_degrees = Vector3(0, {angle}, 0)\nscript = ExtResource("2_door")\nrequired_key = {i}',
    f'[node name="Pivot" type="Node3D" parent="Doors/{n}"]\nposition = Vector3(0, 0, -0.9)',
    f'[node name="Leaf" type="StaticBody3D" parent="Doors/{n}/Pivot"]\nposition = Vector3(0, 1.3, 0.9)',
    f'[node name="Collision" type="CollisionShape3D" parent="Doors/{n}/Pivot/Leaf"]\nshape = SubResource("GateShape")',
    f'[node name="Proximity" type="Area3D" parent="Doors/{n}"]\nposition = Vector3(0, 1, 0)\ncollision_layer = 0\ncollision_mask = 4',
    f'[node name="CollisionShape3D" type="CollisionShape3D" parent="Doors/{n}/Proximity"]\nshape = SubResource("ProximityShape")']
for n in ['Floor', 'Props', 'Pickups', 'Enemies']:
    lines += [f'[node name="{n}" type="Node3D" parent="."]']
Path('scenes/level1_layout.tscn').write_text('\n\n'.join(lines)+'\n')

game = Path('game.tscn'); s = game.read_text()
for n,(x,y) in items.items():
    if n in ('Exit', 'Secret'): continue
    h = 0.9 if n=='Player' else (0.95 if n.startswith('Squirrel') else 0.6)
    pattern = r'(\[node name="'+n+r'"[^\n]+\]\n)position = Vector3\([^\n]+'
    s = re.sub(pattern, lambda m: m[1]+'position = '+pos(x,y,h), s)
s = re.sub(r'(\[node name="Player"[^\n]+\]\nposition = Vector3\([^\n]+\n)(rotation_degrees = Vector3\([^\n]+\n)+',r'\1',s)
s = s.replace('position = '+pos(*items['Player'],0.9), 'position = '+pos(*items['Player'],0.9)+'\nrotation_degrees = Vector3(0, -30, 0)')
game.write_text(s)
print(f'Authored park: {W}x{H}, {sum(r.count("#") for r in grid)} solid cells, 4 episodes, 3 bottlenecks.')
